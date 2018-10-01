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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIELD_VALUE_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIELD_VALUE_H_

#include <string>
#include <unordered_map>
#include <vector>

#include "firebase/firestore/document_reference.h"
#include "firebase/firestore/geo_point.h"
#include "firebase/firestore/map_field_value.h"
#include "firebase/firestore/timestamp.h"

namespace firebase {
namespace firestore {

class DocumentReference;
class FieldValue;
class FieldValueInternal;

/**
 * A field value represents variant datatypes as stored by Firestore. It can be
 * used when reading a particular field with DocumentSnapshot::Get() or fields
 * with DocumentSnapshot::GetData(). When writing document fields with
 * DocumentReference::Set() or DocumentReference::Update(), it can also
 * represents sentinel values in addition to real data values.
 *
 * For a non-sentinel instance, one can check whether it is of a particular type
 * with is_foo() and get the value with foo_value(), where foo can be one of
 * null, boolean, integer, double, timestamp, string, blob, reference,
 * geo_point, array or map. If the instance is not of type foo, the call to
 * foo_value() will fail (and cause a crash).
 */
class FieldValue {
 public:
  enum class Type {
    kNull,
    kBoolean,
    kInteger,
    kDouble,
    kTimestamp,
    kString,
    kBlob,
    kReference,
    kGeoPoint,
    kArray,
    kMap,
    // Below are sentinel types. One will never get a field value of sentinel
    // type from Firestore. One can use field value of sentinel type to set or
    // update Firestore.
    kDelete,
    kServerTimestamp,
    kArrayUnion,
    kArrayRemove,
  };

  /**
   * @brief Default constructor. This creates an invalid FieldValue. Attempting
   * to perform any operations on this FieldValue will fail (and cause a crash)
   * unless a valid FieldValue has been assigned to it.
   */
  FieldValue();

  /** @brief Copy constructor. */
  FieldValue(const FieldValue& value);

  /** @brief Move constructor. */
  FieldValue(FieldValue&& value);

  virtual ~FieldValue();

  /** @brief Copy assignment operator. */
  FieldValue& operator=(const FieldValue& value);

  /** @brief Move assignment operator. */
  FieldValue& operator=(FieldValue&& value);

  /**
   * @brief Construct a FieldValue containing the given boolean {@code value}.
   */
  static FieldValue FromBoolean(bool value);

  /**
   * @brief Construct a FieldValue containing the given 64-bit integer
   * {@code value}.
   */
  static FieldValue FromInteger(int64_t value);

  /**
   * @brief Construct a FieldValue containing the given double-precision
   * floating point value.
   */
  static FieldValue FromDouble(double value);

  /**
   * @brief Construct a FieldValue containing the given Timestamp {@code value}.
   */
  static FieldValue FromTimestamp(Timestamp value);

  /**
   * @brief Construct a FieldValue containing the given std::string
   * {@code value}.
   */
  static FieldValue FromString(std::string value);

  /**
   * @brief Construct a FieldValue containing the given blob {@code value} of
   * size {@code size}. value is copied into the returned FieldValue.
   */
  static FieldValue FromBlob(const uint8_t* value, size_t size);

  /**
   * @brief Construct a FieldValue containing the given reference {@code value}.
   */
  static FieldValue FromReference(DocumentReference value);

  /**
   * @brief Construct a FieldValue containing the given GeoPoint {@code value}.
   */
  static FieldValue FromGeoPoint(GeoPoint value);

  /**
   * @brief Construct a FieldValue containing the given FieldValue vector
   * {@code value}.
   */
  static FieldValue FromArray(std::vector<FieldValue> value);

  /**
   * @brief Construct a FieldValue containing the given FieldValue map
   * {@code value}.
   */
  static FieldValue FromMap(MapFieldValue value);

  /** @brief Get the current type contained in this FieldValue. */
  virtual Type type() const;

  /** @brief Get whether this FieldValue is currently null. */
  bool is_null() const {
    return type() == Type::kNull;
  }

  /** @brief Get whether this FieldValue contains a boolean value. */
  bool is_boolean() const {
    return type() == Type::kBoolean;
  }

  /** @brief Get whether this FieldValue contains an integer value. */
  bool is_integer() const {
    return type() == Type::kInteger;
  }

  /** @brief Get whether this FieldValue contains a double value. */
  bool is_double() const {
    return type() == Type::kDouble;
  }

