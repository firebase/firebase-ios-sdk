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

#include "Firestore/core/include/firebase/firestore/blob.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

TEST(Blob, Getter) {
  const Blob& blob = Blob::FromAllocation("\1\2\3", 3);
  const char* buffer = static_cast<const char*>(blob.get());
  EXPECT_EQ(1, buffer[0]);
  EXPECT_EQ(2, buffer[1]);
  EXPECT_EQ(3, buffer[2]);
  // Just do a naive comparison and let compiler auto-cast the integer type.
  EXPECT_TRUE(3 == blob.size());
}

TEST(Blob, Comparison) {
  EXPECT_TRUE(Blob::FromAllocation("\1\2", 2) < Blob::FromAllocation("\1\2\3", 3));
  EXPECT_TRUE(Blob::FromAllocation("\1\2\3", 3) < Blob::FromAllocation("\1\4", 2));
}

}  // namespace firestore
}  // namespace firebase
