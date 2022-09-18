/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/core/target.h"

#include <cmath>

#include "Firestore/core/src/core/bound.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/value_util.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

namespace {

using core::Bound;
using firebase::firestore::util::ComparisonResult;
using model::CanonicalId;
using model::DocumentComparator;
using model::Equals;
using model::FieldIndex;
using model::FieldPath;
using model::MutableDocument;
using model::Segment;
using nanopb::MakeSharedMessage;

using testing::AssertionResult;
using testing::Not;
using testutil::Array;
using testutil::BlobValue;
using testutil::CollectionGroupQuery;
using testutil::DbId;
using testutil::Doc;
using testutil::Field;
using testutil::Filter;
using testutil::MakeFieldIndex;
using testutil::Map;
using testutil::OrderBy;
using testutil::Query;
using testutil::Ref;
using testutil::Value;
using testutil::Vector;

void VerifyBound(const absl::optional<IndexBoundValues>& bound,
                 bool inclusive,
                 const std::vector<google_firestore_v1_Value>& values) {
  ASSERT_TRUE(bound.has_value());
  EXPECT_EQ(inclusive, bound.value().inclusive);
  EXPECT_EQ(values.size(), bound.value().values.size());
  for (size_t i = 0; i < values.size(); ++i) {
    const auto& expected_value = values[i];
    EXPECT_TRUE(Equals(expected_value, bound.value().values[i]))
        << "Values should be equal: Expected: " << CanonicalId(expected_value)
        << ", Actual: " << CanonicalId(bound.value().values[i]) << "";
  }
}

TEST(TargetTest, EmptyQueryBound) {
  Target target = testutil::Query("c").ToTarget();
  FieldIndex index = MakeFieldIndex("c");

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {});
}

TEST(TargetTest, EqualsQueryBound) {
  Target target =
      Query("c").AddingFilter(Filter("foo", "==", "bar")).ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value("bar")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {*Value("bar")});
}

TEST(TargetTest, LessThanQueryBound) {
  Target target = Query("c").AddingFilter(Filter("foo", "<", "bar")).ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kDescending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, false, {*Value("bar")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {*Value("")});
}

TEST(TargetTest, LessThanOrEqualsQueryBound) {
  Target target =
      Query("c").AddingFilter(Filter("foo", "<=", "bar")).ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value("")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {*Value("bar")});
}

TEST(TargetTest, GreaterThanQueryBound) {
  Target target = Query("c").AddingFilter(Filter("foo", ">", "bar")).ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, false, {*Value("bar")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, false, {*BlobValue()});
}

TEST(TargetTest, GreaterThanOrEqualsQueryBound) {
  Target target =
      Query("c").AddingFilter(Filter("foo", ">=", "bar")).ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kDescending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, false, {*BlobValue()});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {*Value("bar")});
}

TEST(TargetTest, ArrayContainsQueryBound) {
  Target target = Query("c")
                      .AddingFilter(Filter("foo", "array-contains", "bar"))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kContains);

  auto array_values = target.GetArrayValues(index);
  EXPECT_TRUE(array_values.has_value());
  EXPECT_EQ(array_values.value().size(), 1);
  EXPECT_TRUE(Equals(array_values.value()[0], *Value("bar")));

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {});
}

TEST(TargetTest, ArrayContainsAnyQueryBound) {
  Target target = Query("c")
                      .AddingFilter(Filter("foo", "array-contains-any",
                                           Array("bar", "baz")))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kContains);

  auto array_values = target.GetArrayValues(index);
  ASSERT_EQ(array_values.value().size(), 2);
  EXPECT_TRUE(Equals(array_values.value()[0], *Value("bar")));
  EXPECT_TRUE(Equals(array_values.value()[1], *Value("baz")));

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {});
  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {});
}

TEST(TargetTest, OrderByQueryBound) {
  Target target = Query("c").AddingOrderBy(OrderBy("foo")).ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kAscending);
  auto lower_bound = target.GetLowerBound(index);
  EXPECT_EQ(lower_bound.values[0], model::MinValue());
  EXPECT_TRUE(lower_bound.inclusive);

  auto upper_bound = target.GetUpperBound(index);
  EXPECT_EQ(upper_bound.values[0], model::MaxValue());
  EXPECT_TRUE(upper_bound.inclusive);
}

TEST(TargetTest, FilterWithOrderByQueryBound) {
  Target target = Query("c")
                      .AddingFilter(Filter("foo", ">", "bar"))
                      .AddingOrderBy(OrderBy("foo"))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, false, {*Value("bar")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, false, {*BlobValue()});
}

TEST(TargetTest, StartingAtQueryBound) {
  Target target = Query("c")
                      .AddingOrderBy(OrderBy("foo"))
                      .StartingAt(Bound::FromValue(Array(Value("bar")), true))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value("bar")});

  auto upper_bound = target.GetUpperBound(index);
  EXPECT_EQ(upper_bound.values[0], model::MaxValue());
  EXPECT_TRUE(upper_bound.inclusive);
}

