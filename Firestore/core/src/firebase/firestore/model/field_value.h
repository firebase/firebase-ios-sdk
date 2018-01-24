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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_VALUE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_VALUE_H_

#include <memory>
#include <vector>

namespace firebase {
namespace firestore {
namespace model {

/**
 * tagged-union class representing an immutable data value as stored in
 * Firestore. FieldValue represents all the different kinds of values
 * that can be stored in fields in a document.
 */
class FieldValue {
 public:
  /**
   * All the different kinds of values that can be stored in fields in
   * a document. The types of the same comparison order should be defined
   * together as a group. The order of each group is defined by the Firestore
   * backend and is available at:
   *     https://firebase.google.com/docs/firestore/manage-data/data-types
   */
  enum class Type {
    Null,     // Null
    Boolean,  // Boolean
    Long,     // Number type starts here
    Double,
    Timestamp,  // Timestamp type starts here
    ServerTimestamp,
    String,     // String
    Blob,       // Blob
    Reference,  // Reference
    GeoPoint,   // GeoPoint
    Array,      // Array
    Object,     // Object
    // New enum should not always been added at the tail. Add it to the correct
    // position instead, see the doc comment above.
  };

  FieldValue() : tag_(Type::Null) {
  }

  // Do not inline these ctor/dtor below, which contain call to non-trivial
  // operator=.
  FieldValue(const FieldValue& value);
  FieldValue(FieldValue&& value);

  ~FieldValue();

  FieldValue& operator=(const FieldValue& value);
  FieldValue& operator=(FieldValue&& value);

  /** Returns the true type for this value. */
  Type type() const {
    return tag_;
  }

  /** factory methods. */
  static const FieldValue& NullValue();
  static const FieldValue& TrueValue();
  static const FieldValue& FalseValue();
  static const FieldValue& BooleanValue(bool value);
  static FieldValue ArrayValue(const std::vector<const FieldValue>& value);
  static FieldValue ArrayValue(std::vector<const FieldValue>&& value);

  friend bool operator<(const FieldValue& lhs, const FieldValue& rhs);

 private:
  explicit FieldValue(bool value) : tag_(Type::Boolean), boolean_value_(value) {
  }

  /**
   * Switch to the specified type, if different from the current type.
   */
  void SwitchTo(const Type type);

  Type tag_;
  union {
    // There is no null type as tag_ alone is enough for Null FieldValue.
    bool boolean_value_;
    std::vector<const FieldValue> array_value_;
  };
};

/** Compares against another FieldValue. */
bool operator<(const FieldValue& lhs, const FieldValue& rhs);

inline bool operator>(const FieldValue& lhs, const FieldValue& rhs) {
  return rhs < lhs;
}

inline bool operator>=(const FieldValue& lhs, const FieldValue& rhs) {
  return !(lhs < rhs);
}

inline bool operator<=(const FieldValue& lhs, const FieldValue& rhs) {
  return !(lhs > rhs);
}

inline bool operator!=(const FieldValue& lhs, const FieldValue& rhs) {
  return lhs < rhs || lhs > rhs;
}

inline bool operator==(const FieldValue& lhs, const FieldValue& rhs) {
  return !(lhs != rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_VALUE_H_
