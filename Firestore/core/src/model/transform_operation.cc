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

#include "Firestore/core/src/model/transform_operation.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <functional>
#include <memory>
#include <ostream>
#include <utility>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/model/server_timestamp_util.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/util/comparison.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/quadruple.h"
#include "Firestore/core/src/util/to_string.h"
#include "absl/algorithm/container.h"
#include "absl/strings/str_cat.h"

namespace firebase {
namespace firestore {
namespace model {

using nanopb::Message;
using Type = TransformOperation::Type;

// MARK: - TransformOperation

TransformOperation::TransformOperation(std::shared_ptr<const Rep> rep)
    : rep_(std::move(rep)) {
}

/** Returns whether the two are equal. */
bool operator==(const TransformOperation& lhs, const TransformOperation& rhs) {
  return lhs.rep_ == nullptr
             ? rhs.rep_ == nullptr
             : (rhs.rep_ != nullptr && lhs.rep_->Equals(*rhs.rep_));
}

std::ostream& operator<<(std::ostream& os, const TransformOperation& op) {
  return os << op.ToString();
}

// MARK: - ServerTimestampTransform

static_assert(sizeof(TransformOperation) == sizeof(ServerTimestampTransform),
              "No additional members allowed (everything must go in Rep)");

class ServerTimestampTransform::Rep : public TransformOperation::Rep {
 public:
  Type type() const override {
    return Type::ServerTimestamp;
  }

  Message<google_firestore_v1_Value> ApplyToLocalView(
      const absl::optional<google_firestore_v1_Value>& previous_value,
      const Timestamp& local_write_time) const override {
    return EncodeServerTimestamp(local_write_time, previous_value);
  }

  Message<google_firestore_v1_Value> ApplyToRemoteDocument(
      const absl::optional<google_firestore_v1_Value>&,
      Message<google_firestore_v1_Value> transform_result) const override {
    return transform_result;
  }

  absl::optional<nanopb::Message<google_firestore_v1_Value>> ComputeBaseValue(
      const absl::optional<google_firestore_v1_Value>&) const override {
    // Server timestamps are idempotent and don't require a base value.
    return absl::nullopt;
  }

  bool Equals(const TransformOperation::Rep& other) const override {
    // All ServerTimestampTransform objects are equal.
    return other.type() == Type::ServerTimestamp;
  }

  size_t Hash() const override {
    // An arbitrary number, since all instances are equal.
    return 37;
  }

  std::string ToString() const override {
    return "ServerTimestamp";
  }
};

ServerTimestampTransform::ServerTimestampTransform()
    : TransformOperation(std::make_shared<const Rep>()) {
}

// MARK: - ArrayTransform

static_assert(sizeof(TransformOperation) == sizeof(ArrayTransform),
              "No additional members allowed (everything must go in Rep)");

/**
 * Transforms an array via a union or remove operation (for convenience, we use
 * this class for both Type::ArrayUnion and Type::ArrayRemove).
 */
class ArrayTransform::Rep : public TransformOperation::Rep {
 public:
  Rep(Type type, Message<google_firestore_v1_ArrayValue> elements)
      : type_(type), elements_{std::move(elements)} {
  }

  Type type() const override {
    return type_;
  }

  Message<google_firestore_v1_Value> ApplyToLocalView(
      const absl::optional<google_firestore_v1_Value>& previous_value,
      const Timestamp&) const override {
    return Apply(previous_value);
  }

  Message<google_firestore_v1_Value> ApplyToRemoteDocument(
      const absl::optional<google_firestore_v1_Value>& previous_value,
      Message<google_firestore_v1_Value>) const override {
    // The server just sends null as the transform result for array operations,
    // so we have to calculate a result the same as we do for local
    // applications.
    return Apply(previous_value);
  }

  absl::optional<nanopb::Message<google_firestore_v1_Value>> ComputeBaseValue(
      const absl::optional<google_firestore_v1_Value>&) const override {
    // Array transforms are idempotent and don't require a base value.
    return absl::nullopt;
  }

  google_firestore_v1_ArrayValue elements() const {
    return *elements_;
  }

  bool Equals(const TransformOperation::Rep& other) const override;

  size_t Hash() const override;

  std::string ToString() const override;

 private:
  friend class ArrayTransform;