TEST(TargetTest, StartingAtWithFilterQueryBound) {
  // Tests that the StartingAt and the filter get merged to form a narrow bound
  Target target =
      Query("c")
          .AddingFilter(Filter("a", ">=", "a1"))
          .AddingFilter(Filter("b", "==", "b1"))
          .AddingOrderBy(OrderBy("a"))
          .AddingOrderBy(OrderBy("b"))
          .StartingAt(Bound::FromValue(Array(Value("a1"), Value("b1")), true))
          .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "a", Segment::Kind::kAscending, "b",
                                    Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value("a1"), *Value("b1")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, false, {*BlobValue(), *Value("b1")});
}

TEST(TargetTest, StartAfterWithFilterQueryBound) {
  Target target = Query("c")
                      .AddingFilter(Filter("a", ">=", "a1"))
                      .AddingFilter(Filter("b", "==", "b1"))
                      .AddingOrderBy(OrderBy("a"))
                      .AddingOrderBy(OrderBy("b"))
                      .StartingAt(Bound::FromValue(Array("a2", "b1"), false))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "a", Segment::Kind::kAscending, "b",
                                    Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, false, {*Value("a2"), *Value("b1")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, false, {*BlobValue(), *Value("b1")});
}

TEST(TargetTest, StartAfterDoesNotChangeBoundIfNotApplicable) {
  Target target = Query("c")
                      .AddingFilter(Filter("a", ">=", "a2"))
                      .AddingFilter(Filter("b", "==", "b2"))
                      .AddingOrderBy(OrderBy("a"))
                      .AddingOrderBy(OrderBy("b"))
                      .StartingAt(Bound::FromValue(Array("a1", "b1"), false))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "a", Segment::Kind::kAscending, "b",
                                    Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value("a2"), *Value("b2")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, false, {*BlobValue(), *Value("b2")});
}

TEST(TargetTest, EndingAtQueryBound) {
  Target target = Query("c")
                      .AddingOrderBy(OrderBy("foo"))
                      .EndingAt(Bound::FromValue(Array("bar"), true))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "foo", Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  ASSERT_EQ(lower_bound.values[0], model::MinValue());
  ASSERT_TRUE(lower_bound.inclusive);

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {*Value("bar")});
}

TEST(TargetTest, EndingAtWithFilterQueryBound) {
  // Tests that the EndingAt and the filter get merged to form a narrow bound
  Target target = Query("c")
                      .AddingFilter(Filter("a", "<=", "a2"))
                      .AddingFilter(Filter("b", "==", "b2"))
                      .AddingOrderBy(OrderBy("a"))
                      .AddingOrderBy(OrderBy("b"))
                      .EndingAt(Bound::FromValue(Array("a1", "b1"), true))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "a", Segment::Kind::kAscending, "b",
                                    Segment::Kind::kAscending);

  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value(""), *Value("b2")});

  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {*Value("a1"), *Value("b1")});
}

TEST(TargetTest, EndBeforeWithFilterQueryBound) {
  Target target = Query("c")
                      .AddingFilter(Filter("a", "<=", "a2"))
                      .AddingFilter(Filter("b", "==", "b2"))
                      .AddingOrderBy(OrderBy("a"))
                      .AddingOrderBy(OrderBy("b"))
                      .EndingAt(Bound::FromValue(Array("a1", "b1"), false))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "a", Segment::Kind::kAscending, "b",
                                    Segment::Kind::kAscending);
  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value(""), *Value("b2")});
  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, false, {*Value("a1"), *Value("b1")});
}

TEST(TargetTest, EndBeforeDoesNotChangeBoundIfNotApplicable) {
  Target target = Query("c")
                      .AddingFilter(Filter("a", "<=", "a1"))
                      .AddingFilter(Filter("b", "==", "b1"))
                      .AddingOrderBy(OrderBy("a"))
                      .AddingOrderBy(OrderBy("b"))
                      .EndingAt(Bound::FromValue(Array("a2", "b2"), false))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "a", Segment::Kind::kAscending, "b",
                                    Segment::Kind::kAscending);
  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value(""), *Value("b1")});
  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {*Value("a1"), *Value("b1")});
}

TEST(TargetTest, PartialIndexMatchQueryBound) {
  Target target = Query("c")
                      .AddingFilter(Filter("a", "==", "a"))
                      .AddingFilter(Filter("b", "==", "b"))
                      .ToTarget();
  FieldIndex index = MakeFieldIndex("c", "a", Segment::Kind::kAscending);
  auto lower_bound = target.GetLowerBound(index);
  VerifyBound(lower_bound, true, {*Value("a")});
  auto upper_bound = target.GetUpperBound(index);
  VerifyBound(upper_bound, true, {*Value("a")});
}

}  // namespace
}  // namespace core
}  // namespace firestore
}  // namespace firebase
