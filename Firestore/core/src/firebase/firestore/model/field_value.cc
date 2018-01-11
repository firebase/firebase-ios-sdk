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

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

namespace firebase {
namespace firestore {
namespace model {

FieldValue::~FieldValue() {
  switch(tag_) {
    case FieldValue::Type::Array:
      delete value_->array_value_.value_;
      break;
    default:
      ;  // The other types where there is nothing to worry about.
  }
}

FieldValue::TypeOrder FieldValue::type_order() const {
  switch(tag_) {
    case FieldValue::Type::Null:
      return FieldValue::TypeOrder::Null;
    case FieldValue::Type::Boolean:
      return FieldValue::TypeOrder::Boolean;
    case FieldValue::Type::Long:
      return FieldValue::TypeOrder::Number;
    case FieldValue::Type::Double:
      return FieldValue::TypeOrder::Number;
    case FieldValue::Type::Timestamp:
      return FieldValue::TypeOrder::Timestamp;
    case FieldValue::Type::ServerTimestamp:
      return FieldValue::TypeOrder::Timestamp;
    case FieldValue::Type::String:
      return FieldValue::TypeOrder::String;
    case FieldValue::Type::Binary:
      return FieldValue::TypeOrder::Blob;
    case FieldValue::Type::Reference:
      return FieldValue::TypeOrder::Reference;
    case FieldValue::Type::GeoPoint:
      return FieldValue::TypeOrder::GeoPoint;
    case FieldValue::Type::Array:
      return FieldValue::TypeOrder::Array;
    case FieldValue::Type::Object:
      return FieldValue::TypeOrder::Object;
    default:
      FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(false, tag_,
          "Unmatched type %d", tag_);
  }
}

int Compare(const NullValue& lhs, const NullValue& rhs) {
  return 0;
}

int Compare(const BooleanValue& lhs, const BooleanValue& rhs) {
  return lhs.value() == rhs.value() ? 0 : lhs.value() ? 1 : -1;
}

int Compare(const FieldValue& lhs, const FieldValue& rhs) {
  const FieldValue::TypeOrder left = lhs.type_order();
  const FieldValue::TypeOrder right = rhs.type_order();
  if (left == right) {
    switch(lhs.type()) {
      case FieldValue::Type::Null:
        return Compare(lhs.value_->null_value_, rhs.value_->null_value_);
      case FieldValue::Type::Boolean:
        return Compare(lhs.value_->boolean_value_, rhs.value_->boolean_value_);
      case FieldValue::Type::Long:
      case FieldValue::Type::Double:
      case FieldValue::Type::Timestamp:
      case FieldValue::Type::ServerTimestamp:
      case FieldValue::Type::String:
      case FieldValue::Type::Binary:
      case FieldValue::Type::Reference:
      case FieldValue::Type::GeoPoint:
      case FieldValue::Type::Array:
      case FieldValue::Type::Object:
        FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(false, lhs.type(),
            "Unsupported type %d", lhs.type());
      default:
        FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(false, lhs.type(),
            "Unmatched type %d", lhs.type());
    }
  } else if (left > right) {
    return 1;
  } else {
    return -1;
  }
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
