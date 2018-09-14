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

#include "Firestore/core/src/firebase/firestore/remote/serializer.h"

#include <pb_decode.h>
#include <pb_encode.h>

#include <functional>
#include <map>
#include <string>
#include <utility>

#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1beta1/firestore.nanopb.h"
#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/tag.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/timestamp_internal.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {

using firebase::Timestamp;
using firebase::TimestampInternal;
using firebase::firestore::core::Query;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::MaybeDocument;
using firebase::firestore::model::NoDocument;
using firebase::firestore::model::ObjectValue;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::nanopb::Reader;
using firebase::firestore::nanopb::Tag;
using firebase::firestore::nanopb::Writer;
using firebase::firestore::util::Status;
using firebase::firestore::util::StringFormat;

// Aliases for nanopb's equivalent of google::firestore::v1beta1. This shorten
// the symbols and allows them to fit on one line.
namespace v1beta1 {

constexpr uint32_t StructuredQuery_CollectionSelector_collection_id_tag =
    // NOLINTNEXTLINE(whitespace/line_length)
    google_firestore_v1beta1_StructuredQuery_CollectionSelector_collection_id_tag;

}  // namespace v1beta1

// TODO(rsgowman): Move this down below the anon namespace
void Serializer::EncodeTimestamp(Writer* writer,
                                 const Timestamp& timestamp_value) {
  google_protobuf_Timestamp timestamp_proto =
      google_protobuf_Timestamp_init_zero;
  timestamp_proto.seconds = timestamp_value.seconds();
  timestamp_proto.nanos = timestamp_value.nanoseconds();
  writer->WriteNanopbMessage(google_protobuf_Timestamp_fields,
                             &timestamp_proto);
}

std::string Serializer::DecodeString(const pb_bytes_array_t* str) {
  if (str == nullptr) return "";
  return std::string{reinterpret_cast<const char*>(str->bytes), str->size};
}

std::vector<uint8_t> Serializer::DecodeBytes(const pb_bytes_array_t* bytes) {
  if (bytes == nullptr) return {};
  return std::vector<uint8_t>(bytes->bytes, bytes->bytes + bytes->size);
}

namespace {

ObjectValue::Map DecodeMapValue(
    Reader* reader, const google_firestore_v1beta1_MapValue& map_value);

ObjectValue::Map::value_type DecodeFieldsEntry(
    Reader* reader,
    const google_firestore_v1beta1_Document_FieldsEntry& fields) {
  std::string key = Serializer::DecodeString(fields.key);
  FieldValue value = Serializer::DecodeFieldValue(reader, fields.value);

  if (key.empty()) {
    reader->Fail(
        "Invalid message: Empty key while decoding a Map field value.");
  }

  return ObjectValue::Map::value_type{std::move(key), std::move(value)};
}

ObjectValue::Map DecodeFields(
    Reader* reader,
    size_t count,
    const google_firestore_v1beta1_Document_FieldsEntry* fields) {
  ObjectValue::Map result;
  for (size_t i = 0; i < count; i++) {
    result.emplace(DecodeFieldsEntry(reader, fields[i]));
  }

  return result;
}

ObjectValue::Map DecodeMapValue(
    Reader* reader, const google_firestore_v1beta1_MapValue& map_value) {
  ObjectValue::Map result;

  for (size_t i = 0; i < map_value.fields_count; i++) {
    std::string key = Serializer::DecodeString(map_value.fields[i].key);
    FieldValue value =
        Serializer::DecodeFieldValue(reader, map_value.fields[i].value);

    result[key] = value;
  }

  return result;
}

/**
 * Creates the prefix for a fully qualified resource path, without a local path
 * on the end.
 */
ResourcePath EncodeDatabaseId(const DatabaseId& database_id) {
  return ResourcePath{"projects", database_id.project_id(), "databases",
                      database_id.database_id()};
}

/**
 * Encodes a databaseId and resource path into the following form:
 * /projects/$projectId/database/$databaseId/documents/$path
 */
std::string EncodeResourceName(const DatabaseId& database_id,
                               const ResourcePath& path) {
  return EncodeDatabaseId(database_id)
      .Append("documents")
      .Append(path)
      .CanonicalString();
}

/**
 * Validates that a path has a prefix that looks like a valid encoded
 * databaseId.
 */
bool IsValidResourceName(const ResourcePath& path) {
  // Resource names have at least 4 components (project ID, database ID)
  // and commonly the (root) resource type, e.g. documents
  return path.size() >= 4 && path[0] == "projects" && path[2] == "databases";
}

/**
 * Decodes a fully qualified resource name into a resource path and validates
 * that there is a project and database encoded in the path. There are no
 * guarantees that a local path is also encoded in this resource name.
 */
ResourcePath DecodeResourceName(absl::string_view encoded) {
  ResourcePath resource = ResourcePath::FromString(encoded);
  HARD_ASSERT(IsValidResourceName(resource),
              "Tried to deserialize invalid key %s",
              resource.CanonicalString());
  return resource;
}

/**
 * Decodes a fully qualified resource name into a resource path and validates
 * that there is a project and database encoded in the path along with a local
 * path.
 */
ResourcePath ExtractLocalPathFromResourceName(
    const ResourcePath& resource_name) {
  HARD_ASSERT(resource_name.size() > 4 && resource_name[4] == "documents",
              "Tried to deserialize invalid key %s",
              resource_name.CanonicalString());
  return resource_name.PopFirst(5);
}

}  // namespace

