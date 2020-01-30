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

#include "Firestore/core/src/firebase/firestore/local/leveldb_remote_document_cache.h"

#include <string>
#include <utility>

#include "Firestore/Protos/nanopb/firestore/local/maybe_document.nanopb.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"
#include "Firestore/core/src/firebase/firestore/nanopb/message.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_util.h"
#include "leveldb/db.h"

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using leveldb::Status;
using model::Document;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::MaybeDocument;
using model::MaybeDocumentMap;
using model::OptionalMaybeDocumentMap;
using model::ResourcePath;
using model::SnapshotVersion;
using nanopb::ByteString;
using nanopb::Message;
using nanopb::StringReader;

LevelDbRemoteDocumentCache::LevelDbRemoteDocumentCache(
    LevelDbPersistence* db, LocalSerializer* serializer)
    : db_(db), serializer_(NOT_NULL(serializer)) {
}

void LevelDbRemoteDocumentCache::Add(const MaybeDocument& document,
                                     const SnapshotVersion& read_time) {
  const DocumentKey& key = document.key();
  const ResourcePath& path = key.path();

  std::string ldb_document_key = LevelDbRemoteDocumentKey::Key(key);
  db_->current_transaction()->Put(ldb_document_key,
                                  serializer_->EncodeMaybeDocument(document));

  std::string ldb_read_time_key = LevelDbRemoteDocumentReadTimeKey::Key(
      path.PopLast(), read_time, path.last_segment());
  db_->current_transaction()->Put(ldb_read_time_key, "");

  db_->index_manager()->AddToCollectionParentIndex(
      document.key().path().PopLast());
}

void LevelDbRemoteDocumentCache::Remove(const DocumentKey& key) {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(key);
  db_->current_transaction()->Delete(ldb_key);
}

absl::optional<MaybeDocument> LevelDbRemoteDocumentCache::Get(
    const DocumentKey& key) {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(key);
  std::string value;
  Status status = db_->current_transaction()->Get(ldb_key, &value);
  if (status.IsNotFound()) {
    return absl::nullopt;
  } else if (status.ok()) {
    return DecodeMaybeDocument(value, key);
  } else {
    HARD_FAIL("Fetch document for key (%s) failed with status: %s",
              key.ToString(), status.ToString());
  }
}

OptionalMaybeDocumentMap LevelDbRemoteDocumentCache::GetAll(
    const DocumentKeySet& keys) {
  OptionalMaybeDocumentMap results;

  LevelDbRemoteDocumentKey current_key;
  auto it = db_->current_transaction()->NewIterator();

  for (const DocumentKey& key : keys) {
    it->Seek(LevelDbRemoteDocumentKey::Key(key));
    if (!it->Valid() || !current_key.Decode(it->key()) ||
        current_key.document_key() != key) {
      results = results.insert(key, absl::nullopt);
    } else {
      results = results.insert(key, DecodeMaybeDocument(it->value(), key));
    }
  }

  return results;
}

DocumentMap LevelDbRemoteDocumentCache::GetAllExisting(
    const DocumentKeySet& keys) {
  DocumentMap results;

  OptionalMaybeDocumentMap docs = LevelDbRemoteDocumentCache::GetAll(keys);
  for (const auto& kv : docs) {
    const DocumentKey& key = kv.first;
    const auto& maybe_doc = kv.second;
    if (maybe_doc && maybe_doc->is_document()) {
      results = results.insert(key, Document(*maybe_doc));
    }
  }

  return results;
}

DocumentMap LevelDbRemoteDocumentCache::GetMatching(
    const Query& query, const SnapshotVersion& since_read_time) {
  HARD_ASSERT(
      !query.IsCollectionGroupQuery(),
      "CollectionGroup queries should be handled in LocalDocumentsView");

  // Use the query path as a prefix for testing if a document matches the query.
  const ResourcePath& query_path = query.path();
  size_t immediate_children_path_length = query_path.size() + 1;

  if (since_read_time != SnapshotVersion::None()) {
    // Execute an index-free query and filter by read time. This is safe since
    // all document changes to queries that have a
    // last_limbo_free_snapshot_version (`since_read_time`) have a read time
    // set.
    std::string start_key = LevelDbRemoteDocumentReadTimeKey::KeyPrefix(
        query_path, since_read_time);
    auto it = db_->current_transaction()->NewIterator();
    it->Seek(util::ImmediateSuccessor(start_key));

    DocumentKeySet remote_keys;

    LevelDbRemoteDocumentReadTimeKey current_key;
    for (; it->Valid() && current_key.Decode(it->key()); it->Next()) {
      const ResourcePath& collection_path = current_key.collection_path();
      if (collection_path != query_path) {
        break;
      }

      const SnapshotVersion& read_time = current_key.read_time();
      if (read_time > since_read_time) {
        DocumentKey document_key(query_path.Append(current_key.document_id()));
        remote_keys = remote_keys.insert(document_key);
      }
    }

    return LevelDbRemoteDocumentCache::GetAllExisting(remote_keys);
  } else {
    DocumentMap results;

    // Documents are ordered by key, so we can use a prefix scan to narrow down
    // the documents we need to match the query against.
    std::string start_key = LevelDbRemoteDocumentKey::KeyPrefix(query_path);
    auto it = db_->current_transaction()->NewIterator();
    it->Seek(start_key);

    LevelDbRemoteDocumentKey current_key;
    for (; it->Valid() && current_key.Decode(it->key()); it->Next()) {
      // The query is actually returning any path that starts with the query
      // path prefix which may include documents in subcollections. For example,
      // a query on 'rooms' will return rooms/abc/messages/xyx but we shouldn't
      // match it. Fix this by discarding rows with document keys more than one
      // segment longer than the query path.
      const DocumentKey& document_key = current_key.document_key();
      if (document_key.path().size() != immediate_children_path_length) {
        continue;
      }

      MaybeDocument maybe_doc = DecodeMaybeDocument(it->value(), document_key);
      if (!query_path.IsPrefixOf(maybe_doc.key().path())) {
        break;
      } else if (maybe_doc.is_document()) {
        results = results.insert(maybe_doc.key(), Document(maybe_doc));
      }
    }

    return results;
  }
}

MaybeDocument LevelDbRemoteDocumentCache::DecodeMaybeDocument(
    absl::string_view encoded, const DocumentKey& key) {
  StringReader reader{encoded};

  auto message = Message<firestore_client_MaybeDocument>::TryParse(&reader);
  MaybeDocument maybe_document =
      serializer_->DecodeMaybeDocument(&reader, *message);

  if (!reader.ok()) {
    HARD_FAIL("MaybeDocument proto failed to parse: %s",
              reader.status().ToString());
  }
  HARD_ASSERT(maybe_document.key() == key,
              "Read document has key (%s) instead of expected key (%s).",
              maybe_document.key().ToString(), key.ToString());

  return maybe_document;
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
