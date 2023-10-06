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

#include "Firestore/core/src/core/query.h"

#include <cmath>

#include "Firestore/core/src/core/bound.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/core/order_by.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/field_path.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using firebase::firestore::util::ComparisonResult;
using model::DocumentComparator;
using model::FieldPath;
using model::MutableDocument;
using model::ResourcePath;
using nanopb::MakeSharedMessage;

using testing::AssertionResult;
using testing::Not;
using testutil::AndFilters;
using testutil::Array;
using testutil::CollectionGroupQuery;
using testutil::DbId;
using testutil::Doc;
using testutil::Field;
using testutil::Map;
using testutil::OrFilters;
using testutil::Ref;
using testutil::Value;
using testutil::Vector;

MATCHER_P(Matches, doc, "") {
  bool actual = arg.Matches(doc);
  *result_listener << "matches " << actual;
  return actual;
}

TEST(QueryTest, Constructor) {
  const ResourcePath path{"rooms", "Firestore", "messages", "0001"};
  Query query(path);

  ASSERT_EQ(1, query.normalized_order_bys().size());
  EXPECT_EQ(FieldPath::kDocumentKeyPath,
            query.normalized_order_bys()[0].field().CanonicalString());
  EXPECT_EQ(true, query.normalized_order_bys()[0].ascending());

  ASSERT_EQ(0, query.explicit_order_bys().size());
}

TEST(QueryTest, OrderBy) {
  auto query = testutil::Query("rooms/Firestore/messages")
                   .AddingOrderBy(testutil::OrderBy(Field("length"),
                                                    Direction::Descending));

  ASSERT_EQ(2, query.normalized_order_bys().size());
  EXPECT_EQ("length",
            query.normalized_order_bys()[0].field().CanonicalString());
  EXPECT_EQ(false, query.normalized_order_bys()[0].ascending());
  EXPECT_EQ(FieldPath::kDocumentKeyPath,
            query.normalized_order_bys()[1].field().CanonicalString());
  EXPECT_EQ(false, query.normalized_order_bys()[1].ascending());

  ASSERT_EQ(1, query.explicit_order_bys().size());
  EXPECT_EQ("length", query.explicit_order_bys()[0].field().CanonicalString());
  EXPECT_EQ(false, query.explicit_order_bys()[0].ascending());
}

TEST(QueryTest, MatchesBasedOnDocumentKey) {
  auto doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  auto doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  auto doc3 = Doc("rooms/other/messages/1", 0, Map("text", "msg3"));

  auto query = testutil::Query("rooms/eros/messages/1");
  EXPECT_THAT(query, Matches(doc1));
  EXPECT_THAT(query, Not(Matches(doc2)));
  EXPECT_THAT(query, Not(Matches(doc3)));
}

TEST(QueryTest, MatchesShallowAncestorQuery) {
  auto doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  auto doc1_meta = Doc("rooms/eros/messages/1/meta/1", 0, Map("meta", "mv"));
  auto doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  auto doc3 = Doc("rooms/other/messages/1", 0, Map("text", "msg3"));

  auto query = testutil::Query("rooms/eros/messages");
  EXPECT_THAT(query, Matches(doc1));
  EXPECT_THAT(query, Not(Matches(doc1_meta)));
  EXPECT_THAT(query, Matches(doc2));
  EXPECT_THAT(query, Not(Matches(doc3)));
}

TEST(QueryTest, EmptyFieldsAreAllowedForQueries) {
  auto doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  auto doc2 = Doc("rooms/eros/messages/2", 0, Map());

  auto query = testutil::Query("rooms/eros/messages")
                   .AddingFilter(testutil::Filter("text", "==", "msg1"));
  EXPECT_THAT(query, Matches(doc1));
  EXPECT_THAT(query, Not(Matches(doc2)));
}

MATCHER_P2(AssertQueryMatches, matching, non_matching, "") {
  return std::all_of(
             matching.cbegin(), matching.cend(),
             [&arg](const MutableDocument& doc) { return arg.Matches(doc); }) &&
         std::none_of(
             non_matching.cbegin(), non_matching.cend(),
             [&arg](const MutableDocument& doc) { return arg.Matches(doc); });
}

TEST(QueryTest, OrQuery) {
  auto doc1 = Doc("collection/1", 0, Map("a", 1, "b", 0));
  auto doc2 = Doc("collection/2", 0, Map("a", 2, "b", 1));
  auto doc3 = Doc("collection/3", 0, Map("a", 3, "b", 2));
  auto doc4 = Doc("collection/4", 0, Map("a", 1, "b", 3));
  auto doc5 = Doc("collection/5", 0, Map("a", 1, "b", 1));

  // Two equalities: a==1 || b==1.
  auto query1 = testutil::Query("collection")
                    .AddingFilter(OrFilters({testutil::Filter("a", "==", 1),
                                             testutil::Filter("b", "==", 1)}));
  EXPECT_THAT(query1, AssertQueryMatches(
                          /* match */
                          std::vector<MutableDocument>{doc1, doc2, doc4, doc5},
                          /* not match */
                          std::vector<MutableDocument>{doc3}));

  // With one inequality: a>2 || b==1.
  auto query2 = testutil::Query("collection")
                    .AddingFilter(OrFilters({testutil::Filter("a", ">", 2),
                                             testutil::Filter("b", "==", 1)}));
  EXPECT_THAT(query2, AssertQueryMatches(
                          /* match */
                          std::vector<MutableDocument>{doc2, doc3, doc5},
                          /* not match */
                          std::vector<MutableDocument>{doc1, doc4}));

  // (a==1 && b==0) || (a==3 && b==2)
  auto query3 = testutil::Query("collection")
                    .AddingFilter(OrFilters(
                        {AndFilters({testutil::Filter("a", "==", 1),
                                     testutil::Filter("b", "==", 0)}),
                         AndFilters({testutil::Filter("a", "==", 3),
                                     testutil::Filter("b", "==", 2)})}));
  EXPECT_THAT(query3, AssertQueryMatches(
                          /* match */
                          std::vector<MutableDocument>{doc1, doc3},
                          /* not match */
                          std::vector<MutableDocument>{doc2, doc4, doc5}));

  // a==1 && (b==0 || b==3).
  auto query4 = testutil::Query("collection")
                    .AddingFilter(AndFilters(
                        {testutil::Filter("a", "==", 1),
                         OrFilters({testutil::Filter("b", "==", 0),
                                    testutil::Filter("b", "==", 3)})}));
  EXPECT_THAT(query4, AssertQueryMatches(
                          /* match */
                          std::vector<MutableDocument>{doc1, doc4},
                          /* not match */
                          std::vector<MutableDocument>{doc2, doc3, doc5}));

  // (a==2 || b==2) && (a==3 || b==3)
  auto query5 = testutil::Query("collection")
                    .AddingFilter(AndFilters(
                        {OrFilters({testutil::Filter("a", "==", 2),
                                    testutil::Filter("b", "==", 2)}),
                         OrFilters({testutil::Filter("a", "==", 3),
                                    testutil::Filter("b", "==", 3)})}));
  EXPECT_THAT(query5,
              AssertQueryMatches(
                  /* match */
                  std::vector<MutableDocument>{doc3},
                  /* not match */
                  std::vector<MutableDocument>{doc1, doc2, doc4, doc5}));
}

