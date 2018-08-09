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

// Aliases for nanopb's equivalent of google::firestore::v1beta1. This shorten
// the symbols and allows them to fit on one line.
namespace v1beta1 {

constexpr uint32_t StructuredQuery_CollectionSelector_collection_id_tag =
    // NOLINTNEXTLINE(whitespace/line_length)
    google_firestore_v1beta1_StructuredQuery_CollectionSelector_collection_id_tag;

constexpr uint32_t StructuredQuery_CollectionSelector_all_descendants_tag =
    // NOLINTNEXTLINE(whitespace/line_length)
    google_firestore_v1beta1_StructuredQuery_CollectionSelector_all_descendants_tag;

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

namespace {

absl::optional<ObjectValue::Map> DecodeMapValue(Reader* reader);

// There's no f:f::model equivalent of StructuredQuery, so we'll create our
// own struct for decoding. We could use nanopb's struct, but it's slightly
// inconvenient since it's a fixed size (so uses callbacks to represent
// strings, repeated fields, etc.)
struct StructuredQuery {
  struct CollectionSelector {
    std::string collection_id;
    bool all_descendants;
  };
  // TODO(rsgowman): other submessages

  std::vector<CollectionSelector> from;
  // TODO(rsgowman): other fields
};

absl::optional<ObjectValue::Map::value_type> DecodeFieldsEntry(
    Reader* reader, uint32_t key_tag, uint32_t value_tag) {
  std::string key;
  absl::optional<FieldValue> value;

  while (reader->good()) {
    uint32_t tag = reader->ReadTag();
    if (tag == key_tag) {
      key = reader->ReadString();
    } else if (tag == value_tag) {
      value =
          reader->ReadNestedMessage<FieldValue>(Serializer::DecodeFieldValue);
    } else {
      reader->SkipUnknown();
    }
  }

  if (key.empty()) {
    reader->Fail(
        "Invalid message: Empty key while decoding a Map field value.");
    return absl::nullopt;
  }

  if (!value.has_value()) {
    reader->Fail(
        "Invalid message: Empty value while decoding a Map field value.");
    return absl::nullopt;
  }

  return ObjectValue::Map::value_type{key, *std::move(value)};
}

absl::optional<ObjectValue::Map::value_type> DecodeMapValueFieldsEntry(
    Reader* reader) {
  return DecodeFieldsEntry(
      reader, google_firestore_v1beta1_MapValue_FieldsEntry_key_tag,
      google_firestore_v1beta1_MapValue_FieldsEntry_value_tag);
}

absl::optional<ObjectValue::Map::value_type> DecodeDocumentFieldsEntry(
    Reader* reader) {
  return DecodeFieldsEntry(
      reader, google_firestore_v1beta1_Document_FieldsEntry_key_tag,
      google_firestore_v1beta1_Document_FieldsEntry_value_tag);
}

absl::optional<ObjectValue::Map> DecodeMapValue(Reader* reader) {
  ObjectValue::Map result;

  while (reader->good()) {
    switch (reader->ReadTag()) {
      case google_firestore_v1beta1_MapValue_fields_tag: {
        absl::optional<ObjectValue::Map::value_type> fv =
            reader->ReadNestedMessage<ObjectValue::Map::value_type>(
                DecodeMapValueFieldsEntry);

        // Assumption: If we parse two entries for the map that have the same
        // key, then the latter should overwrite the former. This does not
        // appear to be explicitly called out by the docs, but seems to be in
        // the spirit of how things work. (i.e. non-repeated fields explicitly
        // follow this behaviour.) In any case, well behaved proto emitters
        // shouldn't create encodings like this, but well behaved parsers are
        // expected to handle these cases.
        //
        // https://developers.google.com/protocol-buffers/docs/encoding#optional

        // Add this key,fieldvalue to the results map.
        if (reader->status().ok()) result[fv->first] = fv->second;
        break;
      }

      default:
        reader->SkipUnknown();
    }
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

absl::optional<StructuredQuery::CollectionSelector> DecodeCollectionSelector(
    Reader* reader) {
  StructuredQuery::CollectionSelector collection_selector{};

  while (reader->good()) {
    switch (reader->ReadTag()) {
      case v1beta1::StructuredQuery_CollectionSelector_collection_id_tag:
        collection_selector.collection_id = reader->ReadString();
        break;
      case v1beta1::StructuredQuery_CollectionSelector_all_descendants_tag:
        collection_selector.all_descendants = reader->ReadBool();
        break;
      default:
        reader->SkipUnknown();
    }
  }

  return collection_selector;
}

absl::optional<StructuredQuery> DecodeStructuredQuery(Reader* reader) {
  StructuredQuery query{};

  while (reader->good()) {
    switch (reader->ReadTag()) {
      case google_firestore_v1beta1_StructuredQuery_from_tag: {
        absl::optional<StructuredQuery::CollectionSelector>
            collection_selector =
                reader->ReadNestedMessage<StructuredQuery::CollectionSelector>(
                    DecodeCollectionSelector);
        if (reader->status().ok()) query.from.push_back(*collection_selector);
        break;
      }

      // TODO(rsgowman): decode other fields
      default:
        reader->SkipUnknown();
    }
  }

  return query;
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

absl::optional<FieldValue> Serializer::DecodeFieldValue(Reader* reader) {
  if (!reader->status().ok()) return absl::nullopt;

  // There needs to be at least one entry in the FieldValue.
  if (reader->bytes_left() == 0) {
    reader->Fail("Input Value proto missing contents");
    return absl::nullopt;
  }

  FieldValue result = FieldValue::NullValue();

  while (reader->good()) {
    switch (reader->ReadTag()) {
      case google_firestore_v1beta1_Value_null_value_tag:
        reader->ReadNull();
        result = FieldValue::NullValue();
        break;

      case google_firestore_v1beta1_Value_boolean_value_tag:
        result = FieldValue::BooleanValue(reader->ReadBool());
        break;

      case google_firestore_v1beta1_Value_integer_value_tag:
        result = FieldValue::IntegerValue(reader->ReadInteger());
        break;

      case google_firestore_v1beta1_Value_string_value_tag:
        result = FieldValue::StringValue(reader->ReadString());
        break;

      case google_firestore_v1beta1_Value_timestamp_value_tag: {
        absl::optional<Timestamp> timestamp =
            reader->ReadNestedMessage<Timestamp>(DecodeTimestamp);
        if (reader->status().ok())
          result = FieldValue::TimestampValue(*timestamp);
        break;
      }

      case google_firestore_v1beta1_Value_map_value_tag: {
        // TODO(rsgowman): We should merge the existing map (if any) with the
        // newly parsed map.
        absl::optional<ObjectValue::Map> optional_map =
            reader->ReadNestedMessage<ObjectValue::Map>(DecodeMapValue);
        if (reader->status().ok())
          result = FieldValue::ObjectValueFromMap(*optional_map);
        break;
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
        reader->SkipUnknown();
    }
  }

  if (!reader->status().ok()) return absl::nullopt;
  return result;
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
    Reader* reader) const {
  std::unique_ptr<MaybeDocument> maybeDoc =
      DecodeBatchGetDocumentsResponse(reader);

  if (reader->status().ok()) {
    return maybeDoc;
  } else {
    return nullptr;
  }
}

std::unique_ptr<MaybeDocument> Serializer::DecodeBatchGetDocumentsResponse(
    Reader* reader) const {
  // Initialize BatchGetDocumentsResponse fields to their default values
  std::unique_ptr<MaybeDocument> found;
  std::string missing;
  // We explicitly ignore the 'transaction' field
  absl::optional<Timestamp> read_time = Timestamp{};

  while (reader->good()) {
    switch (reader->ReadTag()) {
      case google_firestore_v1beta1_BatchGetDocumentsResponse_found_tag:
        // 'found' and 'missing' are part of a oneof. The proto docs claim that
        // if both are set on the wire, the last one wins.
        missing = "";

        // TODO(rsgowman): If multiple 'found' values are found, we should merge
        // them (rather than using the last one.)
        found = reader->ReadNestedMessage<Document>(
            *this, &Serializer::DecodeDocument);
        break;

      case google_firestore_v1beta1_BatchGetDocumentsResponse_missing_tag:
        // 'found' and 'missing' are part of a oneof. The proto docs claim that
        // if both are set on the wire, the last one wins.
        found = nullptr;

        missing = reader->ReadString();
        break;

      case google_firestore_v1beta1_BatchGetDocumentsResponse_read_time_tag: {
        read_time = reader->ReadNestedMessage<Timestamp>(DecodeTimestamp);
        break;
      }

      case google_firestore_v1beta1_BatchGetDocumentsResponse_transaction_tag:
        // This field is ignored by the client sdk, but we still need to extract
        // it.
      default:
        reader->SkipUnknown();
    }
  }

  if (!reader->status().ok()) {
    return nullptr;
  } else if (found != nullptr) {
    return found;
  } else if (!missing.empty()) {
    return absl::make_unique<NoDocument>(
        DecodeKey(missing), SnapshotVersion{*std::move(read_time)});
  } else {
    reader->Fail(
        "Invalid BatchGetDocumentsReponse message: "
        "Neither 'found' nor 'missing' fields set.");
    return nullptr;
  }
}

std::unique_ptr<Document> Serializer::DecodeDocument(Reader* reader) const {
  std::string name;
  ObjectValue::Map fields_internal;
  absl::optional<SnapshotVersion> version = SnapshotVersion::None();

  while (reader->good()) {
    switch (reader->ReadTag()) {
      case google_firestore_v1beta1_Document_name_tag:
        name = reader->ReadString();
        break;

      case google_firestore_v1beta1_Document_fields_tag: {
        absl::optional<ObjectValue::Map::value_type> fv =
            reader->ReadNestedMessage<ObjectValue::Map::value_type>(
                DecodeDocumentFieldsEntry);

        // Assumption: For duplicates, the latter overrides the former, see
        // comment on writing object map for details (DecodeMapValue).

        // Add fieldvalue to the results map.
        if (reader->status().ok()) fields_internal[fv->first] = fv->second;
        break;
      }

      case google_firestore_v1beta1_Document_update_time_tag:
        // TODO(rsgowman): Rather than overwriting, we should instead merge with
        // the existing SnapshotVersion (if any). Less relevant here, since it's
        // just two numbers which are both expected to be present, but if the
        // proto evolves that might change.
        version =
            reader->ReadNestedMessage<SnapshotVersion>(DecodeSnapshotVersion);
        break;

      case google_firestore_v1beta1_Document_create_time_tag:
        // This field is ignored by the client sdk, but we still need to extract
        // it.
      default:
        reader->SkipUnknown();
    }
  }

  if (!reader->status().ok()) return nullptr;
  return absl::make_unique<Document>(
      FieldValue::ObjectValueFromMap(fields_internal), DecodeKey(name),
      *std::move(version),
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
    ResourcePath path = query.path();
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

absl::optional<Query> Serializer::DecodeQueryTarget(nanopb::Reader* reader) {
  ResourcePath path = ResourcePath::Empty();
  absl::optional<StructuredQuery> query = StructuredQuery{};

  while (reader->good()) {
    switch (reader->ReadTag()) {
      case google_firestore_v1beta1_Target_QueryTarget_parent_tag:
        path = DecodeQueryPath(reader->ReadString());
        break;

      case google_firestore_v1beta1_Target_QueryTarget_structured_query_tag:
        query =
            reader->ReadNestedMessage<StructuredQuery>(DecodeStructuredQuery);
        break;

      default:
        reader->SkipUnknown();
    }
  }

  if (!reader->status().ok()) return Query::Invalid();

  size_t from_count = query->from.size();
  if (from_count > 0) {
    HARD_ASSERT(
        from_count == 1,
        "StructuredQuery.from with more than one collection is not supported.");

    path = path.Append(query->from[0].collection_id);
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

absl::optional<SnapshotVersion> Serializer::DecodeSnapshotVersion(
    nanopb::Reader* reader) {
  absl::optional<Timestamp> version = DecodeTimestamp(reader);
  if (!reader->status().ok()) return absl::nullopt;
  return SnapshotVersion{*version};
}

absl::optional<Timestamp> Serializer::DecodeTimestamp(nanopb::Reader* reader) {
  google_protobuf_Timestamp timestamp_proto =
      google_protobuf_Timestamp_init_zero;
  reader->ReadNanopbMessage(google_protobuf_Timestamp_fields, &timestamp_proto);

  // The Timestamp ctor will assert if we provide values outside the valid
  // range. However, since we're decoding, a single corrupt byte could cause
  // this to occur, so we'll verify the ranges before passing them in since we'd
  // rather not abort in these situations.
  if (timestamp_proto.seconds < TimestampInternal::Min().seconds()) {
    reader->Fail(
        "Invalid message: timestamp beyond the earliest supported date");
  } else if (TimestampInternal::Max().seconds() < timestamp_proto.seconds) {
    reader->Fail("Invalid message: timestamp behond the latest supported date");
  } else if (timestamp_proto.nanos < 0 || timestamp_proto.nanos > 999999999) {
    reader->Fail(
        "Invalid message: timestamp nanos must be between 0 and 999999999");
  }

  if (!reader->status().ok()) return absl::nullopt;
  return Timestamp{timestamp_proto.seconds, timestamp_proto.nanos};
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