  /**
   * Inspects the provided value, returning a copy of the internal array if it's
   * of type Array and an empty array if it's nil or any other type of
   * google_firestore_v1_Value.
   */
  Message<google_firestore_v1_ArrayValue> CoercedFieldValueArray(
      const absl::optional<google_firestore_v1_Value>& value) const;

  Message<google_firestore_v1_Value> Apply(
      const absl::optional<google_firestore_v1_Value>& previous_value) const;

  Type type_;
  nanopb::Message<google_firestore_v1_ArrayValue> elements_;
};

namespace {

constexpr bool IsArrayTransform(Type type) {
  return type == Type::ArrayUnion || type == Type::ArrayRemove;
}

}  // namespace

ArrayTransform::ArrayTransform(Type type,
                               Message<google_firestore_v1_ArrayValue> elements)
    : TransformOperation(
          std::make_shared<const Rep>(type, std::move(elements))) {
  HARD_ASSERT(IsArrayTransform(type), "Expected array transform type; got %s",
              type);
}

ArrayTransform::ArrayTransform(const TransformOperation& op)
    : TransformOperation(op) {
  HARD_ASSERT(IsArrayTransform(op.type()),
              "Expected array transform type; got %s", op.type());
}

google_firestore_v1_ArrayValue ArrayTransform::elements() const {
  return *(array_rep().elements_);
}

const ArrayTransform::Rep& ArrayTransform::array_rep() const {
  return static_cast<const ArrayTransform::Rep&>(rep());
}

bool ArrayTransform::Rep::Equals(const TransformOperation::Rep& other) const {
  if (other.type() != type()) {
    return false;
  }
  auto& other_rep = static_cast<const ArrayTransform::Rep&>(other);
  if (other_rep.elements_->values_count != elements_->values_count) {
    return false;
  }
  for (pb_size_t i = 0; i < elements_->values_count; i++) {
    if (other_rep.elements_->values[i] != elements_->values[i]) {
      return false;
    }
  }
  return true;
}

size_t ArrayTransform::Rep::Hash() const {
  size_t result = 37;
  result = 31 * result + (type() == Type::ArrayUnion ? 1231 : 1237);
  for (size_t i = 0; i < elements_->values_count; i++) {
    result = 31 * result +
             std::hash<std::string>()(CanonicalId(elements_->values[i]));
  }
  return result;
}

std::string ArrayTransform::Rep::ToString() const {
  const char* name = type_ == Type::ArrayUnion ? "ArrayUnion" : "ArrayRemove";
  return absl::StrCat(name, "(", CanonicalId(*elements_), ")");
}

Message<google_firestore_v1_ArrayValue>
ArrayTransform::Rep::CoercedFieldValueArray(
    const absl::optional<google_firestore_v1_Value>& value) const {
  if (IsArray(value)) {
    return DeepClone(value->array_value);
  } else {
    // coerce to empty array.
    return {};
  }
}

Message<google_firestore_v1_Value> ArrayTransform::Rep::Apply(
    const absl::optional<google_firestore_v1_Value>& previous_value) const {
  Message<google_firestore_v1_ArrayValue> array_value =
      CoercedFieldValueArray(previous_value);
  if (type_ == Type::ArrayUnion) {
    // Gather the list of elements that have to be added.
    std::vector<Message<google_firestore_v1_Value>> new_elements;
    for (pb_size_t i = 0; i < elements_->values_count; ++i) {
      const google_firestore_v1_Value& new_element = elements_->values[i];
      if (!Contains(*array_value, new_element) &&
          !std::any_of(new_elements.begin(), new_elements.end(),
                       [&](const Message<google_firestore_v1_Value>& value) {
                         return *value == new_element;
                       })) {
        new_elements.push_back(DeepClone(new_element));
      }
    }

    // Append the elements to the end of the list
    size_t new_size = array_value->values_count + new_elements.size();
    array_value->values = nanopb::ResizeArray<google_firestore_v1_Value>(
        array_value->values, new_size);
    for (auto& element : new_elements) {
      array_value->values[array_value->values_count] = *element.release();
      ++array_value->values_count;
    }
  } else {
    HARD_ASSERT(type_ == Type::ArrayRemove);
    pb_size_t new_index = 0;
    for (pb_size_t old_index = 0; old_index < array_value->values_count;
         ++old_index) {
      if (Contains(*elements_, array_value->values[old_index])) {
        nanopb::FreeFieldsArray(&array_value->values[old_index]);
      } else {
        array_value->values[new_index] = array_value->values[old_index];
        ++new_index;
      }
    }
    array_value->values_count = new_index;
  }

  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_array_value_tag;
  result->array_value = *array_value.release();
  return result;
}

// MARK: - NumericTransform

static_assert(sizeof(TransformOperation) == sizeof(NumericTransform),
              "No additional members allowed (everything must go in Rep)");

namespace {

/**
 * Implements saturating integer addition. Overflows are resolved to
 * INT64_MAX/INT64_MIN.
 */
int64_t SafeIncrement(int64_t x, int64_t y) {
  if (x > 0 && y > INT64_MAX - x) {
    return INT64_MAX;
  }

  if (x < 0 && y < INT64_MIN - x) {
    return INT64_MIN;
  }

  return x + y;
}

/**
 * Implements saturating 32-bit integer addition. Overflows are resolved to
 * INT32_MAX/INT32_MIN.
 */
int32_t SafeIncrementInt32(int32_t x, int32_t y) {
  if (x > 0 && y > INT32_MAX - x) {
    return INT32_MAX;
  }

  if (x < 0 && y < INT32_MIN - x) {
    return INT32_MIN;
  }

  return x + y;
}

Message<google_firestore_v1_Value> MakeInt32Value(int32_t val) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value.fields_count = 1;
  result->map_value.fields =
      nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key =
      nanopb::MakeBytesArray(kRawInt32TypeFieldValue);
  result->map_value.fields[0].value.which_value_type =
      google_firestore_v1_Value_integer_value_tag;
  result->map_value.fields[0].value.integer_value = val;
  return result;
}

Message<google_firestore_v1_Value> MakeDecimal128Value(const std::string& str) {
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_map_value_tag;
  result->map_value.fields_count = 1;
  result->map_value.fields =
      nanopb::MakeArray<google_firestore_v1_MapValue_FieldsEntry>(1);
  result->map_value.fields[0].key =
      nanopb::MakeBytesArray(kRawDecimal128TypeFieldValue);
  result->map_value.fields[0].value.which_value_type =
      google_firestore_v1_Value_string_value_tag;
  result->map_value.fields[0].value.string_value = nanopb::MakeBytesArray(str);
  return result;
}

double ValueAsDouble(const google_firestore_v1_Value& value) {
  if (IsDouble(value)) {
    return value.double_value;
  } else if (IsInteger(value)) {
    return static_cast<double>(value.integer_value);
  } else if (IsInt32Value(value)) {
    return static_cast<double>(value.map_value.fields[0].value.integer_value);
  } else if (IsDecimal128Value(value)) {
    util::Quadruple q;
    std::string str =
        nanopb::MakeString(value.map_value.fields[0].value.string_value);
    HARD_ASSERT(q.Parse(str), "Failed to parse Decimal128 string: %s", str);
    return static_cast<double>(q);
  } else {
    HARD_FAIL("Expected value to be of numeric type, but was %s (type %s)",
              CanonicalId(value), GetTypeOrder(value));
  }
}

}  // namespace

class NumericTransform::Rep : public TransformOperation::Rep {
 public:
  explicit Rep(Message<google_firestore_v1_Value> operand)
      : operand_(std::move(operand)) {
  }