TEST(QueryTest, PrimitiveValueFilter) {
  auto query1 = testutil::Query("collection")
                    .AddingFilter(testutil::Filter("sort", ">=", 2));
  auto query2 = testutil::Query("collection")
                    .AddingFilter(testutil::Filter("sort", "<=", 2));

  auto doc1 = Doc("collection/1", 0, Map("sort", 1));
  auto doc2 = Doc("collection/2", 0, Map("sort", 2));
  auto doc3 = Doc("collection/3", 0, Map("sort", 3));
  auto doc4 = Doc("collection/4", 0, Map("sort", false));
  auto doc5 = Doc("collection/5", 0, Map("sort", "string"));
  auto doc6 = Doc("collection/6", 0, Map());

  EXPECT_THAT(query1, Not(Matches(doc1)));
  EXPECT_THAT(query1, Matches(doc2));
  EXPECT_THAT(query1, Matches(doc3));
  EXPECT_THAT(query1, Not(Matches(doc4)));
  EXPECT_THAT(query1, Not(Matches(doc5)));

  EXPECT_THAT(query2, Matches(doc1));
  EXPECT_THAT(query2, Matches(doc2));
  EXPECT_THAT(query2, Not(Matches(doc3)));
  EXPECT_THAT(query2, Not(Matches(doc4)));
  EXPECT_THAT(query2, Not(Matches(doc5)));
}

TEST(QueryTest, NullFilter) {
  auto query = testutil::Query("collection")
                   .AddingFilter(testutil::Filter("sort", "==", nullptr));
  auto doc1 = Doc("collection/1", 0, Map("sort", nullptr));
  auto doc2 = Doc("collection/2", 0, Map("sort", 2));
  auto doc3 = Doc("collection/2", 0, Map("sort", 3.1));
  auto doc4 = Doc("collection/4", 0, Map("sort", false));
  auto doc5 = Doc("collection/5", 0, Map("sort", "string"));
  auto doc6 = Doc("collection/6", 0, Map("sort", NAN));

  EXPECT_THAT(query, Matches(doc1));
  EXPECT_THAT(query, Not(Matches(doc2)));
  EXPECT_THAT(query, Not(Matches(doc3)));
  EXPECT_THAT(query, Not(Matches(doc4)));
  EXPECT_THAT(query, Not(Matches(doc5)));
  EXPECT_THAT(query, Not(Matches(doc6)));

  query = testutil::Query("collection")
              .AddingFilter(testutil::Filter("sort", "!=", nullptr));
  EXPECT_THAT(query, Not(Matches(doc1)));
  EXPECT_THAT(query, Matches(doc2));
  EXPECT_THAT(query, Matches(doc3));
  EXPECT_THAT(query, Matches(doc4));
  EXPECT_THAT(query, Matches(doc5));
  EXPECT_THAT(query, Matches(doc6));
}

TEST(QueryTest, NanFilter) {
  auto query = testutil::Query("collection")
                   .AddingFilter(testutil::Filter("sort", "==", NAN));

  auto doc1 = Doc("collection/1", 0, Map("sort", NAN));
  auto doc2 = Doc("collection/2", 0, Map("sort", 2));
  auto doc3 = Doc("collection/3", 0, Map("sort", 3.1));
  auto doc4 = Doc("collection/4", 0, Map("sort", false));
  auto doc5 = Doc("collection/5", 0, Map("sort", "string"));
  auto doc6 = Doc("collection/6", 0, Map("sort", nullptr));

  EXPECT_THAT(query, Matches(doc1));
  EXPECT_THAT(query, Not(Matches(doc2)));
  EXPECT_THAT(query, Not(Matches(doc3)));
  EXPECT_THAT(query, Not(Matches(doc4)));
  EXPECT_THAT(query, Not(Matches(doc5)));
  EXPECT_THAT(query, Not(Matches(doc6)));

  query = testutil::Query("collection")
              .AddingFilter(testutil::Filter("sort", "!=", NAN));
  EXPECT_THAT(query, Not(Matches(doc1)));
  EXPECT_THAT(query, Matches(doc2));
  EXPECT_THAT(query, Matches(doc3));
  EXPECT_THAT(query, Matches(doc4));
  EXPECT_THAT(query, Matches(doc5));
  EXPECT_THAT(query, Matches(doc6));
}

