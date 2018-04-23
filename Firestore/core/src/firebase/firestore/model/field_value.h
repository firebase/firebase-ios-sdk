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
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

struct ServerTimestamp {
  Timestamp local_write_time;
  absl::optional<Timestamp> previous_value;
};

struct ReferenceValue {
  DocumentKey reference;
  // Does not own the DatabaseId instance.
  const DatabaseId* database_id;
};

// TODO(rsgowman): Expand this to roughly match the java class
// c.g.f.f.model.value.ObjectValue. Probably move it to a similar namespace as
// well. (FieldValue itself is also in the value package in java.) Also do the
// same with the other FooValue values that FieldValue can return.
class FieldValue;
struct ObjectValue {
  // TODO(rsgowman): These will eventually be private. We do want the serializer
  // to be able to directly access these (possibly implying 'friend' usage, or a
  // getInternalValue() like java has.)
  using Map = std::map<std::string, FieldValue>;
  Map internal_value;
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

  FieldValue() {
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

  bool boolean_value() const {
    FIREBASE_ASSERT(tag_ == Type::Boolean);
    return boolean_value_;
  }

  int64_t integer_value() const {
    FIREBASE_ASSERT(tag_ == Type::Integer);
    return integer_value_;
  }

  Timestamp timestamp_value() const {
    FIREBASE_ASSERT(tag_ == Type::Timestamp);
    return timestamp_value_;
  }

  const std::string& string_value() const {
    FIREBASE_ASSERT(tag_ == Type::String);
    return string_value_;
  }

  ObjectValue object_value() const {
    FIREBASE_ASSERT(tag_ == Type::Object);
    return ObjectValue{object_value_};
  }

  /**
   * Returns a FieldValue with the field at the named path set to value.
   * Any absent parent of the field will also be created accordingly.
   *
   * @param field_path The field path to set. Cannot be empty.
   * @param value The value to set.
   * @return A new FieldValue with the field set.
   */
  FieldValue Set(const FieldPath& field_path, FieldValue value) const;

  /**
   * Returns a FieldValue with the field path deleted. If there is no field at
   * the specified path, the returned value is an identical copy.
   *
   * @param field_path The field path to remove. Cannot be empty.
   * @return A new FieldValue with the field path removed.
   */
  FieldValue Delete(const FieldPath& field_path) const;

  /**
   * Returns the value at the given path or absl::nullopt. If the path is empty,
   * an identical copy of the FieldValue is returned.
   *
   * @param field_path the path to search.
   * @return The value at the path or absl::nullopt if it doesn't exist.
   */
  absl::optional<FieldValue> Get(const FieldPath& field_path) const;

  /** factory methods. */
  static const FieldValue& NullValue();
  static const FieldValue& TrueValue();
  static const FieldValue& FalseValue();
  static const FieldValue& BooleanValue(bool value);
  static const FieldValue& NanValue();
  static FieldValue IntegerValue(int64_t value);
  static FieldValue DoubleValue(double value);
  static FieldValue TimestampValue(const Timestamp& value);
  static FieldValue ServerTimestampValue(const Timestamp& local_write_time,
                                         const Timestamp& previous_value);
  static FieldValue ServerTimestampValue(const Timestamp& local_write_time);
  static FieldValue StringValue(const char* value);
  static FieldValue StringValue(const std::string& value);
  static FieldValue StringValue(std::string&& value);
  static FieldValue BlobValue(const uint8_t* source, size_t size);
  static FieldValue ReferenceValue(const DocumentKey& value,
                                   const DatabaseId* database_id);
  static FieldValue ReferenceValue(DocumentKey&& value,
                                   const DatabaseId* database_id);
  static FieldValue GeoPointValue(const GeoPoint& value);
  static FieldValue ArrayValue(const std::vector<FieldValue>& value);
  static FieldValue ArrayValue(std::vector<FieldValue>&& value);
  static FieldValue ObjectValueFromMap(const ObjectValue::Map& value);
  static FieldValue ObjectValueFromMap(ObjectValue::Map&& value);

  friend bool operator<(const FieldValue& lhs, const FieldValue& rhs);

 private:
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
    Timestamp timestamp_value_;
    ServerTimestamp server_timestamp_value_;
    std::string string_value_;
    std::vector<uint8_t> blob_value_;
    // Qualified name to avoid conflict with the member function of same name.
    firebase::firestore::model::ReferenceValue reference_value_;
    GeoPoint geo_point_value_;
    std::vector<FieldValue> array_value_;
    ObjectValue object_value_;
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

/** Compares against another ObjectValue. */
inline bool operator<(const ObjectValue& lhs, const ObjectValue& rhs) {
  return lhs.internal_value < rhs.internal_value;
}

inline bool operator>(const ObjectValue& lhs, const ObjectValue& rhs) {
  return rhs < lhs;
}

inline bool operator>=(const ObjectValue& lhs, const ObjectValue& rhs) {
  return !(lhs < rhs);
}

inline bool operator<=(const ObjectValue& lhs, const ObjectValue& rhs) {
  return !(lhs > rhs);
}

inline bool operator!=(const ObjectValue& lhs, const ObjectValue& rhs) {
  return lhs < rhs || lhs > rhs;
}

inline bool operator==(const ObjectValue& lhs, const ObjectValue& rhs) {
  return !(lhs != rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_FIELD_VALUE_H_