  Message<google_firestore_v1_Value> ApplyToRemoteDocument(
      const absl::optional<google_firestore_v1_Value>&,
      Message<google_firestore_v1_Value> transform_result) const override {
    return transform_result;
  }

  absl::optional<nanopb::Message<google_firestore_v1_Value>> ComputeBaseValue(
      const absl::optional<google_firestore_v1_Value>&) const override {
    return absl::nullopt;
  }

  double OperandAsDouble() const {
    return ValueAsDouble(*operand_);
  }

  bool Equals(const TransformOperation::Rep& other) const override {
    if (other.type() != type()) {
      return false;
    }
    return *operand_ ==
           static_cast<const NumericTransform::Rep&>(other).operand();
  }

  size_t Hash() const override {
    return std::hash<std::string>()(CanonicalId(*operand_));
  }

  const google_firestore_v1_Value& operand() const {
    return *operand_;
  }

 protected:
  Message<google_firestore_v1_Value> operand_{};
};

NumericTransform::NumericTransform(
    std::shared_ptr<const TransformOperation::Rep> rep)
    : TransformOperation(std::move(rep)) {
}

NumericTransform::NumericTransform(const TransformOperation& op)
    : TransformOperation(op) {
  HARD_ASSERT(op.type() == Type::Increment || op.type() == Type::Minimum ||
                  op.type() == Type::Maximum,
              "Expected numeric transform type; got %s", op.type());
}

const google_firestore_v1_Value& NumericTransform::operand() const {
  return static_cast<const Rep&>(rep()).operand();
}

// MARK: - NumericIncrementTransform

static_assert(sizeof(NumericTransform) == sizeof(NumericIncrementTransform),
              "No additional members allowed (everything must go in Rep)");

class NumericIncrementTransform::Rep : public NumericTransform::Rep {
 public:
  using NumericTransform::Rep::Rep;

