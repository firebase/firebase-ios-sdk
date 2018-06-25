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
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
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
using firebase::firestore::util::StatusOr;

namespace {

ObjectValue::Map DecodeMapValue(Reader* reader);

void EncodeTimestamp(Writer* writer, const Timestamp& timestamp_value) {
  google_protobuf_Timestamp timestamp_proto =
      google_protobuf_Timestamp_init_zero;
  timestamp_proto.seconds = timestamp_value.seconds();
  timestamp_proto.nanos = timestamp_value.nanoseconds();
  writer->WriteNanopbMessage(google_protobuf_Timestamp_fields,
                             &timestamp_proto);
}

Timestamp DecodeTimestamp(Reader* reader) {
  if (!reader->status().ok()) return {};

  google_protobuf_Timestamp timestamp_proto =
      google_protobuf_Timestamp_init_zero;
  reader->ReadNanopbMessage(google_protobuf_Timestamp_fields, &timestamp_proto);

  // The Timestamp ctor will assert if we provide values outside the valid
  // range. However, since we're decoding, a single corrupt byte could cause
  // this to occur, so we'll verify the ranges before passing them in since we'd
  // rather not abort in these situations.
  if (timestamp_proto.seconds < TimestampInternal::Min().seconds()) {
    reader->set_status(Status(
        FirestoreErrorCode::DataLoss,
        "Invalid message: timestamp beyond the earliest supported date"));
    return {};
  } else if (TimestampInternal::Max().seconds() < timestamp_proto.seconds) {
    reader->set_status(
        Status(FirestoreErrorCode::DataLoss,
               "Invalid message: timestamp behond the latest supported date"));
    return {};
  } else if (timestamp_proto.nanos < 0 || timestamp_proto.nanos > 999999999) {
    reader->set_status(Status(
        FirestoreErrorCode::DataLoss,
        "Invalid message: timestamp nanos must be between 0 and 999999999"));
    return {};
  }
  return Timestamp{timestamp_proto.seconds, timestamp_proto.nanos};
}

FieldValue DecodeFieldValueImpl(Reader* reader) {
  if (!reader->status().ok()) return FieldValue::NullValue();

  // There needs to be at least one entry in the FieldValue.
  if (reader->bytes_left() == 0) {
    reader->set_status(Status(FirestoreErrorCode::DataLoss,
                              "Input Value proto missing contents"));
    return FieldValue::NullValue();
  }

  FieldValue result = FieldValue::NullValue();

  while (reader->bytes_left()) {
    Tag tag = reader->ReadTag();
    if (!reader->status().ok()) return FieldValue::NullValue();

    // Ensure the tag matches the wire type
    switch (tag.field_number) {
      case google_firestore_v1beta1_Value_null_value_tag:
        if (!reader->RequireWireType(PB_WT_VARINT, tag))
          return FieldValue::NullValue();
        reader->ReadNull();
        result = FieldValue::NullValue();
        break;

      case google_firestore_v1beta1_Value_boolean_value_tag:
        if (!reader->RequireWireType(PB_WT_VARINT, tag))
          return FieldValue::NullValue();
        result = FieldValue::BooleanValue(reader->ReadBool());
        break;

      case google_firestore_v1beta1_Value_integer_value_tag:
        if (!reader->RequireWireType(PB_WT_VARINT, tag))
          return FieldValue::NullValue();
        result = FieldValue::IntegerValue(reader->ReadInteger());
        break;

      case google_firestore_v1beta1_Value_string_value_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag))
          return FieldValue::NullValue();
        result = FieldValue::StringValue(reader->ReadString());
        break;

      case google_firestore_v1beta1_Value_timestamp_value_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag))
          return FieldValue::NullValue();
        result = FieldValue::TimestampValue(
            reader->ReadNestedMessage<Timestamp>(DecodeTimestamp));
        break;

      case google_firestore_v1beta1_Value_map_value_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag))
          return FieldValue::NullValue();
        // TODO(rsgowman): We should merge the existing map (if any) with the
        // newly parsed map.
        result = FieldValue::ObjectValueFromMap(
            reader->ReadNestedMessage<ObjectValue::Map>(DecodeMapValue));
        break;

      case google_firestore_v1beta1_Value_double_value_tag:
      case google_firestore_v1beta1_Value_bytes_value_tag:
      case google_firestore_v1beta1_Value_reference_value_tag:
      case google_firestore_v1beta1_Value_geo_point_value_tag:
      case google_firestore_v1beta1_Value_array_value_tag:
        // TODO(b/74243929): Implement remaining types.
        HARD_FAIL("Unhandled message field number (tag): %i.",
                  tag.field_number);

      default:
        // Unknown tag. According to the proto spec, we need to ignore these.
        reader->SkipField(tag);
    }
  }

  return result;
}

