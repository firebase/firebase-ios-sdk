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

#ifndef FIRESTORE_CORE_SRC_REMOTE_SERIALIZER_H_
#define FIRESTORE_CORE_SRC_REMOTE_SERIALIZER_H_

#include <cstdint>
#include <cstdlib>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1/firestore.nanopb.h"
#include "Firestore/Protos/nanopb/google/type/latlng.nanopb.h"
#include "Firestore/core/src/core/core_fwd.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/field_value.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/nanopb/writer.h"
#include "Firestore/core/src/remote/watch_change.h"
#include "Firestore/core/src/util/status_fwd.h"
#include "absl/base/attributes.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {

namespace local {
class LocalSerializer;
class TargetData;

enum class QueryPurpose;
}  // namespace local

namespace remote {

core::Target InvalidTarget();

/**
 * @brief Converts internal model objects to their equivalent protocol buffer
 * form, and protocol buffer objects to their equivalent bytes.
 *
 * Methods starting with "Encode" convert from a model object to a nanopb
 * protocol buffer, and methods starting with "Decode" convert from a nanopb
 * protocol buffer to a model object.
 *
 * For encoded messages, `nanopb::FreeNanopbMessage()` must be called on the
 * returned nanopb proto buffer or a memory leak will occur.
 *
 * All errors that occur during serialization are fatal.
 *
 * All deserialization methods (that can fail) take a nanopb::Reader parameter
 * whose status will be set to failed upon an error. Callers must check this
 * before using the returned value via `reader->status()`. A deserialization
 * method might fail if a protocol buffer is missing a critical field or has a
 * value we can't interpret. On error, the return value from a deserialization
 * method is unspecified.
 */
class Serializer {
 public:
  /**
   * @param database_id Must remain valid for the lifetime of this Serializer
   * object.
   */
  explicit Serializer(model::DatabaseId database_id);

  /**
   * Encodes the string to nanopb bytes.
   *
   * This method allocates memory; the caller is responsible for freeing it.
   * Typically, the returned value will be added to a pointer field within a
   * nanopb proto struct. Calling pb_release() on the resulting struct will
   * cause all proto fields to be freed.
   */
  static pb_bytes_array_t* EncodeString(const std::string& str);

  /**
   * Decodes the nanopb bytes to a std::string. If the input pointer is null,
   * then this method will return an empty string.
   */
  static std::string DecodeString(const pb_bytes_array_t* str);

  /**
   * Encodes the std::vector to nanopb bytes. If the input vector is empty, then
   * the resulting return bytes will have length 0 (but will otherwise be valid,
   * i.e. not null.)
   *
   * This method allocates memory; the caller is responsible for freeing it.
   * Typically, the returned value will be added to a pointer field within a
   * nanopb proto struct. Calling pb_release() on the resulting struct will
   * cause all proto fields to be freed.
   */
  static pb_bytes_array_t* EncodeBytes(const std::vector<uint8_t>& bytes);

  /**
   * Returns the database ID, such as
   * `projects/{project_id}/databases/{database_id}`.
   */
  pb_bytes_array_t* EncodeDatabaseName() const;

  /**
   * @brief Converts the FieldValue model passed into bytes.
   */
  google_firestore_v1_Value EncodeFieldValue(
      const model::FieldValue& field_value) const;

  /**
   * @brief Converts from nanopb proto to the model FieldValue format.
   */
  // TODO(rsgowman): Once the proto is read, the only thing the reader object is
  // used for is error handling. This seems questionable. We probably need to
  // rework error handling. Again. But we'll defer that for now and continue
  // just passing the reader object.
  model::FieldValue DecodeFieldValue(
      nanopb::Reader* reader, const google_firestore_v1_Value& proto) const;

  /**
   * Encodes the given document key as a fully qualified name. This includes the
   * DatabaseId associated with this Serializer and the key path.
   */
  pb_bytes_array_t* EncodeKey(
      const firebase::firestore::model::DocumentKey& key) const;

  /**
   * Decodes the given document key from a fully qualified name.
   */
  firebase::firestore::model::DocumentKey DecodeKey(
      nanopb::Reader* reader, const pb_bytes_array_t* name) const;

  /**
   * @brief Converts the Document (i.e. key/value) into bytes.
   */
  google_firestore_v1_Document EncodeDocument(
      const model::DocumentKey& key, const model::ObjectValue& value) const;

  /**
   * @brief Converts from nanopb proto to the model Document format.
   */
  model::MaybeDocument DecodeMaybeDocument(
      nanopb::Reader* reader,
      const google_firestore_v1_BatchGetDocumentsResponse& response) const;

