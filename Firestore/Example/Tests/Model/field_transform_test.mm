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

#include "Firestore/core/src/firebase/firestore/model/field_transform.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operations.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(FieldTransform, Getter) {
  FieldTransform transform(testutil::Field("foo"),
                           absl::make_unique<ServerTimestampTransform>(
                               ServerTimestampTransform::Get()));

  EXPECT_EQ(testutil::Field("foo"), transform.path());
  EXPECT_EQ(ServerTimestampTransform::Get(), transform.transformation());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