ObjectValue::Map::value_type DecodeFieldsEntry(Reader* reader,
                                               uint32_t key_tag,
                                               uint32_t value_tag) {
  if (!reader->status().ok()) return {};

  Tag tag = reader->ReadTag();
  if (!reader->status().ok()) return {};

  // TODO(rsgowman): figure out error handling: We can do better than a failed
  // assertion.
  HARD_ASSERT(tag.field_number == key_tag);
  HARD_ASSERT(tag.wire_type == PB_WT_STRING);
  std::string key = reader->ReadString();

  tag = reader->ReadTag();
  if (!reader->status().ok()) return {};
  HARD_ASSERT(tag.field_number == value_tag);
  HARD_ASSERT(tag.wire_type == PB_WT_STRING);

  FieldValue value =
      reader->ReadNestedMessage<FieldValue>(DecodeFieldValueImpl);

  return ObjectValue::Map::value_type{key, value};
}

ObjectValue::Map::value_type DecodeMapValueFieldsEntry(Reader* reader) {
  return DecodeFieldsEntry(
      reader, google_firestore_v1beta1_MapValue_FieldsEntry_key_tag,
      google_firestore_v1beta1_MapValue_FieldsEntry_value_tag);
}

ObjectValue::Map::value_type DecodeDocumentFieldsEntry(Reader* reader) {
  return DecodeFieldsEntry(
      reader, google_firestore_v1beta1_Document_FieldsEntry_key_tag,
      google_firestore_v1beta1_Document_FieldsEntry_value_tag);
}

