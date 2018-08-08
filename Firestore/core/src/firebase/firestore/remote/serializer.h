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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_SERIALIZER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_SERIALIZER_H_

#include <cstdint>
#include <cstdlib>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/base/attributes.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {

namespace local {
class LocalSerializer;
}

namespace remote {

/**
 * @brief Converts internal model objects to their equivalent protocol buffer
 * form, and protocol buffer objects to their equivalent bytes.
 *
 * Methods starting with "Encode" convert from a model object to a protocol
 * buffer (or directly to bytes in cases where the proto uses a 'oneof', due to
 * limitations in nanopb), and methods starting with "Decode" convert from a
 * protocol buffer to a model object (or from bytes directly to a model
 * objects.)
 */
// TODO(rsgowman): Original docs also has this: "Throws an exception if a
// protocol buffer is missing a critical field or has a value we can't
// interpret." Adjust for C++.
class Serializer {
 public:
  /**
   * @param database_id Must remain valid for the lifetime of this Serializer
   * object.
   */
  explicit Serializer(
      const firebase::firestore::model::DatabaseId& database_id);

  /**
   * @brief Converts the FieldValue model passed into bytes.
   *
   * Any errors that occur during encoding are fatal.
   *
   * @param writer The serialized output will be written to the provided writer.
   * @param field_value the model to convert.
   */
  static void EncodeFieldValue(nanopb::Writer* writer,
                               const model::FieldValue& field_value);

  /**
   * @brief Converts from bytes to the model FieldValue format.
   *
   * @param reader The Reader object containing the bytes to convert. It's
   * assumed that exactly all of the bytes will be used by this conversion.
   * @return The model equivalent of the bytes or nullopt if an error occurred.
   * @post (reader->status().ok() && result) ||
   * (!reader->status().ok() && !result)
   */
  static absl::optional<model::FieldValue> DecodeFieldValue(
      nanopb::Reader* reader);

  /**
   * Encodes the given document key as a fully qualified name. This includes the
   * databaseId associated with this Serializer and the key path.
   */
  std::string EncodeKey(
      const firebase::firestore::model::DocumentKey& key) const;

  /**
   * Decodes the given document key from a fully qualified name.
   */
  firebase::firestore::model::DocumentKey DecodeKey(
      absl::string_view name) const;

  /**
   * @brief Converts the Document (i.e. key/value) into bytes.
   *
   * Any errors that occur during encoding are fatal.
   *
   * @param writer The serialized output will be written to the provided writer.
   */
  void EncodeDocument(nanopb::Writer* writer,
                      const model::DocumentKey& key,
                      const model::ObjectValue& value) const;

  /**
   * @brief Converts from bytes to the model Document format.
   *
   * @param reader The Reader containing the bytes to convert. These bytes must
   * represent a BatchGetDocumentsResponse. It's assumed that exactly all of the
   * bytes will be used by this conversion.
   * @return The model equivalent of the bytes or nullopt if an error occurred.
   * @post (reader->status().ok() && result) ||
   * (!reader->status().ok() && !result)
   */
  std::unique_ptr<model::MaybeDocument> DecodeMaybeDocument(
      nanopb::Reader* reader) const;

  /**
   * @brief Converts the Query into bytes, representing a
   * firestore::v1beta1::Target::QueryTarget.
   *
   * Any errors that occur during encoding are fatal.
   *
   * @param writer The serialized output will be written to the provided writer.
   */
  void EncodeQueryTarget(nanopb::Writer* writer,
                         const core::Query& query) const;

  std::unique_ptr<model::Document> DecodeDocument(nanopb::Reader* reader) const;

  static void EncodeObjectMap(nanopb::Writer* writer,
                              const model::ObjectValue::Map& object_value_map,
                              uint32_t map_tag,
                              uint32_t key_tag,
                              uint32_t value_tag);

  static void EncodeVersion(nanopb::Writer* writer,
                            const model::SnapshotVersion& version);

  static void EncodeTimestamp(nanopb::Writer* writer,
                              const Timestamp& timestamp_value);
  static absl::optional<model::SnapshotVersion> DecodeSnapshotVersion(
      nanopb::Reader* reader);
  static absl::optional<Timestamp> DecodeTimestamp(nanopb::Reader* reader);

  static absl::optional<core::Query> DecodeQueryTarget(nanopb::Reader* reader);

 private:
  std::unique_ptr<model::MaybeDocument> DecodeBatchGetDocumentsResponse(
      nanopb::Reader* reader) const;

  static void EncodeMapValue(nanopb::Writer* writer,
                             const model::ObjectValue& object_value);

  static void EncodeFieldsEntry(nanopb::Writer* writer,
                                const model::ObjectValue::Map::value_type& kv,
                                uint32_t key_tag,
                                uint32_t value_tag);

  void EncodeQueryPath(nanopb::Writer* writer,
                       const model::ResourcePath& path) const;
  std::string EncodeQueryPath(const model::ResourcePath& path) const;

  const model::DatabaseId& database_id_;
  const std::string database_name_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_SERIALIZER_H_