TEST(QueryTest, ArrayContainsFilter) {
  auto query =
      testutil::Query("collection")
          .AddingFilter(testutil::Filter("array", "array_contains", 42));

  // not an array.
  auto doc = Doc("collection/1", 0, Map("array", 1));
  EXPECT_THAT(query, Not(Matches(doc)));

  // empty array.
  doc = Doc("collection/1", 0, Map("array", Array()));
  EXPECT_THAT(query, Not(Matches(doc)));

  // array without element (and make sure it doesn't match in a nested field or
  // a different field).
  doc = Doc("collection/1", 0,
            Map("array", Array(41, "42", Map("a", 42, "b", Array(42))),
                "different", Array(42)));
  EXPECT_THAT(query, Not(Matches(doc)));

  // array with element.
  doc = Doc("collection/1", 0, Map("array", Array(1, "2", 42, Map("a", 1))));
  EXPECT_THAT(query, Matches(doc));
}

TEST(QueryTest, ArrayContainsFilterWithObjectValues) {
  // Search for arrays containing the object { a: [42] }
  auto query = testutil::Query("collection")
                   .AddingFilter(testutil::Filter("array", "array_contains",
                                                  Map("a", Array(42))));

  // array without element.
  auto doc = Doc(
      "collection/1", 0,
      Map("array", Array(Map("a", 42), Map("a", Array(42, 43)),
                         Map("b", Array(42)), Map("a", Array(42), "b", 42))));
  EXPECT_THAT(query, Not(Matches(doc)));

  // array with element.
  doc = Doc("collection/1", 0,
            Map("array", Array(1, "2", 42, Map("a", Array(42)))));
  EXPECT_THAT(query, Matches(doc));
}

TEST(QueryTest, InFilters) {
  auto query = testutil::Query("collection")
                   .AddingFilter(testutil::Filter("zip", "in", Array(12345)));

  auto doc = Doc("collection/1", 0, Map("zip", 12345));
  EXPECT_THAT(query, Matches(doc));

  // Value matches in array.
  doc = Doc("collection/1", 0, Map("zip", Array(12345)));
  EXPECT_THAT(query, Not(Matches(doc)));

  // Non-type match.
  doc = Doc("collection/1", 0, Map("zip", "12345"));
  EXPECT_THAT(query, Not(Matches(doc)));

  // Nested match.
  doc = Doc("collection/1", 0, Map("zip", Array("12345", Map("zip", 12345))));
  EXPECT_THAT(query, Not(Matches(doc)));
}

TEST(QueryTest, InFiltersWithObjectValues) {
  auto query = testutil::Query("collection")
                   .AddingFilter(testutil::Filter("zip", "in",
                                                  Array(Map("a", Array(42)))));

  // Containing object in array.
  auto doc = Doc("collection/1", 0, Map("zip", Array(Map("a", Array(42)))));
  EXPECT_THAT(query, Not(Matches(doc)));

  // Containing object.
  doc = Doc("collection/1", 0, Map("zip", Map("a", Array(42))));
  EXPECT_THAT(query, Matches(doc));
}

TEST(QueryTest, NotInFilters) {
  auto query =
      testutil::Query("collection")
          .AddingFilter(testutil::Filter("zip", "not-in", Array(12345)));

  // No match.
  auto doc = Doc("collection/1", 0, Map("zip", 23456));
  EXPECT_THAT(query, Matches(doc));

  // Value matches in array.
  doc = Doc("collection/1", 0, Map("zip", Array(12345)));
  EXPECT_THAT(query, Matches(doc));

  // Non-type match.
  doc = Doc("collection/1", 0, Map("zip", "12345"));
  EXPECT_THAT(query, Matches(doc));

  // Nested match.
  doc = Doc("collection/1", 0, Map("zip", Array("12345", Map("zip", 12345))));
  EXPECT_THAT(query, Matches(doc));

  // Null match.
  doc = Doc("collection/1", 0, Map("zip", nullptr));
  EXPECT_THAT(query, Matches(doc));

  // NAN match.
  doc = Doc("collection/1", 0, Map("zip", NAN));
  EXPECT_THAT(query, Matches(doc));

  // Direct match.
  doc = Doc("collection/1", 0, Map("zip", 12345));
  EXPECT_THAT(query, Not(Matches(doc)));

  // Field not set.
  doc = Doc("collection/1", 0, Map("chip", 23456));
  EXPECT_THAT(query, Not(Matches(doc)));
}

TEST(QueryTest, NotInFiltersWithObjectValues) {
  auto query = testutil::Query("collection")
                   .AddingFilter(testutil::Filter("zip", "not-in",
                                                  Array(Map("a", Array(42)))));

  // Containing object in array.
  auto doc = Doc("collection/1", 0, Map("zip", Array(Map("a", Array(42)))));
  EXPECT_THAT(query, Matches(doc));

  // Containing object.
  doc = Doc("collection/1", 0, Map("zip", Map("a", Array(42))));
  EXPECT_THAT(query, Not(Matches(doc)));
}

TEST(QueryTest, ArrayContainsAnyFilters) {
  auto query = testutil::Query("collection")
                   .AddingFilter(testutil::Filter("zip", "array-contains-any",
                                                  Array(12345)));

  auto doc = Doc("collection/1", 0, Map("zip", Array(12345)));
  EXPECT_THAT(query, Matches(doc));

  // Value matches in non-array.
  doc = Doc("collection/1", 0, Map("zip", 12345));
  EXPECT_THAT(query, Not(Matches(doc)));

  // Non-type match.
  doc = Doc("collection/1", 0, Map("zip", Array("12345")));
  EXPECT_THAT(query, Not(Matches(doc)));

  // Nested match.
  doc = Doc("collection/1", 0,
            Map("zip", Array("12345", Map("zip", Array(12345)))));
  EXPECT_THAT(query, Not(Matches(doc)));
}

