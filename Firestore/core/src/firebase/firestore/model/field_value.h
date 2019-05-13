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

#include <cstdint>
#include <iosfwd>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/types/optional.h"

#if __OBJC__
@class FSTFieldValue;
#endif  // __OBJC__

namespace firebase {
namespace firestore {
namespace model {

struct ReferenceValue;
struct ServerTimestamp;

/**
 * tagged-union class representing an immutable data value as stored in
 * Firestore. FieldValue represents all the different kinds of values
 * that can be stored in fields in a document.
 */
class FieldValue : public util::Comparable<FieldValue> {
 public:
  using Map = immutable::SortedMap<std::string, FieldValue>;

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
    Integer,  // Number type starts here
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

  /**
   * Checks if the given type is a numeric, such as Type::Integer or
   * Type::Double.
   */
  static bool IsNumber(Type type) {
    return type == Type::Integer || type == Type::Double;
  }

  FieldValue() {
  }

  // Do not inline these ctor/dtor below, which contain call to non-trivial
  // operator=.
  FieldValue(const FieldValue& value);
  FieldValue(FieldValue&& value);

  ~FieldValue();

  FieldValue& operator=(const FieldValue& value);
  FieldValue& operator=(FieldValue&& value);

#if __OBJC__
  FSTFieldValue* Wrap() &&;
#endif  // __OBJC__

  /** Returns the true type for this value. */
  Type type() const {
    return tag_;
  }

  /**
   * PORTING NOTE: This deviates from the other platforms that define TypeOrder.
   * Since we already define Type for union types, we use it together with this
   * function to achieve the equivalent order of types i.e.
   *     i) if two types are comparable, then they are of equal order;
   *    ii) otherwise, their order is the same as the order of their Type.
   */
  static bool Comparable(Type lhs, Type rhs);

  bool boolean_value() const {
    HARD_ASSERT(tag_ == Type::Boolean);
    return boolean_value_;
  }

  int64_t integer_value() const {
    HARD_ASSERT(tag_ == Type::Integer);
    return integer_value_;
  }

  double double_value() const {
    HARD_ASSERT(tag_ == Type::Double);
    return double_value_;
  }

  Timestamp timestamp_value() const {
    HARD_ASSERT(tag_ == Type::Timestamp);
    return *timestamp_value_;
  }

  const std::string& string_value() const {
    HARD_ASSERT(tag_ == Type::String);
    return *string_value_;
  }

  const std::vector<uint8_t>& blob_value() const {
    HARD_ASSERT(tag_ == Type::Blob);
    return *blob_value_;
  }

  /**
   * Returns a string_view of the blob_value(). This can be useful when using
   * abseil bytewise APIs that accept this type.
   */
  absl::string_view blob_value_as_string_view() const;

  const GeoPoint& geo_point_value() const {
    HARD_ASSERT(tag_ == Type::GeoPoint);
    return *geo_point_value_;
  }

  const std::vector<FieldValue>& array_value() const {
    HARD_ASSERT(tag_ == Type::Array);
    return *array_value_;
  }

  /** factory methods. */
  static FieldValue Null();
  static FieldValue True();
  static FieldValue False();
  static FieldValue Nan();
  static FieldValue EmptyObject();
  static FieldValue FromBoolean(bool value);
  static FieldValue FromInteger(int64_t value);
  static FieldValue FromDouble(double value);
  static FieldValue FromTimestamp(const Timestamp& value);
  static FieldValue FromServerTimestamp(const Timestamp& local_write_time,
                                        const FieldValue& previous_value);
  static FieldValue FromServerTimestamp(const Timestamp& local_write_time);
  static FieldValue FromString(const char* value);
  static FieldValue FromString(const std::string& value);
  static FieldValue FromString(std::string&& value);
  static FieldValue FromBlob(const uint8_t* source, size_t size);
  static FieldValue FromReference(const DocumentKey& value,
                                  const DatabaseId* database_id);
  static FieldValue FromReference(DocumentKey&& value,
                                  const DatabaseId* database_id);
  static FieldValue FromGeoPoint(const GeoPoint& value);
  static FieldValue FromArray(const std::vector<FieldValue>& value);
  static FieldValue FromArray(std::vector<FieldValue>&& value);
  static FieldValue FromMap(const Map& value);
  static FieldValue FromMap(Map&& value);

