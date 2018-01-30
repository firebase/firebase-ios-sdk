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

#include "Firestore/core/src/firebase/firestore/model/timestamp.h"

#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(Timestamp, Getter) {
  const Timestamp timestamp_zero;
  EXPECT_EQ(0, timestamp_zero.seconds());
  EXPECT_EQ(0, timestamp_zero.nanos());

  const Timestamp timestamp(100, 200);
  EXPECT_EQ(100, timestamp.seconds());
  EXPECT_EQ(200, timestamp.nanos());

  const Timestamp timestamp_now = Timestamp::Now();
  EXPECT_LT(0, timestamp_now.seconds());
  EXPECT_LE(0, timestamp_now.nanos());
}

TEST(Timestamp, Comparison) {
  EXPECT_TRUE(Timestamp() < Timestamp(1, 2));
  EXPECT_TRUE(Timestamp(1, 2) < Timestamp(2, 1));
  EXPECT_TRUE(Timestamp(2, 1) < Timestamp(2, 2));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