TEST(QueryTest, ArrayContainsAnyFiltersWithObjectValues) {
  auto query = testutil::Query("collection")
                   .AddingFilter(testutil::Filter("zip", "array-contains-any",
                                                  Array(Map("a", Array(42)))));

  // Containing object in array.
  auto doc = Doc("collection/1", 0, Map("zip", Array(Map("a", Array(42)))));
  EXPECT_THAT(query, Matches(doc));

  // Containing object.
  doc = Doc("collection/1", 0, Map("zip", Map("a", Array(42))));
  EXPECT_THAT(query, Not(Matches(doc)));
}

TEST(QueryTest, DoesNotMatchComplexObjectsForFilters) {
  auto query1 = testutil::Query("collection")
                    .AddingFilter(testutil::Filter("sort", "<=", 2));
  auto query2 = testutil::Query("collection")
                    .AddingFilter(testutil::Filter("sort", ">=", 2));

  auto doc1 = Doc("collection/1", 0, Map("sort", 2));
  auto doc2 = Doc("collection/2", 0, Map("sort", Array()));
  auto doc3 = Doc("collection/3", 0, Map("sort", Array(1)));
  auto doc4 = Doc("collection/4", 0, Map("sort", Map("foo", 2)));
  auto doc5 = Doc("collection/5", 0, Map("sort", Map("foo", "bar")));
  auto doc6 = Doc("collection/6", 0, Map("sort", Map()));  // no sort field
  auto doc7 = Doc("collection/7", 0, Map("sort", Array(3, 1)));

  EXPECT_THAT(query1, Matches(doc1));
  EXPECT_THAT(query1, Not(Matches(doc2)));
  EXPECT_THAT(query1, Not(Matches(doc3)));
  EXPECT_THAT(query1, Not(Matches(doc4)));
  EXPECT_THAT(query1, Not(Matches(doc5)));
  EXPECT_THAT(query1, Not(Matches(doc6)));
  EXPECT_THAT(query1, Not(Matches(doc7)));

  EXPECT_THAT(query2, Matches(doc1));
  EXPECT_THAT(query2, Not(Matches(doc2)));
  EXPECT_THAT(query2, Not(Matches(doc3)));
  EXPECT_THAT(query2, Not(Matches(doc4)));
  EXPECT_THAT(query2, Not(Matches(doc5)));
  EXPECT_THAT(query2, Not(Matches(doc6)));
  EXPECT_THAT(query2, Not(Matches(doc7)));
}

TEST(QueryTest, DoesntRemoveComplexObjectsWithOrderBy) {
  auto query1 = testutil::Query("collection")
                    .AddingOrderBy(testutil::OrderBy("sort", "asc"));

  auto doc1 = Doc("collection/1", 0, Map("sort", 2));
  auto doc2 = Doc("collection/2", 0, Map("sort", Array()));
  auto doc3 = Doc("collection/3", 0, Map("sort", Array(1)));
  auto doc4 = Doc("collection/4", 0, Map("sort", Map("foo", 2)));
  auto doc5 = Doc("collection/5", 0, Map("sort", Map("foo", "bar")));
  auto doc6 = Doc("collection/6", 0, Map());

  EXPECT_THAT(query1, Matches(doc1));
  EXPECT_THAT(query1, Matches(doc2));
  EXPECT_THAT(query1, Matches(doc3));
  EXPECT_THAT(query1, Matches(doc4));
  EXPECT_THAT(query1, Matches(doc5));
  EXPECT_THAT(query1, Not(Matches(doc6)));
}

TEST(QueryTest, FiltersBasedOnArrayValue) {
  auto base_query = testutil::Query("collection");
  auto doc1 = Doc("collection/doc", 0, Map("tags", Array("foo", 1, true)));

  std::vector<core::Filter> matching_filters{
      testutil::Filter("tags", "==", Array("foo", 1, true))};

  std::vector<core::Filter> non_matching_filters{
      testutil::Filter("tags", "==", "foo"),
      testutil::Filter("tags", "==", Array("foo", 1)),
      testutil::Filter("tags", "==", Array("foo", true, 1)),
  };

  for (const auto& filter : matching_filters) {
    EXPECT_THAT(base_query.AddingFilter(filter), Matches(doc1));
  }

  for (const auto& filter : non_matching_filters) {
    EXPECT_THAT(base_query.AddingFilter(filter), Not(Matches(doc1)));
  }
}

TEST(QueryTest, FiltersBasedOnObjectValue) {
  auto base_query = testutil::Query("collection");
  auto doc1 = Doc("collection/doc", 0,
                  Map("tags", Map("foo", "foo", "a", 0, "b", true, "c", NAN)));

  std::vector<core::Filter> matching_filters{
      testutil::Filter("tags",
                       "==", Map("foo", "foo", "a", 0, "b", true, "c", NAN)),
      testutil::Filter("tags",
                       "==", Map("b", true, "a", 0, "foo", "foo", "c", NAN)),
      testutil::Filter("tags.foo", "==", "foo")};

  std::vector<core::Filter> non_matching_filters{
      testutil::Filter("tags", "==", "foo"),
      testutil::Filter("tags", "==", Map("foo", "foo", "a", 0, "b", true))};

  for (const auto& filter : matching_filters) {
    EXPECT_THAT(base_query.AddingFilter(filter), Matches(doc1));
  }

  for (const auto& filter : non_matching_filters) {
    EXPECT_THAT(base_query.AddingFilter(filter), Not(Matches(doc1)));
  }
}

/**
 * Checks that an ordered array of elements yields the correct pair-wise
 * comparison result for the supplied comparator.
 */