  google_firestore_v1_Write EncodeMutation(
      const model::Mutation& mutation) const;
  model::Mutation DecodeMutation(
      nanopb::Reader* reader, const google_firestore_v1_Write& mutation) const;

  static google_firestore_v1_Precondition EncodePrecondition(
      const model::Precondition& precondition);
  static model::Precondition DecodePrecondition(
      nanopb::Reader* reader,
      const google_firestore_v1_Precondition& precondition);

  static google_firestore_v1_DocumentMask EncodeFieldMask(
      const model::FieldMask& mask);
  static model::FieldMask DecodeFieldMask(
      const google_firestore_v1_DocumentMask& mask);

  google_firestore_v1_DocumentTransform_FieldTransform EncodeFieldTransform(
      const model::FieldTransform& field_transform) const;
  model::FieldTransform DecodeFieldTransform(
      nanopb::Reader* reader,
      const google_firestore_v1_DocumentTransform_FieldTransform& proto) const;

  model::MutationResult DecodeMutationResult(
      nanopb::Reader* reader,
      const google_firestore_v1_WriteResult& write_result,
      const model::SnapshotVersion& commit_version) const;

  std::vector<google_firestore_v1_ListenRequest_LabelsEntry>
  EncodeListenRequestLabels(const local::TargetData& target_data) const;

  static pb_bytes_array_t* EncodeFieldPath(const model::FieldPath& field_path);
  static model::FieldPath DecodeFieldPath(const pb_bytes_array_t* field_path);

  static google_protobuf_Timestamp EncodeVersion(
      const model::SnapshotVersion& version);

  static google_protobuf_Timestamp EncodeTimestamp(
      const Timestamp& timestamp_value);

  static model::SnapshotVersion DecodeVersion(
      nanopb::Reader* reader, const google_protobuf_Timestamp& proto);

  static Timestamp DecodeTimestamp(
      nanopb::Reader* reader, const google_protobuf_Timestamp& timestamp_proto);

  static GeoPoint DecodeGeoPoint(nanopb::Reader* reader,
                                 const google_type_LatLng& latlng_proto);

  google_firestore_v1_ArrayValue EncodeArray(
      const std::vector<model::FieldValue>& array_value) const;
  std::vector<model::FieldValue> DecodeArray(
      nanopb::Reader* reader,
      const google_firestore_v1_ArrayValue& array_proto) const;

  google_firestore_v1_MapValue EncodeMapValue(
      const model::ObjectValue& object_value) const;

  google_firestore_v1_Target EncodeTarget(
      const local::TargetData& target_data) const;
  google_firestore_v1_Target_DocumentsTarget EncodeDocumentsTarget(
      const core::Target& target) const;
  core::Target DecodeDocumentsTarget(
      nanopb::Reader* reader,
      const google_firestore_v1_Target_DocumentsTarget& proto) const;
  google_firestore_v1_Target_QueryTarget EncodeQueryTarget(
      const core::Target& target) const;
  core::Target DecodeQueryTarget(
      nanopb::Reader* reader,
      const google_firestore_v1_Target_QueryTarget& proto) const;

  std::unique_ptr<remote::WatchChange> DecodeWatchChange(
      nanopb::Reader* reader,
      const google_firestore_v1_ListenResponse& watch_change) const;

  model::SnapshotVersion DecodeVersionFromListenResponse(
      nanopb::Reader* reader,
      const google_firestore_v1_ListenResponse& listen_response) const;

  model::ObjectValue DecodeFields(
      nanopb::Reader* reader,
      size_t count,
      const google_firestore_v1_Document_FieldsEntry* fields) const;

  // Public for the sake of tests.
  google_firestore_v1_StructuredQuery_Filter EncodeFilters(
      const core::FilterList& filters) const;
  core::FilterList DecodeFilters(
      nanopb::Reader* reader,
      const google_firestore_v1_StructuredQuery_Filter& proto) const;

 private:
  google_firestore_v1_Value EncodeNull() const;
  google_firestore_v1_Value EncodeBoolean(bool value) const;
  google_firestore_v1_Value EncodeInteger(int64_t value) const;
  google_firestore_v1_Value EncodeDouble(double value) const;
  google_firestore_v1_Value EncodeTimestampValue(Timestamp value) const;
  google_firestore_v1_Value EncodeStringValue(const std::string& value) const;
  google_firestore_v1_Value EncodeBlob(const nanopb::ByteString& value) const;
  google_firestore_v1_Value EncodeReference(
      const model::FieldValue::Reference& value) const;
  google_firestore_v1_Value EncodeGeoPoint(const GeoPoint& value) const;

  model::Document DecodeFoundDocument(
      nanopb::Reader* reader,
      const google_firestore_v1_BatchGetDocumentsResponse& response) const;
  model::NoDocument DecodeMissingDocument(
      nanopb::Reader* reader,
      const google_firestore_v1_BatchGetDocumentsResponse& response) const;

