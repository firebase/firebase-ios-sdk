/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"

#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/local/leveldb_util.h"
#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"
#include "absl/strings/escaping.h"
#include "absl/strings/str_cat.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::OrderedCode;

namespace firebase {
namespace firestore {
namespace local {

namespace {

const char *kVersionGlobalTable = "version";
const char *kMutationsTable = "mutation";
const char *kDocumentMutationsTable = "document_mutation";
const char *kMutationQueuesTable = "mutation_queue";
const char *kTargetGlobalTable = "target_global";
const char *kTargetsTable = "target";
const char *kQueryTargetsTable = "query_target";
const char *kTargetDocumentsTable = "target_document";
const char *kDocumentTargetsTable = "document_target";
const char *kRemoteDocumentsTable = "remote_document";

/**
 * Labels for the components of keys. These serve to make keys self-describing.
 *
 * These are intended to sort similarly to keys in the server storage format.
 *
 * Note that the server writes component labels using the equivalent to
 * OrderedCode::WriteSignedNumDecreasing. This means that despite the higher
 * numeric value, a terminator sorts before a path segment. In order to avoid
 * needing the WriteSignedNumDecreasing code just for these values, this enum's
 * values are in the reverse order to the server side.
 *
 * Most server-side values don't apply here. For example, the server embeds
 * projects, databases, namespaces and similar values in its entity keys where
 * the clients just open a different leveldb. Similarly, many of these values
 * don't apply to the server since the server is backed by spanner which
 * natively has concepts of tables and indexes. Where there's overlap, a comment
 * denotes the server value from the storage_format_internal.proto.
 */
enum ComponentLabel {
  /**
   * A terminator is the final component of a key. All complete keys have a
   * terminator and a key is known to be a key prefix if it doesn't have a
   * terminator.
   */
  Terminator = 0,  // TERMINATOR_COMPONENT = 63, server-side

  /**
   * A table name component names the logical table to which the key belongs.
   */
  TableName = 5,

  /** A component containing the batch Id of a mutation. */
  BatchId = 10,

  /** A component containing the canonical Id of a query. */
  CanonicalId = 11,

  /** A component containing the target Id of a query. */
  TargetId = 12,

  /** A component containing a user Id. */
  UserId = 13,

  /**
   * A path segment describes just a single segment in a resource path. Path
   * segments that occur sequentially in a key represent successive segments in
   * a single path.
   *
   * This value must be greater than ComponentLabel::Terminator to ensure that
   * longer paths sort after paths that are prefixes of them.
   *
   * This value must also be larger than other separators so that path suffixes
   * sort after other key components.
   */
  PathSegment = 62,  // PATH = 60, server-side

