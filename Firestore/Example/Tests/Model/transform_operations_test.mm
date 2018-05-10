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

#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

class DummyOperation : public TransformOperation {
 public:
  DummyOperation() {
  }

  Type type() const override {
    return Type::Test;
  }

  FSTFieldValue* ApplyToLocalView(FSTFieldValue* /* previousValue */,
                                  FIRTimestamp* /* localWriteTime */) const override {
    return nil;
  }

  FSTFieldValue* ApplyToRemoteDocument(FSTFieldValue* /* previousValue */,
                                       FSTFieldValue* /* transformResult */) const override {
    return nil;
  }

  bool operator==(const TransformOperation& other) const override {
    return this == &other;
  }

  NSUInteger Hash() const override {
    // arbitrary number, the same as used in ObjC implementation, since all
    // instances are equal.
    return 37;
  }
};

TEST(TransformOperations, ServerTimestamp) {
  ServerTimestampTransform transform = ServerTimestampTransform::Get();
  EXPECT_EQ(TransformOperation::Type::ServerTimestamp, transform.type());

  ServerTimestampTransform another = ServerTimestampTransform::Get();
  DummyOperation dummy;
  EXPECT_EQ(transform, another);
  EXPECT_NE(transform, dummy);
}

// TODO(mikelehen): Add ArrayTransform test once it no longer depends on
// FSTFieldValue and can be exposed to C++ code.

}  // namespace model
}  // namespace firestore
}  // namespace firebase