testing::AssertionResult CorrectComparisons(
    const std::vector<MutableDocument>& vector,
    const DocumentComparator& comp) {
  for (size_t i = 0; i < vector.size(); i++) {
    for (size_t j = 0; j < vector.size(); j++) {
      const MutableDocument& i_doc = vector[i];
      const MutableDocument& j_doc = vector[j];
      ComparisonResult expected = util::Compare(i, j);
      ComparisonResult actual = comp.Compare(i_doc, j_doc);
      if (actual != expected) {
        return testing::AssertionFailure()
               << "Comparison failure " << i_doc << " to " << j_doc << " at ("
               << i << ", " << j << ").";
      }
    }
  }
  return testing::AssertionSuccess();
}

TEST(QueryTest, SortsDocumentsInTheCorrectOrder) {
  auto query =
      testutil::Query("collection").AddingOrderBy(testutil::OrderBy("sort"));

  // clang-format off
  std::vector<MutableDocument> docs = {
      Doc("collection/1", 0, Map("sort", nullptr)),
      Doc("collection/1", 0, Map("sort", false)),
      Doc("collection/1", 0, Map("sort", true)),
      Doc("collection/1", 0, Map("sort", 1)),
      Doc("collection/2", 0, Map("sort", 1)),  // by key
      Doc("collection/3", 0, Map("sort", 1)),  // by key
      Doc("collection/1", 0, Map("sort", 1.9)),
      Doc("collection/1", 0, Map("sort", 2)),
      Doc("collection/1", 0, Map("sort", 2.1)),
      Doc("collection/1", 0, Map("sort", "")),
      Doc("collection/1", 0, Map("sort", "a")),
      Doc("collection/1", 0, Map("sort", "ab")),
      Doc("collection/1", 0, Map("sort", "b")),
      Doc("collection/1", 0, Map("sort", Ref("project", "collection/id1"))),
  };
  // clang-format on

  ASSERT_TRUE(CorrectComparisons(docs, query.Comparator()));
}

TEST(QueryTest, SortsDocumentsUsingMultipleFields) {
  auto query = testutil::Query("collection")
                   .AddingOrderBy(testutil::OrderBy("sort1"))
                   .AddingOrderBy(testutil::OrderBy("sort2"));

  // clang-format off
  std::vector<MutableDocument> docs = {
      Doc("collection/1", 0, Map("sort1", 1, "sort2", 1)),
      Doc("collection/1", 0, Map("sort1", 1, "sort2", 2)),
      Doc("collection/2", 0, Map("sort1", 1, "sort2", 2)),  // by key
      Doc("collection/3", 0, Map("sort1", 1, "sort2", 2)),  // by key
      Doc("collection/1", 0, Map("sort1", 1, "sort2", 3)),
      Doc("collection/1", 0, Map("sort1", 2, "sort2", 1)),
      Doc("collection/1", 0, Map("sort1", 2, "sort2", 2)),
      Doc("collection/2", 0, Map("sort1", 2, "sort2", 2)),  // by key
      Doc("collection/3", 0, Map("sort1", 2, "sort2", 2)),  // by key
      Doc("collection/1", 0, Map("sort1", 2, "sort2", 3)),
  };
  // clang-format on

  ASSERT_TRUE(CorrectComparisons(docs, query.Comparator()));
}

TEST(QueryTest, SortsDocumentsWithDescendingToo) {
  auto query = testutil::Query("collection")
                   .AddingOrderBy(testutil::OrderBy("sort1", "desc"))
                   .AddingOrderBy(testutil::OrderBy("sort2", "desc"));

  // clang-format off
  std::vector<MutableDocument> docs = {
      Doc("collection/1", 0, Map("sort1", 2, "sort2", 3)),
      Doc("collection/3", 0, Map("sort1", 2, "sort2", 2)),
      Doc("collection/2", 0, Map("sort1", 2, "sort2", 2)),  // by key
      Doc("collection/1", 0, Map("sort1", 2, "sort2", 2)),  // by key
      Doc("collection/1", 0, Map("sort1", 2, "sort2", 1)),
      Doc("collection/1", 0, Map("sort1", 1, "sort2", 3)),
      Doc("collection/3", 0, Map("sort1", 1, "sort2", 2)),
      Doc("collection/2", 0, Map("sort1", 1, "sort2", 2)),  // by key
      Doc("collection/1", 0, Map("sort1", 1, "sort2", 2)),  // by key
      Doc("collection/1", 0, Map("sort1", 1, "sort2", 1)),
  };
  // clang-format on

  ASSERT_TRUE(CorrectComparisons(docs, query.Comparator()));
}

TEST(QueryTest, Equality) {
  auto q11 = testutil::Query("foo")
                 .AddingFilter(testutil::Filter("i1", "<", 2))
                 .AddingFilter(testutil::Filter("i2", "==", 3));
  auto q12 = testutil::Query("foo")
                 .AddingFilter(testutil::Filter("i2", "==", 3))
                 .AddingFilter(testutil::Filter("i1", "<", 2));

  auto q21 = testutil::Query("foo");
  auto q22 = testutil::Query("foo");

  auto q31 = testutil::Query("foo/bar");
  auto q32 = testutil::Query("foo/bar");

  auto q41 = testutil::Query("foo")
                 .AddingOrderBy(testutil::OrderBy("foo", "asc"))
                 .AddingOrderBy(testutil::OrderBy("bar", "asc"));
  auto q42 = testutil::Query("foo")
                 .AddingOrderBy(testutil::OrderBy("foo", "asc"))
                 .AddingOrderBy(testutil::OrderBy("bar", "asc"));
  auto q43Diff = testutil::Query("foo")
                     .AddingOrderBy(testutil::OrderBy("bar", "asc"))
                     .AddingOrderBy(testutil::OrderBy("foo", "asc"));

  auto q51 = testutil::Query("foo")
                 .AddingOrderBy(testutil::OrderBy("foo", "asc"))
                 .AddingFilter(testutil::Filter("foo", ">", 2));
  auto q52 = testutil::Query("foo")
                 .AddingFilter(testutil::Filter("foo", ">", 2))
                 .AddingOrderBy(testutil::OrderBy("foo", "asc"));
  auto q53Diff = testutil::Query("foo")
                     .AddingFilter(testutil::Filter("bar", ">", 2))
                     .AddingOrderBy(testutil::OrderBy("bar", "asc"));

  auto q61 = testutil::Query("foo").WithLimitToFirst(10);

  // ASSERT_EQ(q12, q11);  // TODO(klimt): not canonical yet
  ASSERT_NE(q21, q11);
  ASSERT_NE(q31, q11);
  ASSERT_NE(q41, q11);
  ASSERT_NE(q51, q11);
  ASSERT_NE(q61, q11);

  ASSERT_EQ(q22, q21);
  ASSERT_NE(q31, q21);
  ASSERT_NE(q41, q21);
  ASSERT_NE(q51, q21);
  ASSERT_NE(q61, q21);

  ASSERT_EQ(q32, q31);
  ASSERT_NE(q41, q31);
  ASSERT_NE(q51, q31);
  ASSERT_NE(q61, q31);

  ASSERT_EQ(q42, q41);
  ASSERT_NE(q43Diff, q41);
  ASSERT_NE(q51, q41);
  ASSERT_NE(q61, q41);

  ASSERT_EQ(q52, q51);
  ASSERT_NE(q53Diff, q51);
  ASSERT_NE(q61, q51);
}