ObjectValue::Map DecodeMapValue(Reader* reader) {
  ObjectValue::Map result;
  if (!reader->status().ok()) return result;

  while (reader->bytes_left()) {
    Tag tag = reader->ReadTag();
    if (!reader->status().ok()) return result;
    // The MapValue message only has a single valid tag.
    // TODO(rsgowman): figure out error handling: We can do better than a
    // failed assertion.
    HARD_ASSERT(tag.field_number ==
                google_firestore_v1beta1_MapValue_fields_tag);
    HARD_ASSERT(tag.wire_type == PB_WT_STRING);

    ObjectValue::Map::value_type fv =
        reader->ReadNestedMessage<ObjectValue::Map::value_type>(
            DecodeMapValueFieldsEntry);

    if (!reader->status().ok()) return result;

    // Assumption: If we parse two entries for the map that have the same key,
    // then the latter should overwrite the former. This does not appear to be
    // explicitly called out by the docs, but seems to be in the spirit of how
    // things work. (i.e. non-repeated fields explicitly follow this behaviour.)
    // In any case, well behaved proto emitters shouldn't create encodings like
    // this, but well behaved parsers are expected to handle these cases.
    //
    // https://developers.google.com/protocol-buffers/docs/encoding#optional

    // Add this key,fieldvalue to the results map.
    result[fv.first] = fv.second;
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

Status Serializer::EncodeFieldValue(const FieldValue& field_value,
                                    std::vector<uint8_t>* out_bytes) {
  Writer writer = Writer::Wrap(out_bytes);
  EncodeFieldValue(&writer, field_value);
  return writer.status();
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

StatusOr<FieldValue> Serializer::DecodeFieldValue(const uint8_t* bytes,
                                                  size_t length) {
  Reader reader = Reader::Wrap(bytes, length);
  FieldValue fv = DecodeFieldValueImpl(&reader);
  if (reader.status().ok()) {
    return fv;
  } else {
    return reader.status();
  }
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

util::Status Serializer::EncodeDocument(const DocumentKey& key,
                                        const ObjectValue& value,
                                        std::vector<uint8_t>* out_bytes) const {
  Writer writer = Writer::Wrap(out_bytes);
  EncodeDocument(&writer, key, value);
  return writer.status();
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

util::StatusOr<std::unique_ptr<model::MaybeDocument>>
Serializer::DecodeMaybeDocument(const uint8_t* bytes, size_t length) const {
  Reader reader = Reader::Wrap(bytes, length);
  std::unique_ptr<MaybeDocument> maybeDoc =
      DecodeBatchGetDocumentsResponse(&reader);

  if (reader.status().ok()) {
    return std::move(maybeDoc);
  } else {
    return reader.status();
  }
}

std::unique_ptr<MaybeDocument> Serializer::DecodeBatchGetDocumentsResponse(
    Reader* reader) const {
  if (!reader->status().ok()) return nullptr;

  // Initialize BatchGetDocumentsResponse fields to their default values
  std::unique_ptr<MaybeDocument> found;
  std::string missing;
  // We explicitly ignore the 'transaction' field
  SnapshotVersion read_time = SnapshotVersion::None();

  while (reader->bytes_left()) {
    Tag tag = reader->ReadTag();
    if (!reader->status().ok()) return nullptr;

    // Ensure the tag matches the wire type
    switch (tag.field_number) {
      case google_firestore_v1beta1_BatchGetDocumentsResponse_found_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag)) return nullptr;
        // 'found' and 'missing' are part of a oneof. The proto docs claim that
        // if both are set on the wire, the last one wins.
        missing = "";

        // TODO(rsgowman): If multiple 'found' values are found, we should merge
        // them (rather than using the last one.)
        found = reader->ReadNestedMessage<std::unique_ptr<MaybeDocument>>(
            [this](Reader* reader) -> std::unique_ptr<MaybeDocument> {
              return DecodeDocument(reader);
            });
        break;

      case google_firestore_v1beta1_BatchGetDocumentsResponse_missing_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag)) return nullptr;
        // 'found' and 'missing' are part of a oneof. The proto docs claim that
        // if both are set on the wire, the last one wins.
        found = nullptr;

        missing = reader->ReadString();
        break;

      case google_firestore_v1beta1_BatchGetDocumentsResponse_read_time_tag:
        if (!reader->RequireWireType(PB_WT_STRING, tag)) return nullptr;
        read_time = SnapshotVersion{
            reader->ReadNestedMessage<Timestamp>(DecodeTimestamp)};
        break;

      case google_firestore_v1beta1_BatchGetDocumentsResponse_transaction_tag:
        // This field is ignored by the client sdk, but we still need to extract
        // it.
      default:
        // Unknown tag. According to the proto spec, we need to ignore these.
        reader->SkipField(tag);
    }
  }

  if (found != nullptr) {
    return found;
  } else if (!missing.empty()) {
    return absl::make_unique<NoDocument>(DecodeKey(missing), read_time);
  } else {
    reader->set_status(Status(FirestoreErrorCode::DataLoss,
                              "Invalid BatchGetDocumentsReponse message: "
                              "Neither 'found' nor 'missing' fields set."));
    return nullptr;
  }
}

std::unique_ptr<Document> Serializer::DecodeDocument(Reader* reader) const {
  if (!reader->status().ok()) return nullptr;

  std::string name;
  ObjectValue::Map fields_internal;
  SnapshotVersion version = SnapshotVersion::None();

  while (reader->bytes_left()) {
    Tag tag = reader->ReadTag();
    if (!reader->status().ok()) return nullptr;
    HARD_ASSERT(tag.wire_type == PB_WT_STRING);
    switch (tag.field_number) {
      case google_firestore_v1beta1_Document_name_tag:
        name = reader->ReadString();
        break;
      case google_firestore_v1beta1_Document_fields_tag: {
        ObjectValue::Map::value_type fv =
            reader->ReadNestedMessage<ObjectValue::Map::value_type>(
                DecodeDocumentFieldsEntry);

        if (!reader->status().ok()) return nullptr;

        // Assumption: For duplicates, the latter overrides the former, see
        // comment on writing object map for details (DecodeMapValue).

        // Add fieldvalue to the results map.
        fields_internal[fv.first] = fv.second;
        break;
      }
      case google_firestore_v1beta1_Document_create_time_tag:
        // This field is ignored by the client sdk, but we still need to extract
        // it.
        reader->ReadNestedMessage<Timestamp>(DecodeTimestamp);
        break;
      case google_firestore_v1beta1_Document_update_time_tag:
        // TODO(rsgowman): Rather than overwriting, we should instead merge with
        // the existing SnapshotVersion (if any). Less relevant here, since it's
        // just two numbers which are both expected to be present, but if the
        // proto evolves that might change.
        version = SnapshotVersion{
            reader->ReadNestedMessage<Timestamp>(DecodeTimestamp)};
        break;
      default:
        // TODO(rsgowman): Error handling. (Invalid tags should fail to decode,
        // but shouldn't cause a crash.)
        abort();
    }
  }

  return absl::make_unique<Document>(
      FieldValue::ObjectValueFromMap(fields_internal), DecodeKey(name), version,
      /*has_local_modifications=*/false);
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

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
