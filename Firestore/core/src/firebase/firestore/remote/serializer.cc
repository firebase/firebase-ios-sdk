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

#include <algorithm>
#include <functional>
#include <limits>
#include <map>
#include <set>
#include <string>
#include <utility>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1/firestore.nanopb.h"
#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/delete_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/patch_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/model/set_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/transform_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/verify_mutation.h"
#include "Firestore/core/src/firebase/firestore/nanopb/byte_string.h"
#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/timestamp_internal.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/string_format.h"
#include "absl/algorithm/container.h"

namespace firebase {
namespace firestore {
namespace remote {

using core::Bound;
using core::CollectionGroupId;
using core::Direction;
using core::FieldFilter;
using core::Filter;
using core::FilterList;
using core::LimitType;
using core::OrderBy;
using core::OrderByList;
using core::Query;
using core::Target;
using local::QueryPurpose;
using local::TargetData;
using model::ArrayTransform;
using model::DatabaseId;
using model::DeleteMutation;
using model::Document;
using model::DocumentKey;
using model::DocumentState;
using model::FieldMask;
using model::FieldPath;
using model::FieldTransform;
using model::FieldValue;
using model::MaybeDocument;
using model::Mutation;
using model::MutationResult;
using model::NoDocument;
using model::NumericIncrementTransform;
using model::ObjectValue;
using model::PatchMutation;
using model::Precondition;
using model::ResourcePath;
using model::ServerTimestampTransform;
using model::SetMutation;
using model::SnapshotVersion;
using model::TargetId;
using model::TransformMutation;
using model::TransformOperation;
using model::VerifyMutation;
using nanopb::ByteString;
using nanopb::CheckedSize;
using nanopb::MakeArray;
using nanopb::MakeStringView;
using nanopb::Reader;
using nanopb::SafeReadBoolean;
using nanopb::Writer;
using remote::WatchChange;
using util::Status;
using util::StringFormat;

pb_bytes_array_t* Serializer::EncodeString(const std::string& str) {
  return nanopb::MakeBytesArray(str);
}

std::string Serializer::DecodeString(const pb_bytes_array_t* str) {
  return nanopb::MakeString(str);
}

namespace {

/**
 * Creates the prefix for a fully qualified resource path, without a local path
 * on the end.
 */
ResourcePath DatabaseName(const DatabaseId& database_id) {
  return ResourcePath{"projects", database_id.project_id(), "databases",
                      database_id.database_id()};
}

/**
 * Validates that a path has a prefix that looks like a valid encoded
 * database ID.
 */
bool IsValidResourceName(const ResourcePath& path) {
  // Resource names have at least 4 components (project ID, database ID)
  // and commonly the (root) resource type, e.g. documents
  return path.size() >= 4 && path[0] == "projects" && path[2] == "databases";
}

/**
 * Decodes a fully qualified resource name into a resource path and validates
 * that there is a project and database encoded in the path along with a local
 * path.
 */
ResourcePath ExtractLocalPathFromResourceName(
    Reader* reader, const ResourcePath& resource_name) {
  if (resource_name.size() <= 4 || resource_name[4] != "documents") {
    reader->Fail(StringFormat("Tried to deserialize invalid key %s",
                              resource_name.CanonicalString()));
    return ResourcePath{};
  }
  return resource_name.PopFirst(5);
}

Filter InvalidFilter() {
  // The exact value doesn't matter. Note that there's no way to create the base
  // class `Filter`, so it has to be one of the derived classes.
  return FieldFilter::Create({}, {}, {});
}

}  // namespace

Serializer::Serializer(DatabaseId database_id)
    : database_id_(std::move(database_id)) {
}

pb_bytes_array_t* Serializer::EncodeDatabaseName() const {
  return EncodeString(DatabaseName(database_id_).CanonicalString());
}

google_firestore_v1_Value Serializer::EncodeFieldValue(
    const FieldValue& field_value) const {
  switch (field_value.type()) {
    case FieldValue::Type::Null:
      return EncodeNull();

    case FieldValue::Type::Boolean:
      return EncodeBoolean(field_value.boolean_value());

    case FieldValue::Type::Integer:
      return EncodeInteger(field_value.integer_value());

    case FieldValue::Type::Double:
      return EncodeDouble(field_value.double_value());

    case FieldValue::Type::Timestamp:
      return EncodeTimestampValue(field_value.timestamp_value());

    case FieldValue::Type::String:
      return EncodeStringValue(field_value.string_value());

    case FieldValue::Type::Blob:
      return EncodeBlob(field_value.blob_value());

    case FieldValue::Type::Reference:
      return EncodeReference(field_value.reference_value());

    case FieldValue::Type::GeoPoint:
      return EncodeGeoPoint(field_value.geo_point_value());

    case FieldValue::Type::Array: {
      google_firestore_v1_Value result{};
      result.which_value_type = google_firestore_v1_Value_array_value_tag;
      result.array_value = EncodeArray(field_value.array_value());
      return result;
    }

    case FieldValue::Type::Object: {
      google_firestore_v1_Value result{};
      result.which_value_type = google_firestore_v1_Value_map_value_tag;
      result.map_value = EncodeMapValue(ObjectValue(field_value));
      return result;
    }

    case FieldValue::Type::ServerTimestamp:
      HARD_FAIL("Unhandled type %s on %s", field_value.type(),
                field_value.ToString());
  }
  UNREACHABLE();
}

google_firestore_v1_Value Serializer::EncodeNull() const {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_null_value_tag;
  result.null_value = google_protobuf_NullValue_NULL_VALUE;
  return result;
}

google_firestore_v1_Value Serializer::EncodeBoolean(bool value) const {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_boolean_value_tag;
  result.boolean_value = value;
  return result;
}

google_firestore_v1_Value Serializer::EncodeInteger(int64_t value) const {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_integer_value_tag;
  result.integer_value = value;
  return result;
}

google_firestore_v1_Value Serializer::EncodeDouble(double value) const {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_double_value_tag;
  result.double_value = value;
  return result;
}

google_firestore_v1_Value Serializer::EncodeTimestampValue(
    Timestamp value) const {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_timestamp_value_tag;
  result.timestamp_value = EncodeTimestamp(value);
  return result;
}

google_firestore_v1_Value Serializer::EncodeStringValue(
    const std::string& value) const {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_string_value_tag;
  result.string_value = EncodeString(value);
  return result;
}

google_firestore_v1_Value Serializer::EncodeBlob(
    const nanopb::ByteString& value) const {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_bytes_value_tag;
  // Copy the blob so that pb_release can do the right thing.
  result.bytes_value = nanopb::CopyBytesArray(value.get());
  return result;
}

google_firestore_v1_Value Serializer::EncodeReference(
    const FieldValue::Reference& value) const {
  HARD_ASSERT(database_id_ == value.database_id(),
              "Database %s cannot encode reference from %s",
              database_id_.ToString(), value.database_id().ToString());

  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_reference_value_tag;
  result.reference_value =
      EncodeResourceName(value.database_id(), value.key().path());

  return result;
}

google_firestore_v1_Value Serializer::EncodeGeoPoint(
    const GeoPoint& value) const {
  google_firestore_v1_Value result{};
  result.which_value_type = google_firestore_v1_Value_geo_point_value_tag;

  google_type_LatLng geo_point{};
  geo_point.latitude = value.latitude();
  geo_point.longitude = value.longitude();
  result.geo_point_value = geo_point;

  return result;
}

FieldValue::Map::value_type Serializer::DecodeFieldsEntry(
    Reader* reader,
    const google_firestore_v1_Document_FieldsEntry& fields) const {
  std::string key = DecodeString(fields.key);
  FieldValue value = DecodeFieldValue(reader, fields.value);

  if (key.empty()) {
    reader->Fail(
        "Invalid message: Empty key while decoding a Map field value.");
    return {};
  }

  return FieldValue::Map::value_type{std::move(key), std::move(value)};
}

ObjectValue Serializer::DecodeFields(
    Reader* reader,
    size_t count,
    const google_firestore_v1_Document_FieldsEntry* fields) const {
  FieldValue::Map result;
  for (size_t i = 0; i < count; i++) {
    FieldValue::Map::value_type kv = DecodeFieldsEntry(reader, fields[i]);
    result = result.insert(std::move(kv.first), std::move(kv.second));
  }

  return ObjectValue::FromMap(result);
}

FieldValue::Map Serializer::DecodeMapValue(
    Reader* reader, const google_firestore_v1_MapValue& map_value) const {
  FieldValue::Map result;

  for (size_t i = 0; i < map_value.fields_count; i++) {
    std::string key = DecodeString(map_value.fields[i].key);
    FieldValue value = DecodeFieldValue(reader, map_value.fields[i].value);

    result = result.insert(key, value);
  }

  return result;
}

FieldValue Serializer::DecodeFieldValue(
    Reader* reader, const google_firestore_v1_Value& msg) const {
  switch (msg.which_value_type) {
    case google_firestore_v1_Value_null_value_tag:
      if (msg.null_value != google_protobuf_NullValue_NULL_VALUE) {
        reader->Fail("Input proto bytes cannot be parsed (invalid null value)");
      }
      return FieldValue::Null();

    case google_firestore_v1_Value_boolean_value_tag: {
      return FieldValue::FromBoolean(SafeReadBoolean(msg.boolean_value));
    }

    case google_firestore_v1_Value_integer_value_tag:
      return FieldValue::FromInteger(msg.integer_value);

    case google_firestore_v1_Value_double_value_tag:
      return FieldValue::FromDouble(msg.double_value);

    case google_firestore_v1_Value_timestamp_value_tag: {
      return FieldValue::FromTimestamp(
          DecodeTimestamp(reader, msg.timestamp_value));
    }

    case google_firestore_v1_Value_string_value_tag:
      return FieldValue::FromString(DecodeString(msg.string_value));

    case google_firestore_v1_Value_bytes_value_tag:
      return FieldValue::FromBlob(ByteString(msg.bytes_value));

    case google_firestore_v1_Value_reference_value_tag:
      return DecodeReference(reader, msg.reference_value);

    case google_firestore_v1_Value_geo_point_value_tag:
      return FieldValue::FromGeoPoint(
          DecodeGeoPoint(reader, msg.geo_point_value));

    case google_firestore_v1_Value_array_value_tag:
      return FieldValue::FromArray(DecodeArray(reader, msg.array_value));

    case google_firestore_v1_Value_map_value_tag: {
      return FieldValue::FromMap(DecodeMapValue(reader, msg.map_value));
    }

    default:
      reader->Fail(StringFormat("Invalid type while decoding FieldValue: %s",
                                msg.which_value_type));
      return FieldValue::Null();
  }

  UNREACHABLE();
}

pb_bytes_array_t* Serializer::EncodeKey(const DocumentKey& key) const {
  return EncodeResourceName(database_id_, key.path());
}

void Serializer::ValidateDocumentKeyPath(
    Reader* reader, const ResourcePath& resource_name) const {
  if (resource_name.size() < 5) {
    reader->Fail(
        StringFormat("Attempted to decode invalid key: '%s'. Should have at "
                     "least 5 segments.",
                     resource_name.CanonicalString()));
  } else if (resource_name[1] != database_id_.project_id()) {
    reader->Fail(
        StringFormat("Tried to deserialize key from different project. "
                     "Expected: '%s'. Found: '%s'. (Full key: '%s')",
                     database_id_.project_id(), resource_name[1],
                     resource_name.CanonicalString()));
  } else if (resource_name[3] != database_id_.database_id()) {
    reader->Fail(
        StringFormat("Tried to deserialize key from different database. "
                     "Expected: '%s'. Found: '%s'. (Full key: '%s')",
                     database_id_.database_id(), resource_name[3],
                     resource_name.CanonicalString()));
  }
}

DocumentKey Serializer::DecodeKey(Reader* reader,
                                  const pb_bytes_array_t* name) const {
  ResourcePath resource_name = DecodeResourceName(reader, MakeStringView(name));
  ValidateDocumentKeyPath(reader, resource_name);

  return DecodeKey(reader, resource_name);
}

DocumentKey Serializer::DecodeKey(Reader* reader,
                                  const ResourcePath& resource_name) const {
  ResourcePath local_path =
      ExtractLocalPathFromResourceName(reader, resource_name);

  if (!DocumentKey::IsDocumentKey(local_path)) {
    reader->Fail(StringFormat("Invalid document key path: %s",
                              local_path.CanonicalString()));
  }

  // Avoid assertion failures in DocumentKey if local_path is invalid.
  if (!reader->status().ok()) return DocumentKey{};
  return DocumentKey{std::move(local_path)};
}

pb_bytes_array_t* Serializer::EncodeQueryPath(const ResourcePath& path) const {
  return EncodeResourceName(database_id_, path);
}

ResourcePath Serializer::DecodeQueryPath(Reader* reader,
                                         absl::string_view name) const {
  ResourcePath resource = DecodeResourceName(reader, name);
  if (resource.size() == 4) {
    // In v1beta1 queries for collections at the root did not have a trailing
    // "/documents". In v1 all resource paths contain "/documents". Preserve the
    // ability to read the v1beta1 form for compatibility with queries persisted
    // in the local target cache.
    return ResourcePath::Empty();
  } else {
    return ExtractLocalPathFromResourceName(reader, resource);
  }
}

pb_bytes_array_t* Serializer::EncodeResourceName(
    const DatabaseId& database_id, const ResourcePath& path) const {
  return Serializer::EncodeString(DatabaseName(database_id)
                                      .Append("documents")
                                      .Append(path)
                                      .CanonicalString());
}

ResourcePath Serializer::DecodeResourceName(Reader* reader,
                                            absl::string_view encoded) const {
  ResourcePath resource = ResourcePath::FromStringView(encoded);
  if (!IsValidResourceName(resource)) {
    reader->Fail(StringFormat("Tried to deserialize an invalid key %s",
                              resource.CanonicalString()));
  }
  return resource;
}

DatabaseId Serializer::DecodeDatabaseId(
    Reader* reader, const ResourcePath& resource_name) const {
  if (resource_name.size() < 4) {
    reader->Fail(StringFormat("Tried to deserialize invalid key %s",
                              resource_name.CanonicalString()));
    return DatabaseId{};
  }

  const std::string& project_id = resource_name[1];
  const std::string& database_id = resource_name[3];
  return DatabaseId{project_id, database_id};
}

google_firestore_v1_Document Serializer::EncodeDocument(
    const DocumentKey& key, const ObjectValue& object_value) const {
  google_firestore_v1_Document result{};

  result.name = EncodeKey(key);

  // Encode Document.fields (unless it's empty)
  pb_size_t count = CheckedSize(object_value.GetInternalValue().size());
  result.fields_count = count;
  result.fields = MakeArray<google_firestore_v1_Document_FieldsEntry>(count);
  int i = 0;
  for (const auto& kv : object_value.GetInternalValue()) {
    result.fields[i].key = EncodeString(kv.first);
    result.fields[i].value = EncodeFieldValue(kv.second);
    i++;
  }

  // Skip Document.create_time and Document.update_time, since they're
  // output-only fields.

  return result;
}

MaybeDocument Serializer::DecodeMaybeDocument(
    Reader* reader,
    const google_firestore_v1_BatchGetDocumentsResponse& response) const {
  switch (response.which_result) {
    case google_firestore_v1_BatchGetDocumentsResponse_found_tag:
      return DecodeFoundDocument(reader, response);
    case google_firestore_v1_BatchGetDocumentsResponse_missing_tag:
      return DecodeMissingDocument(reader, response);
    default:
      reader->Fail(
          StringFormat("Unknown result case: %s", response.which_result));
      return {};
  }

  UNREACHABLE();
}

Document Serializer::DecodeFoundDocument(
    Reader* reader,
    const google_firestore_v1_BatchGetDocumentsResponse& response) const {
  HARD_ASSERT(response.which_result ==
                  google_firestore_v1_BatchGetDocumentsResponse_found_tag,
              "Tried to deserialize a found document from a missing document.");

  DocumentKey key = DecodeKey(reader, response.found.name);
  ObjectValue value =
      DecodeFields(reader, response.found.fields_count, response.found.fields);
  SnapshotVersion version = DecodeVersion(reader, response.found.update_time);

  if (version == SnapshotVersion::None()) {
    reader->Fail("Got a document response with no snapshot version");
  }

  return Document(std::move(value), std::move(key), version,
                  DocumentState::kSynced);
}

NoDocument Serializer::DecodeMissingDocument(
    Reader* reader,
    const google_firestore_v1_BatchGetDocumentsResponse& response) const {
  HARD_ASSERT(response.which_result ==
                  google_firestore_v1_BatchGetDocumentsResponse_missing_tag,
              "Tried to deserialize a missing document from a found document.");

  DocumentKey key = DecodeKey(reader, response.missing);
  SnapshotVersion version = DecodeVersion(reader, response.read_time);

  if (version == SnapshotVersion::None()) {
    reader->Fail("Got a no document response with no snapshot version");
    return {};
  }

  return NoDocument(std::move(key), version,
                    /*has_committed_mutations=*/false);
}

google_firestore_v1_Write Serializer::EncodeMutation(
    const Mutation& mutation) const {
  HARD_ASSERT(mutation.is_valid(), "Invalid mutation encountered.");
  google_firestore_v1_Write result{};

  if (!mutation.precondition().is_none()) {
    result.has_current_document = true;
    result.current_document = EncodePrecondition(mutation.precondition());
  }

  switch (mutation.type()) {
    case Mutation::Type::Set: {
      result.which_operation = google_firestore_v1_Write_update_tag;
      result.update = EncodeDocument(
          mutation.key(), static_cast<const SetMutation&>(mutation).value());
      return result;
    }

    case Mutation::Type::Patch: {
      result.which_operation = google_firestore_v1_Write_update_tag;
      auto patch_mutation = static_cast<const PatchMutation&>(mutation);
      result.update = EncodeDocument(mutation.key(), patch_mutation.value());
      // Note: the fact that this field is set (even if the mask is empty) is
      // what makes the backend treat this as a patch mutation, not a set
      // mutation.
      result.has_update_mask = true;
      if (patch_mutation.mask().size() != 0) {
        result.update_mask = EncodeFieldMask(patch_mutation.mask());
      }
      return result;
    }

    case Mutation::Type::Transform: {
      result.which_operation = google_firestore_v1_Write_transform_tag;
      auto transform = static_cast<const TransformMutation&>(mutation);
      result.transform.document = EncodeKey(transform.key());

      pb_size_t count = CheckedSize(transform.field_transforms().size());
      result.transform.field_transforms_count = count;
      result.transform.field_transforms =
          MakeArray<google_firestore_v1_DocumentTransform_FieldTransform>(
              count);
      int i = 0;
      for (const FieldTransform& field_transform :
           transform.field_transforms()) {
        result.transform.field_transforms[i] =
            EncodeFieldTransform(field_transform);
        i++;
      }

      // NOTE: We set a precondition of exists: true as a safety-check, since we
      // always combine TransformMutations with a SetMutation or PatchMutation
      // which (if successful) should end up with an existing document.
      result.has_current_document = true;
      result.current_document = EncodePrecondition(Precondition::Exists(true));

      return result;
    }

    case Mutation::Type::Delete: {
      result.which_operation = google_firestore_v1_Write_delete_tag;
      result.delete_ = EncodeKey(mutation.key());
      return result;
    }

    case Mutation::Type::Verify: {
      result.which_operation = google_firestore_v1_Write_verify_tag;
      result.verify = EncodeKey(mutation.key());
      return result;
    }
  }

  UNREACHABLE();
}

Mutation Serializer::DecodeMutation(
    nanopb::Reader* reader, const google_firestore_v1_Write& mutation) const {
  auto precondition = Precondition::None();
  if (mutation.has_current_document) {
    precondition = DecodePrecondition(reader, mutation.current_document);
  }

  switch (mutation.which_operation) {
    case google_firestore_v1_Write_update_tag: {
      DocumentKey key = DecodeKey(reader, mutation.update.name);
      ObjectValue value = DecodeFields(reader, mutation.update.fields_count,
                                       mutation.update.fields);
      if (mutation.has_update_mask) {
        FieldMask mask = DecodeFieldMask(mutation.update_mask);
        return PatchMutation(std::move(key), std::move(value), std::move(mask),
                             std::move(precondition));
      } else {
        return SetMutation(std::move(key), std::move(value),
                           std::move(precondition));
      }
    }

    case google_firestore_v1_Write_delete_tag:
      return DeleteMutation(DecodeKey(reader, mutation.delete_),
                            std::move(precondition));

    case google_firestore_v1_Write_transform_tag: {
      std::vector<FieldTransform> field_transforms;
      for (size_t i = 0; i < mutation.transform.field_transforms_count; i++) {
        field_transforms.push_back(DecodeFieldTransform(
            reader, mutation.transform.field_transforms[i]));
      }

      HARD_ASSERT(precondition.type() == Precondition::Type::Exists &&
                      precondition.exists(),
                  "Transforms only support precondition \"exists == true\"");

      return TransformMutation(DecodeKey(reader, mutation.transform.document),
                               field_transforms);
    }

    case google_firestore_v1_Write_verify_tag: {
      return VerifyMutation(DecodeKey(reader, mutation.verify),
                            std::move(precondition));
    }

    default:
      reader->Fail(StringFormat("Unknown mutation operation: %s",
                                mutation.which_operation));
      return {};
  }

  UNREACHABLE();
}

/* static */
google_firestore_v1_Precondition Serializer::EncodePrecondition(
    const Precondition& precondition) {
  google_firestore_v1_Precondition result{};

  switch (precondition.type()) {
    case Precondition::Type::None:
      HARD_FAIL("Can't serialize an empty precondition");

    case Precondition::Type::UpdateTime:
      result.which_condition_type =
          google_firestore_v1_Precondition_update_time_tag;
      result.update_time = EncodeVersion(precondition.update_time());
      return result;

    case Precondition::Type::Exists:
      result.which_condition_type = google_firestore_v1_Precondition_exists_tag;
      result.exists = precondition.exists();
      return result;
  }

  UNREACHABLE();
}

/* static */
Precondition Serializer::DecodePrecondition(
    nanopb::Reader* reader,
    const google_firestore_v1_Precondition& precondition) {
  switch (precondition.which_condition_type) {
    // 0 => type unset. nanopb doesn't provide a constant for this, so we use a
    // raw integer.
    case 0:
      return Precondition::None();
    case google_firestore_v1_Precondition_exists_tag: {
      // TODO(rsgowman): Refactor with other instance of bit_cast.

      // Due to the nanopb implementation, precondition.exists could be an
      // integer other than 0 or 1, (such as 2). This leads to undefined
      // behaviour when it's read as a boolean. eg. on at least gcc, the value
      // is treated as both true *and* false. So we'll instead memcpy to an
      // integer (via absl::bit_cast) and compare with 0.
      int bool_as_int = absl::bit_cast<int8_t>(precondition.exists);
      return Precondition::Exists(bool_as_int != 0);
    }
    case google_firestore_v1_Precondition_update_time_tag:
      return Precondition::UpdateTime(
          DecodeVersion(reader, precondition.update_time));
  }

  reader->Fail(StringFormat("Unknown Precondition type: %s",
                            precondition.which_condition_type));
  return Precondition::None();
}

/* static */
google_firestore_v1_DocumentMask Serializer::EncodeFieldMask(
    const FieldMask& mask) {
  google_firestore_v1_DocumentMask result{};

  pb_size_t count = CheckedSize(mask.size());
  result.field_paths_count = count;
  result.field_paths = MakeArray<pb_bytes_array_t*>(count);

  int i = 0;
  for (const FieldPath& path : mask) {
    result.field_paths[i] = EncodeFieldPath(path);
    i++;
  }

  return result;
}

/* static */
FieldMask Serializer::DecodeFieldMask(
    const google_firestore_v1_DocumentMask& mask) {
  std::set<FieldPath> fields;
  for (size_t i = 0; i < mask.field_paths_count; i++) {
    fields.insert(DecodeFieldPath(mask.field_paths[i]));
  }
  return FieldMask(std::move(fields));
}

google_firestore_v1_DocumentTransform_FieldTransform
Serializer::EncodeFieldTransform(const FieldTransform& field_transform) const {
  using Type = TransformOperation::Type;

  google_firestore_v1_DocumentTransform_FieldTransform proto{};
  proto.field_path = EncodeFieldPath(field_transform.path());

  switch (field_transform.transformation().type()) {
    case Type::ServerTimestamp:
      proto.which_transform_type =
          google_firestore_v1_DocumentTransform_FieldTransform_set_to_server_value_tag;  // NOLINT
      proto.set_to_server_value =
          google_firestore_v1_DocumentTransform_FieldTransform_ServerValue_REQUEST_TIME;  // NOLINT
      return proto;

    case Type::ArrayUnion:
      proto.which_transform_type =
          google_firestore_v1_DocumentTransform_FieldTransform_append_missing_elements_tag;  // NOLINT
      proto.append_missing_elements = EncodeArray(
          ArrayTransform(field_transform.transformation()).elements());
      return proto;

    case Type::ArrayRemove:
      proto.which_transform_type =
          google_firestore_v1_DocumentTransform_FieldTransform_remove_all_from_array_tag;  // NOLINT
      proto.remove_all_from_array = EncodeArray(
          ArrayTransform(field_transform.transformation()).elements());
      return proto;

    case Type::Increment: {
      proto.which_transform_type =
          google_firestore_v1_DocumentTransform_FieldTransform_increment_tag;
      const auto& increment = static_cast<const NumericIncrementTransform&>(
          field_transform.transformation());
      proto.increment = EncodeFieldValue(increment.operand());
      return proto;
    }
  }

  UNREACHABLE();
}

FieldTransform Serializer::DecodeFieldTransform(
    nanopb::Reader* reader,
    const google_firestore_v1_DocumentTransform_FieldTransform& proto) const {
  switch (proto.which_transform_type) {
    case google_firestore_v1_DocumentTransform_FieldTransform_set_to_server_value_tag: {  // NOLINT
      HARD_ASSERT(
          proto.set_to_server_value ==
              google_firestore_v1_DocumentTransform_FieldTransform_ServerValue_REQUEST_TIME,  // NOLINT
          "Unknown transform setToServerValue: %s", proto.set_to_server_value);

      return FieldTransform(DecodeFieldPath(proto.field_path),
                            ServerTimestampTransform());
    }

    case google_firestore_v1_DocumentTransform_FieldTransform_append_missing_elements_tag: {  // NOLINT
      std::vector<FieldValue> elements =
          DecodeArray(reader, proto.append_missing_elements);
      return FieldTransform(DecodeFieldPath(proto.field_path),
                            ArrayTransform(TransformOperation::Type::ArrayUnion,
                                           std::move(elements)));
    }

    case google_firestore_v1_DocumentTransform_FieldTransform_remove_all_from_array_tag: {  // NOLINT
      std::vector<FieldValue> elements =
          DecodeArray(reader, proto.remove_all_from_array);
      return FieldTransform(
          DecodeFieldPath(proto.field_path),
          ArrayTransform(TransformOperation::Type::ArrayRemove,
                         std::move(elements)));
    }

    case google_firestore_v1_DocumentTransform_FieldTransform_increment_tag: {
      FieldValue operand = DecodeFieldValue(reader, proto.increment);
      return FieldTransform(DecodeFieldPath(proto.field_path),
                            NumericIncrementTransform(std::move(operand)));
    }
  }

  UNREACHABLE();
}

google_firestore_v1_Target Serializer::EncodeTarget(
    const TargetData& target_data) const {
  google_firestore_v1_Target result{};
  const Target& target = target_data.target();

  if (target.IsDocumentQuery()) {
    result.which_target_type = google_firestore_v1_Target_documents_tag;
    result.target_type.documents = EncodeDocumentsTarget(target);
  } else {
    result.which_target_type = google_firestore_v1_Target_query_tag;
    result.target_type.query = EncodeQueryTarget(target);
  }

  result.target_id = target_data.target_id();
  if (!target_data.resume_token().empty()) {
    result.which_resume_type = google_firestore_v1_Target_resume_token_tag;
    result.resume_type.resume_token =
        nanopb::CopyBytesArray(target_data.resume_token().get());
  }

  return result;
}

google_firestore_v1_Target_DocumentsTarget Serializer::EncodeDocumentsTarget(
    const core::Target& target) const {
  google_firestore_v1_Target_DocumentsTarget result{};

  result.documents_count = 1;
  result.documents = MakeArray<pb_bytes_array_t*>(result.documents_count);
  result.documents[0] = EncodeQueryPath(target.path());

  return result;
}

Target Serializer::DecodeDocumentsTarget(
    nanopb::Reader* reader,
    const google_firestore_v1_Target_DocumentsTarget& proto) const {
  if (proto.documents_count != 1) {
    reader->Fail(
        StringFormat("DocumentsTarget contained other than 1 document %s",
                     proto.documents_count));
    return {};
  }

  ResourcePath path = DecodeQueryPath(reader, DecodeString(proto.documents[0]));
  return Query(std::move(path)).ToTarget();
}

google_firestore_v1_Target_QueryTarget Serializer::EncodeQueryTarget(
    const core::Target& target) const {
  google_firestore_v1_Target_QueryTarget result{};
  result.which_query_type =
      google_firestore_v1_Target_QueryTarget_structured_query_tag;

  pb_size_t from_count = 1;
  result.structured_query.from_count = from_count;
  result.structured_query.from =
      MakeArray<google_firestore_v1_StructuredQuery_CollectionSelector>(
          from_count);
  google_firestore_v1_StructuredQuery_CollectionSelector& from =
      result.structured_query.from[0];

  // Dissect the path into parent, collection_id and optional key filter.
  const ResourcePath& path = target.path();
  if (target.collection_group()) {
    HARD_ASSERT(
        path.size() % 2 == 0,
        "Collection group queries should be within a document path or root.");
    result.parent = EncodeQueryPath(path);

    from.collection_id = EncodeString(*target.collection_group());
    from.all_descendants = true;

  } else {
    HARD_ASSERT(path.size() % 2 != 0,
                "Document queries with filters are not supported.");
    result.parent = EncodeQueryPath(path.PopLast());
    from.collection_id = EncodeString(path.last_segment());
  }

  // Encode the filters.
  const auto& filters = target.filters();
  if (!filters.empty()) {
    result.structured_query.where = EncodeFilters(filters);
  }

  const auto& orders = target.order_bys();
  if (!orders.empty()) {
    result.structured_query.order_by_count = CheckedSize(orders.size());
    result.structured_query.order_by = EncodeOrderBys(orders);
  }

  if (target.limit() != Target::kNoLimit) {
    result.structured_query.has_limit = true;
    result.structured_query.limit.value = target.limit();
  }

  if (target.start_at()) {
    result.structured_query.start_at = EncodeBound(*target.start_at());
  }

  if (target.end_at()) {
    result.structured_query.end_at = EncodeBound(*target.end_at());
  }

  return result;
}

Target Serializer::DecodeQueryTarget(
    nanopb::Reader* reader,
    const google_firestore_v1_Target_QueryTarget& proto) const {
  // The QueryTarget oneof only has a single valid value.
  if (proto.which_query_type !=
      google_firestore_v1_Target_QueryTarget_structured_query_tag) {
    reader->Fail(
        StringFormat("Unknown query_type: %s", proto.which_query_type));
    return {};
  }

  ResourcePath path = DecodeQueryPath(reader, DecodeString(proto.parent));
  const google_firestore_v1_StructuredQuery& query = proto.structured_query;

  CollectionGroupId collection_group;
  size_t from_count = query.from_count;
  if (from_count > 0) {
    if (from_count != 1) {
      reader->Fail(
          "StructuredQuery.from with more than one collection is not "
          "supported.");
      return {};
    }

    google_firestore_v1_StructuredQuery_CollectionSelector& from =
        query.from[0];
    auto collection_id = DecodeString(from.collection_id);
    if (from.all_descendants) {
      collection_group = std::make_shared<const std::string>(collection_id);
    } else {
      path = path.Append(collection_id);
    }
  }

  FilterList filter_by;
  if (query.where.which_filter_type != 0) {
    filter_by = DecodeFilters(reader, query.where);
  }

  OrderByList order_by;
  if (query.order_by_count > 0) {
    order_by = DecodeOrderBys(reader, query.order_by, query.order_by_count);
  }

  int32_t limit = Target::kNoLimit;
  if (query.has_limit) {
    limit = query.limit.value;
  }

  std::shared_ptr<Bound> start_at;
  if (query.start_at.values_count > 0) {
    start_at = DecodeBound(reader, query.start_at);
  }

  std::shared_ptr<Bound> end_at;
  if (query.end_at.values_count > 0) {
    end_at = DecodeBound(reader, query.end_at);
  }

  return Query(std::move(path), std::move(collection_group),
               std::move(filter_by), std::move(order_by), limit,
               LimitType::First, std::move(start_at), std::move(end_at))
      .ToTarget();
}

google_firestore_v1_StructuredQuery_Filter Serializer::EncodeFilters(
    const FilterList& filters) const {
  google_firestore_v1_StructuredQuery_Filter result{};

  auto is_field_filter = [](const Filter& f) { return f.IsAFieldFilter(); };
  size_t filters_count = absl::c_count_if(filters, is_field_filter);
  if (filters_count == 1) {
    auto first = absl::c_find_if(filters, is_field_filter);
    // Special case: no existing filters and we only need to add one filter.
    // This can be made the single root filter without a composite filter.
    FieldFilter filter{*first};
    return EncodeSingularFilter(filter);
  }

  result.which_filter_type =
      google_firestore_v1_StructuredQuery_Filter_composite_filter_tag;
  google_firestore_v1_StructuredQuery_CompositeFilter& composite =
      result.composite_filter;
  composite.op =
      google_firestore_v1_StructuredQuery_CompositeFilter_Operator_AND;

  auto count = CheckedSize(filters_count);
  composite.filters_count = count;
  composite.filters =
      MakeArray<google_firestore_v1_StructuredQuery_Filter>(count);
  pb_size_t i = 0;
  for (const auto& filter : filters) {
    if (filter.IsAFieldFilter()) {
      HARD_ASSERT(i < count, "Index out of bounds");
      composite.filters[i] = EncodeSingularFilter(FieldFilter{filter});
      ++i;
    }
  }

  return result;
}

FilterList Serializer::DecodeFilters(
    nanopb::Reader* reader,
    const google_firestore_v1_StructuredQuery_Filter& proto) const {
  FilterList result;

  switch (proto.which_filter_type) {
    case google_firestore_v1_StructuredQuery_Filter_composite_filter_tag:
      return DecodeCompositeFilter(reader, proto.composite_filter);

    case google_firestore_v1_StructuredQuery_Filter_unary_filter_tag:
      return result.push_back(DecodeUnaryFilter(reader, proto.unary_filter));

    case google_firestore_v1_StructuredQuery_Filter_field_filter_tag:
      return result.push_back(DecodeFieldFilter(reader, proto.field_filter));

    default:
      reader->Fail(StringFormat("Unrecognized Filter.which_filter_type %s",
                                proto.which_filter_type));
      return result;
  }
}

google_firestore_v1_StructuredQuery_Filter Serializer::EncodeSingularFilter(
    const FieldFilter& filter) const {
  google_firestore_v1_StructuredQuery_Filter result{};

  if (filter.op() == Filter::Operator::Equal) {
    if (filter.value().is_null() || filter.value().is_nan()) {
      result.which_filter_type =
          google_firestore_v1_StructuredQuery_Filter_unary_filter_tag;
      result.unary_filter.which_operand_type =
          google_firestore_v1_StructuredQuery_UnaryFilter_field_tag;
      result.unary_filter.field.field_path = EncodeFieldPath(filter.field());

      auto op =
          filter.value().is_null()
              ? google_firestore_v1_StructuredQuery_UnaryFilter_Operator_IS_NULL
              : google_firestore_v1_StructuredQuery_UnaryFilter_Operator_IS_NAN;
      result.unary_filter.op = op;

      return result;
    }
  }

  result.which_filter_type =
      google_firestore_v1_StructuredQuery_Filter_field_filter_tag;

  result.field_filter.field.field_path = EncodeFieldPath(filter.field());
  result.field_filter.op = EncodeFieldFilterOperator(filter.op());
  result.field_filter.value = EncodeFieldValue(filter.value());

  return result;
}

Filter Serializer::DecodeFieldFilter(
    nanopb::Reader* reader,
    const google_firestore_v1_StructuredQuery_FieldFilter& field_filter) const {
  FieldPath field_path =
      FieldPath::FromServerFormat(DecodeString(field_filter.field.field_path));
  Filter::Operator op = DecodeFieldFilterOperator(reader, field_filter.op);
  FieldValue value = DecodeFieldValue(reader, field_filter.value);

  return FieldFilter::Create(std::move(field_path), op, std::move(value));
}

Filter Serializer::DecodeUnaryFilter(
    nanopb::Reader* reader,
    const google_firestore_v1_StructuredQuery_UnaryFilter& unary) const {
  HARD_ASSERT(unary.which_operand_type ==
                  google_firestore_v1_StructuredQuery_UnaryFilter_field_tag,
              "Unexpected UnaryFilter.which_operand_type: %s",
              unary.which_operand_type);

  auto field =
      FieldPath::FromServerFormat(DecodeString(unary.field.field_path));

  switch (unary.op) {
    case google_firestore_v1_StructuredQuery_UnaryFilter_Operator_IS_NULL:
      return FieldFilter::Create(std::move(field), Filter::Operator::Equal,
                                 FieldValue::Null());

    case google_firestore_v1_StructuredQuery_UnaryFilter_Operator_IS_NAN:
      return FieldFilter::Create(std::move(field), Filter::Operator::Equal,
                                 FieldValue::Nan());

    default:
      reader->Fail(StringFormat("Unrecognized UnaryFilter.op %s", unary.op));
      return InvalidFilter();
  }
}

FilterList Serializer::DecodeCompositeFilter(
    nanopb::Reader* reader,
    const google_firestore_v1_StructuredQuery_CompositeFilter& composite)
    const {
  if (composite.op !=
      google_firestore_v1_StructuredQuery_CompositeFilter_Operator_AND) {
    reader->Fail(StringFormat(
        "Only AND-type composite filters are supported, got %s", composite.op));
    return FilterList{};
  }

  FilterList result;
  result = result.reserve(composite.filters_count);

  for (pb_size_t i = 0; i != composite.filters_count; ++i) {
    auto& filter = composite.filters[i];
    switch (filter.which_filter_type) {
      case google_firestore_v1_StructuredQuery_Filter_composite_filter_tag:
        reader->Fail("Nested composite filters are not supported");
        return FilterList{};

      case google_firestore_v1_StructuredQuery_Filter_unary_filter_tag:
        result =
            result.push_back(DecodeUnaryFilter(reader, filter.unary_filter));
        break;

      case google_firestore_v1_StructuredQuery_Filter_field_filter_tag:
        result =
            result.push_back(DecodeFieldFilter(reader, filter.field_filter));
        break;

      default:
        reader->Fail(StringFormat("Unrecognized Filter.which_filter_type %s",
                                  filter.which_filter_type));
        return FilterList{};
    }
  }

  return result;
}

google_firestore_v1_StructuredQuery_FieldFilter_Operator
Serializer::EncodeFieldFilterOperator(Filter::Operator op) const {
  switch (op) {
    case Filter::Operator::LessThan:
      return google_firestore_v1_StructuredQuery_FieldFilter_Operator_LESS_THAN;

    case Filter::Operator::LessThanOrEqual:
      return google_firestore_v1_StructuredQuery_FieldFilter_Operator_LESS_THAN_OR_EQUAL;  // NOLINT

    case Filter::Operator::GreaterThan:
      return google_firestore_v1_StructuredQuery_FieldFilter_Operator_GREATER_THAN;  // NOLINT

    case Filter::Operator::GreaterThanOrEqual:
      return google_firestore_v1_StructuredQuery_FieldFilter_Operator_GREATER_THAN_OR_EQUAL;  // NOLINT

    case Filter::Operator::Equal:
      return google_firestore_v1_StructuredQuery_FieldFilter_Operator_EQUAL;

    case Filter::Operator::ArrayContains:
      return google_firestore_v1_StructuredQuery_FieldFilter_Operator_ARRAY_CONTAINS;  // NOLINT

    case Filter::Operator::In:
      return google_firestore_v1_StructuredQuery_FieldFilter_Operator_IN;

    case Filter::Operator::ArrayContainsAny:
      return google_firestore_v1_StructuredQuery_FieldFilter_Operator_ARRAY_CONTAINS_ANY;  // NOLINT

    default:
      HARD_FAIL("Unhandled Filter::Operator: %s", op);
  }
}

Filter::Operator Serializer::DecodeFieldFilterOperator(
    nanopb::Reader* reader,
    google_firestore_v1_StructuredQuery_FieldFilter_Operator op) const {
  switch (op) {
    case google_firestore_v1_StructuredQuery_FieldFilter_Operator_LESS_THAN:
      return Filter::Operator::LessThan;

    case google_firestore_v1_StructuredQuery_FieldFilter_Operator_LESS_THAN_OR_EQUAL:  // NOLINT
      return Filter::Operator::LessThanOrEqual;

    case google_firestore_v1_StructuredQuery_FieldFilter_Operator_GREATER_THAN:
      return Filter::Operator::GreaterThan;

    case google_firestore_v1_StructuredQuery_FieldFilter_Operator_GREATER_THAN_OR_EQUAL:  // NOLINT
      return Filter::Operator::GreaterThanOrEqual;

    case google_firestore_v1_StructuredQuery_FieldFilter_Operator_EQUAL:
      return Filter::Operator::Equal;

    case google_firestore_v1_StructuredQuery_FieldFilter_Operator_ARRAY_CONTAINS:  // NOLINT
      return Filter::Operator::ArrayContains;

    case google_firestore_v1_StructuredQuery_FieldFilter_Operator_IN:
      return Filter::Operator::In;

    case google_firestore_v1_StructuredQuery_FieldFilter_Operator_ARRAY_CONTAINS_ANY:  // NOLINT
      return Filter::Operator::ArrayContainsAny;

    default:
      reader->Fail(StringFormat("Unhandled FieldFilter.op: %s", op));
      return Filter::Operator{};
  }
}

google_firestore_v1_StructuredQuery_Order* Serializer::EncodeOrderBys(
    const OrderByList& orders) const {
  auto* result = MakeArray<google_firestore_v1_StructuredQuery_Order>(
      CheckedSize(orders.size()));

  int i = 0;
  for (const OrderBy& order : orders) {
    auto& encoded_order = result[i];

    encoded_order.field.field_path = EncodeFieldPath(order.field());
    auto dir = order.ascending()
                   ? google_firestore_v1_StructuredQuery_Direction_ASCENDING
                   : google_firestore_v1_StructuredQuery_Direction_DESCENDING;
    encoded_order.direction = dir;

    ++i;
  }

  return result;
}

OrderByList Serializer::DecodeOrderBys(
    nanopb::Reader* reader,
    google_firestore_v1_StructuredQuery_Order* order_bys,
    pb_size_t size) const {
  OrderByList result;
  result = result.reserve(size);

  for (pb_size_t i = 0; i != size; ++i) {
    result = result.push_back(DecodeOrderBy(reader, order_bys[i]));
  }

  return result;
}

OrderBy Serializer::DecodeOrderBy(
    nanopb::Reader* reader,
    const google_firestore_v1_StructuredQuery_Order& order_by) const {
  auto field_path =
      FieldPath::FromServerFormat(DecodeString(order_by.field.field_path));

  Direction direction;
  switch (order_by.direction) {
    case google_firestore_v1_StructuredQuery_Direction_ASCENDING:
      direction = Direction::Ascending;
      break;

    case google_firestore_v1_StructuredQuery_Direction_DESCENDING:
      direction = Direction::Descending;
      break;

    default:
      reader->Fail(StringFormat(
          "Unrecognized google_firestore_v1_StructuredQuery_Direction %s",
          order_by.direction));
      return OrderBy{};
  }

  return OrderBy(std::move(field_path), direction);
}

google_firestore_v1_Cursor Serializer::EncodeBound(const Bound& bound) const {
  google_firestore_v1_Cursor result{};
  result.before = bound.before();

  auto count = CheckedSize(bound.position().size());
  result.values_count = count;
  result.values = MakeArray<google_firestore_v1_Value>(count);

  int i = 0;
  for (const FieldValue& field_value : bound.position()) {
    result.values[i] = EncodeFieldValue(field_value);
    ++i;
  }

  return result;
}

std::shared_ptr<Bound> Serializer::DecodeBound(
    nanopb::Reader* reader, const google_firestore_v1_Cursor& cursor) const {
  std::vector<FieldValue> index_components;
  index_components.reserve(cursor.values_count);

  for (pb_size_t i = 0; i != cursor.values_count; ++i) {
    FieldValue value = DecodeFieldValue(reader, cursor.values[i]);
    index_components.push_back(std::move(value));
  }

  return std::make_shared<Bound>(std::move(index_components), cursor.before);
}

/* static */
pb_bytes_array_t* Serializer::EncodeFieldPath(const FieldPath& field_path) {
  return EncodeString(field_path.CanonicalString());
}

/* static */
FieldPath Serializer::DecodeFieldPath(const pb_bytes_array_t* field_path) {
  absl::string_view str = MakeStringView(field_path);
  return FieldPath::FromServerFormatView(str);
}

google_protobuf_Timestamp Serializer::EncodeVersion(
    const SnapshotVersion& version) {
  return EncodeTimestamp(version.timestamp());
}

google_protobuf_Timestamp Serializer::EncodeTimestamp(
    const Timestamp& timestamp_value) {
  google_protobuf_Timestamp result{};
  result.seconds = timestamp_value.seconds();
  result.nanos = timestamp_value.nanoseconds();
  return result;
}

SnapshotVersion Serializer::DecodeVersion(
    nanopb::Reader* reader, const google_protobuf_Timestamp& proto) {
  return SnapshotVersion{DecodeTimestamp(reader, proto)};
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

  if (!reader->status().ok()) return Timestamp();
  return Timestamp{timestamp_proto.seconds, timestamp_proto.nanos};
}

FieldValue Serializer::DecodeReference(
    Reader* reader, const pb_bytes_array_t* resource_name_raw) const {
  ResourcePath resource_name =
      DecodeResourceName(reader, MakeStringView(resource_name_raw));
  ValidateDocumentKeyPath(reader, resource_name);
  DatabaseId database_id = DecodeDatabaseId(reader, resource_name);
  DocumentKey key = DecodeKey(reader, resource_name);

  return FieldValue::FromReference(std::move(database_id), std::move(key));
}

/* static */
GeoPoint Serializer::DecodeGeoPoint(nanopb::Reader* reader,
                                    const google_type_LatLng& latlng_proto) {
  // The GeoPoint ctor will assert if we provide values outside the valid range.
  // However, since we're decoding, a single corrupt byte could cause this to
  // occur, so we'll verify the ranges before passing them in since we'd rather
  // not abort in these situations.
  double latitude = latlng_proto.latitude;
  double longitude = latlng_proto.longitude;
  if (std::isnan(latitude) || latitude < -90 || 90 < latitude) {
    reader->Fail("Invalid message: Latitude must be in the range of [-90, 90]");
  } else if (std::isnan(longitude) || longitude < -180 || 180 < longitude) {
    reader->Fail(
        "Invalid message: Latitude must be in the range of [-180, 180]");
  }

  if (!reader->status().ok()) return GeoPoint();
  return GeoPoint(latitude, longitude);
}

google_firestore_v1_ArrayValue Serializer::EncodeArray(
    const std::vector<FieldValue>& array_value) const {
  google_firestore_v1_ArrayValue result{};

  pb_size_t count = CheckedSize(array_value.size());
  result.values_count = count;
  result.values = MakeArray<google_firestore_v1_Value>(count);

  size_t i = 0;
  for (const FieldValue& fv : array_value) {
    result.values[i++] = EncodeFieldValue(fv);
  }

  return result;
}

std::vector<FieldValue> Serializer::DecodeArray(
    nanopb::Reader* reader,
    const google_firestore_v1_ArrayValue& array_proto) const {
  std::vector<FieldValue> result;
  result.reserve(array_proto.values_count);

  for (size_t i = 0; i < array_proto.values_count; i++) {
    result.push_back(DecodeFieldValue(reader, array_proto.values[i]));
  }

  return result;
}

google_firestore_v1_MapValue Serializer::EncodeMapValue(
    const ObjectValue& object_value) const {
  google_firestore_v1_MapValue result{};

  pb_size_t count = CheckedSize(object_value.GetInternalValue().size());

  result.fields_count = count;
  result.fields = MakeArray<google_firestore_v1_MapValue_FieldsEntry>(count);

  int i = 0;
  for (const auto& kv : object_value.GetInternalValue()) {
    result.fields[i].key = EncodeString(kv.first);
    result.fields[i].value = EncodeFieldValue(kv.second);
    i++;
  }

  return result;
}

MutationResult Serializer::DecodeMutationResult(
    nanopb::Reader* reader,
    const google_firestore_v1_WriteResult& write_result,
    const SnapshotVersion& commit_version) const {
  // NOTE: Deletes don't have an update_time, use commit_version instead.
  SnapshotVersion version =
      write_result.has_update_time
          ? DecodeVersion(reader, write_result.update_time)
          : commit_version;

  absl::optional<std::vector<FieldValue>> transform_results;
  if (write_result.transform_results_count > 0) {
    transform_results = std::vector<FieldValue>{};
    for (pb_size_t i = 0; i < write_result.transform_results_count; i++) {
      transform_results->push_back(
          DecodeFieldValue(reader, write_result.transform_results[i]));
    }
  }

  return MutationResult(version, std::move(transform_results));
}

std::vector<google_firestore_v1_ListenRequest_LabelsEntry>
Serializer::EncodeListenRequestLabels(const TargetData& target_data) const {
  std::vector<google_firestore_v1_ListenRequest_LabelsEntry> result;
  auto value = EncodeLabel(target_data.purpose());
  if (value.empty()) {
    return result;
  }

  result.push_back({/* key */ EncodeString("goog-listen-tags"),
                    /* value */ EncodeString(value)});

  return result;
}

std::string Serializer::EncodeLabel(QueryPurpose purpose) const {
  switch (purpose) {
    case QueryPurpose::Listen:
      return "";
    case QueryPurpose::ExistenceFilterMismatch:
      return "existence-filter-mismatch";
    case QueryPurpose::LimboResolution:
      return "limbo-document";
  }
  UNREACHABLE();
}

std::unique_ptr<WatchChange> Serializer::DecodeWatchChange(
    nanopb::Reader* reader,
    const google_firestore_v1_ListenResponse& watch_change) const {
  switch (watch_change.which_response_type) {
    case google_firestore_v1_ListenResponse_target_change_tag:
      return DecodeTargetChange(reader, watch_change.target_change);

    case google_firestore_v1_ListenResponse_document_change_tag:
      return DecodeDocumentChange(reader, watch_change.document_change);

    case google_firestore_v1_ListenResponse_document_delete_tag:
      return DecodeDocumentDelete(reader, watch_change.document_delete);

    case google_firestore_v1_ListenResponse_document_remove_tag:
      return DecodeDocumentRemove(reader, watch_change.document_remove);

    case google_firestore_v1_ListenResponse_filter_tag:
      return DecodeExistenceFilterWatchChange(reader, watch_change.filter);
  }
  UNREACHABLE();
}

SnapshotVersion Serializer::DecodeVersionFromListenResponse(
    nanopb::Reader* reader,
    const google_firestore_v1_ListenResponse& listen_response) const {
  // We have only reached a consistent snapshot for the entire stream if there
  // is a read_time set and it applies to all targets (i.e. the list of targets
  // is empty). The backend is guaranteed to send such responses.
  if (listen_response.which_response_type !=
      google_firestore_v1_ListenResponse_target_change_tag) {
    return SnapshotVersion::None();
  }
  if (listen_response.target_change.target_ids_count != 0) {
    return SnapshotVersion::None();
  }

  return DecodeVersion(reader, listen_response.target_change.read_time);
}

std::unique_ptr<WatchChange> Serializer::DecodeTargetChange(
    nanopb::Reader* reader,
    const google_firestore_v1_TargetChange& change) const {
  WatchTargetChangeState state =
      DecodeTargetChangeState(reader, change.target_change_type);
  std::vector<TargetId> target_ids(change.target_ids,
                                   change.target_ids + change.target_ids_count);
  ByteString resume_token(change.resume_token);

  util::Status cause;
  if (change.has_cause) {
    cause = util::Status{static_cast<Error>(change.cause.code),
                         DecodeString(change.cause.message)};
  }

  return absl::make_unique<WatchTargetChange>(
      state, std::move(target_ids), std::move(resume_token), std::move(cause));
}

WatchTargetChangeState Serializer::DecodeTargetChangeState(
    nanopb::Reader* reader,
    const google_firestore_v1_TargetChange_TargetChangeType state) {
  switch (state) {
    case google_firestore_v1_TargetChange_TargetChangeType_NO_CHANGE:
      return WatchTargetChangeState::NoChange;
    case google_firestore_v1_TargetChange_TargetChangeType_ADD:
      return WatchTargetChangeState::Added;
    case google_firestore_v1_TargetChange_TargetChangeType_REMOVE:
      return WatchTargetChangeState::Removed;
    case google_firestore_v1_TargetChange_TargetChangeType_CURRENT:
      return WatchTargetChangeState::Current;
    case google_firestore_v1_TargetChange_TargetChangeType_RESET:
      return WatchTargetChangeState::Reset;
  }
  UNREACHABLE();
}

std::unique_ptr<WatchChange> Serializer::DecodeDocumentChange(
    nanopb::Reader* reader,
    const google_firestore_v1_DocumentChange& change) const {
  ObjectValue value = DecodeFields(reader, change.document.fields_count,
                                   change.document.fields);
  DocumentKey key = DecodeKey(reader, change.document.name);

  HARD_ASSERT(change.document.has_update_time,
              "Got a document change with no snapshot version");
  SnapshotVersion version = DecodeVersion(reader, change.document.update_time);

  // TODO(b/142956770): other platforms memoize `change.document` inside the
  // `Document`. This currently cannot be implemented efficiently because it
  // would require a reference-counted ownership model for the proto (copying it
  // would defeat the purpose). Note, however, that even without this
  // optimization C++ implementation is on par with the preceding Objective-C
  // implementation.
  Document document(std::move(value), key, version, DocumentState::kSynced);

  std::vector<TargetId> updated_target_ids(
      change.target_ids, change.target_ids + change.target_ids_count);
  std::vector<TargetId> removed_target_ids(
      change.removed_target_ids,
      change.removed_target_ids + change.removed_target_ids_count);

  return absl::make_unique<DocumentWatchChange>(
      std::move(updated_target_ids), std::move(removed_target_ids),
      std::move(key), std::move(document));
}

std::unique_ptr<WatchChange> Serializer::DecodeDocumentDelete(
    nanopb::Reader* reader,
    const google_firestore_v1_DocumentDelete& change) const {
  DocumentKey key = DecodeKey(reader, change.document);
  // Note that version might be unset in which case we use
  // SnapshotVersion::None().
  SnapshotVersion version = change.has_read_time
                                ? DecodeVersion(reader, change.read_time)
                                : SnapshotVersion::None();
  NoDocument document(key, version, /* has_committed_mutations= */ false);

  std::vector<TargetId> removed_target_ids(
      change.removed_target_ids,
      change.removed_target_ids + change.removed_target_ids_count);

  return absl::make_unique<DocumentWatchChange>(
      std::vector<TargetId>{}, std::move(removed_target_ids), std::move(key),
      std::move(document));
}

std::unique_ptr<WatchChange> Serializer::DecodeDocumentRemove(
    nanopb::Reader* reader,
    const google_firestore_v1_DocumentRemove& change) const {
  DocumentKey key = DecodeKey(reader, change.document);
  std::vector<TargetId> removed_target_ids(
      change.removed_target_ids,
      change.removed_target_ids + change.removed_target_ids_count);

  return absl::make_unique<DocumentWatchChange>(std::vector<TargetId>{},
                                                std::move(removed_target_ids),
                                                std::move(key), absl::nullopt);
}

std::unique_ptr<WatchChange> Serializer::DecodeExistenceFilterWatchChange(
    nanopb::Reader* reader,
    const google_firestore_v1_ExistenceFilter& filter) const {
  ExistenceFilter existence_filter{filter.count};
  return absl::make_unique<ExistenceFilterWatchChange>(existence_filter,
                                                       filter.target_id);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