  pb_bytes_array_t* EncodeQueryPath(const model::ResourcePath& path) const;
  model::ResourcePath DecodeQueryPath(nanopb::Reader* reader,
                                      absl::string_view name) const;

  /**
   * Encodes a database ID and resource path into the following form:
   * /projects/$project_id/database/$database_id/documents/$path
   */
  pb_bytes_array_t* EncodeResourceName(const model::DatabaseId& database_id,
                                       const model::ResourcePath& path) const;

  /**
   * Decodes a fully qualified resource name into a resource path and validates
   * that there is a project and database encoded in the path. There are no
   * guarantees that a local path is also encoded in this resource name.
   */
  model::ResourcePath DecodeResourceName(nanopb::Reader* reader,
                                         absl::string_view encoded) const;

  void ValidateDocumentKeyPath(nanopb::Reader* reader,
                               const model::ResourcePath& resource_name) const;
  model::DocumentKey DecodeKey(nanopb::Reader* reader,
                               const model::ResourcePath& resource_name) const;

  model::FieldValue::Map::value_type DecodeFieldsEntry(
      nanopb::Reader* reader,
      const google_firestore_v1_Document_FieldsEntry& fields) const;

  model::FieldValue::Map DecodeMapValue(
      nanopb::Reader* reader,
      const google_firestore_v1_MapValue& map_value) const;

  model::DatabaseId DecodeDatabaseId(
      nanopb::Reader* reader, const model::ResourcePath& resource_name) const;
  model::FieldValue DecodeReference(
      nanopb::Reader* reader, const pb_bytes_array_t* resource_name_raw) const;

  std::string EncodeLabel(local::QueryPurpose purpose) const;

  google_firestore_v1_StructuredQuery_Filter EncodeSingularFilter(
      const core::FieldFilter& filter) const;
  core::Filter DecodeFieldFilter(
      nanopb::Reader* reader,
      const google_firestore_v1_StructuredQuery_FieldFilter& field_filter)
      const;
  core::Filter DecodeUnaryFilter(
      nanopb::Reader* reader,
      const google_firestore_v1_StructuredQuery_UnaryFilter& unary) const;
  core::FilterList DecodeCompositeFilter(
      nanopb::Reader* reader,
      const google_firestore_v1_StructuredQuery_CompositeFilter& composite)
      const;

  google_firestore_v1_StructuredQuery_FieldFilter_Operator
  EncodeFieldFilterOperator(core::Filter::Operator op) const;
  core::Filter::Operator DecodeFieldFilterOperator(
      nanopb::Reader* reader,
      google_firestore_v1_StructuredQuery_FieldFilter_Operator op) const;

  google_firestore_v1_StructuredQuery_Order* EncodeOrderBys(
      const core::OrderByList& orders) const;
  core::OrderByList DecodeOrderBys(
      nanopb::Reader* reader,
      google_firestore_v1_StructuredQuery_Order* order_bys,
      pb_size_t size) const;
  core::OrderBy DecodeOrderBy(
      nanopb::Reader* reader,
      const google_firestore_v1_StructuredQuery_Order& order_by) const;

  google_firestore_v1_Cursor EncodeBound(const core::Bound& bound) const;
  std::shared_ptr<core::Bound> DecodeBound(
      nanopb::Reader* reader, const google_firestore_v1_Cursor& cursor) const;

  std::unique_ptr<remote::WatchChange> DecodeTargetChange(
      nanopb::Reader* reader,
      const google_firestore_v1_TargetChange& change) const;
  static remote::WatchTargetChangeState DecodeTargetChangeState(
      nanopb::Reader* reader,
      const google_firestore_v1_TargetChange_TargetChangeType state);

  std::unique_ptr<remote::WatchChange> DecodeDocumentChange(
      nanopb::Reader* reader,
      const google_firestore_v1_DocumentChange& change) const;
  std::unique_ptr<remote::WatchChange> DecodeDocumentDelete(
      nanopb::Reader* reader,
      const google_firestore_v1_DocumentDelete& change) const;
  std::unique_ptr<remote::WatchChange> DecodeDocumentRemove(
      nanopb::Reader* reader,
      const google_firestore_v1_DocumentRemove& change) const;
  std::unique_ptr<remote::WatchChange> DecodeExistenceFilterWatchChange(
      nanopb::Reader* reader,
      const google_firestore_v1_ExistenceFilter& filter) const;

  model::DatabaseId database_id_;
  // TODO(varconst): Android caches the result of calling `EncodeDatabaseName`
  // as well, consider implementing that.
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_REMOTE_SERIALIZER_H_
