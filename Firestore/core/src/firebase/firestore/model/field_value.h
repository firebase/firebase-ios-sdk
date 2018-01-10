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

namespace firebase {
namespace firestore {
namespace model {

/**
 * Abstract base class representing an immutable data value as stored in
 * Firestore. FieldValue represents all the different kinds of values
 * that can be stored in fields in a document.
 */
class FieldValue {
 public:

  /** The order of types in Firestore; this order is defined by the backend. */
  typedef enum {
    TypeOrderNull,
    TypeOrderBoolean,
    TypeOrderNumber,
    TypeOrderTimestamp,
    TypeOrderString,
    TypeOrderBlob,
    TypeOrderReference,
    TypeOrderGeoPoint,
    TypeOrderArray,
    TypeOrderObject,
  } TypeOrder;

  /**
   * All the different kinds of values that can be stored in fields in
   * a document.
   */
  typedef enum {
    TypeNull,
    TypeBoolean,
    TypeLong,
    TypeDouble,
    TypeTimestamp,
    TypeServerTimestamp,
    TypeString,
    TypeBinary,
    TypeReference,
    TypeGeoPoint,
    TypeArray,
    TypeObject,
  } Type;

  /** Returns the TypeOrder for this value. */
  virtual TypeOrder type_order() const = 0;

  /** Returns the true type for this value. */
  virtual Type type() const = 0;

  /** Compares against another FieldValue. */
  virtual int Compare(const FieldValue& other) const = 0;

 protected:
  /** default compare method. */
  int DefaultCompare(const FieldValue& other) const;
};

class NullValue : public FieldValue {
 public:
  /* Override */
  virtual TypeOrder type_order() const {
    return TypeOrderNull;
  }

  /* Override */
  virtual Type type() const {
    return TypeNull;
  }

  /* Override */
  virtual int Compare(const FieldValue& other) const;

  static NullValue NulValue() {
    return kInstance;
  }

 private:
  NullValue() {}

  static const NullValue kInstance;
};

class BooleanValue : public FieldValue {
 public:
  /* Override */
  virtual TypeOrder type_order() const {
    return TypeOrderBoolean;
  }

  /* Override */
  virtual Type type() const {
    return TypeBoolean;
  }

  /* Override */
  virtual int Compare(const FieldValue& other) const;

  bool Value() const {
    return value_;
  }

  static BooleanValue TrueValue() {
    return kTrueValue;
  }

  static BooleanValue FalseValue() {
    return kFalseValue;
  }

 private:
  explicit BooleanValue(bool value) : value_(value) {}

  const bool value_;

  static const BooleanValue kTrueValue;
  static const BooleanValue kFalseValue;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_VALUE_H_
