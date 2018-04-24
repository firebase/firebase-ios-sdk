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
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/base/attributes.h"

namespace firebase {
namespace firestore {
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
  Serializer() {
  }
  // TODO(rsgowman): We eventually need the DatabaseId, but can't add it just
  // yet since it's not used yet (which travis complains about). So for now,
  // we'll create a parameterless ctor (above) that likely won't exist in the
  // final version of this class.
  ///**
  // * @param database_id Must remain valid for the lifetime of this Serializer
  // * object.
  // */
  // explicit Serializer(const firebase::firestore::model::DatabaseId&
  // database_id)
  //    : database_id_(database_id) {
  //}

  /**
   * Converts the FieldValue model passed into bytes.
   *
   * @param field_value the model to convert.
   * @param[out] out_bytes A buffer to place the output. The bytes will be
   * appended to this vector.
   */
  // TODO(rsgowman): error handling, incl return code.
  // TODO(rsgowman): If we never support any output except to a vector, it may
  // make sense to have Serializer own the vector and provide an accessor rather
  // than asking the user to create it first.
  util::Status EncodeFieldValue(
      const firebase::firestore::model::FieldValue& field_value,
      std::vector<uint8_t>* out_bytes);

  /**
   * @brief Converts from bytes to the model FieldValue format.
   *
   * @param bytes The bytes to convert. It's assumed that exactly all of the
   * bytes will be used by this conversion.
   * @return The model equivalent of the bytes.
   */
  // TODO(rsgowman): error handling.
  model::FieldValue DecodeFieldValue(const uint8_t* bytes, size_t length);

  /**
   * @brief Converts from bytes to the model FieldValue format.
   *
   * @param bytes The bytes to convert. It's assumed that exactly all of the
   * bytes will be used by this conversion.
   * @return The model equivalent of the bytes.
   */
  // TODO(rsgowman): error handling.
  model::FieldValue DecodeFieldValue(const std::vector<uint8_t>& bytes) {
    return DecodeFieldValue(bytes.data(), bytes.size());
  }

 private:
  // TODO(rsgowman): We don't need the database_id_ yet (but will eventually).
  // model::DatabaseId* database_id_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_SERIALIZER_H_
