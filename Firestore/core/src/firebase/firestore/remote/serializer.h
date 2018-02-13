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

#include <stdint.h>
#include <stdlib.h>
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1beta1/document.pb.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

/**
 * @brief Converts internal model objects to their equivalent protocol buffer
 * form, and protocol buffer objects to their equivalent bytes.
 *
 * Methods starting with "Encode" either convert from a model object to a
 * protocol buffer or from a protocol buffer to bytes, and methods starting with
 * "Decode" either convert from a protocol buffer to a model object or from
 * bytes to a protocol buffer.
 *
 */
// TODO(rsgowman): Original docs also has this: "Throws an exception if a
// protocol buffer is missing a critical field or has a value we can't
// interpret." Adjust for C++.
class Serializer {
 public:
  /**
   * @brief Wraps (nanopb) google_firestore_v1beta1_Value with type information.
   */
  struct TypedValue {
    firebase::firestore::model::FieldValue::Type type;
    google_firestore_v1beta1_Value value;
  };

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
   * Converts the FieldValue model passed into the Value proto equivalent.
   *
   * @param field_value the model to convert.
   * @return the proto representation of the model.
   */
  static Serializer::TypedValue EncodeFieldValue(
      const firebase::firestore::model::FieldValue& field_value);

  /**
   * @brief Converts the value proto passed into bytes.
   *
   * @param[out] out_bytes A buffer to place the output. The bytes will be
   * appended to this vector.
   */
  // TODO(rsgowman): error handling, incl return code.
  static void EncodeTypedValue(const TypedValue& value,
                               std::vector<uint8_t>* out_bytes);

  /**
   * Converts from the proto Value format to the model FieldValue format
   *
   * @return The model equivalent of the proto data.
   */
  static firebase::firestore::model::FieldValue DecodeFieldValue(
      const Serializer::TypedValue& value_proto);

  /**
   * @brief Converts from bytes to the nanopb proto.
   *
   * @param bytes The bytes to convert. It's assumed that exactly all of the
   * bytes will be used by this conversion.
   * @return The (nanopb) proto equivalent of the bytes.
   */
  // TODO(rsgowman): error handling.
  static TypedValue DecodeTypedValue(const uint8_t* bytes, size_t length);

  /**
   * @brief Converts from bytes to the nanopb proto.
   *
   * @param bytes The bytes to convert. It's assumed that exactly all of the
   * bytes will be used by this conversion.
   * @return The (nanopb) proto equivalent of the bytes.
   */
  // TODO(rsgowman): error handling.
  static TypedValue DecodeTypedValue(const std::vector<uint8_t>& bytes) {
    return DecodeTypedValue(bytes.data(), bytes.size());
  }

 private:
  // TODO(rsgowman): We don't need the database_id_ yet (but will eventually).
  // const firebase::firestore::model::DatabaseId& database_id_;
};

inline bool operator==(const Serializer::TypedValue& lhs,
                       const Serializer::TypedValue& rhs) {
  if (lhs.type != rhs.type) {
    return false;
  }

  switch (lhs.type) {
    case firebase::firestore::model::FieldValue::Type::Null:
      FIREBASE_DEV_ASSERT(lhs.value.null_value ==
                          google_protobuf_NullValue_NULL_VALUE);
      FIREBASE_DEV_ASSERT(rhs.value.null_value ==
                          google_protobuf_NullValue_NULL_VALUE);
      return true;
    default:
      // TODO(rsgowman): implement the other types
      abort();
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_SERIALIZER_H_