TEST(QueryTest, UniqueIds) {
  auto q11 = testutil::Query("foo")
                 .AddingFilter(testutil::Filter("i1", "<", 2))
                 .AddingFilter(testutil::Filter("i2", "==", 3));
  auto q12 = testutil::Query("foo")
                 .AddingFilter(testutil::Filter("i2", "==", 3))
                 .AddingFilter(testutil::Filter("i1", "<", 2));

  auto q21 = testutil::Query("foo");
  auto q22 = testutil::Query("foo");

  auto q31 = testutil::Query("foo/bar");
  auto q32 = testutil::Query("foo/bar");

  auto q41 = testutil::Query("foo")
                 .AddingOrderBy(testutil::OrderBy("foo", "asc"))
                 .AddingOrderBy(testutil::OrderBy("bar", "asc"));
  auto q42 = testutil::Query("foo")
                 .AddingOrderBy(testutil::OrderBy("foo", "asc"))
                 .AddingOrderBy(testutil::OrderBy("bar", "asc"));
  auto q43Diff = testutil::Query("foo")
                     .AddingOrderBy(testutil::OrderBy("bar", "asc"))
                     .AddingOrderBy(testutil::OrderBy("foo", "asc"));

  auto q51 = testutil::Query("foo")
                 .AddingOrderBy(testutil::OrderBy("foo", "asc"))
                 .AddingFilter(testutil::Filter("foo", ">", 2));
  auto q52 = testutil::Query("foo")
                 .AddingFilter(testutil::Filter("foo", ">", 2))
                 .AddingOrderBy(testutil::OrderBy("foo", "asc"));
  auto q53Diff = testutil::Query("foo")
                     .AddingFilter(testutil::Filter("bar", ">", 2))
                     .AddingOrderBy(testutil::OrderBy("bar", "asc"));

  auto q61 = testutil::Query("foo").WithLimitToFirst(10);

  // XCTAssertEqual(q11.Hash(), q12.Hash());  // TODO(klimt): not canonical yet
  ASSERT_NE(q21.Hash(), q11.Hash());
  ASSERT_NE(q31.Hash(), q11.Hash());
  ASSERT_NE(q41.Hash(), q11.Hash());
  ASSERT_NE(q51.Hash(), q11.Hash());
  ASSERT_NE(q61.Hash(), q11.Hash());

  ASSERT_EQ(q22.Hash(), q21.Hash());
  ASSERT_NE(q31.Hash(), q21.Hash());
  ASSERT_NE(q41.Hash(), q21.Hash());
  ASSERT_NE(q51.Hash(), q21.Hash());
  ASSERT_NE(q61.Hash(), q21.Hash());

  ASSERT_EQ(q32.Hash(), q31.Hash());
  ASSERT_NE(q41.Hash(), q31.Hash());
  ASSERT_NE(q51.Hash(), q31.Hash());
  ASSERT_NE(q61.Hash(), q31.Hash());

  ASSERT_EQ(q42.Hash(), q41.Hash());
  ASSERT_NE(q43Diff.Hash(), q41.Hash());
  ASSERT_NE(q51.Hash(), q41.Hash());
  ASSERT_NE(q61.Hash(), q41.Hash());

  ASSERT_EQ(q52.Hash(), q51.Hash());
  ASSERT_NE(q53Diff.Hash(), q51.Hash());
  ASSERT_NE(q61.Hash(), q51.Hash());
}

