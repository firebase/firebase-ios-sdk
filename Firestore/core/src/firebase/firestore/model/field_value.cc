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
#include <vector>

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace model {

using Type = FieldValue::Type;

namespace {

bool Comparable(Type lhs, Type rhs) {
  switch(lhs) {
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

void FieldValue::ResetUnion() {
  // Must call destructor explicitly for any non-POD type for UnionValue.
  switch(tag_) {
    case Type::Array:
      tag_ = Type::Null;
      value_.array_value_.~vector();
      break;
    default:
      ;  // The other types where there is nothing to worry about.
  }
}

void FieldValue::CopyUnion(const FieldValue& value){
  switch(value.tag_) {
    case Type::Null:
      break;
    case Type::Boolean:
      new (&value_) UnionValue(value.value_.boolean_value_);
      break;
    case Type::Array:
      new (&value_) UnionValue(value.value_.array_value_);
      break;
    default:
      FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(false, lhs.type(),
          "Unsupported type %d", value.type());
  }
}

FieldValue::FieldValue(const FieldValue& value) : tag_(value.tag_) {
  CopyUnion(value);
}

FieldValue::~FieldValue() {
  ResetUnion();
}

FieldValue& FieldValue::operator=(const FieldValue& value) {
  // Not same type. Destruct old type first.
  if (tag_ != value.tag_) {
    ResetUnion();
  }
  tag_ = value.tag_;
  CopyUnion(value);
}

const FieldValue& FieldValue::NullValue() {
  static const FieldValue kNullInstance;
  return kNullInstance;
}

const FieldValue& FieldValue::BooleanValue(bool value) {
  static const FieldValue kTrueInstance(true);
  static const FieldValue kFalseInstance(false);
  return value ? kTrueInstance : kFalseInstance;
}

bool operator<(const FieldValue& lhs, const FieldValue& rhs) {
  if (!Comparable(lhs.type(), rhs.type())) {
    return lhs.type() < rhs.type();
  }

  switch(lhs.type()) {
    case Type::Null:
      return 0;
    case Type::Boolean:
      // lhs < rhs iff lhs == false and rhs == true.
      return !lhs.value_.boolean_value_ && rhs.value_.boolean_value_;
    case Type::Array:
      return lhs.value_.array_value_ < rhs.value_.array_value_;
    default:
      FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(false, lhs.type(),
          "Unsupported type %d", lhs.type());
  }
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