  size_t Hash() const;

  util::ComparisonResult CompareTo(const FieldValue& rhs) const;

  std::string ToString() const;
  friend std::ostream& operator<<(std::ostream& os, const FieldValue& value);

 private:
  friend class ObjectValue;

  explicit FieldValue(bool value) : tag_(Type::Boolean), boolean_value_(value) {
  }

  /**
   * Switch to the specified type, if different from the current type.
   */
  void SwitchTo(Type type);

  Type tag_ = Type::Null;
  union {
    // There is no null type as tag_ alone is enough for Null FieldValue.
    bool boolean_value_;
    int64_t integer_value_;
    double double_value_;
    std::unique_ptr<Timestamp> timestamp_value_;
    std::unique_ptr<ServerTimestamp> server_timestamp_value_;
    // TODO(rsgowman): Change unique_ptr<std::string> to nanopb::String?
    std::unique_ptr<std::string> string_value_;
    std::unique_ptr<std::vector<uint8_t>> blob_value_;
    std::unique_ptr<ReferenceValue> reference_value_;
    std::unique_ptr<GeoPoint> geo_point_value_;
    std::unique_ptr<std::vector<FieldValue>> array_value_;
    std::unique_ptr<Map> object_value_;
  };
};

/** A structured object value stored in Firestore. */
class ObjectValue : public util::Comparable<ObjectValue> {
 public:
  explicit ObjectValue(FieldValue fv) : fv_(std::move(fv)) {
    HARD_ASSERT(fv_.type() == FieldValue::Type::Object);
  }

  static ObjectValue Empty() {
    return ObjectValue(FieldValue::EmptyObject());
  }

  static ObjectValue FromMap(const FieldValue::Map& value);
  static ObjectValue FromMap(FieldValue::Map&& value);

  /**
   * Returns the value at the given path or absl::nullopt. If the path is empty,
   * an identical copy of the FieldValue is returned.
   *
   * @param field_path the path to search.
   * @return The value at the path or absl::nullopt if it doesn't exist.
   */
  absl::optional<FieldValue> Get(const FieldPath& field_path) const;

  /**
   * Returns a FieldValue with the field at the named path set to value.
   * Any absent parent of the field will also be created accordingly.
   *
   * @param field_path The field path to set. Cannot be empty.
   * @param value The value to set.
   * @return A new FieldValue with the field set.
   */
  ObjectValue Set(const FieldPath& field_path, const FieldValue& value) const;

  /**
   * Returns a FieldValue with the field path deleted. If there is no field at
   * the specified path, the returned value is an identical copy.
   *
   * @param field_path The field path to remove. Cannot be empty.
   * @return A new FieldValue with the field path removed.
   */
  ObjectValue Delete(const FieldPath& field_path) const;

  // TODO(rsgowman): Add Value() method?
  //
  // Java has a value() method which returns a (non-immutable) java.util.Map,
  // which is a copy of the immutable map, but with some fields (such as server
  // timestamps) optionally resolved. Do we need the same here?

  const FieldValue::Map& GetInternalValue() const {
    return *fv_.object_value_;
  }

  util::ComparisonResult CompareTo(const ObjectValue& rhs) const;

  std::string ToString() const;
  friend std::ostream& operator<<(std::ostream& os, const ObjectValue& value);

  size_t Hash() const;

 private:
  ObjectValue SetChild(const std::string& child_name,
                       const FieldValue& value) const;

  FieldValue fv_;
};

struct ServerTimestamp {
  Timestamp local_write_time;
  absl::optional<FieldValue> previous_value;

  std::string ToString() const;
  friend std::ostream& operator<<(std::ostream& os,
                                  const ServerTimestamp& value);

  size_t Hash() const;
};

struct ReferenceValue {
  DocumentKey reference;
  // Does not own the DatabaseId instance.
  const DatabaseId* database_id = nullptr;

  std::string ToString() const;
  friend std::ostream& operator<<(std::ostream& os,
                                  const ReferenceValue& value);

  size_t Hash() const;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_VALUE_H_
