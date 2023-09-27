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

#include "Firestore/core/src/model/target_index_matcher.h"

#include <string>
#include <vector>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {
namespace {

using testutil::Array;
using testutil::Field;
using testutil::Filter;
using testutil::MakeFieldIndex;
using testutil::OrderBy;

std::vector<core::Query> QueriesWithEqualities() {
  return {
      testutil::Query("collId").AddingFilter(Filter("a", "==", "a")),
      testutil::Query("collId").AddingFilter(Filter("a", "in", Array("a")))};
}

std::vector<core::Query> QueriesWithInequalities() {
  return {testutil::Query("collId").AddingFilter(Filter("a", "<", "a")),
          testutil::Query("collId").AddingFilter(Filter("a", "<=", "a")),
          testutil::Query("collId").AddingFilter(Filter("a", ">", "a")),
          testutil::Query("collId").AddingFilter(Filter("a", ">=", "a")),
          testutil::Query("collId").AddingFilter(Filter("a", "!=", "a")),
          testutil::Query("collId").AddingFilter(
              Filter("a", "not-in", Array("a")))};
}

std::vector<core::Query> QueriesWithArrayContains() {
  return {testutil::Query("collId").AddingFilter(
              Filter("a", "array-contains", "a")),
          testutil::Query("collId").AddingFilter(
              Filter("a", "array-contains-any", Array("a")))};
}

std::vector<core::Query> QueriesWithOrderBys() {
  return {testutil::Query("collId").AddingOrderBy(OrderBy("a")),
          testutil::Query("collId").AddingOrderBy(OrderBy("a", "desc")),
          testutil::Query("collId").AddingOrderBy(OrderBy("a", "asc")),
          testutil::Query("collId")
              .AddingOrderBy(OrderBy("a"))
              .AddingOrderBy(OrderBy("__name__")),
          testutil::Query("collId")
              .AddingFilter(Filter("a", "array-contains", "a"))
              .AddingOrderBy(OrderBy("b"))};
}

void ValidateServesTarget(const core::Query& query,
                          const std::string& field,
                          Segment::Kind kind) {
  FieldIndex expected_index = MakeFieldIndex("collId", field, kind);
  TargetIndexMatcher matcher(query.ToTarget());
  EXPECT_TRUE(matcher.ServedByIndex(expected_index));
}

void ValidateServesTarget(const core::Query& query,
                          const std::string& field1,
                          Segment::Kind kind1,
                          const std::string& field2,
                          Segment::Kind kind2) {
  FieldIndex expected_index =
      MakeFieldIndex("collId", field1, kind1, field2, kind2);
  TargetIndexMatcher matcher(query.ToTarget());
  EXPECT_TRUE(matcher.ServedByIndex(expected_index));
}

void ValidateServesTarget(const core::Query& query,
                          const std::string& field1,
                          Segment::Kind kind1,
                          const std::string& field2,
                          Segment::Kind kind2,
                          const std::string& field3,
                          Segment::Kind kind3) {
  FieldIndex expected_index =
      MakeFieldIndex("collId", field1, kind1, field2, kind2, field3, kind3);
  TargetIndexMatcher matcher(query.ToTarget());
  EXPECT_TRUE(matcher.ServedByIndex(expected_index));
}

void ValidateDoesNotServeTarget(const core::Query& query,
                                const std::string& field1,
                                Segment::Kind kind1) {
  FieldIndex expected_index = MakeFieldIndex("collId", field1, kind1);
  TargetIndexMatcher matcher(query.ToTarget());
  EXPECT_FALSE(matcher.ServedByIndex(expected_index));
}

void ValidateDoesNotServeTarget(const core::Query& query,
                                const std::string& field1,
                                Segment::Kind kind1,
                                const std::string& field2,
                                Segment::Kind kind2) {
  FieldIndex expected_index =
      MakeFieldIndex("collId", field1, kind1, field2, kind2);
  TargetIndexMatcher matcher(query.ToTarget());
  EXPECT_FALSE(matcher.ServedByIndex(expected_index));
}

void ValidateDoesNotServeTarget(const core::Query& query,
                                const std::string& field1,
                                Segment::Kind kind1,
                                const std::string& field2,
                                Segment::Kind kind2,
                                const std::string& field3,
                                Segment::Kind kind3) {
  FieldIndex expected_index =
      MakeFieldIndex("collId", field1, kind1, field2, kind2, field3, kind3);
  TargetIndexMatcher matcher(query.ToTarget());
  EXPECT_FALSE(matcher.ServedByIndex(expected_index));
}

void ValidateBuildTargetIndexCreateFullMatchIndex(const core::Query& query) {
  const core::Target& target = query.ToTarget();
  TargetIndexMatcher matcher(target);
  EXPECT_FALSE(matcher.HasMultipleInequality());
  absl::optional<FieldIndex> actual_index = matcher.BuildTargetIndex();
  ASSERT_TRUE(actual_index.has_value());
  EXPECT_TRUE(matcher.ServedByIndex(actual_index.value()));
  // Check the index created is a FULL MATCH index
  EXPECT_TRUE(actual_index.value().segments().size() >=
              target.GetSegmentCount());
}

TEST(TargetIndexMatcher, CanUseMergeJoin) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "==", 1))
               .AddingFilter(Filter("b", "==", 2));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  ValidateServesTarget(q, "b", Segment::Kind::kAscending);

  q = testutil::Query("collId")
          .AddingFilter(Filter("a", "==", 1))
          .AddingFilter(Filter("b", "==", 2))
          .AddingOrderBy(OrderBy("__name__", "desc"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending, "__name__",
                       Segment::Kind::kDescending);
  ValidateServesTarget(q, "b", Segment::Kind::kAscending, "__name__",
                       Segment::Kind::kDescending);
}

