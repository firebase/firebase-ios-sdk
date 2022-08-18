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

#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/core/composite_filter.h"
#include "Firestore/core/src/core/field_filter.h"

#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using testutil::AndFilters;
using testutil::Field;
using testutil::OrFilters;
using testutil::Resource;
using testutil::Value;

namespace {

/** Helper method to get unique filters */
FieldFilter NameFilter(const char* name) {
  return testutil::Filter("name", "==", name);
}

const FieldFilter A = NameFilter("A");
const FieldFilter B = NameFilter("B");
const FieldFilter C = NameFilter("C");
const FieldFilter D = NameFilter("D");

}  // namespace

TEST(FilterTest, Equality) {
  auto filter = testutil::Filter("f", "==", 1);
  EXPECT_EQ(filter, testutil::Filter("f", "==", 1));
  EXPECT_NE(filter, testutil::Filter("g", "==", 1));
  EXPECT_NE(filter, testutil::Filter("f", ">", 1));
  EXPECT_NE(filter, testutil::Filter("f", "==", 2));
  EXPECT_NE(filter, testutil::Filter("f", "==", NAN));
  EXPECT_NE(filter, testutil::Filter("f", "==", nullptr));

  auto null_filter = testutil::Filter("g", "==", nullptr);
  EXPECT_EQ(null_filter, testutil::Filter("g", "==", nullptr));
  EXPECT_NE(null_filter, testutil::Filter("h", "==", nullptr));

  auto nan_filter = testutil::Filter("g", "==", NAN);
  EXPECT_EQ(nan_filter, testutil::Filter("g", "==", NAN));
  EXPECT_NE(nan_filter, testutil::Filter("h", "==", NAN));
}

TEST(FilterTest, CompositeFilterMembers) {
  CompositeFilter and_filter = AndFilters({A, B, C});
  EXPECT_TRUE(and_filter.IsConjunction());
  std::vector<core::Filter> expect{A, B, C};
  EXPECT_EQ(and_filter.filters(), expect);

  CompositeFilter or_filter = OrFilters({A, B, C});
  EXPECT_TRUE(or_filter.IsDisjunction());
  EXPECT_EQ(or_filter.filters(), expect);
}

TEST(FilterTest, CompositeFilterNestedChecks) {
  CompositeFilter and_filter1 = AndFilters({A, B, C});
  EXPECT_TRUE(and_filter1.IsConjunction());
  EXPECT_FALSE(and_filter1.IsDisjunction());

  CompositeFilter or_filter1 = OrFilters({A, B, C});
  EXPECT_FALSE(or_filter1.IsConjunction());
  EXPECT_TRUE(or_filter1.IsDisjunction());

  CompositeFilter and_filter2 = AndFilters({D, and_filter1});
  EXPECT_TRUE(and_filter2.IsConjunction());
  EXPECT_FALSE(and_filter2.IsDisjunction());

  CompositeFilter or_filter2 = OrFilters({D, and_filter1});
  EXPECT_FALSE(or_filter2.IsConjunction());
  EXPECT_TRUE(or_filter2.IsDisjunction());
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
