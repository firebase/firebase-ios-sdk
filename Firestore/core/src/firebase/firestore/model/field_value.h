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

class NullValue {};

class BooleanValue {
 public:
  BooleanValue(bool value) : value_(value) {}

  bool value() const {
    return value_;
  }

 private:
  bool value_;
};

class FieldValue;
class ArrayValue {
 public:
  /* take ownership */
  ArrayValue(std::vector<FieldValue>* value) : value_(value) {}

  ~ArrayValue() {
    delete value_;
  }

  std::vector<FieldValue>* value() const {
    return value_;
  }

  friend class FieldValue;

 private:
  // Cannot use smart pointer or otherwise will make this non-compatible
  // with the union logic (e.g. delete the copy constructor of this class).
  std::vector<FieldValue>* value_;
};

/**
 * tagged-union class representing an immutable data value as stored in
 * Firestore. FieldValue represents all the different kinds of values
 * that can be stored in fields in a document.
 */
class FieldValue {
 public:
  /**
   * All the different kinds of values that can be stored in fields in
   * a document.
   */
  enum class Type {
    Null,
    Boolean,
    Long,
    Double,
    Timestamp,
    ServerTimestamp,
    String,
    Binary,
    Reference,
    GeoPoint,
    Array,
    Object,
  };

  /** The order of types in Firestore; this order is defined by the backend. */
  enum class TypeOrder {
    Null,
    Boolean,
    Number,
    Timestamp,
    String,
    Blob,
    Reference,
    GeoPoint,
    Array,
    Object,
  };

  union UnionValue {
    NullValue null_value_;
    BooleanValue boolean_value_;
    ArrayValue array_value_;
    ~UnionValue() {}
  };

  FieldValue() : tag_(Type::Null) {}

  explicit FieldValue(const NullValue& value) : tag_(Type::Null) {}

  explicit FieldValue(const BooleanValue& value) : tag_(Type::Boolean) {
    value_.reset(new UnionValue({.boolean_value_ = {value.value()}}));
  }

  ~FieldValue();

  /** Returns the true type for this value. */
  Type type() const {
    return tag_;
  }

  /** Returns the TypeOrder for this value. */
  TypeOrder type_order() const;

  /** Compares against another FieldValue. */
  friend int Compare(const FieldValue& lhs, const FieldValue& rhs);
  friend bool operator< (const FieldValue& lhs, const FieldValue& rhs);
  friend bool operator<= (const FieldValue& lhs, const FieldValue& rhs);
  friend bool operator== (const FieldValue& lhs, const FieldValue& rhs);
  friend bool operator!= (const FieldValue& lhs, const FieldValue& rhs);
  friend bool operator>= (const FieldValue& lhs, const FieldValue& rhs);
  friend bool operator> (const FieldValue& lhs, const FieldValue& rhs);

 private:
  Type tag_;
  std::shared_ptr<UnionValue> value_;
};

int Compare(const NullValue& lhs, const NullValue& rhs);
int Compare(const BooleanValue& lhs, const BooleanValue& rhs);

inline bool operator< (const FieldValue& lhs, const FieldValue& rhs) {
  return Compare(lhs, rhs) == -1;
}

inline bool operator<= (const FieldValue& lhs, const FieldValue& rhs) {
  return Compare(lhs, rhs) <= 0;
}

inline bool operator== (const FieldValue& lhs, const FieldValue& rhs) {
  return Compare(lhs, rhs) == 0;
}

inline bool operator!= (const FieldValue& lhs, const FieldValue& rhs) {
  return Compare(lhs, rhs) != 0;
}

inline bool operator>= (const FieldValue& lhs, const FieldValue& rhs) {
  return Compare(lhs, rhs) >= 0;
}

inline bool operator> (const FieldValue& lhs, const FieldValue& rhs) {
  return Compare(lhs, rhs) == 1;
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_VALUE_H_