TEST(TargetIndexMatcher, CanUsePartialIndex) {
  auto q = testutil::Query("collId").AddingOrderBy(OrderBy("a"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);

  q = testutil::Query("collId")
          .AddingOrderBy(OrderBy("a"))
          .AddingOrderBy(OrderBy("b"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  ValidateServesTarget(q, "a", Segment::Kind::kAscending, "b",
                       Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, CannotUsePartialIndexWithMissingArrayContains) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "array-contains", "a"))
               .AddingOrderBy(OrderBy("b"));
  ValidateServesTarget(q, "a", Segment::Kind::kContains, "b",
                       Segment::Kind::kAscending);

  q = testutil::Query("collId").AddingOrderBy(OrderBy("b"));
  ValidateDoesNotServeTarget(q, "a", Segment::Kind::kContains, "b",
                             Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, CannotUseOverspecifiedIndex) {
  auto q = testutil::Query("collId").AddingOrderBy(OrderBy("a"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  ValidateDoesNotServeTarget(q, "a", Segment::Kind::kAscending, "b",
                             Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, EqualitiesWithDefaultOrder) {
  for (const auto& query : QueriesWithEqualities()) {
    ValidateServesTarget(query, "a", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query, "b", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query, "a", Segment::Kind::kContains);
  }
}

TEST(TargetIndexMatcher, EqualitiesWithAscendingOrder) {
  for (auto q : QueriesWithEqualities()) {
    auto query_asc_order = q.AddingOrderBy(OrderBy("a", "asc"));
    ValidateServesTarget(query_asc_order, "a", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query_asc_order, "b", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query_asc_order, "a", Segment::Kind::kContains);
  }
}

TEST(TargetIndexMatcher, EqualitiesWithDescendingOrder) {
  for (auto q : QueriesWithEqualities()) {
    auto query_desc_order = q.AddingOrderBy(OrderBy("a", "desc"));
    ValidateServesTarget(query_desc_order, "a", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query_desc_order, "b",
                               Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query_desc_order, "a", Segment::Kind::kContains);
  }
}

TEST(TargetIndexMatcher, InequalitiesWithDefaultOrder) {
  for (const auto& query : QueriesWithInequalities()) {
    ValidateServesTarget(query, "a", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query, "b", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query, "a", Segment::Kind::kContains);
  }
}

TEST(TargetIndexMatcher, InequalitiesWithAscendingOrder) {
  for (const auto& q : QueriesWithInequalities()) {
    auto query_asc = q.AddingOrderBy(OrderBy("a", "asc"));
    ValidateServesTarget(query_asc, "a", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query_asc, "b", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query_asc, "a", Segment::Kind::kContains);
  }
}

TEST(TargetIndexMatcher, InequalitiesWithDescendingOrder) {
  for (const auto& q : QueriesWithInequalities()) {
    auto query_asc = q.AddingOrderBy(OrderBy("a", "desc"));
    ValidateServesTarget(query_asc, "a", Segment::Kind::kDescending);
    ValidateDoesNotServeTarget(query_asc, "b", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query_asc, "a", Segment::Kind::kContains);
  }
}

TEST(TargetIndexMatcher, InequalityUsesSingleFieldIndex) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", ">", 1))
               .AddingFilter(Filter("a", "<", 10));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, InQueryUsesMergeJoin) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "in", Array(1, 2)))
               .AddingFilter(Filter("b", "==", 5));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  ValidateServesTarget(q, "b", Segment::Kind::kAscending);
  ValidateServesTarget(q, "a", Segment::Kind::kAscending, "b",
                       Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, ValidatesCollection) {
  {
    TargetIndexMatcher matcher(testutil::Query("collId").ToTarget());
    FieldIndex fieldIndex = MakeFieldIndex("collId");
    EXPECT_NO_THROW(matcher.ServedByIndex(fieldIndex));
  }

  {
    TargetIndexMatcher matcher(
        testutil::CollectionGroupQuery("collId").ToTarget());
    FieldIndex fieldIndex = MakeFieldIndex("collId");
    EXPECT_NO_THROW(matcher.ServedByIndex(fieldIndex));
  }

  {
    TargetIndexMatcher matcher(testutil::Query("collId2").ToTarget());
    FieldIndex fieldIndex = MakeFieldIndex("collId");
    EXPECT_ANY_THROW(matcher.ServedByIndex(fieldIndex));
  }
}

TEST(TargetIndexMatcher, WithArrayContains) {
  for (const auto& query : QueriesWithArrayContains()) {
    ValidateDoesNotServeTarget(query, "a", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(query, "a", Segment::Kind::kAscending);
    ValidateServesTarget(query, "a", Segment::Kind::kContains);
  }
}

TEST(TargetIndexMatcher, TestArrayContainsIsIndependent) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("value", "array-contains", "foo"))
                   .AddingOrderBy(OrderBy("value"));
  ValidateServesTarget(query, "value", Segment::Kind::kContains, "value",
                       Segment::Kind::kAscending);
  ValidateServesTarget(query, "value", Segment::Kind::kAscending, "value",
                       Segment::Kind::kContains);
}

TEST(TargetIndexMatcher, WithArrayContainsAndOrderBy) {
  auto queries_multiple_filters =
      testutil::Query("collId")
          .AddingFilter(Filter("a", "array-contains", "a"))
          .AddingFilter(Filter("a", ">", "b"))
          .AddingOrderBy(OrderBy("a", "asc"));
  ValidateServesTarget(queries_multiple_filters, "a", Segment::Kind::kContains,
                       "a", Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithEqualityAndDescendingOrder) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "==", 1))
               .AddingOrderBy(OrderBy("__name__", "desc"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending, "__name__",
                       Segment::Kind::kDescending);
}