  /** @brief Get whether this FieldValue contains a timestamp. */
  bool is_timestamp() const {
    return type() == Type::kTimestamp;
  }

  /** @brief Get whether this FieldValue contains a string. */
  bool is_string() const {
    return type() == Type::kString;
  }

  /** @brief Get whether this FieldValue contains a blob. */
  bool is_blob() const {
    return type() == Type::kBlob;
  }

  /**
   * @brief Get whether this FieldValue contains a reference to a document in
   * the same Firestore.
   */
  bool is_reference() const {
    return type() == Type::kReference;
  }

  /** @brief Get whether this FieldValue contains a GeoPoint. */
  bool is_geo_point() const {
    return type() == Type::kGeoPoint;
  }

  /** @brief Get whether this FieldValue contains an array of FieldValue. */
  bool is_array() const {
    return type() == Type::kArray;
  }

  /** @brief Get whether this FieldValue contains a map of std::string to
   * FieldValue. */
  bool is_map() const {
    return type() == Type::kMap;
  }

  /** @brief Get the bool value contained in this FieldValue. */
  virtual bool boolean_value() const;

  /** @brief Get the integer value contained in this FieldValue. */
  virtual int64_t integer_value() const;

  /** @brief Get the double value contained in this FieldValue. */
  virtual double double_value() const;

  /** @brief Get the timestamp value contained in this FieldValue. */
  virtual Timestamp timestamp_value() const;

  /** @brief Get the string value contained in this FieldValue. */
  virtual std::string string_value() const;

  /** @brief Get the blob value contained in this FieldValue. */
  virtual const uint8_t* blob_value() const;

  /** @brief Get the blob size contained in this FieldValue. */
  virtual size_t blob_size() const;

  /** @brief Get the DocumentReference contained in this FieldValue. */
  virtual DocumentReference reference_value() const;

  /** @brief Get the GeoPoint value contained in this FieldValue. */
  virtual GeoPoint geo_point_value() const;

  /** @brief Get the vector of FieldValue contained in this FieldValue. */
  virtual std::vector<FieldValue> array_value() const;

  /**
   * @brief Get the map of string to FieldValue contained in this FieldValue.
   */
  virtual MapFieldValue map_value() const;

  /** @brief Construct a null. */
  static FieldValue Null();

  /** @brief Construct a true. */
  static FieldValue True() {
    return FieldValue::FromBoolean(true);
  }

  /** @brief Construct a false. */
  static FieldValue False() {
    return FieldValue::FromBoolean(false);
  }

  /**
   * @brief Returns a sentinel for use with Update() to mark a field for
   * deletion.
   */
  static FieldValue Delete();

  /**
   * Returns a sentinel for use with Set() or Update() to include a server-
   * generated timestamp in the written data.
   */
  static FieldValue ServerTimestamp();

  /**
   * Returns a special value that can be used with Set() or Update() that tells
   * the server to union the given elements with any array value that already
   * exists on the server. Each specified element that doesn't already exist in
   * the array will be added to the end. If the field being modified is not
   * already an array it will be overwritten with an array containing exactly
   * the specified elements.
   *
   * @param elements The elements to union into the array.
   * @return The FieldValue sentinel for use in a call to Set() or Update().
   */
  static FieldValue ArrayUnion(std::vector<FieldValue> elements);

  /**
   * Returns a special value that can be used with Set() or Update() that tells
   * the server to remove the given elements from any array value that already
   * exists on the server. All instances of each element specified will be
   * removed from the array. If the field being modified is not already an array
   * it will be overwritten with an empty array.
   *
   * @param elements The elements to remove from the array.
   * @return The FieldValue sentinel for use in a call to Set() or Update().
   */
  static FieldValue ArrayRemove(std::vector<FieldValue> elements);

 protected:
  explicit FieldValue(FieldValueInternal* internal);

 private:
  friend class DocumentSnapshotInternal;
  friend class FieldValueInternal;
  friend class FirestoreInternal;
  friend class QueryInternal;
  friend class Wrapper;
  friend bool operator==(const FieldValue& lhs, const FieldValue& rhs);

  FieldValueInternal* internal_ = nullptr;
};

bool operator==(const FieldValue& lhs, const FieldValue& rhs);

inline bool operator!=(const FieldValue& lhs, const FieldValue& rhs) {
  return !(lhs == rhs);
}

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIELD_VALUE_H_