  /**
   * The maximum value that can be encoded by WriteSignedNumIncreasing in a
   * single byte.
   */
  Unknown = 63,
};

/** OrderedCode::ReadSignedNumIncreasing adapted to leveldb::Slice. */
bool ReadSignedNumIncreasing(leveldb::Slice *src, int64_t *result) {
  absl::string_view tmp = MakeStringView(*src);
  if (OrderedCode::ReadSignedNumIncreasing(&tmp, result)) {
    *src = MakeSlice(tmp);
    return true;
  }
  return false;
}

/** OrderedCode::ReadString adapted to leveldb::Slice. */
bool ReadString(leveldb::Slice *src, std::string *result) {
  absl::string_view tmp = MakeStringView(*src);
  if (OrderedCode::ReadString(&tmp, result)) {
    *src = MakeSlice(tmp);
    return true;
  }
  return false;
}

/** Writes a component label to the given key destination. */
void WriteComponentLabel(std::string *dest, ComponentLabel label) {
  OrderedCode::WriteSignedNumIncreasing(dest, label);
}

/**
 * Reads a component label from the given key contents.
 *
 * If the read is unsuccessful, returns false, and changes none of its
 * arguments.
 *
 * If the read is successful, returns true, contents will be updated to the next
 * unread byte, and label will be set to the decoded label value.
 */
bool ReadComponentLabel(leveldb::Slice *contents, ComponentLabel *label) {
  int64_t raw_result = 0;
  leveldb::Slice tmp = *contents;
  if (ReadSignedNumIncreasing(&tmp, &raw_result)) {
    if (raw_result >= ComponentLabel::Terminator &&
        raw_result <= ComponentLabel::Unknown) {
      *contents = tmp;
      *label = static_cast<ComponentLabel>(raw_result);
      return true;
    }
  }
  return false;
}

/**
 * Reads a component label from the given key contents.
 *
 * If the read is unsuccessful or if the read was successful but the label that
 * was read did not match the expected_label returns false and changes none of
 * its arguments.
 *
 * If the read is successful, returns true and contents will be updated to the
 * next unread byte.
 */
bool ReadComponentLabelMatching(leveldb::Slice *contents,
                                ComponentLabel expected_label) {
  int64_t raw_result = 0;
  leveldb::Slice tmp = *contents;
  if (ReadSignedNumIncreasing(&tmp, &raw_result)) {
    if (raw_result == expected_label) {
      *contents = tmp;
      return true;
    }
  }
  return false;
}

/**
 * Reads a signed number from the given key contents and verifies that the value
 * fits in a 32-bit integer.
 *
 * If the read is unsuccessful or the number that was read was out of bounds for
 * an int32_t, returns false, and changes none of its arguments.
 *
 * If the read is successful, returns true, contents will be updated to the next
 * unread byte, and result will be set to the decoded integer value.
 */
bool ReadInt32(leveldb::Slice *contents, int32_t *result) {
  int64_t raw_result = 0;
  leveldb::Slice tmp = *contents;
  if (ReadSignedNumIncreasing(&tmp, &raw_result)) {
    if (raw_result >= INT32_MIN && raw_result <= INT32_MAX) {
      *contents = tmp;
      *result = static_cast<int32_t>(raw_result);
      return true;
    }
  }
  return false;
}

/**
 * Writes a component label and a signed integer to the given key destination.
 */
void WriteLabeledInt32(std::string *dest, ComponentLabel label, int32_t value) {
  WriteComponentLabel(dest, label);
  OrderedCode::WriteSignedNumIncreasing(dest, value);
}

/**
 * Reads a component label and signed number from the given key contents and
 * verifies that the label matches the expected_label and the value fits in a
 * 32-bit integer.
 *
 * If the read is unsuccessful, the label didn't match, or the number that was
 * read was out of bounds for an int32_t, returns false, and changes none of its
 * arguments.
 *
 * If the read is successful, returns true, contents will be updated to the next
 * unread byte, and value will be set to the decoded integer value.
 */
bool ReadLabeledInt32(leveldb::Slice *contents,
                      ComponentLabel expected_label,
                      int32_t *value) {
  leveldb::Slice tmp = *contents;
  if (ReadComponentLabelMatching(&tmp, expected_label)) {
    if (ReadInt32(&tmp, value)) {
      *contents = tmp;
      return true;
    }
  }
  return false;
}

/**
 * Writes a component label and an encoded string to the given key destination.
 */
void WriteLabeledString(std::string *dest,
                        ComponentLabel label,
                        absl::string_view value) {
  WriteComponentLabel(dest, label);
  OrderedCode::WriteString(dest, value);
}

/**
 * Reads a component label and a string from the given key contents and verifies
 * that the label matches the expected_label.
 *
 * If the read is unsuccessful or the label didn't match, returns false, and
 * changes none of its arguments.
 *
 * If the read is successful, returns true, contents will be updated to the next
 * unread byte, and value will be set to the decoded string value.
 */
bool ReadLabeledString(leveldb::Slice *contents,
                       ComponentLabel expected_label,
                       std::string *value) {
  leveldb::Slice tmp = *contents;
  if (ReadComponentLabelMatching(&tmp, expected_label)) {
    if (ReadString(&tmp, value)) {
      *contents = tmp;
      return true;
    }
  }
  return false;
}

/**
 * Reads a component label and a string from the given key contents and verifies
 * that the label matches the expected_label and the string matches the
 * expected_value.
 *
 * If the read is unsuccessful, the label or didn't match, or the string value
 * didn't match, returns false, and changes none of its arguments.
 *
 * If the read is successful, returns true, contents will be updated to the next
 * unread byte.
 */
bool ReadLabeledStringMatching(leveldb::Slice *contents,
                               ComponentLabel expected_label,
                               const char *expected_value) {
  std::string value;
  leveldb::Slice tmp = *contents;
  if (ReadLabeledString(&tmp, expected_label, &value)) {
    if (value == expected_value) {
      *contents = tmp;
      return true;
    }
  }

  return false;
}

/**
 * For each segment in the given resource path writes an
 * ComponentLabel::PathSegment component label and a string containing the path
 * segment.
 */
void WriteResourcePath(std::string *dest, const ResourcePath &path) {
  for (const auto &segment : path) {
    WriteComponentLabel(dest, ComponentLabel::PathSegment);
    OrderedCode::WriteString(dest, segment);
  }
}

/**
 * Reads component labels and strings from the given key contents until it finds
 * a component label other that ComponentLabel::PathSegment. All matched path
 * segments are assembled into a resource path and wrapped in an DocumentKey.
 *
 * If the read is unsuccessful or the document key is invalid, returns false,
 * and changes none of its arguments.
 *
 * If the read is successful, returns true, contents will be updated to the next
 * unread byte, and value will be set to the decoded document key.
 */
bool ReadDocumentKey(leveldb::Slice *contents, DocumentKey *result) {
  leveldb::Slice complete_segments = *contents;

  std::string segment;
  std::vector<std::string> path_segments;
  for (;;) {
    // Advance a temporary slice to avoid advancing contents into the next key
    // component which may not be a path segment.
    leveldb::Slice read_position = complete_segments;
    if (!ReadComponentLabelMatching(&read_position,
                                    ComponentLabel::PathSegment)) {
      break;
    }
    if (!ReadString(&read_position, &segment)) {
      return false;
    }

    path_segments.push_back(std::move(segment));
    segment.clear();

    complete_segments = read_position;
  }

  ResourcePath path{std::move(path_segments)};
  if (path.size() > 0 && DocumentKey::IsDocumentKey(path)) {
    *contents = complete_segments;
    *result = DocumentKey{std::move(path)};
    return true;
  }

  return false;
}

// Trivial shortcuts that make reading and writing components type-safe.

inline void WriteTerminator(std::string *dest) {
  OrderedCode::WriteSignedNumIncreasing(dest, ComponentLabel::Terminator);
}

inline bool ReadTerminator(leveldb::Slice *contents) {
  return ReadComponentLabelMatching(contents, ComponentLabel::Terminator);
}

inline void WriteTableName(std::string *dest, const char *table_name) {
  WriteLabeledString(dest, ComponentLabel::TableName, table_name);
}

inline bool ReadTableNameMatching(leveldb::Slice *contents,
                                  const char *expected_table_name) {
  return ReadLabeledStringMatching(contents, ComponentLabel::TableName,
                                   expected_table_name);
}

inline void WriteBatchId(std::string *dest, model::BatchId batch_id) {
  WriteLabeledInt32(dest, ComponentLabel::BatchId, batch_id);
}

inline bool ReadBatchId(leveldb::Slice *contents, model::BatchId *batch_id) {
  return ReadLabeledInt32(contents, ComponentLabel::BatchId, batch_id);
}

inline void WriteCanonicalId(std::string *dest,
                             absl::string_view canonical_id) {
  WriteLabeledString(dest, ComponentLabel::CanonicalId, canonical_id);
}

inline bool ReadCanonicalId(leveldb::Slice *contents,
                            std::string *canonical_id) {
  return ReadLabeledString(contents, ComponentLabel::CanonicalId, canonical_id);
}

inline void WriteTargetId(std::string *dest, model::TargetId target_id) {
  WriteLabeledInt32(dest, ComponentLabel::TargetId, target_id);
}

inline bool ReadTargetId(leveldb::Slice *contents, model::TargetId *target_id) {
  return ReadLabeledInt32(contents, ComponentLabel::TargetId, target_id);
}

inline void WriteUserId(std::string *dest, absl::string_view user_id) {
  WriteLabeledString(dest, ComponentLabel::UserId, user_id);
}

inline bool ReadUserId(leveldb::Slice *contents, std::string *user_id) {
  return ReadLabeledString(contents, ComponentLabel::UserId, user_id);
}

/**
 * Returns a base64-encoded string for an invalid key, used for debug-friendly
 * description text.
 */
std::string InvalidKey(leveldb::Slice key) {
  std::string result;
  absl::Base64Escape(MakeStringView(key), &result);
  return result;
}

}  // namespace

std::string Describe(leveldb::Slice key) {
  leveldb::Slice contents = key;
  bool is_terminated = false;

  std::string description;
  absl::StrAppend(&description, "[");

  while (contents.size() > 0) {
    leveldb::Slice tmp = contents;
    ComponentLabel label = ComponentLabel::Unknown;
    if (!ReadComponentLabel(&tmp, &label)) {
      break;
    }

    if (label == ComponentLabel::Terminator) {
      is_terminated = true;
      contents = tmp;
      break;
    }

    // Reset tmp since all the different read routines expect to see the
    // separator first
    tmp = contents;

    if (label == ComponentLabel::PathSegment) {
      DocumentKey document_key;
      if (!ReadDocumentKey(&tmp, &document_key)) {
        break;
      }
      absl::StrAppend(&description,
                      " key=", document_key.path().CanonicalString());

    } else if (label == ComponentLabel::TableName) {
      std::string table;
      if (!ReadLabeledString(&tmp, ComponentLabel::TableName, &table)) {
        break;
      }
      absl::StrAppend(&description, table, ":");

    } else if (label == ComponentLabel::BatchId) {
      model::BatchId batch_id;
      if (!ReadBatchId(&tmp, &batch_id)) {
        break;
      }
      absl::StrAppend(&description, " batch_id=", batch_id);

    } else if (label == ComponentLabel::CanonicalId) {
      std::string canonical_id;
      if (!ReadCanonicalId(&tmp, &canonical_id)) {
        break;
      }
      absl::StrAppend(&description, " canonical_id=", canonical_id);

    } else if (label == ComponentLabel::TargetId) {
      model::TargetId target_id;
      if (!ReadTargetId(&tmp, &target_id)) {
        break;
      }
      absl::StrAppend(&description, " target_id=", target_id);

    } else if (label == ComponentLabel::UserId) {
      std::string user_id;
      if (!ReadUserId(&tmp, &user_id)) {
        break;
      }
      absl::StrAppend(&description, " user_id=", user_id);

    } else {
      absl::StrAppend(&description, " unknown label=", static_cast<int>(label));
      break;
    }

    contents = tmp;
  }

  if (contents.size() > 0) {
    absl::StrAppend(&description, " invalid key=<", InvalidKey(key), ">");

  } else if (!is_terminated) {
    absl::StrAppend(&description, " incomplete key");
  }

  absl::StrAppend(&description, "]");
  return description;
}

std::string LevelDbVersionKey::Key() {
  std::string result;
  WriteTableName(&result, kVersionGlobalTable);
  WriteTerminator(&result);
  return result;
}

std::string LevelDbMutationKey::KeyPrefix() {
  std::string result;
  WriteTableName(&result, kMutationsTable);
  return result;
}

std::string LevelDbMutationKey::KeyPrefix(absl::string_view user_id) {
  std::string result;
  WriteTableName(&result, kMutationsTable);
  WriteUserId(&result, user_id);
  return result;
}

std::string LevelDbMutationKey::Key(absl::string_view user_id,
                                    model::BatchId batch_id) {
  std::string result;
  WriteTableName(&result, kMutationsTable);
  WriteUserId(&result, user_id);
  WriteBatchId(&result, batch_id);
  WriteTerminator(&result);
  return result;
}

bool LevelDbMutationKey::Decode(leveldb::Slice key) {
  user_id_.clear();
  batch_id_ = 0;

  return ReadTableNameMatching(&key, kMutationsTable) &&
         ReadUserId(&key, &user_id_) && ReadBatchId(&key, &batch_id_) &&
         ReadTerminator(&key);
}

std::string LevelDbDocumentMutationKey::KeyPrefix() {
  std::string result;
  WriteTableName(&result, kDocumentMutationsTable);
  return result;
}

std::string LevelDbDocumentMutationKey::KeyPrefix(absl::string_view user_id) {
  std::string result;
  WriteTableName(&result, kDocumentMutationsTable);
  WriteUserId(&result, user_id);
  return result;
}

std::string LevelDbDocumentMutationKey::KeyPrefix(
    absl::string_view user_id, const ResourcePath &resource_path) {
  std::string result;
  WriteTableName(&result, kDocumentMutationsTable);
  WriteUserId(&result, user_id);
  WriteResourcePath(&result, resource_path);
  return result;
}

std::string LevelDbDocumentMutationKey::Key(absl::string_view user_id,
                                            const DocumentKey &document_key,
                                            model::BatchId batch_id) {
  std::string result;
  WriteTableName(&result, kDocumentMutationsTable);
  WriteUserId(&result, user_id);
  WriteResourcePath(&result, document_key.path());
  WriteBatchId(&result, batch_id);
  WriteTerminator(&result);
  return result;
}

bool LevelDbDocumentMutationKey::Decode(leveldb::Slice key) {
  user_id_.clear();
  document_key_ = DocumentKey{};
  batch_id_ = 0;

  return ReadTableNameMatching(&key, kDocumentMutationsTable) &&
         ReadUserId(&key, &user_id_) && ReadDocumentKey(&key, &document_key_) &&
         ReadBatchId(&key, &batch_id_) && ReadTerminator(&key);
}

std::string LevelDbMutationQueueKey::KeyPrefix() {
  std::string result;
  WriteTableName(&result, kMutationQueuesTable);
  return result;
}

std::string LevelDbMutationQueueKey::Key(absl::string_view user_id) {
  std::string result;
  WriteTableName(&result, kMutationQueuesTable);
  WriteUserId(&result, user_id);
  WriteTerminator(&result);
  return result;
}

bool LevelDbMutationQueueKey::Decode(leveldb::Slice key) {
  user_id_.clear();

  return ReadTableNameMatching(&key, kMutationQueuesTable) &&
         ReadUserId(&key, &user_id_) && ReadTerminator(&key);
}

std::string LevelDbTargetGlobalKey::Key() {
  std::string result;
  WriteTableName(&result, kTargetGlobalTable);
  WriteTerminator(&result);
  return result;
}

bool LevelDbTargetGlobalKey::Decode(leveldb::Slice key) {
  return ReadTableNameMatching(&key, kTargetGlobalTable) &&
         ReadTerminator(&key);
}

std::string LevelDbTargetKey::KeyPrefix() {
  std::string result;
  WriteTableName(&result, kTargetsTable);
  return result;
}

std::string LevelDbTargetKey::Key(model::TargetId target_id) {
  std::string result;
  WriteTableName(&result, kTargetsTable);
  WriteTargetId(&result, target_id);
  WriteTerminator(&result);
  return result;
}

bool LevelDbTargetKey::Decode(leveldb::Slice key) {
  target_id_ = 0;
  return ReadTableNameMatching(&key, kTargetsTable) &&
         ReadTargetId(&key, &target_id_) && ReadTerminator(&key);
}

std::string LevelDbQueryTargetKey::KeyPrefix() {
  std::string result;
  WriteTableName(&result, kQueryTargetsTable);
  return result;
}

std::string LevelDbQueryTargetKey::KeyPrefix(absl::string_view canonical_id) {
  std::string result;
  WriteTableName(&result, kQueryTargetsTable);
  WriteCanonicalId(&result, canonical_id);
  return result;
}

std::string LevelDbQueryTargetKey::Key(absl::string_view canonical_id,
                                       model::TargetId target_id) {
  std::string result;
  WriteTableName(&result, kQueryTargetsTable);
  WriteCanonicalId(&result, canonical_id);
  WriteTargetId(&result, target_id);
  WriteTerminator(&result);
  return result;
}

bool LevelDbQueryTargetKey::Decode(leveldb::Slice key) {
  canonical_id_.clear();
  target_id_ = 0;

  return ReadTableNameMatching(&key, kQueryTargetsTable) &&
         ReadCanonicalId(&key, &canonical_id_) &&
         ReadTargetId(&key, &target_id_) && ReadTerminator(&key);
}

std::string LevelDbTargetDocumentKey::KeyPrefix() {
  std::string result;
  WriteTableName(&result, kTargetDocumentsTable);
  return result;
}

std::string LevelDbTargetDocumentKey::KeyPrefix(model::TargetId target_id) {
  std::string result;
  WriteTableName(&result, kTargetDocumentsTable);
  WriteTargetId(&result, target_id);
  return result;
}

std::string LevelDbTargetDocumentKey::Key(model::TargetId target_id,
                                          const DocumentKey &document_key) {
  std::string result;
  WriteTableName(&result, kTargetDocumentsTable);
  WriteTargetId(&result, target_id);
  WriteResourcePath(&result, document_key.path());
  WriteTerminator(&result);
  return result;
}

bool LevelDbTargetDocumentKey::Decode(leveldb::Slice key) {
  target_id_ = 0;
  document_key_ = DocumentKey{};

  return ReadTableNameMatching(&key, kTargetDocumentsTable) &&
         ReadTargetId(&key, &target_id_) &&
         ReadDocumentKey(&key, &document_key_) && ReadTerminator(&key);
}

std::string LevelDbDocumentTargetKey::KeyPrefix() {
  std::string result;
  WriteTableName(&result, kDocumentTargetsTable);
  return result;
}

std::string LevelDbDocumentTargetKey::KeyPrefix(
    const ResourcePath &resource_path) {
  std::string result;
  WriteTableName(&result, kDocumentTargetsTable);
  WriteResourcePath(&result, resource_path);
  return result;
}

std::string LevelDbDocumentTargetKey::Key(const DocumentKey &document_key,
                                          model::TargetId target_id) {
  std::string result;
  WriteTableName(&result, kDocumentTargetsTable);
  WriteResourcePath(&result, document_key.path());
  WriteTargetId(&result, target_id);
  WriteTerminator(&result);
  return result;
}

bool LevelDbDocumentTargetKey::Decode(leveldb::Slice key) {
  document_key_ = DocumentKey{};
  target_id_ = 0;

  return ReadTableNameMatching(&key, kDocumentTargetsTable) &&
         ReadDocumentKey(&key, &document_key_) &&
         ReadTargetId(&key, &target_id_) && ReadTerminator(&key);
}

std::string LevelDbRemoteDocumentKey::KeyPrefix() {
  std::string result;
  WriteTableName(&result, kRemoteDocumentsTable);
  return result;
}

std::string LevelDbRemoteDocumentKey::KeyPrefix(
    const ResourcePath &resource_path) {
  std::string result;
  WriteTableName(&result, kRemoteDocumentsTable);
  WriteResourcePath(&result, resource_path);
  return result;
}

std::string LevelDbRemoteDocumentKey::Key(const DocumentKey &key) {
  std::string result;
  WriteTableName(&result, kRemoteDocumentsTable);
  WriteResourcePath(&result, key.path());
  WriteTerminator(&result);
  return result;
}

bool LevelDbRemoteDocumentKey::Decode(leveldb::Slice key) {
  document_key_ = DocumentKey{};

  return ReadTableNameMatching(&key, kRemoteDocumentsTable) &&
         ReadDocumentKey(&key, &document_key_) && ReadTerminator(&key);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
