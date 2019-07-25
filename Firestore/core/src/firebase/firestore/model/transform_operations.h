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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_TRANSFORM_OPERATIONS_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_TRANSFORM_OPERATIONS_H_

#include <utility>
#include <vector>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace model {

/** Represents a transform within a TransformMutation. */
class TransformOperation {
 public:
  /** All the different kinds to TransformOperation. */
  enum class Type {
    ServerTimestamp,
    ArrayUnion,
    ArrayRemove,
    Increment,
    Test,  // Purely for test purpose.
  };

  virtual ~TransformOperation() {
  }

  /** Returns the actual type. */
  virtual Type type() const = 0;

  /**
   * Computes the local transform result against the provided `previous_value`,
   * optionally using the provided local_write_time.
   */
  virtual model::FieldValue ApplyToLocalView(
      const absl::optional<model::FieldValue>& previous_value,
      const Timestamp& local_write_time) const = 0;

  /**
   * Computes a final transform result after the transform has been acknowledged
   * by the server, potentially using the server-provided transform_result.
   */
  virtual model::FieldValue ApplyToRemoteDocument(
      const absl::optional<model::FieldValue>& previous_value,
      const model::FieldValue& transform_result) const = 0;

  /**
   * If this transform operation is not idempotent, returns the base value to
   * persist for this transform operation. If a base value is returned, the
   * transform operation is always applied to this base value, even if document
   * has already been updated.
   *
   * <p>Base values provide consistent behavior for non-idempotent transforms
   * and allow us to return the same latency-compensated value even if the
   * backend has already applied the transform operation. The base value is
   * empty for idempotent transforms, as they can be re-played even if the
   * backend has already applied them.
   *
   * @return a base value to store along with the mutation, or empty for
   * idempotent transforms.
   */
  virtual absl::optional<model::FieldValue> ComputeBaseValue(
      const absl::optional<model::FieldValue>& previous_value) const = 0;

  /** Returns whether the two are equal. */
  virtual bool operator==(const TransformOperation& other) const = 0;

  /** Returns whether the two are not equal. */
  bool operator!=(const TransformOperation& other) const {
    return !operator==(other);
  }

  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  virtual size_t Hash() const = 0;
};

/** Transforms a value into a server-generated timestamp. */
class ServerTimestampTransform : public TransformOperation {
 public:
  Type type() const override {
    return Type::ServerTimestamp;
  }

  model::FieldValue ApplyToLocalView(
      const absl::optional<model::FieldValue>& previous_value,
      const Timestamp& local_write_time) const override;

  model::FieldValue ApplyToRemoteDocument(
      const absl::optional<model::FieldValue>& previous_value,
      const model::FieldValue& transform_result) const override;

  absl::optional<model::FieldValue> ComputeBaseValue(
      const absl::optional<model::FieldValue>& /* previous_value */)
      const override {
    return absl::nullopt;  // Server timestamps are idempotent and don't require
                           // a base value.
  }

  bool operator==(const TransformOperation& other) const override;

  static const ServerTimestampTransform& Get();

  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  size_t Hash() const override;

 private:
  ServerTimestampTransform() = default;
};

/**
 * Transforms an array via a union or remove operation (for convenience, we use
 * this class for both Type::ArrayUnion and Type::ArrayRemove).
 */
class ArrayTransform : public TransformOperation {
 public:
  ArrayTransform(Type type, std::vector<model::FieldValue> elements)
      : type_(type), elements_(std::move(elements)) {
  }

  Type type() const override {
    return type_;
  }

  model::FieldValue ApplyToLocalView(
      const absl::optional<model::FieldValue>& previous_value,
      const Timestamp& local_write_time) const override;

  model::FieldValue ApplyToRemoteDocument(
      const absl::optional<model::FieldValue>& previous_value,
      const model::FieldValue& transform_result) const override;

  absl::optional<model::FieldValue> ComputeBaseValue(
      const absl::optional<model::FieldValue>& /* previous_value */)
      const override {
    return absl::nullopt;  // Array transforms are idempotent and don't require
                           // a base value.
  }

  const std::vector<model::FieldValue>& elements() const {
    return elements_;
  }

  bool operator==(const TransformOperation& other) const override;

  size_t Hash() const override;

  static const std::vector<model::FieldValue>& Elements(
      const TransformOperation& op);

 private:
  /**
   * Inspects the provided value, returning a mutable copy of the internal array
   * if it's of type Array and an empty mutable array if it's nil or any other
   * type of FieldValue.
   */
  static std::vector<model::FieldValue> CoercedFieldValuesArray(
      const absl::optional<model::FieldValue>& value);

  model::FieldValue Apply(
      const absl::optional<model::FieldValue>& previous_value) const;

  Type type_;
  std::vector<model::FieldValue> elements_;
};

/**
 * Implements the backend semantics for locally computed NUMERIC_ADD (increment)
 * transforms. Converts all field values to longs or doubles and resolves
 * overflows to LONG_MAX/LONG_MIN.
 */
class NumericIncrementTransform : public TransformOperation {
 public:
  explicit NumericIncrementTransform(model::FieldValue operand);

  Type type() const override {
    return Type::Increment;
  }

  model::FieldValue ApplyToLocalView(
      const absl::optional<model::FieldValue>& previous_value,
      const Timestamp& local_write_time) const override;

  model::FieldValue ApplyToRemoteDocument(
      const absl::optional<model::FieldValue>& previous_value,
      const model::FieldValue& transform_result) const override;

  absl::optional<model::FieldValue> ComputeBaseValue(
      const absl::optional<model::FieldValue>& previous_value) const override;

  model::FieldValue operand() const {
    return operand_;
  }

  bool operator==(const TransformOperation& other) const override;

  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  size_t Hash() const override;

 private:
  model::FieldValue operand_;
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_TRANSFORM_OPERATIONS_H_