TEST(TargetIndexMatcher, WithMultipleEqualities) {
  auto queries_multiple_filters = testutil::Query("collId")
                                      .AddingFilter(Filter("a1", "==", "a"))
                                      .AddingFilter(Filter("a2", "==", "b"));
  ValidateServesTarget(queries_multiple_filters, "a1",
                       Segment::Kind::kAscending, "a2",
                       Segment::Kind::kAscending);
  ValidateServesTarget(queries_multiple_filters, "a2",
                       Segment::Kind::kAscending, "a1",
                       Segment::Kind::kAscending);
  ValidateDoesNotServeTarget(
      queries_multiple_filters, "a1", Segment::Kind::kAscending, "a2",
      Segment::Kind::kAscending, "a3", Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithMultipleEqualitiesAndInequality) {
  auto queries_multiple_filters =
      testutil::Query("collId")
          .AddingFilter(Filter("equality1", "==", "a"))
          .AddingFilter(Filter("equality2", "==", "b"))
          .AddingFilter(Filter("inequality", ">=", "c"));
  ValidateServesTarget(queries_multiple_filters, "equality1",
                       Segment::Kind::kAscending, "equality2",
                       Segment::Kind::kAscending, "inequality",
                       Segment::Kind::kAscending);
  ValidateServesTarget(queries_multiple_filters, "equality2",
                       Segment::Kind::kAscending, "equality1",
                       Segment::Kind::kAscending, "inequality",
                       Segment::Kind::kAscending);
  ValidateDoesNotServeTarget(queries_multiple_filters, "equality2",
                             Segment::Kind::kAscending, "inequality",
                             Segment::Kind::kAscending, "equality1",
                             Segment::Kind::kAscending);

  queries_multiple_filters = testutil::Query("collId")
                                 .AddingFilter(Filter("equality1", "==", "a"))
                                 .AddingFilter(Filter("inequality", ">=", "c"))
                                 .AddingFilter(Filter("equality2", "==", "b"));
  ValidateServesTarget(queries_multiple_filters, "equality1",
                       Segment::Kind::kAscending, "equality2",
                       Segment::Kind::kAscending, "inequality",
                       Segment::Kind::kAscending);
  ValidateServesTarget(queries_multiple_filters, "equality2",
                       Segment::Kind::kAscending, "equality1",
                       Segment::Kind::kAscending, "inequality",
                       Segment::Kind::kAscending);
  ValidateDoesNotServeTarget(queries_multiple_filters, "equality1",
                             Segment::Kind::kAscending, "inequality",
                             Segment::Kind::kAscending, "equality2",
                             Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithOrderBy) {
  auto q = testutil::Query("collId").AddingOrderBy(OrderBy("a"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  ValidateDoesNotServeTarget(q, "a", Segment::Kind::kDescending);

  q = testutil::Query("collId").AddingOrderBy(OrderBy("a", "desc"));
  ValidateDoesNotServeTarget(q, "a", Segment::Kind::kAscending);
  ValidateServesTarget(q, "a", Segment::Kind::kDescending);

  q = testutil::Query("collId")
          .AddingOrderBy(OrderBy("a"))
          .AddingOrderBy(OrderBy("__name__"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending, "__name__",
                       Segment::Kind::kAscending);
  ValidateDoesNotServeTarget(q, "a", Segment::Kind::kAscending, "__name__",
                             Segment::Kind::kDescending);
}

TEST(TargetIndexMatcher, WithNotEquals) {
  auto q = testutil::Query("collId").AddingFilter(Filter("a", "!=", 1));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);

  q = testutil::Query("collId")
          .AddingFilter(Filter("a", "!=", 1))
          .AddingOrderBy(OrderBy("a"))
          .AddingOrderBy(OrderBy("b"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending, "b",
                       Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithMultipleFilters) {
  auto queriesMultipleFilters = testutil::Query("collId")
                                    .AddingFilter(Filter("a", "==", "a"))
                                    .AddingFilter(Filter("b", ">", "b"));
  ValidateServesTarget(queriesMultipleFilters, "a", Segment::Kind::kAscending);
  ValidateServesTarget(queriesMultipleFilters, "a", Segment::Kind::kAscending,
                       "b", Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, MultipleFiltersRequireMatchingPrefix) {
  auto queriesMultipleFilters = testutil::Query("collId")
                                    .AddingFilter(Filter("a", "==", "a"))
                                    .AddingFilter(Filter("b", ">", "b"));

  ValidateServesTarget(queriesMultipleFilters, "b", Segment::Kind::kAscending);
  ValidateDoesNotServeTarget(queriesMultipleFilters, "c",
                             Segment::Kind::kAscending, "a",
                             Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithMultipleFiltersAndOrderBy) {
  auto queriesMultipleFilters = testutil::Query("collId")
                                    .AddingFilter(Filter("a1", "==", "a"))
                                    .AddingFilter(Filter("a2", ">", "b"))
                                    .AddingOrderBy(OrderBy("a2", "asc"));
  ValidateServesTarget(queriesMultipleFilters, "a1", Segment::Kind::kAscending,
                       "a2", Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithMultipleInequalities) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", ">=", 1))
               .AddingFilter(Filter("a", "==", 5))
               .AddingFilter(Filter("a", "<=", 10));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithMultipleNotIn) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "not-in", Array(1, 2, 3)))
               .AddingFilter(Filter("a", ">=", 2));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithMultipleOrderBys) {
  auto q = testutil::Query("collId")
               .AddingOrderBy(OrderBy("fff"))
               .AddingOrderBy(OrderBy("bar", "desc"))
               .AddingOrderBy(OrderBy("__name__"));
  ValidateServesTarget(q, "fff", Segment::Kind::kAscending, "bar",
                       Segment::Kind::kDescending, "__name__",
                       Segment::Kind::kAscending);
  ValidateDoesNotServeTarget(q, "fff", Segment::Kind::kAscending, "__name__",
                             Segment::Kind::kAscending, "bar",
                             Segment::Kind::kDescending);

  q = testutil::Query("collId")
          .AddingOrderBy(OrderBy("foo"))
          .AddingOrderBy(OrderBy("bar"))
          .AddingOrderBy(OrderBy("__name__", "desc"));
  ValidateServesTarget(q, "foo", Segment::Kind::kAscending, "bar",
                       Segment::Kind::kAscending, "__name__",
                       Segment::Kind::kDescending);
  ValidateDoesNotServeTarget(q, "foo", Segment::Kind::kAscending, "__name__",
                             Segment::Kind::kDescending, "bar",
                             Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithInAndNotIn) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "not-in", Array(1, 2, 3)))
               .AddingFilter(Filter("b", "in", Array(1, 2, 3)));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  ValidateServesTarget(q, "b", Segment::Kind::kAscending);
  ValidateServesTarget(q, "b", Segment::Kind::kAscending, "a",
                       Segment::Kind::kAscending);
  // If provided, equalities have to come first
  ValidateDoesNotServeTarget(q, "a", Segment::Kind::kAscending, "b",
                             Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithEqualityAndDifferentOrderBy) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("foo", "==", ""))
               .AddingFilter(Filter("bar", "==", ""))
               .AddingOrderBy(OrderBy("qux"));
  ValidateServesTarget(q, "foo", Segment::Kind::kAscending, "bar",
                       Segment::Kind::kAscending, "qux",
                       Segment::Kind::kAscending);

  q = testutil::Query("collId")
          .AddingFilter(Filter("aaa", "==", ""))
          .AddingFilter(Filter("qqq", "==", ""))
          .AddingFilter(Filter("ccc", "==", ""))
          .AddingOrderBy(OrderBy("fff", "desc"))
          .AddingOrderBy(OrderBy("bbb"));

  model::FieldIndex index{-1,
                          "collId",
                          {
                              Segment{Field("aaa"), Segment::Kind::kAscending},
                              Segment{Field("qqq"), Segment::Kind::kAscending},
                              Segment{Field("ccc"), Segment::Kind::kAscending},
                              Segment{Field("fff"), Segment::Kind::kDescending},
                          },
                          FieldIndex::InitialState()};
  TargetIndexMatcher matcher(q.ToTarget());
  EXPECT_TRUE(matcher.ServedByIndex(index));
}

TEST(TargetIndexMatcher, WithEqualsAndNotIn) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "==", 1))
               .AddingFilter(Filter("b", "not-in", Array(1, 2, 3)));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending, "b",
                       Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithInAndOrderBy) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "not-in", Array(1, 2, 3)))
               .AddingOrderBy(OrderBy("a"))
               .AddingOrderBy(OrderBy("b"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending, "b",
                       Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithInAndOrderBySameField) {
  auto q = testutil::Query("collId")
               .AddingFilter(Filter("a", "in", Array(1, 2, 3)))
               .AddingOrderBy(OrderBy("a"));
  ValidateServesTarget(q, "a", Segment::Kind::kAscending);
}

TEST(TargetIndexMatcher, WithEqualityAndInequalityOnTheSameField) {
  ValidateServesTarget(testutil::Query("collId")
                           .AddingFilter(Filter("a", ">=", 5))
                           .AddingFilter(Filter("a", "==", 0)),
                       "a", Segment::Kind::kAscending);

  ValidateServesTarget(testutil::Query("collId")
                           .AddingFilter(Filter("a", ">=", 5))
                           .AddingFilter(Filter("a", "==", 0))
                           .AddingOrderBy(OrderBy("a")),
                       "a", Segment::Kind::kAscending);

  ValidateServesTarget(testutil::Query("collId")
                           .AddingFilter(Filter("a", ">=", 5))
                           .AddingFilter(Filter("a", "==", 0))
                           .AddingOrderBy(OrderBy("a"))
                           .AddingOrderBy(OrderBy("__name__")),
                       "a", Segment::Kind::kAscending);

  ValidateServesTarget(testutil::Query("collId")
                           .AddingFilter(Filter("a", ">=", 5))
                           .AddingFilter(Filter("a", "==", 0))
                           .AddingOrderBy(OrderBy("a"))
                           .AddingOrderBy(OrderBy("__name__", "desc")),
                       "a", Segment::Kind::kAscending);

  ValidateServesTarget(testutil::Query("collId")
                           .AddingFilter(Filter("a", ">=", 5))
                           .AddingFilter(Filter("a", "==", 0))
                           .AddingOrderBy(OrderBy("a"))
                           .AddingOrderBy(OrderBy("b"))
                           .AddingOrderBy(OrderBy("__name__", "desc")),
                       "a", Segment::Kind::kAscending, "b",
                       Segment::Kind::kAscending);

  ValidateServesTarget(testutil::Query("collId")
                           .AddingFilter(Filter("a", ">=", 5))
                           .AddingFilter(Filter("a", "==", 0))
                           .AddingOrderBy(OrderBy("a", "desc"))
                           .AddingOrderBy(OrderBy("__name__", "desc")),
                       "a", Segment::Kind::kDescending);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithQueriesWithEqualities) {
  for (const auto& query : QueriesWithEqualities()) {
    ValidateBuildTargetIndexCreateFullMatchIndex(query);
  }
}

TEST(TargetIndexMatcher, BuildTargetIndexWithQueriesWithInequalities) {
  for (const auto& query : QueriesWithInequalities()) {
    ValidateBuildTargetIndexCreateFullMatchIndex(query);
  }
}

TEST(TargetIndexMatcher, BuildTargetIndexWithQueriesWithArrayContains) {
  for (const auto& query : QueriesWithArrayContains()) {
    ValidateBuildTargetIndexCreateFullMatchIndex(query);
  }
}

TEST(TargetIndexMatcher, BuildTargetIndexWithQueriesWithOrderBys) {
  for (const auto& query : QueriesWithOrderBys()) {
    ValidateBuildTargetIndexCreateFullMatchIndex(query);
  }
}

TEST(TargetIndexMatcher, BuildTargetIndexWithInequalityUsesSingleFieldIndex) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", ">", 1))
                   .AddingFilter(Filter("a", "<", 10));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithCollection) {
  auto query = testutil::Query("collId");
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithArrayContainsAndOrderBy) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", "array-contains", "a"))
                   .AddingFilter(Filter("a", ">", "b"))
                   .AddingOrderBy(OrderBy("a", "asc"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithEqualityAndDescendingOrder) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", "==", 1))
                   .AddingOrderBy(OrderBy("__name__", "desc"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithMultipleEqualities) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a1", "==", "a"))
                   .AddingFilter(Filter("a2", "==", "b"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithMultipleEqualitiesAndInequality) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("equality1", "==", "a"))
                   .AddingFilter(Filter("equality2", "==", "b"))
                   .AddingFilter(Filter("inequality", ">=", "c"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
  query = testutil::Query("collId")
              .AddingFilter(Filter("equality1", "==", "a"))
              .AddingFilter(Filter("inequality", ">=", "c"))
              .AddingFilter(Filter("equality2", "==", "b"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithMultipleFilters) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", "==", "a"))
                   .AddingFilter(Filter("b", ">", "b"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
  query = testutil::Query("collId")
              .AddingFilter(Filter("a1", "==", "a"))
              .AddingFilter(Filter("a2", ">", "b"))
              .AddingOrderBy(OrderBy("a2", "asc"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
  query = testutil::Query("collId")
              .AddingFilter(Filter("a", ">=", 1))
              .AddingFilter(Filter("a", "==", 5))
              .AddingFilter(Filter("a", "<=", 10));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
  query = testutil::Query("collId")
              .AddingFilter(Filter("a", "not-in", Array(1, 2, 3)))
              .AddingFilter(Filter("a", ">=", 2));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithMultipleOrderBys) {
  auto query = testutil::Query("collId")
                   .AddingOrderBy(OrderBy("fff"))
                   .AddingOrderBy(OrderBy("bar", "desc"))
                   .AddingOrderBy(OrderBy("__name__"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
  query = testutil::Query("collId")
              .AddingOrderBy(OrderBy("foo"))
              .AddingOrderBy(OrderBy("bar"))
              .AddingOrderBy(OrderBy("__name__", "desc"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithInAndNotIn) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", "not-in", Array(1, 2, 3)))
                   .AddingFilter(Filter("b", "in", Array(1, 2, 3)));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithEqualityAndDifferentOrderBy) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("foo", "==", ""))
                   .AddingFilter(Filter("bar", "==", ""))
                   .AddingOrderBy(OrderBy("qux"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
  query = testutil::Query("collId")
              .AddingFilter(Filter("aaa", "==", ""))
              .AddingFilter(Filter("qqq", "==", ""))
              .AddingFilter(Filter("ccc", "==", ""))
              .AddingOrderBy(OrderBy("fff", "desc"))
              .AddingOrderBy(OrderBy("bbb"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithEqualsAndNotIn) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", "==", 1))
                   .AddingFilter(Filter("b", "not-in", Array(1, 2, 3)));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithInAndOrderBy) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", "not-in", Array(1, 2, 3)))
                   .AddingOrderBy(OrderBy("a"))
                   .AddingOrderBy(OrderBy("b"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexWithInAndOrderBySameField) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", "in", Array(1, 2, 3)))
                   .AddingOrderBy(OrderBy("a"));
  ValidateBuildTargetIndexCreateFullMatchIndex(query);
}

TEST(TargetIndexMatcher, BuildTargetIndexReturnsNullForMultipleInequality) {
  auto query = testutil::Query("collId")
                   .AddingFilter(Filter("a", ">=", 1))
                   .AddingFilter(Filter("b", "<=", 10));
  const core::Target& target = query.ToTarget();
  TargetIndexMatcher matcher(target);
  EXPECT_TRUE(matcher.HasMultipleInequality());
  absl::optional<FieldIndex> actual_index = matcher.BuildTargetIndex();
  EXPECT_FALSE(actual_index.has_value());
}

}  //  namespace
}  //  namespace model
}  //  namespace firestore
}  //  namespace firebase
