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

#if defined(__OBJC__)
#import "Firestore/Source/Model/FSTFieldValue.h"
#endif

namespace firebase {
namespace firestore {
namespace model {

// TODO(zxu123): We might want to refactor transform_operations.h into several
// files when the number of different types of operations grows gigantically.
// For now, put the interface and the only operation here.

/** Represents a transform within a TransformMutation. */
class TransformOperation {
 public:
  /** All the different kinds to TransformOperation. */
  enum class Type {
    ServerTimestamp,
    ArrayUnion,
    ArrayRemove,
    Test,  // Purely for test purpose.
  };

  virtual ~TransformOperation() {
  }

  /** Returns the actual type. */
  virtual Type type() const = 0;

  /** Returns whether the two are equal. */
  virtual bool operator==(const TransformOperation& other) const = 0;

  /** Returns whether the two are not equal. */
  bool operator!=(const TransformOperation& other) const {
    return !operator==(other);
  }

#if defined(__OBJC__)
  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  virtual NSUInteger Hash() const = 0;
#endif  // defined(__OBJC__)
};

/** Transforms a value into a server-generated timestamp. */
class ServerTimestampTransform : public TransformOperation {
 public:
  ~ServerTimestampTransform() override {
  }

  Type type() const override {
    return Type::ServerTimestamp;
  }

  bool operator==(const TransformOperation& other) const override {
    // All ServerTimestampTransform objects are equal.
    return other.type() == Type::ServerTimestamp;
  }

  static const ServerTimestampTransform& Get() {
    static ServerTimestampTransform shared_instance;
    return shared_instance;
  }

#if defined(__OBJC__)
  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  NSUInteger Hash() const override {
    // arbitrary number, the same as used in ObjC implementation, since all
    // instances are equal.
    return 37;
  }
#endif  // defined(__OBJC__)

 private:
  ServerTimestampTransform() {
  }
};

// TODO(mikelehen): ArrayTransform can only be used from Obj-C until we switch
// to using FieldValue instead of FSTFieldValue.
#if defined(__OBJC__)
/**
 * Transforms an array via a union or remove operation (for convenience, we use
 * this class for both Type::ArrayUnion and Type::ArrayRemove).
 */
class ArrayTransform : public TransformOperation {
 public:
  ArrayTransform(Type type, std::vector<FSTFieldValue*> elements)
      : type_(type), elements_(std::move(elements)) {
  }

  ~ArrayTransform() override {
  }

  Type type() const override {
    return type_;
  }

  const std::vector<FSTFieldValue*>& elements() const {
    return elements_;
  }

  bool operator==(const TransformOperation& other) const override {
    if (other.type() != type()) {
      return false;
    }
    auto array_transform = static_cast<const ArrayTransform&>(other);
    if (array_transform.elements_.size() != elements_.size()) {
      return false;
    }
    for (int i = 0; i < elements_.size(); i++) {
      if (![array_transform.elements_[i] isEqual:elements_[i]]) {
        return false;
      }
    }
    return true;
  }

#if defined(__OBJC__)
  // For Objective-C++ hash; to be removed after migration.
  // Do NOT use in C++ code.
  NSUInteger Hash() const override {
    NSUInteger result = 37;
    result = 31 * result + (type() == Type::ArrayUnion ? 1231 : 1237);
    for (FSTFieldValue* element : elements_) {
      result = 31 * result + [element hash];
    }
    return result;
  }
#endif  // defined(__OBJC__)

  static const std::vector<FSTFieldValue*>& Elements(
      const TransformOperation& op) {
    FIREBASE_ASSERT(op.type() == Type::ArrayUnion ||
                    op.type() == Type::ArrayRemove);
    return static_cast<const ArrayTransform&>(op).elements();
  }

 private:
  Type type_;
  std::vector<FSTFieldValue*> elements_;
};
#endif

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_TRANSFORM_OPERATIONS_H_