Serializer::Serializer(
    const firebase::firestore::model::DatabaseId& database_id)
    : database_id_(database_id),
      database_name_(EncodeDatabaseId(database_id).CanonicalString()) {
}

void Serializer::EncodeFieldValue(Writer* writer,
                                  const FieldValue& field_value) {
  // TODO(rsgowman): some refactoring is in order... but will wait until after a
  // non-varint, non-fixed-size (i.e. string) type is present before doing so.
  switch (field_value.type()) {
    case FieldValue::Type::Null:
      writer->WriteTag(
          {PB_WT_VARINT, google_firestore_v1beta1_Value_null_value_tag});
      writer->WriteNull();
      break;

    case FieldValue::Type::Boolean:
      writer->WriteTag(
          {PB_WT_VARINT, google_firestore_v1beta1_Value_boolean_value_tag});
      writer->WriteBool(field_value.boolean_value());
      break;

    case FieldValue::Type::Integer:
      writer->WriteTag(
          {PB_WT_VARINT, google_firestore_v1beta1_Value_integer_value_tag});
      writer->WriteInteger(field_value.integer_value());
      break;

    case FieldValue::Type::String:
      writer->WriteTag(
          {PB_WT_STRING, google_firestore_v1beta1_Value_string_value_tag});
      writer->WriteString(field_value.string_value());
      break;

    case FieldValue::Type::Timestamp:
      writer->WriteTag(
          {PB_WT_STRING, google_firestore_v1beta1_Value_timestamp_value_tag});
      writer->WriteNestedMessage([&field_value](Writer* writer) {
        EncodeTimestamp(writer, field_value.timestamp_value());
      });
      break;

    case FieldValue::Type::Object:
      writer->WriteTag(
          {PB_WT_STRING, google_firestore_v1beta1_Value_map_value_tag});
      writer->WriteNestedMessage([&field_value](Writer* writer) {
        EncodeMapValue(writer, field_value.object_value());
      });
      break;

    default:
      // TODO(rsgowman): implement the other types
      abort();
  }
}