TEST(QueryTest, ImplicitOrderBy) {
  auto base_query = testutil::Query("foo");
  // Default is ascending
  ASSERT_EQ(base_query.normalized_order_bys(),
            std::vector<core::OrderBy>{
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc")});

  // Explicit key ordering is respected
  ASSERT_EQ(
      base_query
          .AddingOrderBy(testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"))
          .normalized_order_bys(),
      std::vector<OrderBy>{
          testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc")});
  ASSERT_EQ(
      base_query
          .AddingOrderBy(testutil::OrderBy(FieldPath::kDocumentKeyPath, "desc"))
          .normalized_order_bys(),
      std::vector<OrderBy>{
          testutil::OrderBy(FieldPath::kDocumentKeyPath, "desc")});

  ASSERT_EQ(
      base_query.AddingOrderBy(testutil::OrderBy("foo", "asc"))
          .AddingOrderBy(testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"))
          .normalized_order_bys(),
      (std::vector<OrderBy>{
          testutil::OrderBy("foo", "asc"),
          testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc")}));

  ASSERT_EQ(
      base_query.AddingOrderBy(testutil::OrderBy("foo", "asc"))
          .AddingOrderBy(testutil::OrderBy(FieldPath::kDocumentKeyPath, "desc"))
          .normalized_order_bys(),
      (std::vector<OrderBy>{
          testutil::OrderBy("foo", "asc"),
          testutil::OrderBy(FieldPath::kDocumentKeyPath, "desc")}));

  // Inequality filters add order bys
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("foo", "<", 5))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("foo", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc")}));

  // Descending order by applies to implicit key ordering
  ASSERT_EQ(base_query.AddingOrderBy(testutil::OrderBy("foo", "desc"))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("foo", "desc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "desc")}));
  ASSERT_EQ(base_query.AddingOrderBy(testutil::OrderBy("foo", "asc"))
                .AddingOrderBy(testutil::OrderBy("bar", "desc"))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("foo", "asc"),
                testutil::OrderBy("bar", "desc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "desc"),
            }));
  ASSERT_EQ(base_query.AddingOrderBy(testutil::OrderBy("foo", "desc"))
                .AddingOrderBy(testutil::OrderBy("bar", "asc"))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("foo", "desc"),
                testutil::OrderBy("bar", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));
}

TEST(QueryTest, ImplicitOrderByInMultipleInequality) {
  auto base_query = testutil::Query("foo");
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("a", "<", 5))
                .AddingFilter(testutil::Filter("a", ">=", 5))
                .AddingFilter(testutil::Filter("aa", ">", 5))
                .AddingFilter(testutil::Filter("b", "<=", 5))
                .AddingFilter(testutil::Filter("A", ">=", 5))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("A", "asc"),
                testutil::OrderBy("a", "asc"),
                testutil::OrderBy("aa", "asc"),
                testutil::OrderBy("b", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));

  // numbers
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("a", "<", 5))
                .AddingFilter(testutil::Filter("1", ">", 5))
                .AddingFilter(testutil::Filter("19", "<=", 5))
                .AddingFilter(testutil::Filter("2", ">=", 5))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("1", "asc"),
                testutil::OrderBy("19", "asc"),
                testutil::OrderBy("2", "asc"),
                testutil::OrderBy("a", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));

  // nested fields
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("a", "<", 5))
                .AddingFilter(testutil::Filter("aa", ">", 5))
                .AddingFilter(testutil::Filter("a.a", "<=", 5))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("a", "asc"),
                testutil::OrderBy("a.a", "asc"),
                testutil::OrderBy("aa", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));

  // special characters
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("a", "<", 5))
                .AddingFilter(testutil::Filter("_a", ">", 5))
                .AddingFilter(testutil::Filter("a.a", "<=", 5))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("_a", "asc"),
                testutil::OrderBy("a", "asc"),
                testutil::OrderBy("a.a", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));

  // field name with dot
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("a", "<", 5))
                .AddingFilter(testutil::Filter("a.z", ">", 5))
                .AddingFilter(testutil::Filter(("`a.a`"), "<=", 5))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("a", "asc"),
                testutil::OrderBy("a.z", "asc"),
                testutil::OrderBy(("`a.a`"), "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));

  // composite filter
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("a", "<", 5))
                .AddingFilter(
                    AndFilters({OrFilters({testutil::Filter("b", ">=", 1),
                                           testutil::Filter("c", "<=", 0)}),
                                OrFilters({testutil::Filter("d", ">", 3),
                                           testutil::Filter("e", "==", 2)})}))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("a", "asc"),
                testutil::OrderBy("b", "asc"),
                testutil::OrderBy("c", "asc"),
                testutil::OrderBy("d", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));

  // OrderBy
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("b", "<", 5))
                .AddingFilter(testutil::Filter("a", ">", 5))
                .AddingFilter(testutil::Filter(("z"), "<=", 5))
                .AddingOrderBy(testutil::OrderBy("z"))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("z", "asc"),
                testutil::OrderBy("a", "asc"),
                testutil::OrderBy("b", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));

  // last explicit order by direction
  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("b", "<", 5))
                .AddingFilter(testutil::Filter("a", ">", 5))
                .AddingOrderBy(testutil::OrderBy("z", "desc"))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("z", "desc"),
                testutil::OrderBy("a", "desc"),
                testutil::OrderBy("b", "desc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "desc"),
            }));

  ASSERT_EQ(base_query.AddingFilter(testutil::Filter("b", "<", 5))
                .AddingFilter(testutil::Filter("a", ">", 5))
                .AddingOrderBy(testutil::OrderBy("z", "desc"))
                .AddingOrderBy(testutil::OrderBy("c"))
                .normalized_order_bys(),
            (std::vector<OrderBy>{
                testutil::OrderBy("z", "desc"),
                testutil::OrderBy("c", "asc"),
                testutil::OrderBy("a", "asc"),
                testutil::OrderBy("b", "asc"),
                testutil::OrderBy(FieldPath::kDocumentKeyPath, "asc"),
            }));
}

MATCHER_P(HasCanonicalId, expected, "") {
  const std::string& actual = arg.CanonicalId();
  *result_listener << "which has CanonicalId " << actual;
  return actual == expected;
}

