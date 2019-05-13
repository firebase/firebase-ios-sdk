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

#include "Firestore/core/src/firebase/firestore/model/field_value.h"

#include <algorithm>
#include <cmath>
#include <iostream>
#include <memory>
#include <new>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/immutable/sorted_map.h"
#include "Firestore/core/src/firebase/firestore/util/comparison.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"
#include "absl/memory/memory.h"
#include "absl/strings/escaping.h"

namespace firebase {
namespace firestore {
namespace model {

using Type = FieldValue::Type;

using util::Compare;
using util::ComparisonResult;

std::string ServerTimestamp::ToString() const {
  std::string time = local_write_time.ToString();
  return absl::StrCat("ServerTimestamp(local_write_time=", time, ")");
}

std::ostream& operator<<(std::ostream& os, const ServerTimestamp& value) {
  return os << value.ToString();
}

size_t ServerTimestamp::Hash() const {
  size_t result =
      util::Hash(local_write_time.seconds(), local_write_time.nanoseconds());

  if (previous_value) {
    result = util::Hash(result, *previous_value);
  }
  return result;
}

std::string ReferenceValue::ToString() const {
  return absl::StrCat("Reference(key=", reference.ToString(), ")");
}

std::ostream& operator<<(std::ostream& os, const ReferenceValue& value) {
  return os << value.ToString();
}

size_t ReferenceValue::Hash() const {
  return util::Hash(reference, *database_id);
}

FieldValue::FieldValue(const FieldValue& value) {
  *this = value;
}

FieldValue::FieldValue(FieldValue&& value) {
  *this = std::move(value);
}

FieldValue::~FieldValue() {
  SwitchTo(Type::Null);
}

FieldValue& FieldValue::operator=(const FieldValue& value) {
  SwitchTo(value.tag_);
  switch (tag_) {
    case Type::Null:
      break;
    case Type::Boolean:
      boolean_value_ = value.boolean_value_;
      break;
    case Type::Integer:
      integer_value_ = value.integer_value_;
      break;
    case Type::Double:
      double_value_ = value.double_value_;
      break;
    case Type::Timestamp:
      *timestamp_value_ = *value.timestamp_value_;
      break;
    case Type::ServerTimestamp:
      *server_timestamp_value_ = *value.server_timestamp_value_;
      break;
    case Type::String:
      *string_value_ = *value.string_value_;
      break;
    case Type::Blob: {
      // copy-and-swap
      std::vector<uint8_t> tmp = *value.blob_value_;
      std::swap(*blob_value_, tmp);
      break;
    }
    case Type::Reference:
      *reference_value_ = *value.reference_value_;
      break;
    case Type::GeoPoint:
      *geo_point_value_ = *value.geo_point_value_;
      break;
    case Type::Array: {
      // copy-and-swap
      std::vector<FieldValue> tmp = *value.array_value_;
      std::swap(*array_value_, tmp);
      break;
    }
    case Type::Object: {
      // copy-and-swap
      Map tmp = *value.object_value_;
      std::swap(*object_value_, tmp);
      break;
    }
  }
  return *this;
}

FieldValue& FieldValue::operator=(FieldValue&& value) {
  switch (value.tag_) {
    case Type::String:
      SwitchTo(Type::String);
      string_value_->swap(*value.string_value_);
      return *this;
    case Type::Blob:
      SwitchTo(Type::Blob);
      std::swap(blob_value_, value.blob_value_);
      return *this;
    case Type::Reference:
      SwitchTo(Type::Reference);
      std::swap(reference_value_, value.reference_value_);
      return *this;
    case Type::Array:
      SwitchTo(Type::Array);
      std::swap(array_value_, value.array_value_);
      return *this;
    case Type::Object:
      SwitchTo(Type::Object);
      std::swap(object_value_, value.object_value_);
      return *this;
    default:
      // We just copy over POD union types.
      *this = value;
      return *this;
  }
}

bool FieldValue::Comparable(Type lhs, Type rhs) {
  switch (lhs) {
    case Type::Integer:
    case Type::Double:
      return rhs == Type::Integer || rhs == Type::Double;
    case Type::Timestamp:
    case Type::ServerTimestamp:
      return rhs == Type::Timestamp || rhs == Type::ServerTimestamp;
    default:
      return lhs == rhs;
  }
}

// TODO(rsgowman): Reorder this file to match its header.
ObjectValue ObjectValue::Set(const FieldPath& field_path,
                             const FieldValue& value) const {
  HARD_ASSERT(!field_path.empty(),
              "Cannot set field for empty path on FieldValue");
  // Set the value by recursively calling on child object.
  const std::string& child_name = field_path.first_segment();
  if (field_path.size() == 1) {
    return SetChild(child_name, value);
  } else {
    ObjectValue child = ObjectValue::Empty();
    const auto iter = fv_.object_value_->find(child_name);
    if (iter != fv_.object_value_->end() &&
        iter->second.type() == Type::Object) {
      child = ObjectValue(iter->second);
    }
    ObjectValue new_child = child.Set(field_path.PopFirst(), value);
    return SetChild(child_name, new_child.fv_);
  }
}

ObjectValue ObjectValue::Delete(const FieldPath& field_path) const {
  HARD_ASSERT(!field_path.empty(),
              "Cannot delete field for empty path on FieldValue");
  // Delete the value by recursively calling on child object.
  const std::string& child_name = field_path.first_segment();
  if (field_path.size() == 1) {
    return ObjectValue::FromMap(fv_.object_value_->erase(child_name));
  } else {
    const auto iter = fv_.object_value_->find(child_name);
    if (iter != fv_.object_value_->end() &&
        iter->second.type() == Type::Object) {
      ObjectValue new_child =
          ObjectValue(iter->second).Delete(field_path.PopFirst());
      return SetChild(child_name, new_child.fv_);
    } else {
      // If the found value isn't an object, it cannot contain the remaining
      // segments of the path. We don't actually change a primitive value to
      // an object for a delete.
      return *this;
    }
  }
}

absl::optional<FieldValue> ObjectValue::Get(const FieldPath& field_path) const {
  const FieldValue* current = &this->fv_;
  for (const auto& path : field_path) {
    if (current->type() != Type::Object) {
      return absl::nullopt;
    }
    const auto iter = current->object_value_->find(path);
    if (iter == current->object_value_->end()) {
      return absl::nullopt;
    } else {
      current = &iter->second;
    }
  }
  return *current;
}

ObjectValue ObjectValue::SetChild(const std::string& child_name,
                                  const FieldValue& value) const {
  return ObjectValue::FromMap(fv_.object_value_->insert(child_name, value));
}

absl::string_view FieldValue::blob_value_as_string_view() const {
  const std::vector<uint8_t>& blob = blob_value();

  // string_view accepts const char*, but treats it internally as unsigned.
  auto data = reinterpret_cast<const char*>(blob.data());
  return absl::string_view(data, blob.size());
}

FieldValue FieldValue::Null() {
  return FieldValue();
}

FieldValue FieldValue::True() {
  return FieldValue(true);
}

FieldValue FieldValue::False() {
  return FieldValue(false);
}

FieldValue FieldValue::FromBoolean(bool value) {
  return value ? True() : False();
}

FieldValue FieldValue::Nan() {
  return FieldValue::FromDouble(NAN);
}

FieldValue FieldValue::EmptyObject() {
  return FieldValue::FromMap(FieldValue::Map());
}

FieldValue FieldValue::FromInteger(int64_t value) {
  FieldValue result;
  result.SwitchTo(Type::Integer);
  result.integer_value_ = value;
  return result;
}

FieldValue FieldValue::FromDouble(double value) {
  FieldValue result;
  result.SwitchTo(Type::Double);
  result.double_value_ = value;
  return result;
}

FieldValue FieldValue::FromTimestamp(const Timestamp& value) {
  FieldValue result;
  result.SwitchTo(Type::Timestamp);
  *result.timestamp_value_ = value;
  return result;
}

FieldValue FieldValue::FromServerTimestamp(const Timestamp& local_write_time,
                                           const FieldValue& previous_value) {
  FieldValue result;
  result.SwitchTo(Type::ServerTimestamp);
  result.server_timestamp_value_->local_write_time = local_write_time;
  result.server_timestamp_value_->previous_value = previous_value;
  return result;
}

FieldValue FieldValue::FromServerTimestamp(const Timestamp& local_write_time) {
  FieldValue result;
  result.SwitchTo(Type::ServerTimestamp);
  result.server_timestamp_value_->local_write_time = local_write_time;
  result.server_timestamp_value_->previous_value = absl::nullopt;
  return result;
}

FieldValue FieldValue::FromString(const char* value) {
  std::string copy(value);
  return FromString(std::move(copy));
}

FieldValue FieldValue::FromString(const std::string& value) {
  std::string copy(value);
  return FromString(std::move(copy));
}

FieldValue FieldValue::FromString(std::string&& value) {
  FieldValue result;
  result.SwitchTo(Type::String);
  result.string_value_->swap(value);
  return result;
}

FieldValue FieldValue::FromBlob(const uint8_t* source, size_t size) {
  FieldValue result;
  result.SwitchTo(Type::Blob);
  std::vector<uint8_t> copy(source, source + size);
  std::swap(*result.blob_value_, copy);
  return result;
}

// Does NOT pass ownership of database_id.
FieldValue FieldValue::FromReference(const DocumentKey& value,
                                     const DatabaseId* database_id) {
  FieldValue result;
  result.SwitchTo(Type::Reference);
  result.reference_value_->reference = value;
  result.reference_value_->database_id = database_id;
  return result;
}

// Does NOT pass ownership of database_id.
FieldValue FieldValue::FromReference(DocumentKey&& value,
                                     const DatabaseId* database_id) {
  FieldValue result;
  result.SwitchTo(Type::Reference);
  std::swap(result.reference_value_->reference, value);
  result.reference_value_->database_id = database_id;
  return result;
}

FieldValue FieldValue::FromGeoPoint(const GeoPoint& value) {
  FieldValue result;
  result.SwitchTo(Type::GeoPoint);
  *result.geo_point_value_ = value;
  return result;
}

FieldValue FieldValue::FromArray(const std::vector<FieldValue>& value) {
  std::vector<FieldValue> copy(value);
  return FromArray(std::move(copy));
}

FieldValue FieldValue::FromArray(std::vector<FieldValue>&& value) {
  FieldValue result;
  result.SwitchTo(Type::Array);
  std::swap(*result.array_value_, value);
  return result;
}

FieldValue FieldValue::FromMap(const FieldValue::Map& value) {
  FieldValue::Map copy(value);
  return FromMap(std::move(copy));
}

FieldValue FieldValue::FromMap(FieldValue::Map&& value) {
  FieldValue result;
  result.SwitchTo(Type::Object);
  std::swap(*result.object_value_, value);
  return result;
}

static size_t HashObject(const FieldValue::Map& object) {
  size_t result = 0;
  for (auto&& entry : object) {
    result = util::Hash(result, entry.first, entry.second);
  }
  return result;
}

size_t FieldValue::Hash() const {
  switch (type()) {
    case FieldValue::Type::Null:
      // std::hash is not defined for nullptr_t.
      return util::Hash(static_cast<void*>(nullptr));
    case FieldValue::Type::Boolean:
      return util::Hash(boolean_value_);
    case FieldValue::Type::Integer:
      return util::Hash(integer_value_);
    case FieldValue::Type::Double:
      return util::DoubleBitwiseHash(double_value_);
    case FieldValue::Type::Timestamp:
      return util::Hash(timestamp_value_->seconds(),
                        timestamp_value_->nanoseconds());
    case FieldValue::Type::ServerTimestamp:
      return util::Hash(*server_timestamp_value_);
    case FieldValue::Type::String:
      return util::Hash(*string_value_);
    case FieldValue::Type::Blob:
      return util::Hash(*blob_value_);
    case FieldValue::Type::Reference:
      return util::Hash(*reference_value_);
    case FieldValue::Type::GeoPoint:
      return util::Hash(geo_point_value_->latitude(),
                        geo_point_value_->longitude());
    case FieldValue::Type::Array:
      return util::Hash(*array_value_);
    case FieldValue::Type::Object:
      return HashObject(*object_value_);
  }

  UNREACHABLE();
}

ComparisonResult FieldValue::CompareTo(const FieldValue& rhs) const {
  if (!FieldValue::Comparable(type(), rhs.type())) {
    return Compare(type(), rhs.type());
  }

  ComparisonResult cmp;
  switch (type()) {
    case Type::Null:
      return ComparisonResult::Same;
    case Type::Boolean:
      return Compare(boolean_value_, rhs.boolean_value_);
    case Type::Integer:
      if (rhs.type() == Type::Integer) {
        return Compare(integer_value_, rhs.integer_value_);
      } else {
        return util::ReverseOrder(
            util::CompareMixedNumber(rhs.double_value_, integer_value_));
      }
    case Type::Double:
      if (rhs.type() == Type::Double) {
        return Compare(double_value_, rhs.double_value_);
      } else {
        return util::CompareMixedNumber(double_value_, rhs.integer_value_);
      }
    case Type::Timestamp:
      if (rhs.type() == Type::Timestamp) {
        return Compare(*timestamp_value_, *rhs.timestamp_value_);
      } else {
        return ComparisonResult::Ascending;
      }
    case Type::ServerTimestamp:
      if (rhs.type() == Type::ServerTimestamp) {
        return Compare(server_timestamp_value_->local_write_time,
                       rhs.server_timestamp_value_->local_write_time);
      } else {
        return ComparisonResult::Descending;
      }
    case Type::String:
      return Compare(*string_value_, *rhs.string_value_);
    case Type::Blob:
      return Compare(*blob_value_, *rhs.blob_value_);
    case Type::Reference:
      cmp = Compare(reference_value_->database_id,
                    rhs.reference_value_->database_id);
      if (!util::Same(cmp)) return cmp;

      return Compare(reference_value_->reference,
                     rhs.reference_value_->reference);
    case Type::GeoPoint:
      return Compare(*geo_point_value_, *rhs.geo_point_value_);
    case Type::Array:
      return CompareContainer(*array_value_, *rhs.array_value_);
    case Type::Object:
      return CompareContainer(*object_value_, *rhs.object_value_);
  }

  UNREACHABLE();
}

std::string FieldValue::ToString() const {
  switch (tag_) {
    case Type::Null:
      return util::ToString(nullptr);
    case Type::Boolean:
      return util::ToString(boolean_value_);
    case Type::Integer:
      return util::ToString(integer_value_);
    case Type::Double:
      return util::ToString(double_value_);
    case Type::Timestamp:
      return util::ToString(*timestamp_value_);
    case Type::ServerTimestamp:
      return util::ToString(*server_timestamp_value_);
    case Type::String:
      return util::ToString(*string_value_);
    case Type::Blob:
      return absl::StrCat(
          "<", absl::BytesToHexString(blob_value_as_string_view()), ">");
    case Type::Reference:
      return util::ToString(*reference_value_);
    case Type::GeoPoint:
      return util::ToString(*geo_point_value_);
    case Type::Array:
      return util::ToString(*array_value_);
    case Type::Object:
      return util::ToString(*object_value_);
  }

  UNREACHABLE();
}

std::ostream& operator<<(std::ostream& os, const FieldValue& value) {
  return os << value.ToString();
}

void FieldValue::SwitchTo(const Type type) {
  if (tag_ == type) {
    return;
  }
  // Not same type. Destruct old type first and then initialize new type.
  // Must call destructor explicitly for any non-POD type.
  switch (tag_) {
    case Type::Timestamp:
      timestamp_value_.~unique_ptr<Timestamp>();
      break;
    case Type::ServerTimestamp:
      server_timestamp_value_.~unique_ptr<ServerTimestamp>();
      break;
    case Type::String:
      string_value_.~unique_ptr<std::string>();
      break;
    case Type::Blob:
      blob_value_.~unique_ptr<std::vector<uint8_t>>();
      break;
    case Type::Reference:
      reference_value_.~unique_ptr<ReferenceValue>();
      break;
    case Type::GeoPoint:
      geo_point_value_.~unique_ptr<GeoPoint>();
      break;
    case Type::Array:
      array_value_.~unique_ptr<std::vector<FieldValue>>();
      break;
    case Type::Object:
      object_value_.~unique_ptr<Map>();
      break;
    default: {}  // The other types where there is nothing to worry about.
  }
  tag_ = type;
  // Must call constructor explicitly for any non-POD type to initialize.
  switch (tag_) {
    case Type::Timestamp:
      new (&timestamp_value_)
          std::unique_ptr<Timestamp>(absl::make_unique<Timestamp>(0, 0));
      break;
    case Type::ServerTimestamp:
      new (&server_timestamp_value_) std::unique_ptr<ServerTimestamp>(
          absl::make_unique<ServerTimestamp>());
      break;
    case Type::String:
      new (&string_value_)
          std::unique_ptr<std::string>(absl::make_unique<std::string>());
      break;
    case Type::Blob:
      // Do not even bother to allocate a new array of size 0.
      new (&blob_value_) std::unique_ptr<std::vector<uint8_t>>(
          absl::make_unique<std::vector<uint8_t>>());
      break;
    case Type::Reference:
      new (&reference_value_)
          std::unique_ptr<ReferenceValue>(absl::make_unique<ReferenceValue>());
      break;
    case Type::GeoPoint:
      new (&geo_point_value_)
          std::unique_ptr<GeoPoint>(absl::make_unique<GeoPoint>());
      break;
    case Type::Array:
      new (&array_value_) std::unique_ptr<std::vector<FieldValue>>(
          absl::make_unique<std::vector<FieldValue>>());
      break;
    case Type::Object:
      new (&object_value_) std::unique_ptr<Map>(absl::make_unique<Map>());
      break;
    default: {}  // The other types where there is nothing to worry about.
  }
}

ObjectValue ObjectValue::FromMap(const FieldValue::Map& value) {
  return ObjectValue(FieldValue::FromMap(value));
}

ObjectValue ObjectValue::FromMap(FieldValue::Map&& value) {
  return ObjectValue(FieldValue::FromMap(std::move(value)));
}

ComparisonResult ObjectValue::CompareTo(const ObjectValue& rhs) const {
  return fv_.CompareTo(rhs.fv_);
}

std::string ObjectValue::ToString() const {
  return fv_.ToString();
}

std::ostream& operator<<(std::ostream& os, const ObjectValue& value) {
  return os << value.ToString();
}

size_t ObjectValue::Hash() const {
  return fv_.Hash();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