FieldValue Serializer::DecodeFieldValue(
    Reader* reader, const google_firestore_v1beta1_Value& msg) {
  switch (msg.which_value_type) {
    case google_firestore_v1beta1_Value_null_value_tag:
      if (msg.null_value != google_protobuf_NullValue_NULL_VALUE) {
        reader->Fail("Input proto bytes cannot be parsed (invalid null value)");
      }
      return FieldValue::NullValue();

    case google_firestore_v1beta1_Value_boolean_value_tag:
      return FieldValue::BooleanValue(msg.boolean_value);

    case google_firestore_v1beta1_Value_integer_value_tag:
      return FieldValue::IntegerValue(msg.integer_value);

    case google_firestore_v1beta1_Value_string_value_tag:
      return FieldValue::StringValue(DecodeString(msg.string_value));

    case google_firestore_v1beta1_Value_timestamp_value_tag: {
      Timestamp timestamp =
          DecodeTimestamp(reader, msg.timestamp_value);
      return FieldValue::TimestampValue(timestamp);
    }

    case google_firestore_v1beta1_Value_map_value_tag: {
      ObjectValue::Map map = DecodeMapValue(reader, msg.map_value);
      return FieldValue::ObjectValueFromMap(map);
    }

    case google_firestore_v1beta1_Value_double_value_tag:
    case google_firestore_v1beta1_Value_bytes_value_tag:
    case google_firestore_v1beta1_Value_reference_value_tag:
    case google_firestore_v1beta1_Value_geo_point_value_tag:
    case google_firestore_v1beta1_Value_array_value_tag:
      // TODO(b/74243929): Implement remaining types.
      HARD_FAIL("Unhandled message field number (tag): %i.",
                reader->last_tag().field_number);

    default:
      // Unspecified type.
      reader->Fail("Invalid type while decoding FieldValue");
      return FieldValue::NullValue();
  }

  UNREACHABLE();
}

std::string Serializer::EncodeKey(const DocumentKey& key) const {
  return EncodeResourceName(database_id_, key.path());
}

DocumentKey Serializer::DecodeKey(absl::string_view name) const {
  ResourcePath resource = DecodeResourceName(name);
  HARD_ASSERT(resource[1] == database_id_.project_id(),
              "Tried to deserialize key from different project.");
  HARD_ASSERT(resource[3] == database_id_.database_id(),
              "Tried to deserialize key from different database.");
  return DocumentKey{ExtractLocalPathFromResourceName(resource)};
}

void Serializer::EncodeDocument(Writer* writer,
                                const DocumentKey& key,
                                const ObjectValue& object_value) const {
  // Encode Document.name
  writer->WriteTag({PB_WT_STRING, google_firestore_v1beta1_Document_name_tag});
  writer->WriteString(EncodeKey(key));

  // Encode Document.fields (unless it's empty)
  if (!object_value.internal_value.empty()) {
    EncodeObjectMap(writer, object_value.internal_value,
                    google_firestore_v1beta1_Document_fields_tag,
                    google_firestore_v1beta1_Document_FieldsEntry_key_tag,
                    google_firestore_v1beta1_Document_FieldsEntry_value_tag);
  }

  // Skip Document.create_time and Document.update_time, since they're
  // output-only fields.
}

std::unique_ptr<model::MaybeDocument> Serializer::DecodeMaybeDocument(
    Reader* reader,
    const google_firestore_v1beta1_BatchGetDocumentsResponse& response) const {
  switch (response.which_result) {
    case google_firestore_v1beta1_BatchGetDocumentsResponse_found_tag:
      return DecodeFoundDocument(reader, response);
    case google_firestore_v1beta1_BatchGetDocumentsResponse_missing_tag:
      return DecodeMissingDocument(reader, response);
    default:
      reader->Fail(
          StringFormat("Unknown result case: %s", response.which_result));
      return nullptr;
  }

  UNREACHABLE();
}

std::unique_ptr<model::Document> Serializer::DecodeFoundDocument(
    Reader* reader,
    const google_firestore_v1beta1_BatchGetDocumentsResponse& response) const {
  HARD_ASSERT(response.which_result ==
                  google_firestore_v1beta1_BatchGetDocumentsResponse_found_tag,
              "Tried to deserialize a found document from a missing document.");

  DocumentKey key = DecodeKey(DecodeString(response.found.name));
  ObjectValue::Map value =
      DecodeFields(reader, response.found.fields_count, response.found.fields);
  SnapshotVersion version =
      DecodeSnapshotVersion(reader, response.found.update_time);
  HARD_ASSERT(version != SnapshotVersion::None(),
              "Got a document response with no snapshot version");

  return absl::make_unique<Document>(
      FieldValue::ObjectValueFromMap(std::move(value)), std::move(key),
      version, /*has_local_modifications=*/false);
}