TEST(QueryTest, CanonicalIDs) {
  auto query = testutil::Query("coll");
  EXPECT_THAT(query, HasCanonicalId("coll|f:|ob:__name__asc"));

  auto cg = CollectionGroupQuery("foo");
  EXPECT_THAT(cg, HasCanonicalId("|cg:foo|f:|ob:__name__asc"));

  auto subcoll = testutil::Query("foo/bar/baz");
  EXPECT_THAT(subcoll, HasCanonicalId("foo/bar/baz|f:|ob:__name__asc"));

  auto filters = testutil::Query("coll").AddingFilter(
      testutil::Filter("str", "==", "foo"));
  EXPECT_THAT(filters, HasCanonicalId("coll|f:str==foo|ob:__name__asc"));

  // Inequality filters end up in the order by too
  filters = filters.AddingFilter(testutil::Filter("int", "<", 42));
  EXPECT_THAT(filters,
              HasCanonicalId("coll|f:str==fooint<42|ob:intasc__name__asc"));

  // != filter
  filters = testutil::Query("coll").AddingFilter(
      testutil::Filter("str", "!=", "foo"));
  EXPECT_THAT(filters, HasCanonicalId("coll|f:str!=foo|ob:strasc__name__asc"));

  // not-in filter
  filters = testutil::Query("coll").AddingFilter(
      testutil::Filter("a", "not-in", Array(1, 2, 3)));
  EXPECT_THAT(filters,
              HasCanonicalId("coll|f:anot-in[1,2,3]|ob:aasc__name__asc"));

  auto order_bys =
      testutil::Query("coll").AddingOrderBy(testutil::OrderBy("up", "asc"));
  EXPECT_THAT(order_bys, HasCanonicalId("coll|f:|ob:upasc__name__asc"));

  // __name__'s order matches the trailing component
  order_bys = order_bys.AddingOrderBy(testutil::OrderBy("down", "desc"));
  EXPECT_THAT(order_bys,
              HasCanonicalId("coll|f:|ob:upascdowndesc__name__desc"));

  auto limit = testutil::Query("coll").WithLimitToFirst(25);
  EXPECT_THAT(limit, HasCanonicalId("coll|f:|ob:__name__asc|l:25|lt:f"));

  auto bounds = testutil::Query("airports")
                    .AddingOrderBy(testutil::OrderBy("name", "asc"))
                    .AddingOrderBy(testutil::OrderBy("score", "desc"))
                    .StartingAt(Bound::FromValue(Array("OAK", 1000),
                                                 /* inclusive= */ true))
                    .EndingAt(Bound::FromValue(Array("SFO", 2000),
                                               /* inclusive= */ true));
  EXPECT_THAT(bounds, HasCanonicalId("airports|f:|ob:nameascscoredesc__name__"
                                     "desc|lb:b:OAK1000|ub:a:SFO2000"));
}

TEST(QueryTest, MatchesAllDocuments) {
  auto base_query = testutil::Query("coll");
  EXPECT_TRUE(base_query.MatchesAllDocuments());

  auto query = base_query.AddingOrderBy(testutil::OrderBy("__name__"));
  EXPECT_TRUE(query.MatchesAllDocuments());

  query = base_query.AddingOrderBy(testutil::OrderBy("foo"));
  EXPECT_FALSE(query.MatchesAllDocuments());

  query = base_query.AddingFilter(testutil::Filter("foo", "==", "bar"));
  EXPECT_FALSE(query.MatchesAllDocuments());

  query = base_query.WithLimitToFirst(1);
  EXPECT_FALSE(query.MatchesAllDocuments());

  query = base_query.StartingAt(Bound::FromValue(Array("SFO"), true));
  EXPECT_FALSE(query.MatchesAllDocuments());

  query = base_query.StartingAt(Bound::FromValue(Array("OAK"), true));
  EXPECT_FALSE(query.MatchesAllDocuments());
}

TEST(QueryTest, OrderByForAggregateAndNonAggregate) {
  auto col = testutil::Query("coll");

  // Build two identical queries
  auto query1 = col.AddingFilter(testutil::Filter("foo", ">", 1));
  auto query2 = col.AddingFilter(testutil::Filter("foo", ">", 1));

  // Compute an aggregate and non-aggregate target from the queries
  auto aggregateTarget = query1.ToAggregateTarget();
  auto target = query2.ToTarget();

  EXPECT_EQ(aggregateTarget.order_bys().size(), 0);

  ASSERT_EQ(target.order_bys().size(), 2);
  EXPECT_EQ(target.order_bys()[0].direction(), Direction::Ascending);
  EXPECT_EQ(target.order_bys()[0].field().CanonicalString(), "foo");
  EXPECT_EQ(target.order_bys()[1].direction(), Direction::Ascending);
  EXPECT_EQ(target.order_bys()[1].field().CanonicalString(), "__name__");
}

TEST(QueryTest, GeneratedOrderBysNotAffectedByPreviouslyMemoizedTargets) {
  auto col = testutil::Query("coll");

  // Build two identical queries
  auto query1 = col.AddingFilter(testutil::Filter("foo", ">", 1));
  auto query2 = col.AddingFilter(testutil::Filter("foo", ">", 1));

  // query1 - first to aggregate target, then to non-aggregate target
  auto aggregateTarget1 = query1.ToAggregateTarget();
  auto target1 = query1.ToTarget();

  // query2 - first to aggregate target, then to non-aggregate target
  auto target2 = query2.ToTarget();
  auto aggregateTarget2 = query2.ToAggregateTarget();

  EXPECT_EQ(aggregateTarget1.order_bys().size(), 0);

  EXPECT_EQ(aggregateTarget2.order_bys().size(), 0);

  ASSERT_EQ(target1.order_bys().size(), 2);
  EXPECT_EQ(target1.order_bys()[0].direction(), Direction::Ascending);
  EXPECT_EQ(target1.order_bys()[0].field().CanonicalString(), "foo");
  EXPECT_EQ(target1.order_bys()[1].direction(), Direction::Ascending);
  EXPECT_EQ(target1.order_bys()[1].field().CanonicalString(), "__name__");

  ASSERT_EQ(target2.order_bys().size(), 2);
  EXPECT_EQ(target2.order_bys()[0].direction(), Direction::Ascending);
  EXPECT_EQ(target2.order_bys()[0].field().CanonicalString(), "foo");
  EXPECT_EQ(target2.order_bys()[1].direction(), Direction::Ascending);
  EXPECT_EQ(target2.order_bys()[1].field().CanonicalString(), "__name__");
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
