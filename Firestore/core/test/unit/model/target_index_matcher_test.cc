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

#include "Firestore/core/src/model/target_index_matcher_test.h"

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {
namespace {

using testutil::Array;
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
    auto query_asc = q.AddingOrderBy(OrderBy("a", "asc"));
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
      TargetIndexMatcher matcher(testutil::CollectionGroupQuery("collId").ToTarget());
      FieldIndex fieldIndex = MakeFieldIndex("collId");
      EXPECT_NO_THROW(matcher.ServedByIndex(fieldIndex));
    }

    {
      TargetIndexMatcher matcher(testutil::Query("collId2").ToTarget());
      FieldIndex fieldIndex = MakeFieldIndex("collId");
      EXPECT_ANY_THROW(matcher.ServedByIndex(fieldIndex));
    }
  }

  TEST(TargetIndexMatcher, withArrayContains) {
    for (Query query : queriesWithArrayContains) {
      ValidateDoesNotServeTarget(query, "a", Segment::Kind::kAscending);
      ValidateDoesNotServeTarget(query, "a", Segment::Kind::kAscending);
      ValidateServesTarget(query, "a", Segment::Kind::kContains);
    }
  }

  TEST(TargetIndexMatcher, testArrayContainsIsIndependent) {
    Query query =
        query("collId").filter(filter("value", "array-contains", "foo")).orderBy(orderBy("value"));
    ValidateServesTarget(
        query,
        "value",
        Segment::Kind::kContains,
        "value",
        Segment::Kind::kAscending);
    ValidateServesTarget(
        query,
        "value",
        Segment::Kind::kAscending,
        "value",
        Segment::Kind::kContains);
  }

  TEST(TargetIndexMatcher, withArrayContainsAndOrderBy) {
    Query queriesMultipleFilters =
        query("collId")
            .filter(filter("a", "array-contains", "a"))
            .filter(filter("a", ">", "b"))
            .orderBy(orderBy("a", "asc"));
    ValidateServesTarget(
        queriesMultipleFilters,
        "a",
        Segment::Kind::kContains,
        "a",
        Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withEqualityAndDescendingOrder) {
    Query q = query("collId").filter(filter("a", "==", 1)).orderBy(orderBy("__name__", "desc"));
    ValidateServesTarget(
        q, "a", Segment::Kind::kAscending, "__name__", Segment::Kind::kDescending);
  }

  TEST(TargetIndexMatcher, withMultipleEqualities) {
    Query queriesMultipleFilters =
        query("collId").filter(filter("a1", "==", "a")).filter(filter("a2", "==", "b"));
    ValidateServesTarget(
        queriesMultipleFilters,
        "a1",
        Segment::Kind::kAscending,
        "a2",
        Segment::Kind::kAscending);
    ValidateServesTarget(
        queriesMultipleFilters,
        "a2",
        Segment::Kind::kAscending,
        "a1",
        Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(
        queriesMultipleFilters,
        "a1",
        Segment::Kind::kAscending,
        "a2",
        Segment::Kind::kAscending,
        "a3",
        Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withMultipleEqualitiesAndInequality) {
    Query queriesMultipleFilters =
        query("collId")
            .filter(filter("equality1", "==", "a"))
            .filter(filter("equality2", "==", "b"))
            .filter(filter("inequality", ">=", "c"));
    ValidateServesTarget(
        queriesMultipleFilters,
        "equality1",
        Segment::Kind::kAscending,
        "equality2",
        Segment::Kind::kAscending,
        "inequality",
        Segment::Kind::kAscending);
    ValidateServesTarget(
        queriesMultipleFilters,
        "equality2",
        Segment::Kind::kAscending,
        "equality1",
        Segment::Kind::kAscending,
        "inequality",
        Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(
        queriesMultipleFilters,
        "equality2",
        Segment::Kind::kAscending,
        "inequality",
        Segment::Kind::kAscending,
        "equality1",
        Segment::Kind::kAscending);

    queriesMultipleFilters =
        query("collId")
            .filter(filter("equality1", "==", "a"))
            .filter(filter("inequality", ">=", "c"))
            .filter(filter("equality2", "==", "b"));
    ValidateServesTarget(
        queriesMultipleFilters,
        "equality1",
        Segment::Kind::kAscending,
        "equality2",
        Segment::Kind::kAscending,
        "inequality",
        Segment::Kind::kAscending);
    ValidateServesTarget(
        queriesMultipleFilters,
        "equality2",
        Segment::Kind::kAscending,
        "equality1",
        Segment::Kind::kAscending,
        "inequality",
        Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(
        queriesMultipleFilters,
        "equality1",
        Segment::Kind::kAscending,
        "inequality",
        Segment::Kind::kAscending,
        "equality2",
        Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withOrderBy) {
    Query q = query("collId").orderBy(orderBy("a"));
    ValidateServesTarget(q, "a", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(q, "a", Segment::Kind::kDescending);

    q = query("collId").orderBy(orderBy("a", "desc"));
    ValidateDoesNotServeTarget(q, "a", Segment::Kind::kAscending);
    ValidateServesTarget(q, "a", Segment::Kind::kDescending);

    q = query("collId").orderBy(orderBy("a")).orderBy(orderBy("__name__"));
    ValidateServesTarget(
        q, "a", Segment::Kind::kAscending, "__name__", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(
        q, "a", Segment::Kind::kAscending, "__name__", Segment::Kind::kDescending);
  }

  TEST(TargetIndexMatcher, withNotEquals) {
    Query q = query("collId").filter(filter("a", "!=", 1));
    ValidateServesTarget(q, "a", Segment::Kind::kAscending);

    q = query("collId").filter(filter("a", "!=", 1)).orderBy(orderBy("a")).orderBy(orderBy("b"));
    ValidateServesTarget(
        q, "a", Segment::Kind::kAscending, "b", Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withMultipleFilters) {
    Query queriesMultipleFilters =
        query("collId").filter(filter("a", "==", "a")).filter(filter("b", ">", "b"));
    ValidateServesTarget(queriesMultipleFilters, "a", Segment::Kind::kAscending);
    ValidateServesTarget(
        queriesMultipleFilters,
        "a",
        Segment::Kind::kAscending,
        "b",
        Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, multipleFiltersRequireMatchingPrefix) {
    Query queriesMultipleFilters =
        query("collId").filter(filter("a", "==", "a")).filter(filter("b", ">", "b"));

    ValidateServesTarget(queriesMultipleFilters, "b", Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(
        queriesMultipleFilters,
        "c",
        Segment::Kind::kAscending,
        "a",
        Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withMultipleFiltersAndOrderBy) {
    Query queriesMultipleFilters =
        query("collId")
            .filter(filter("a1", "==", "a"))
            .filter(filter("a2", ">", "b"))
            .orderBy(orderBy("a2", "asc"));
    ValidateServesTarget(
        queriesMultipleFilters,
        "a1",
        Segment::Kind::kAscending,
        "a2",
        Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withMultipleInequalities) {
    Query q =
        query("collId")
            .filter(filter("a", ">=", 1))
            .filter(filter("a", "==", 5))
            .filter(filter("a", "<=", 10));
    ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withMultipleNotIn) {
    Query q =
        query("collId")
            .filter(filter("a", "not-in", Arrays.asList(1, 2, 3)))
            .filter(filter("a", ">=", 2));
    ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withMultipleOrderBys) {
    Query q =
        query("collId")
            .orderBy(orderBy("fff"))
            .orderBy(orderBy("bar", "desc"))
            .orderBy(orderBy("__name__"));
    ValidateServesTarget(
        q,
        "fff",
        Segment::Kind::kAscending,
        "bar",
        Segment::Kind::kDescending,
        "__name__",
        Segment::Kind::kAscending);
    ValidateDoesNotServeTarget(
        q,
        "fff",
        Segment::Kind::kAscending,
        "__name__",
        Segment::Kind::kAscending,
        "bar",
        Segment::Kind::kDescending);

    q =
        query("collId")
            .orderBy(orderBy("foo"))
            .orderBy(orderBy("bar"))
            .orderBy(orderBy("__name__", "desc"));
    ValidateServesTarget(
        q,
        "foo",
        Segment::Kind::kAscending,
        "bar",
        Segment::Kind::kAscending,
        "__name__",
        Segment::Kind::kDescending);
    ValidateDoesNotServeTarget(
        q,
        "foo",
        Segment::Kind::kAscending,
        "__name__",
        Segment::Kind::kDescending,
        "bar",
        Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withInAndNotIn) {
    Query q =
        query("collId")
            .filter(filter("a", "not-in", Arrays.asList(1, 2, 3)))
            .filter(filter("b", "in", Arrays.asList(1, 2, 3)));
    ValidateServesTarget(q, "a", Segment::Kind::kAscending);
    ValidateServesTarget(q, "b", Segment::Kind::kAscending);
    ValidateServesTarget(
        q, "b", Segment::Kind::kAscending, "a", Segment::Kind::kAscending);
    // If provided, equalities have to come first
    ValidateDoesNotServeTarget(
        q, "a", Segment::Kind::kAscending, "b", Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withEqualityAndDifferentOrderBy) {
    Query q =
        query("collId")
            .filter(filter("foo", "==", ""))
            .filter(filter("bar", "==", ""))
            .orderBy(orderBy("qux"));
    ValidateServesTarget(
        q,
        "foo",
        Segment::Kind::kAscending,
        "bar",
        Segment::Kind::kAscending,
        "qux",
        Segment::Kind::kAscending);

    q =
        query("collId")
            .filter(filter("aaa", "==", ""))
            .filter(filter("qqq", "==", ""))
            .filter(filter("ccc", "==", ""))
            .orderBy(orderBy("fff", "desc"))
            .orderBy(orderBy("bbb"));
    ValidateServesTarget(
        q,
        "aaa",
        Segment::Kind::kAscending,
        "qqq",
        Segment::Kind::kAscending,
        "ccc",
        Segment::Kind::kAscending,
        "fff",
        Segment::Kind::kDescending);
  }

  TEST(TargetIndexMatcher, withEqualsAndNotIn) {
    Query q =
        query("collId")
            .filter(filter("a", "==", 1))
            .filter(filter("b", "not-in", Arrays.asList(1, 2, 3)));
    ValidateServesTarget(
        q, "a", Segment::Kind::kAscending, "b", Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withInAndOrderBy) {
    Query q =
        query("collId")
            .filter(filter("a", "not-in", Arrays.asList(1, 2, 3)))
            .orderBy(orderBy("a"))
            .orderBy(orderBy("b"));
    ValidateServesTarget(
        q, "a", Segment::Kind::kAscending, "b", Segment::Kind::kAscending);
  }

  TEST(TargetIndexMatcher, withInAndOrderBySameField) {
    Query q =
        query("collId").filter(filter("a", "in", Arrays.asList(1, 2, 3))).orderBy(orderBy("a"));
    ValidateServesTarget(q, "a", Segment::Kind::kAscending);
  }


}  //  namespace
}  //  namespace model
}  //  namespace firestore
}  //  namespace firebase
