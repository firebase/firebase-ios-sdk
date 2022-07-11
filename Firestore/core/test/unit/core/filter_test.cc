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
using testutil::Filter;
using testutil::OrFilters;
using testutil::Resource;
using testutil::Value;

/** Helper method to get unique filters */
FieldFilter numberFilter(int num) {
  return Filter("name", "==", num);
}

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

TEST(FilterTest, AndFilters) {
  const FieldFilter Zero = numberFilter(0);
  const FieldFilter One = numberFilter(1);
  const FieldFilter Two = numberFilter(2);

  CompositeFilter andFilter = AndFilters({Zero, One, Two});
  ASSERT_TRUE(andFilter.IsConjunction());
  EXPECT_EQ(andFilter.filters().size(), 3);
  EXPECT_EQ(andFilter.filters()[0], Zero);
  EXPECT_EQ(andFilter.filters()[1], One);
  EXPECT_EQ(andFilter.filters()[2], Two);
}

TEST(FilterTest, OrFilters) {
  const FieldFilter Zero = numberFilter(0);
  const FieldFilter One = numberFilter(1);
  const FieldFilter Two = numberFilter(2);

  CompositeFilter orFilter = OrFilters({Zero, One, Two});
  ASSERT_TRUE(orFilter.IsDisjunction());
  EXPECT_EQ(orFilter.filters().size(), 3);
  EXPECT_EQ(orFilter.filters()[0], Zero);
  EXPECT_EQ(orFilter.filters()[1], One);
  EXPECT_EQ(orFilter.filters()[2], Two);
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
