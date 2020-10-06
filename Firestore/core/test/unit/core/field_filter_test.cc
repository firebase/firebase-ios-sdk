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

#include "Firestore/core/src/core/field_filter.h"

#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using testutil::Field;
using testutil::Filter;
using testutil::Resource;
using testutil::Value;

TEST(FilterTest, Equality) {
  auto filter = Filter("f", "==", 1);
  EXPECT_EQ(filter, Filter("f", "==", 1));
  EXPECT_NE(filter, Filter("g", "==", 1));
  EXPECT_NE(filter, Filter("f", ">", 1));
  EXPECT_NE(filter, Filter("f", "==", 2));
  EXPECT_NE(filter, Filter("f", "==", NAN));
  EXPECT_NE(filter, Filter("f", "==", nullptr));

  auto null_filter = Filter("g", "==", nullptr);
  EXPECT_EQ(null_filter, Filter("g", "==", nullptr));
  EXPECT_NE(null_filter, Filter("h", "==", nullptr));

  auto nan_filter = Filter("g", "==", NAN);
  EXPECT_EQ(nan_filter, Filter("g", "==", NAN));
  EXPECT_NE(nan_filter, Filter("h", "==", NAN));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