std::unique_ptr<model::NoDocument> Serializer::DecodeMissingDocument(
    Reader* reader,
    const google_firestore_v1beta1_BatchGetDocumentsResponse& response) const {
  HARD_ASSERT(
      response.which_result ==
          google_firestore_v1beta1_BatchGetDocumentsResponse_missing_tag,
      "Tried to deserialize a missing document from a found document.");

  DocumentKey key = DecodeKey(DecodeString(response.missing));
  SnapshotVersion version = DecodeSnapshotVersion(reader, response.read_time);

  if (version == SnapshotVersion::None()) {
    reader->Fail("Got a no document response with no snapshot version");
  }

  return absl::make_unique<NoDocument>(std::move(key), version);
}

std::unique_ptr<Document> Serializer::DecodeDocument(
    Reader* reader, const google_firestore_v1beta1_Document& proto) const {
  ObjectValue::Map fields =
      DecodeFields(reader, proto.fields_count, proto.fields);
  SnapshotVersion version = DecodeSnapshotVersion(reader, proto.update_time);

  return absl::make_unique<Document>(
      FieldValue::ObjectValueFromMap(fields),
      DecodeKey(DecodeString(proto.name)), version,
      /*has_local_modifications=*/false);
}

void Serializer::EncodeQueryTarget(Writer* writer,
                                   const core::Query& query) const {
  // Dissect the path into parent, collection_id and optional key filter.
  std::string collection_id;
  if (query.path().empty()) {
    writer->WriteTag(
        {PB_WT_STRING, google_firestore_v1beta1_Target_QueryTarget_parent_tag});
    writer->WriteString(EncodeQueryPath(ResourcePath::Empty()));
  } else {
    const ResourcePath& path = query.path();
    HARD_ASSERT(path.size() % 2 != 0,
                "Document queries with filters are not supported.");
    writer->WriteTag(
        {PB_WT_STRING, google_firestore_v1beta1_Target_QueryTarget_parent_tag});
    writer->WriteString(EncodeQueryPath(path.PopLast()));

    collection_id = path.last_segment();
  }

  writer->WriteTag(
      {PB_WT_STRING,
       google_firestore_v1beta1_Target_QueryTarget_structured_query_tag});
  writer->WriteNestedMessage([&](Writer* writer) {
    if (!collection_id.empty()) {
      writer->WriteTag(
          {PB_WT_STRING, google_firestore_v1beta1_StructuredQuery_from_tag});
      writer->WriteNestedMessage([&](Writer* writer) {
        writer->WriteTag(
            {PB_WT_STRING,
             v1beta1::StructuredQuery_CollectionSelector_collection_id_tag});
        writer->WriteString(collection_id);
      });
    }

    // Encode the filters.
    if (!query.filters().empty()) {
      // TODO(rsgowman): Implement
      abort();
    }

    // TODO(rsgowman): Encode the orders.
    // TODO(rsgowman): Encode the limit.
    // TODO(rsgowman): Encode the startat.
    // TODO(rsgowman): Encode the endat.
  });
}

ResourcePath DecodeQueryPath(absl::string_view name) {
  ResourcePath resource = DecodeResourceName(name);
  if (resource.size() == 4) {
    // Path missing the trailing documents path segment, indicating an empty
    // path.
    return ResourcePath::Empty();
  } else {
    return ExtractLocalPathFromResourceName(resource);
  }
}

Query Serializer::DecodeQueryTarget(
    nanopb::Reader* reader,
    const google_firestore_v1beta1_Target_QueryTarget& proto) {
  // The QueryTarget oneof only has a single valid value.
  if (proto.which_query_type !=
      google_firestore_v1beta1_Target_QueryTarget_structured_query_tag) {
    reader->Fail(
        StringFormat("Unknown query_type: %s", proto.which_query_type));
    return Query::Invalid();
  }

  ResourcePath path = DecodeQueryPath(DecodeString(proto.parent));
  size_t from_count = proto.structured_query.from_count;
  if (from_count > 0) {
    HARD_ASSERT(
        from_count == 1,
        "StructuredQuery.from with more than one collection is not supported.");

    path =
        path.Append(DecodeString(proto.structured_query.from[0].collection_id));
  }

  // TODO(rsgowman): Dencode the filters.
  // TODO(rsgowman): Dencode the orders.
  // TODO(rsgowman): Dencode the limit.
  // TODO(rsgowman): Dencode the startat.
  // TODO(rsgowman): Dencode the endat.

  return Query(path, {});
}

