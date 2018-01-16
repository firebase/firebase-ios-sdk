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
#include <memory>
#include <vector>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace model {

using Type = FieldValue::Type;

namespace {
/**
 * This deviates from the other platforms that define TypeOrder. Since
 * we already define Type for union types, we use it together with this
 * function to achive the equivalent order of types i.e.
 *     i) if two types are comparable, then they are of equal order;
 *    ii) otherwise, their order is the same as the order of their Type.
 */
bool Comparable(Type lhs, Type rhs) {
  switch (lhs) {
    case Type::Long:
    case Type::Double:
      return rhs == Type::Long || rhs == Type::Double;
    case Type::Timestamp:
    case Type::ServerTimestamp:
      return rhs == Type::Timestamp || rhs == Type::ServerTimestamp;
    default:
      return lhs == rhs;
  }
}

}  // namespace

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
    case Type::Array: {
      // copy-and-swap
      std::vector<const FieldValue> tmp = value.array_value_;
      std::swap(array_value_, tmp);
      break;
    }
    default:
      FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
          false, lhs.type(), "Unsupported type %d", value.type());
  }
  return *this;
}

FieldValue& FieldValue::operator=(FieldValue&& value) {
  switch (value.tag_) {
    case Type::Array:
      SwitchTo(Type::Array);
      std::swap(array_value_, value.array_value_);
      return *this;
    default:
      // We just copy over POD union types.
      return *this = value;
  }
}

const FieldValue& FieldValue::NullValue() {
  static const FieldValue kNullInstance;
  return kNullInstance;
}

const FieldValue& FieldValue::TrueValue() {
  static const FieldValue kTrueInstance(true);
  return kTrueInstance;
}

const FieldValue& FieldValue::FalseValue() {
  static const FieldValue kFalseInstance(false);
  return kFalseInstance;
}

const FieldValue& FieldValue::BooleanValue(bool value) {
  return value ? TrueValue() : FalseValue();
}

FieldValue FieldValue::ArrayValue(const std::vector<const FieldValue>& value) {
  std::vector<const FieldValue> copy(value);
  return ArrayValue(std::move(copy));
}

FieldValue FieldValue::ArrayValue(std::vector<const FieldValue>&& value) {
  FieldValue result;
  result.SwitchTo(Type::Array);
  std::swap(result.array_value_, value);
  return result;
}

bool operator<(const FieldValue& lhs, const FieldValue& rhs) {
  if (!Comparable(lhs.type(), rhs.type())) {
    return lhs.type() < rhs.type();
  }

  switch (lhs.type()) {
    case Type::Null:
      return false;
    case Type::Boolean:
      // lhs < rhs iff lhs == false and rhs == true.
      return !lhs.boolean_value_ && rhs.boolean_value_;
    case Type::Array:
      return lhs.array_value_ < rhs.array_value_;
    default:
      FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(
          false, lhs.type(), "Unsupported type %d", lhs.type());
      // return false if assertion does not abort the program. We will say
      // each unsupported type takes only one value thus everything is equal.
      return false;
  }
}

void FieldValue::SwitchTo(const Type type) {
  if (tag_ == type) {
    return;
  }
  // Not same type. Destruct old type first and then initialize new type.
  // Must call destructor explicitly for any non-POD type.
  switch (tag_) {
    case Type::Array:
      array_value_.~vector();
      break;
    default:;  // The other types where there is nothing to worry about.
  }
  tag_ = type;
  // Must call constructor explicitly for any non-POD type to initialize.
  switch (tag_) {
    case Type::Array:
      new (&array_value_) std::vector<const FieldValue>();
      break;
    default:;  // The other types where there is nothing to worry about.
  }
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