  Type type() const override {
    return Type::Increment;
  }

  Message<google_firestore_v1_Value> ApplyToLocalView(
      const absl::optional<google_firestore_v1_Value>& previous_value,
      const Timestamp& local_write_time) const override;

  absl::optional<nanopb::Message<google_firestore_v1_Value>> ComputeBaseValue(
      const absl::optional<google_firestore_v1_Value>& previous_value)
      const override {
    if (IsNumber(previous_value)) {
      return DeepClone(*previous_value);
    }

    Message<google_firestore_v1_Value> zero_value;
    zero_value->which_value_type = google_firestore_v1_Value_integer_value_tag;
    zero_value->integer_value = 0;
    return zero_value;
  }

  std::string ToString() const override {
    return absl::StrCat("NumericIncrement(", operand_->ToString(), ")");
  }
};

NumericIncrementTransform::NumericIncrementTransform(
    Message<google_firestore_v1_Value> operand)
    : NumericTransform(std::make_shared<Rep>(std::move(operand))) {
  HARD_ASSERT(IsNumber(this->operand()));
}

NumericIncrementTransform::NumericIncrementTransform(
    const TransformOperation& op)
    : NumericTransform(op) {
  HARD_ASSERT(op.type() == Type::Increment, "Expected increment type; got %s",
              op.type());
}

// MARK: - NumericMinimumTransform

static_assert(sizeof(NumericTransform) == sizeof(NumericMinimumTransform),
              "No additional members allowed (everything must go in Rep)");

class NumericMinimumTransform::Rep : public NumericTransform::Rep {
 public:
  using NumericTransform::Rep::Rep;

  Type type() const override {
    return Type::Minimum;
  }

  Message<google_firestore_v1_Value> ApplyToLocalView(
      const absl::optional<google_firestore_v1_Value>& previous_value,
      const Timestamp& local_write_time) const override;

  std::string ToString() const override {
    return absl::StrCat("NumericMinimum(", operand_->ToString(), ")");
  }
};

NumericMinimumTransform::NumericMinimumTransform(
    Message<google_firestore_v1_Value> operand)
    : NumericTransform(std::make_shared<Rep>(std::move(operand))) {
  HARD_ASSERT(IsNumber(this->operand()));
}

NumericMinimumTransform::NumericMinimumTransform(const TransformOperation& op)
    : NumericTransform(op) {
  HARD_ASSERT(op.type() == Type::Minimum, "Expected minimum type; got %s",
              op.type());
}

// MARK: - NumericMaximumTransform

static_assert(sizeof(NumericTransform) == sizeof(NumericMaximumTransform),
              "No additional members allowed (everything must go in Rep)");

class NumericMaximumTransform::Rep : public NumericTransform::Rep {
 public:
  using NumericTransform::Rep::Rep;

  Type type() const override {
    return Type::Maximum;
  }

  Message<google_firestore_v1_Value> ApplyToLocalView(
      const absl::optional<google_firestore_v1_Value>& previous_value,
      const Timestamp& local_write_time) const override;