std::string Serializer::EncodeQueryPath(const ResourcePath& path) const {
  if (path.empty()) {
    // If the path is empty, the backend requires we leave off the /documents at
    // the end.
    return database_name_;
  }
  return EncodeResourceName(database_id_, path);
}

void Serializer::EncodeMapValue(Writer* writer,
                                const ObjectValue& object_value) {
  EncodeObjectMap(writer, object_value.internal_value,
                  google_firestore_v1beta1_MapValue_fields_tag,
                  google_firestore_v1beta1_MapValue_FieldsEntry_key_tag,
                  google_firestore_v1beta1_MapValue_FieldsEntry_value_tag);
}

void Serializer::EncodeObjectMap(
    nanopb::Writer* writer,
    const model::ObjectValue::Map& object_value_map,
    uint32_t map_tag,
    uint32_t key_tag,
    uint32_t value_tag) {
  // Write each FieldsEntry (i.e. key-value pair.)
  for (const auto& kv : object_value_map) {
    writer->WriteTag({PB_WT_STRING, map_tag});
    writer->WriteNestedMessage([&kv, &key_tag, &value_tag](Writer* writer) {
      return EncodeFieldsEntry(writer, kv, key_tag, value_tag);
    });
  }
}

void Serializer::EncodeVersion(nanopb::Writer* writer,
                               const model::SnapshotVersion& version) {
  EncodeTimestamp(writer, version.timestamp());
}

/**
 * Encodes a 'FieldsEntry' object, within a FieldValue's map_value type.
 *
 * In protobuf, maps are implemented as a repeated set of key/values. For
 * instance, this:
 *   message Foo {
 *     map<string, Value> fields = 1;
 *   }
 * would be written (in proto text format) as:
 *   {
 *     fields: {key:"key string 1", value:{<Value message here>}}
 *     fields: {key:"key string 2", value:{<Value message here>}}
 *     ...
 *   }
 *
 * This method writes an individual entry from that list. It is expected that
 * this method will be called once for each entry in the map.
 *
 * @param kv The individual key/value pair to write.
 */
void Serializer::EncodeFieldsEntry(Writer* writer,
                                   const ObjectValue::Map::value_type& kv,
                                   uint32_t key_tag,
                                   uint32_t value_tag) {
  // Write the key (string)
  writer->WriteTag({PB_WT_STRING, key_tag});
  writer->WriteString(kv.first);

  // Write the value (FieldValue)
  writer->WriteTag({PB_WT_STRING, value_tag});
  writer->WriteNestedMessage(
      [&kv](Writer* writer) { EncodeFieldValue(writer, kv.second); });
}

SnapshotVersion Serializer::DecodeSnapshotVersion(
    nanopb::Reader* reader, const google_protobuf_Timestamp& proto) {
  Timestamp version = DecodeTimestamp(reader, proto);
  return SnapshotVersion{version};
}

Timestamp Serializer::DecodeTimestamp(
    nanopb::Reader* reader, const google_protobuf_Timestamp& timestamp_proto) {
  // The Timestamp ctor will assert if we provide values outside the valid
  // range. However, since we're decoding, a single corrupt byte could cause
  // this to occur, so we'll verify the ranges before passing them in since we'd
  // rather not abort in these situations.
  if (timestamp_proto.seconds < TimestampInternal::Min().seconds()) {
    reader->Fail(
        "Invalid message: timestamp beyond the earliest supported date");
  } else if (TimestampInternal::Max().seconds() < timestamp_proto.seconds) {
    reader->Fail("Invalid message: timestamp beyond the latest supported date");
  } else if (timestamp_proto.nanos < 0 || timestamp_proto.nanos > 999999999) {
    reader->Fail(
        "Invalid message: timestamp nanos must be between 0 and 999999999");
  }
  if (!reader->status().ok()) return Timestamp{};

  return Timestamp{timestamp_proto.seconds, timestamp_proto.nanos};
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
