/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"

#include <utility>
#include <vector>

#import "Firestore/Source/Model/FSTFieldValue.h"

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace model {

FSTFieldValue* ServerTimestampTransform::ApplyToLocalView(
    FSTFieldValue* previousValue,
    const Timestamp& local_write_time) const {
  // TODO(wilhuff): DO NOT SUBMIT: handle previousValue
  return FieldValue::FromServerTimestamp(local_write_time, FieldValue::Null())
      .Wrap();
}

FSTFieldValue* ServerTimestampTransform::ApplyToRemoteDocument(
    FSTFieldValue* /* previousValue */,
    FSTFieldValue* transformResult) const {
  return transformResult;
}

bool ServerTimestampTransform::operator==(const TransformOperation& other) const {
  // All ServerTimestampTransform objects are equal.
  return other.type() == Type::ServerTimestamp;
}

const ServerTimestampTransform& ServerTimestampTransform::Get() {
  static ServerTimestampTransform shared_instance;
  return shared_instance;
}

size_t ServerTimestampTransform::Hash() const {
  // arbitrary number, the same as used in ObjC implementation, since all
  // instances are equal.
  return 37;
}

FSTFieldValue* ArrayTransform::ApplyToLocalView(
    FSTFieldValue* previousValue,
    const Timestamp& /* local_write_time */) const {
  return Apply(previousValue);
}

FSTFieldValue* ArrayTransform::ApplyToRemoteDocument(
    FSTFieldValue* previousValue,
    FSTFieldValue* /* transformResult */) const {
  // The server just sends null as the transform result for array operations,
  // so we have to calculate a result the same as we do for local
  // applications.
  return Apply(previousValue);
}

bool ArrayTransform::operator==(const TransformOperation& other) const {
  if (other.type() != type()) {
    return false;
  }
  auto array_transform = static_cast<const ArrayTransform&>(other);
  if (array_transform.elements_.size() != elements_.size()) {
    return false;
  }
  for (size_t i = 0; i < elements_.size(); i++) {
    if (![array_transform.elements_[i] isEqual:elements_[i]]) {
      return false;
    }
  }
  return true;
}

size_t ArrayTransform::Hash() const {
  size_t result = 37;
  result = 31 * result + (type() == Type::ArrayUnion ? 1231 : 1237);
  for (FSTFieldValue* element : elements_) {
    result = 31 * result + [element hash];
  }
  return result;
}

const std::vector<FSTFieldValue*>& ArrayTransform::Elements(
    const TransformOperation& op) {
  HARD_ASSERT(op.type() == Type::ArrayUnion ||
              op.type() == Type::ArrayRemove);
  return static_cast<const ArrayTransform&>(op).elements();
}

/**
 * Inspects the provided value, returning a mutable copy of the internal array
 * if it's an FSTArrayValue and an empty mutable array if it's nil or any
 * other type of FSTFieldValue.
 */
NSMutableArray<FSTFieldValue*>* ArrayTransform::CoercedFieldValuesArray(
    FSTFieldValue* value) {
  if ([value isMemberOfClass:[FSTArrayValue class]]) {
    return [NSMutableArray
        arrayWithArray:reinterpret_cast<FSTArrayValue*>(value).internalValue];
  } else {
    // coerce to empty array.
    return [NSMutableArray array];
  }
}

FSTFieldValue* ArrayTransform::Apply(FSTFieldValue* previousValue) const {
  NSMutableArray<FSTFieldValue*>* result =
      ArrayTransform::CoercedFieldValuesArray(previousValue);
  for (FSTFieldValue* element : elements_) {
    if (type_ == Type::ArrayUnion) {
      if (![result containsObject:element]) {
        [result addObject:element];
      }
    } else {
      HARD_ASSERT(type_ == Type::ArrayRemove);
      [result removeObject:element];
    }
  }
  return [[FSTArrayValue alloc] initWithValueNoCopy:result];
}

namespace {

/**
 * Implements saturating integer addition. Overflows are resolved to
 * LONG_MAX/LONG_MIN.
 */
int64_t SafeIncrement(int64_t x, int64_t y) {
  if (x > 0 && y > LONG_MAX - x) {
    return LONG_MAX;
  }

  if (x < 0 && y < LONG_MIN - x) {
    return LONG_MIN;
  }

  return x + y;
}

double AsDouble(FSTFieldValue* value) {
  if (value.type == FieldValue::Type::Double) {
    return value.doubleValue;
  } else if (value.type == FieldValue::Type::Integer) {
    return value.integerValue;
  } else {
    HARD_FAIL("Expected 'operand' to be of numeric type, but was %s",
              NSStringFromClass([value class]));
  }
}

}  // namespace

NumericIncrementTransform::NumericIncrementTransform(FSTFieldValue* operand)
    : operand_(operand) {
  HARD_ASSERT(FieldValue::IsNumber(operand.type));
}

  FSTFieldValue* NumericIncrementTransform::ApplyToLocalView(
      FSTFieldValue* previousValue,
      const Timestamp& /* local_write_time */) const {
    // Return an integer value only if the previous value and the operand is an
    // integer.
    if (previousValue.type == FieldValue::Type::Integer &&
        operand_.type == FieldValue::Type::Integer) {
      int64_t sum =
          SafeIncrement(previousValue.integerValue, operand_.integerValue);
      return FieldValue::FromInteger(sum).Wrap();
    } else if (previousValue.type == FieldValue::Type::Integer) {
      double sum = previousValue.integerValue + AsDouble(operand_);
      return FieldValue::FromDouble(sum).Wrap();
    } else if (previousValue.type == FieldValue::Type::Double) {
      double sum = previousValue.doubleValue + AsDouble(operand_);
      return FieldValue::FromDouble(sum).Wrap();
    } else {
      // If the existing value is not a number, use the value of the transform
      // as the new base value.
      return operand_;
    }
  }

  FSTFieldValue* NumericIncrementTransform::ApplyToRemoteDocument(
      FSTFieldValue*, FSTFieldValue* transformResult) const {
    return transformResult;
  }

  bool NumericIncrementTransform::operator==(const TransformOperation& other) const {
    if (other.type() != type()) {
      return false;
    }
    auto numeric_add = static_cast<const NumericIncrementTransform&>(other);
    return [operand_ isEqual:numeric_add.operand_];
  }

  size_t NumericIncrementTransform::Hash() const {
    size_t result = 37;
    result = 31 * result + [operand_ hash];
    return result;
  }

}  // namespace model
}  // namespace firestore
}  // namespace firebase

