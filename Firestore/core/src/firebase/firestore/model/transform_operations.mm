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

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/algorithm/container.h"

namespace firebase {
namespace firestore {
namespace model {

FieldValue ServerTimestampTransform::ApplyToLocalView(
    const absl::optional<FieldValue>& previous_value,
    const Timestamp& local_write_time) const {
  return FieldValue::FromServerTimestamp(local_write_time, previous_value);
}

FieldValue ServerTimestampTransform::ApplyToRemoteDocument(
    const absl::optional<FieldValue>& /* previous_value */,
    const FieldValue& transform_result) const {
  return transform_result;
}

bool ServerTimestampTransform::operator==(
    const TransformOperation& other) const {
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

FieldValue ArrayTransform::ApplyToLocalView(
    const absl::optional<FieldValue>& previous_value,
    const Timestamp& /* local_write_time */) const {
  return Apply(previous_value);
}

FieldValue ArrayTransform::ApplyToRemoteDocument(
    const absl::optional<FieldValue>& previous_value,
    const FieldValue& /* transform_result */) const {
  // The server just sends null as the transform result for array operations,
  // so we have to calculate a result the same as we do for local
  // applications.
  return Apply(previous_value);
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
    if (array_transform.elements_[i] != elements_[i]) {
      return false;
    }
  }
  return true;
}

size_t ArrayTransform::Hash() const {
  size_t result = 37;
  result = 31 * result + (type() == Type::ArrayUnion ? 1231 : 1237);
  for (const FieldValue& element : elements_) {
    result = 31 * result + element.Hash();
  }
  return result;
}

const std::vector<FieldValue>& ArrayTransform::Elements(
    const TransformOperation& op) {
  HARD_ASSERT(op.type() == Type::ArrayUnion || op.type() == Type::ArrayRemove);
  return static_cast<const ArrayTransform&>(op).elements();
}

FieldValue::Array ArrayTransform::CoercedFieldValuesArray(
    const absl::optional<model::FieldValue>& value) {
  if (value && value->type() == FieldValue::Type::Array) {
    return value->array_value();
  } else {
    // coerce to empty array.
    return {};
  }
}

FieldValue ArrayTransform::Apply(
    const absl::optional<FieldValue>& previous_value) const {
  FieldValue::Array result =
      ArrayTransform::CoercedFieldValuesArray(previous_value);
  for (const FieldValue& element : elements_) {
    auto pos = absl::c_find(result, element);
    if (type_ == Type::ArrayUnion) {
      if (pos == result.end()) {
        result.push_back(element);
      }
    } else {
      HARD_ASSERT(type_ == Type::ArrayRemove);
      if (pos != result.end()) {
        result.erase(pos);
      }
    }
  }
  return FieldValue::FromArray(std::move(result));
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

double AsDouble(const FieldValue& value) {
  if (value.type() == FieldValue::Type::Double) {
    return value.double_value();
  } else if (value.type() == FieldValue::Type::Integer) {
    return value.integer_value();
  } else {
    HARD_FAIL("Expected 'operand' to be of numeric type, but was %s (type %s)",
              value.ToString(), value.type());
  }
}

}  // namespace

NumericIncrementTransform::NumericIncrementTransform(FieldValue operand)
    : operand_(operand) {
  HARD_ASSERT(FieldValue::IsNumber(operand.type()));
}

FieldValue NumericIncrementTransform::ApplyToLocalView(
    const absl::optional<FieldValue>& previous_value,
    const Timestamp& /* local_write_time */) const {
  absl::optional<FieldValue> base_value = ComputeBaseValue(previous_value);

  // Return an integer value only if the previous value and the operand is an
  // integer.
  if (base_value && base_value->type() == FieldValue::Type::Integer &&
      operand_.type() == FieldValue::Type::Integer) {
    int64_t sum =
        SafeIncrement(base_value->integer_value(), operand_.integer_value());
    return FieldValue::FromInteger(sum);
  } else {
    HARD_ASSERT(base_value && FieldValue::IsNumber(base_value->type()),
                "'base_value' is not of numeric type");
    double sum = AsDouble(*base_value) + AsDouble(operand_);
    return FieldValue::FromDouble(sum);
  }
}

FieldValue NumericIncrementTransform::ApplyToRemoteDocument(
    const absl::optional<FieldValue>&,
    const FieldValue& transform_result) const {
  return transform_result;
}

absl::optional<FieldValue> NumericIncrementTransform::ComputeBaseValue(
    const absl::optional<FieldValue>& previous_value) const {
  return previous_value && FieldValue::IsNumber(previous_value->type())
             ? previous_value
             : absl::optional<FieldValue>{FieldValue::FromInteger(0)};
}

bool NumericIncrementTransform::operator==(
    const TransformOperation& other) const {
  if (other.type() != type()) {
    return false;
  }
  auto numeric_add = static_cast<const NumericIncrementTransform&>(other);
  return operand_ == numeric_add.operand_;
}

size_t NumericIncrementTransform::Hash() const {
  return operand_.Hash();
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
