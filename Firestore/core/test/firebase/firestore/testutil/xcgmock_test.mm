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

#include "Firestore/core/test/firebase/firestore/testutil/xcgmock.h"

#import "Firestore/Source/Core/FSTQuery.h"

#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace testutil {

TEST(XcGmockTest, NSArrayPrints) {
  std::string expected = util::ToString(@[ @"value" ]);

  EXPECT_EQ(expected, testing::PrintToString(@[ @"value" ]));
}

TEST(XcGmockTest, NSNumberPrints) {
  EXPECT_EQ("1", testing::PrintToString(@1));
}

// TODO(wilhuff): make this actually work!
// For whatever reason, this prints like a pointer.
TEST(XcGmockTest, DISABLED_NSStringPrints) {
  EXPECT_EQ("value", testing::PrintToString(@"value"));
}

TEST(XcGmockTest, FSTNullFilterPrints) {
  FSTNullFilter* filter =
      [[FSTNullFilter alloc] initWithField:model::FieldPath({"field"})];
  EXPECT_EQ("field IS NULL", testing::PrintToString(filter));
}

TEST(XcGmockTest, StatusPrints) {
  util::Status status(FirestoreErrorCode::NotFound, "missing foo");
  EXPECT_EQ("Not found: missing foo", testing::PrintToString(status));
}

TEST(XcGmockTest, TimestampPrints) {
  Timestamp timestamp(32, 42);
  EXPECT_EQ("Timestamp(seconds=32, nanoseconds=42)",
            testing::PrintToString(timestamp));
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