  std::string ToString() const override {
    return absl::StrCat("NumericMaximum(", operand_->ToString(), ")");
  }
};

NumericMaximumTransform::NumericMaximumTransform(
    Message<google_firestore_v1_Value> operand)
    : NumericTransform(std::make_shared<Rep>(std::move(operand))) {
  HARD_ASSERT(IsNumber(this->operand()));
}

NumericMaximumTransform::NumericMaximumTransform(const TransformOperation& op)
    : NumericTransform(op) {
  HARD_ASSERT(op.type() == Type::Maximum, "Expected maximum type; got %s",
              op.type());
}

Message<google_firestore_v1_Value>
NumericIncrementTransform::Rep::ApplyToLocalView(
    const absl::optional<google_firestore_v1_Value>& previous_value,
    const Timestamp& /* local_write_time */) const {
  auto base_value = ComputeBaseValue(previous_value);
  HARD_ASSERT(base_value.has_value() && IsNumber(**base_value),
              "'base_value' is not of numeric type");

  // If either base_value or operand is Decimal128, the result is Decimal128.
  if (IsDecimal128Value(**base_value) || IsDecimal128Value(*operand_)) {
    // Local evaluation is an IEEE 754 64-bit double approximation for latency
    // compensation before server acknowledgment.
    double sum = ValueAsDouble(**base_value) + OperandAsDouble();
    std::string sum_str;
    if (std::isnan(sum)) {
      sum_str = "NaN";
    } else if (std::isinf(sum)) {
      sum_str = sum < 0 ? "-Infinity" : "Infinity";
    } else {
      sum_str = absl::StrCat(sum);
    }
    return MakeDecimal128Value(sum_str);
  }

  // If base_value is Int32:
  if (IsInt32Value(**base_value)) {
    int32_t base_int32 = static_cast<int32_t>(
        (*base_value)->map_value.fields[0].value.integer_value);
    if (IsDouble(*operand_)) {
      Message<google_firestore_v1_Value> result;
      result->which_value_type = google_firestore_v1_Value_double_value_tag;
      result->double_value =
          static_cast<double>(base_int32) + operand_->double_value;
      return result;
    } else if (IsInteger(*operand_)) {
      Message<google_firestore_v1_Value> result;
      result->which_value_type = google_firestore_v1_Value_integer_value_tag;
      result->integer_value =
          SafeIncrement(base_int32, operand_->integer_value);
      return result;
    } else {
      int32_t operand_int32 = static_cast<int32_t>(
          operand_->map_value.fields[0].value.integer_value);
      return MakeInt32Value(SafeIncrementInt32(base_int32, operand_int32));
    }
  }

  // If base_value is Integer:
  if (IsInteger(**base_value)) {
    int64_t base_int64 = (*base_value)->integer_value;
    if (IsInteger(*operand_)) {
      Message<google_firestore_v1_Value> result;
      result->which_value_type = google_firestore_v1_Value_integer_value_tag;
      result->integer_value =
          SafeIncrement(base_int64, operand_->integer_value);
      return result;
    } else if (IsInt32Value(*operand_)) {
      int32_t operand_int32 = static_cast<int32_t>(
          operand_->map_value.fields[0].value.integer_value);
      Message<google_firestore_v1_Value> result;
      result->which_value_type = google_firestore_v1_Value_integer_value_tag;
      result->integer_value = SafeIncrement(base_int64, operand_int32);
      return result;
    } else {
      Message<google_firestore_v1_Value> result;
      result->which_value_type = google_firestore_v1_Value_double_value_tag;
      result->double_value =
          static_cast<double>(base_int64) + operand_->double_value;
      return result;
    }
  }

  HARD_ASSERT(IsDouble(**base_value), "'base_value' is not of numeric type");
  Message<google_firestore_v1_Value> result;
  result->which_value_type = google_firestore_v1_Value_double_value_tag;
  result->double_value = (*base_value)->double_value + OperandAsDouble();
  return result;
}

Message<google_firestore_v1_Value>
NumericMinimumTransform::Rep::ApplyToLocalView(
    const absl::optional<google_firestore_v1_Value>& previous_value,
    const Timestamp& /* local_write_time */) const {
  if (!IsNumber(previous_value)) {
    return DeepClone(*operand_);
  }
  util::ComparisonResult cmp = CompareNumbers(*operand_, *previous_value);
  if (cmp == util::ComparisonResult::Ascending) {
    return DeepClone(*operand_);
  }
  return DeepClone(*previous_value);
}

Message<google_firestore_v1_Value>
NumericMaximumTransform::Rep::ApplyToLocalView(
    const absl::optional<google_firestore_v1_Value>& previous_value,
    const Timestamp& /* local_write_time */) const {
  if (!IsNumber(previous_value)) {
    return DeepClone(*operand_);
  }
  util::ComparisonResult cmp = CompareNumbers(*operand_, *previous_value);
  if (cmp == util::ComparisonResult::Descending) {
    return DeepClone(*operand_);
  }
  return DeepClone(*previous_value);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
