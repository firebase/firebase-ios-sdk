/*
 * Copyright 2017 Google
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

#import <XCTest/XCTest.h>

#include "Firestore/core/src/firebase/firestore/core/direction.h"
#include "Firestore/core/src/firebase/firestore/core/order_by.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "Firestore/core/test/firebase/firestore/testutil/xcgmock.h"
#include "absl/strings/string_view.h"

namespace core = firebase::firestore::core;
namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::core::Bound;
using firebase::firestore::core::Direction;
using firebase::firestore::core::FilterList;
using firebase::firestore::core::OrderByList;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentComparator;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::util::ComparisonResult;

using testing::Not;
using testutil::Array;
using testutil::CollectionGroupQuery;
using testutil::DbId;
using testutil::Doc;
using testutil::Field;
using testutil::Filter;
using testutil::Map;
using testutil::OrderBy;
using testutil::Query;
using testutil::Ref;
using testutil::Value;
using testutil::Vector;

MATCHER_P(Matches, doc, "") {
  bool actual = arg.Matches(doc);
  *result_listener << "matches " << actual;
  return actual == true;
}

NS_ASSUME_NONNULL_BEGIN

@interface FSTQueryTests : XCTestCase
@end

@implementation FSTQueryTests

- (void)testConstructor {
  const ResourcePath path{"rooms", "Firestore", "messages", "0001"};
  core::Query query(path);

  XCTAssertEqual(query.order_bys().size(), 1);
  XCTAssertEqual(query.order_bys()[0].field().CanonicalString(), FieldPath::kDocumentKeyPath);
  XCTAssertEqual(query.order_bys()[0].ascending(), true);

  XCTAssertEqual(query.explicit_order_bys().size(), 0);
}

- (void)testOrderBy {
  core::Query query = Query("rooms/Firestore/messages")
                          .AddingOrderBy(OrderBy(Field("length"), Direction::Descending));

  XCTAssertEqual(query.order_bys().size(), 2);
  XCTAssertEqual(query.order_bys()[0].field().CanonicalString(), "length");
  XCTAssertEqual(query.order_bys()[0].ascending(), false);
  XCTAssertEqual(query.order_bys()[1].field().CanonicalString(), FieldPath::kDocumentKeyPath);
  XCTAssertEqual(query.order_bys()[1].ascending(), false);

  XCTAssertEqual(query.explicit_order_bys().size(), 1);
  XCTAssertEqual(query.explicit_order_bys()[0].field().CanonicalString(), "length");
  XCTAssertEqual(query.explicit_order_bys()[0].ascending(), false);
}

- (void)testMatchesBasedOnDocumentKey {
  auto doc1 = *Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  auto doc2 = *Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  auto doc3 = *Doc("rooms/other/messages/1", 0, Map("text", "msg3"));

  // document query
  core::Query query = Query("rooms/eros/messages/1");
  XC_ASSERT_THAT(query, Matches(doc1));
  XC_ASSERT_THAT(query, Not(Matches(doc2)));
  XC_ASSERT_THAT(query, Not(Matches(doc3)));
}

- (void)testMatchesCorrectlyForShallowAncestorQuery {
  auto doc1 = *Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  auto doc1Meta = *Doc("rooms/eros/messages/1/meta/1", 0, Map("meta", "mv"));
  auto doc2 = *Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  auto doc3 = *Doc("rooms/other/messages/1", 0, Map("text", "msg3"));

  // shallow ancestor query
  core::Query query = Query("rooms/eros/messages");
  XC_ASSERT_THAT(query, Matches(doc1));
  XC_ASSERT_THAT(query, Not(Matches(doc1Meta)));
  XC_ASSERT_THAT(query, Matches(doc2));
  XC_ASSERT_THAT(query, Not(Matches(doc3)));
}

- (void)testEmptyFieldsAreAllowedForQueries {
  auto doc1 = *Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  auto doc2 = *Doc("rooms/eros/messages/2", 0, Map());

  core::Query query = Query("rooms/eros/messages").AddingFilter(Filter("text", "==", "msg1"));
  XC_ASSERT_THAT(query, Matches(doc1));
  XC_ASSERT_THAT(query, Not(Matches(doc2)));
}

- (void)testMatchesPrimitiveValuesForFilters {
  core::Query query1 = Query("collection").AddingFilter(Filter("sort", ">=", 2));
  core::Query query2 = Query("collection").AddingFilter(Filter("sort", "<=", 2));

  auto doc1 = *Doc("collection/1", 0, Map("sort", 1));
  auto doc2 = *Doc("collection/2", 0, Map("sort", 2));
  auto doc3 = *Doc("collection/3", 0, Map("sort", 3));
  auto doc4 = *Doc("collection/4", 0, Map("sort", false));
  auto doc5 = *Doc("collection/5", 0, Map("sort", "string"));
  auto doc6 = *Doc("collection/6", 0, Map());

  XC_ASSERT_THAT(query1, Not(Matches(doc1)));
  XC_ASSERT_THAT(query1, Matches(doc2));
  XC_ASSERT_THAT(query1, Matches(doc3));
  XC_ASSERT_THAT(query1, Not(Matches(doc4)));
  XC_ASSERT_THAT(query1, Not(Matches(doc5)));
  XC_ASSERT_THAT(query1, Not(Matches(doc6)));

  XC_ASSERT_THAT(query2, Matches(doc1));
  XC_ASSERT_THAT(query2, Matches(doc2));
  XC_ASSERT_THAT(query2, Not(Matches(doc3)));
  XC_ASSERT_THAT(query2, Not(Matches(doc4)));
  XC_ASSERT_THAT(query2, Not(Matches(doc5)));
  XC_ASSERT_THAT(query2, Not(Matches(doc6)));
}

- (void)testArrayContainsFilter {
  core::Query query = Query("collection").AddingFilter(Filter("array", "array_contains", 42));

  // not an array.
  auto doc = *Doc("collection/1", 0, Map("array", 1));
  XC_ASSERT_THAT(query, Not(Matches(doc)));

  // empty array.
  doc = *Doc("collection/1", 0, Map("array", Array()));
  XC_ASSERT_THAT(query, Not(Matches(doc)));

  // array without element (and make sure it doesn't match in a nested field or a different field).
  doc = *Doc("collection/1", 0,
             Map("array", Array(41, "42", Map("a", 42, "b", Array(42))), "different", Array(42)));
  XC_ASSERT_THAT(query, Not(Matches(doc)));

  // array with element.
  doc = *Doc("collection/1", 0, Map("array", Array(1, "2", 42, Map("a", 1))));
  XC_ASSERT_THAT(query, Matches(doc));
}

- (void)testArrayContainsFilterWithObjectValue {
  // Search for arrays containing the object { a: [42] }
  core::Query query =
      Query("collection").AddingFilter(Filter("array", "array_contains", Map("a", Array(42))));

  // array without element.
  auto doc = *Doc("collection/1", 0,
                  Map("array", Array(Map("a", 42), Map("a", Array(42, 43)), Map("b", Array(42)),
                                     Map("a", Array(42), "b", 42))));
  XC_ASSERT_THAT(query, Not(Matches(doc)));

  // array with element.
  doc = *Doc("collection/1", 0, Map("array", Array(1, "2", 42, Map("a", Array(42)))));
  XC_ASSERT_THAT(query, Matches(doc));
}

- (void)testNullFilter {
  core::Query query = Query("collection").AddingFilter(Filter("sort", "==", nullptr));
  auto doc1 = *Doc("collection/1", 0, Map("sort", nullptr));
  auto doc2 = *Doc("collection/2", 0, Map("sort", 2));
  auto doc3 = *Doc("collection/2", 0, Map("sort", 3.1));
  auto doc4 = *Doc("collection/4", 0, Map("sort", false));
  auto doc5 = *Doc("collection/5", 0, Map("sort", "string"));

  XC_ASSERT_THAT(query, Matches(doc1));
  XC_ASSERT_THAT(query, Not(Matches(doc2)));
  XC_ASSERT_THAT(query, Not(Matches(doc3)));
  XC_ASSERT_THAT(query, Not(Matches(doc4)));
  XC_ASSERT_THAT(query, Not(Matches(doc5)));
}

- (void)testNanFilter {
  core::Query query = Query("collection").AddingFilter(Filter("sort", "==", NAN));
  auto doc1 = *Doc("collection/1", 0, Map("sort", (NAN)));
  auto doc2 = *Doc("collection/2", 0, Map("sort", 2));
  auto doc3 = *Doc("collection/2", 0, Map("sort", 3.1));
  auto doc4 = *Doc("collection/4", 0, Map("sort", false));
  auto doc5 = *Doc("collection/5", 0, Map("sort", "string"));

  XC_ASSERT_THAT(query, Matches(doc1));
  XC_ASSERT_THAT(query, Not(Matches(doc2)));
  XC_ASSERT_THAT(query, Not(Matches(doc3)));
  XC_ASSERT_THAT(query, Not(Matches(doc4)));
  XC_ASSERT_THAT(query, Not(Matches(doc5)));
}

- (void)testDoesNotMatchComplexObjectsForFilters {
  core::Query query1 = Query("collection").AddingFilter(Filter("sort", "<=", 2));
  core::Query query2 = Query("collection").AddingFilter(Filter("sort", ">=", 2));

  auto doc1 = *Doc("collection/1", 0, Map("sort", 2));
  auto doc2 = *Doc("collection/2", 0, Map("sort", Array()));
  auto doc3 = *Doc("collection/3", 0, Map("sort", Array(1)));
  auto doc4 = *Doc("collection/4", 0, Map("sort", Map("foo", 2)));
  auto doc5 = *Doc("collection/5", 0, Map("sort", Map("foo", "bar")));
  auto doc6 = *Doc("collection/6", 0, Map("sort", Map()));  // no sort field
  auto doc7 = *Doc("collection/7", 0, Map("sort", Array(3, 1)));

  XC_ASSERT_THAT(query1, Matches(doc1));
  XC_ASSERT_THAT(query1, Not(Matches(doc2)));
  XC_ASSERT_THAT(query1, Not(Matches(doc3)));
  XC_ASSERT_THAT(query1, Not(Matches(doc4)));
  XC_ASSERT_THAT(query1, Not(Matches(doc5)));
  XC_ASSERT_THAT(query1, Not(Matches(doc6)));
  XC_ASSERT_THAT(query1, Not(Matches(doc7)));

  XC_ASSERT_THAT(query2, Matches(doc1));
  XC_ASSERT_THAT(query2, Not(Matches(doc2)));
  XC_ASSERT_THAT(query2, Not(Matches(doc3)));
  XC_ASSERT_THAT(query2, Not(Matches(doc4)));
  XC_ASSERT_THAT(query2, Not(Matches(doc5)));
  XC_ASSERT_THAT(query2, Not(Matches(doc6)));
  XC_ASSERT_THAT(query2, Not(Matches(doc7)));
}

- (void)testDoesntRemoveComplexObjectsWithOrderBy {
  core::Query query1 = Query("collection").AddingOrderBy(OrderBy("sort", "asc"));

  auto doc1 = *Doc("collection/1", 0, Map("sort", 2));
  auto doc2 = *Doc("collection/2", 0, Map("sort", Array()));
  auto doc3 = *Doc("collection/3", 0, Map("sort", Array(1)));
  auto doc4 = *Doc("collection/4", 0, Map("sort", Map("foo", 2)));
  auto doc5 = *Doc("collection/5", 0, Map("sort", Map("foo", "bar")));
  auto doc6 = *Doc("collection/6", 0, Map());

  XC_ASSERT_THAT(query1, Matches(doc1));
  XC_ASSERT_THAT(query1, Matches(doc2));
  XC_ASSERT_THAT(query1, Matches(doc3));
  XC_ASSERT_THAT(query1, Matches(doc4));
  XC_ASSERT_THAT(query1, Matches(doc5));
  XC_ASSERT_THAT(query1, Not(Matches(doc6)));
}

- (void)testFiltersBasedOnArrayValue {
  core::Query baseQuery = Query("collection");
  auto doc1 = *Doc("collection/doc", 0, Map("tags", Array("foo", 1, true)));

  FilterList matchingFilters = {Filter("tags", "==", Array("foo", 1, true))};

  FilterList nonMatchingFilters = {
      Filter("tags", "==", "foo"),
      Filter("tags", "==", Array("foo", 1)),
      Filter("tags", "==", Array("foo", true, 1)),
  };

  for (const auto &filter : matchingFilters) {
    XCTAssertTrue(baseQuery.AddingFilter(filter).Matches(doc1));
  }

  for (const auto &filter : nonMatchingFilters) {
    XCTAssertFalse(baseQuery.AddingFilter(filter).Matches(doc1));
  }
}

- (void)testFiltersBasedOnObjectValue {
  core::Query baseQuery = Query("collection");
  auto doc1 =
      *Doc("collection/doc", 0, Map("tags", Map("foo", "foo", "a", 0, "b", true, "c", NAN)));

  FilterList matchingFilters = {
      Filter("tags", "==", Map("foo", "foo", "a", 0, "b", true, "c", NAN)),
      Filter("tags", "==", Map("b", true, "a", 0, "foo", "foo", "c", NAN)),
      Filter("tags.foo", "==", "foo")};

  FilterList nonMatchingFilters = {Filter("tags", "==", "foo"),
                                   Filter("tags", "==", Map("foo", "foo", "a", 0, "b", true))};

  for (const auto &filter : matchingFilters) {
    XCTAssertTrue(baseQuery.AddingFilter(filter).Matches(doc1));
  }

  for (const auto &filter : nonMatchingFilters) {
    XCTAssertFalse(baseQuery.AddingFilter(filter).Matches(doc1));
  }
}

/**
 * Checks that an ordered array of elements yields the correct pair-wise comparison result for the
 * supplied comparator.
 */
- (void)assertCorrectComparisonsWithArray:(std::vector<Document>)array
                               comparator:(const DocumentComparator &)comp {
  for (size_t i = 0; i < array.size(); i++) {
    for (size_t j = 0; j < array.size(); j++) {
      const Document &iDoc = array[i];
      const Document &jDoc = array[j];
      ComparisonResult expected = util::Compare(i, j);
      ComparisonResult actual = comp.Compare(iDoc, jDoc);
      XCTAssertEqual(actual, expected, @"Compared %@ to %@ at (%lu, %lu).", iDoc.ToDocument(),
                     jDoc.ToDocument(), (unsigned long)i, (unsigned long)j);
    }
  }
}

- (void)testSortsDocumentsInTheCorrectOrder {
  core::Query query = Query("collection").AddingOrderBy(OrderBy("sort"));

  // clang-format off
  std::vector<Document> docs = {
      *Doc("collection/1", 0, Map("sort", nullptr)),
      *Doc("collection/1", 0, Map("sort", false)),
      *Doc("collection/1", 0, Map("sort", true)),
      *Doc("collection/1", 0, Map("sort", 1)),
      *Doc("collection/2", 0, Map("sort", 1)),  // by key
      *Doc("collection/3", 0, Map("sort", 1)),  // by key
      *Doc("collection/1", 0, Map("sort", 1.9)),
      *Doc("collection/1", 0, Map("sort", 2)),
      *Doc("collection/1", 0, Map("sort", 2.1)),
      *Doc("collection/1", 0, Map("sort", "")),
      *Doc("collection/1", 0, Map("sort", "a")),
      *Doc("collection/1", 0, Map("sort", "ab")),
      *Doc("collection/1", 0, Map("sort", "b")),
      *Doc("collection/1", 0, Map("sort", Ref("project", "collection/id1"))),
  };
  // clang-format on

  [self assertCorrectComparisonsWithArray:docs comparator:query.Comparator()];
}

- (void)testSortsDocumentsUsingMultipleFields {
  core::Query query =
      Query("collection").AddingOrderBy(OrderBy("sort1")).AddingOrderBy(OrderBy("sort2"));

  // clang-format off
  std::vector<Document> docs = {
      *Doc("collection/1", 0, Map("sort1", 1, "sort2", 1)),
      *Doc("collection/1", 0, Map("sort1", 1, "sort2", 2)),
      *Doc("collection/2", 0, Map("sort1", 1, "sort2", 2)),  // by key
      *Doc("collection/3", 0, Map("sort1", 1, "sort2", 2)),  // by key
      *Doc("collection/1", 0, Map("sort1", 1, "sort2", 3)),
      *Doc("collection/1", 0, Map("sort1", 2, "sort2", 1)),
      *Doc("collection/1", 0, Map("sort1", 2, "sort2", 2)),
      *Doc("collection/2", 0, Map("sort1", 2, "sort2", 2)),  // by key
      *Doc("collection/3", 0, Map("sort1", 2, "sort2", 2)),  // by key
      *Doc("collection/1", 0, Map("sort1", 2, "sort2", 3)),
  };
  // clang-format on

  [self assertCorrectComparisonsWithArray:docs comparator:query.Comparator()];
}

- (void)testSortsDocumentsWithDescendingToo {
  core::Query query = Query("collection")
                          .AddingOrderBy(OrderBy("sort1", "desc"))
                          .AddingOrderBy(OrderBy("sort2", "desc"));

  // clang-format off
  std::vector<Document> docs = {
      *Doc("collection/1", 0, Map("sort1", 2, "sort2", 3)),
      *Doc("collection/3", 0, Map("sort1", 2, "sort2", 2)),
      *Doc("collection/2", 0, Map("sort1", 2, "sort2", 2)),  // by key
      *Doc("collection/1", 0, Map("sort1", 2, "sort2", 2)),  // by key
      *Doc("collection/1", 0, Map("sort1", 2, "sort2", 1)),
      *Doc("collection/1", 0, Map("sort1", 1, "sort2", 3)),
      *Doc("collection/3", 0, Map("sort1", 1, "sort2", 2)),
      *Doc("collection/2", 0, Map("sort1", 1, "sort2", 2)),  // by key
      *Doc("collection/1", 0, Map("sort1", 1, "sort2", 2)),  // by key
      *Doc("collection/1", 0, Map("sort1", 1, "sort2", 1)),
  };
  // clang-format on

  [self assertCorrectComparisonsWithArray:docs comparator:query.Comparator()];
}

- (void)testEquality {
  core::Query q11 =
      Query("foo").AddingFilter(Filter("i1", "<", 2)).AddingFilter(Filter("i2", "==", 3));
  core::Query q12 =
      Query("foo").AddingFilter(Filter("i2", "==", 3)).AddingFilter(Filter("i1", "<", 2));

  core::Query q21 = Query("foo");
  core::Query q22 = Query("foo");

  core::Query q31 = Query("foo/bar");
  core::Query q32 = Query("foo/bar");

  core::Query q41 =
      Query("foo").AddingOrderBy(OrderBy("foo", "asc")).AddingOrderBy(OrderBy("bar", "asc"));
  core::Query q42 =
      Query("foo").AddingOrderBy(OrderBy("foo", "asc")).AddingOrderBy(OrderBy("bar", "asc"));
  core::Query q43Diff =
      Query("foo").AddingOrderBy(OrderBy("bar", "asc")).AddingOrderBy(OrderBy("foo", "asc"));

  core::Query q51 =
      Query("foo").AddingOrderBy(OrderBy("foo", "asc")).AddingFilter(Filter("foo", ">", 2));
  core::Query q52 =
      Query("foo").AddingFilter(Filter("foo", ">", 2)).AddingOrderBy(OrderBy("foo", "asc"));
  core::Query q53Diff =
      Query("foo").AddingFilter(Filter("bar", ">", 2)).AddingOrderBy(OrderBy("bar", "asc"));

  core::Query q61 = Query("foo").WithLimit(10);

  // XCTAssertEqual(q11, q12);  // TODO(klimt): not canonical yet
  XCTAssertNotEqual(q11, q21);
  XCTAssertNotEqual(q11, q31);
  XCTAssertNotEqual(q11, q41);
  XCTAssertNotEqual(q11, q51);
  XCTAssertNotEqual(q11, q61);

  XCTAssertEqual(q21, q22);
  XCTAssertNotEqual(q21, q31);
  XCTAssertNotEqual(q21, q41);
  XCTAssertNotEqual(q21, q51);
  XCTAssertNotEqual(q21, q61);

  XCTAssertEqual(q31, q32);
  XCTAssertNotEqual(q31, q41);
  XCTAssertNotEqual(q31, q51);
  XCTAssertNotEqual(q31, q61);

  XCTAssertEqual(q41, q42);
  XCTAssertNotEqual(q41, q43Diff);
  XCTAssertNotEqual(q41, q51);
  XCTAssertNotEqual(q41, q61);

  XCTAssertEqual(q51, q52);
  XCTAssertNotEqual(q51, q53Diff);
  XCTAssertNotEqual(q51, q61);
}

- (void)testUniqueIds {
  core::Query q11 =
      Query("foo").AddingFilter(Filter("i1", "<", 2)).AddingFilter(Filter("i2", "==", 3));
  core::Query q12 =
      Query("foo").AddingFilter(Filter("i2", "==", 3)).AddingFilter(Filter("i1", "<", 2));

  core::Query q21 = Query("foo");
  core::Query q22 = Query("foo");

  core::Query q31 = Query("foo/bar");
  core::Query q32 = Query("foo/bar");

  core::Query q41 =
      Query("foo").AddingOrderBy(OrderBy("foo", "asc")).AddingOrderBy(OrderBy("bar", "asc"));
  core::Query q42 =
      Query("foo").AddingOrderBy(OrderBy("foo", "asc")).AddingOrderBy(OrderBy("bar", "asc"));
  core::Query q43Diff =
      Query("foo").AddingOrderBy(OrderBy("bar", "asc")).AddingOrderBy(OrderBy("foo", "asc"));

  core::Query q51 =
      Query("foo").AddingOrderBy(OrderBy("foo", "asc")).AddingFilter(Filter("foo", ">", 2));
  core::Query q52 =
      Query("foo").AddingFilter(Filter("foo", ">", 2)).AddingOrderBy(OrderBy("foo", "asc"));
  core::Query q53Diff =
      Query("foo").AddingFilter(Filter("bar", ">", 2)).AddingOrderBy(OrderBy("bar", "asc"));

  core::Query q61 = Query("foo").WithLimit(10);

  // XCTAssertEqual(q11.Hash(), q12.Hash());  // TODO(klimt): not canonical yet
  XCTAssertNotEqual(q11.Hash(), q21.Hash());
  XCTAssertNotEqual(q11.Hash(), q31.Hash());
  XCTAssertNotEqual(q11.Hash(), q41.Hash());
  XCTAssertNotEqual(q11.Hash(), q51.Hash());
  XCTAssertNotEqual(q11.Hash(), q61.Hash());

  XCTAssertEqual(q21.Hash(), q22.Hash());
  XCTAssertNotEqual(q21.Hash(), q31.Hash());
  XCTAssertNotEqual(q21.Hash(), q41.Hash());
  XCTAssertNotEqual(q21.Hash(), q51.Hash());
  XCTAssertNotEqual(q21.Hash(), q61.Hash());

  XCTAssertEqual(q31.Hash(), q32.Hash());
  XCTAssertNotEqual(q31.Hash(), q41.Hash());
  XCTAssertNotEqual(q31.Hash(), q51.Hash());
  XCTAssertNotEqual(q31.Hash(), q61.Hash());

  XCTAssertEqual(q41.Hash(), q42.Hash());
  XCTAssertNotEqual(q41.Hash(), q43Diff.Hash());
  XCTAssertNotEqual(q41.Hash(), q51.Hash());
  XCTAssertNotEqual(q41.Hash(), q61.Hash());

  XCTAssertEqual(q51.Hash(), q52.Hash());
  XCTAssertNotEqual(q51.Hash(), q53Diff.Hash());
  XCTAssertNotEqual(q51.Hash(), q61.Hash());
}

- (void)testImplicitOrderBy {
  core::Query baseQuery = Query("foo");
  // Default is ascending
  XCTAssertEqual(baseQuery.order_bys(), OrderByList{OrderBy(FieldPath::kDocumentKeyPath, "asc")});

  // Explicit key ordering is respected
  XCTAssertEqual(baseQuery.AddingOrderBy(OrderBy(FieldPath::kDocumentKeyPath, "asc")).order_bys(),
                 OrderByList{OrderBy(FieldPath::kDocumentKeyPath, "asc")});
  XCTAssertEqual(baseQuery.AddingOrderBy(OrderBy(FieldPath::kDocumentKeyPath, "desc")).order_bys(),
                 OrderByList{OrderBy(FieldPath::kDocumentKeyPath, "desc")});

  XCTAssertEqual(baseQuery.AddingOrderBy(OrderBy("foo", "asc"))
                     .AddingOrderBy(OrderBy(FieldPath::kDocumentKeyPath, "asc"))
                     .order_bys(),
                 (OrderByList{OrderBy("foo", "asc"), OrderBy(FieldPath::kDocumentKeyPath, "asc")}));

  XCTAssertEqual(
      baseQuery.AddingOrderBy(OrderBy("foo", "asc"))
          .AddingOrderBy(OrderBy(FieldPath::kDocumentKeyPath, "desc"))
          .order_bys(),
      (OrderByList{OrderBy("foo", "asc"), OrderBy(FieldPath::kDocumentKeyPath, "desc")}));

  // Inequality filters add order bys
  XCTAssertEqual(baseQuery.AddingFilter(Filter("foo", "<", 5)).order_bys(),
                 (OrderByList{OrderBy("foo", "asc"), OrderBy(FieldPath::kDocumentKeyPath, "asc")}));

  // Descending order by applies to implicit key ordering
  XCTAssertEqual(
      baseQuery.AddingOrderBy(OrderBy("foo", "desc")).order_bys(),
      (OrderByList{OrderBy("foo", "desc"), OrderBy(FieldPath::kDocumentKeyPath, "desc")}));
  XCTAssertEqual(baseQuery.AddingOrderBy(OrderBy("foo", "asc"))
                     .AddingOrderBy(OrderBy("bar", "desc"))
                     .order_bys(),
                 (OrderByList{
                     OrderBy("foo", "asc"),
                     OrderBy("bar", "desc"),
                     OrderBy(FieldPath::kDocumentKeyPath, "desc"),
                 }));
  XCTAssertEqual(baseQuery.AddingOrderBy(OrderBy("foo", "desc"))
                     .AddingOrderBy(OrderBy("bar", "asc"))
                     .order_bys(),
                 (OrderByList{
                     OrderBy("foo", "desc"),
                     OrderBy("bar", "asc"),
                     OrderBy(FieldPath::kDocumentKeyPath, "asc"),
                 }));
}

MATCHER_P(HasCanonicalId, expected, "") {
  const std::string &actual = arg.CanonicalId();
  *result_listener << "which has canonicalID " << actual;
  return actual == expected;
}

- (void)testCanonicalIDs {
  core::Query query = Query("coll");
  XC_ASSERT_THAT(query, HasCanonicalId("coll|f:|ob:__name__asc"));

  core::Query cg = CollectionGroupQuery("foo");
  XC_ASSERT_THAT(cg, HasCanonicalId("|cg:foo|f:|ob:__name__asc"));

  core::Query subcoll = Query("foo/bar/baz");
  XC_ASSERT_THAT(subcoll, HasCanonicalId("foo/bar/baz|f:|ob:__name__asc"));

  core::Query filters = Query("coll").AddingFilter(Filter("str", "==", "foo"));
  XC_ASSERT_THAT(filters, HasCanonicalId("coll|f:str==foo|ob:__name__asc"));

  // Inequality filters end up in the order by too
  filters = filters.AddingFilter(Filter("int", "<", 42));
  XC_ASSERT_THAT(filters, HasCanonicalId("coll|f:str==fooint<42|ob:intasc__name__asc"));

  core::Query orderBys = Query("coll").AddingOrderBy(OrderBy("up", "asc"));
  XC_ASSERT_THAT(orderBys, HasCanonicalId("coll|f:|ob:upasc__name__asc"));

  // __name__'s order matches the trailing component
  orderBys = orderBys.AddingOrderBy(OrderBy("down", "desc"));
  XC_ASSERT_THAT(orderBys, HasCanonicalId("coll|f:|ob:upascdowndesc__name__desc"));

  core::Query limit = Query("coll").WithLimit(25);
  XC_ASSERT_THAT(limit, HasCanonicalId("coll|f:|ob:__name__asc|l:25"));

  core::Query bounds = Query("airports")
                           .AddingOrderBy(OrderBy("name", "asc"))
                           .AddingOrderBy(OrderBy("score", "desc"))
                           .StartingAt(Bound({Value("OAK"), Value(1000)}, /* is_before= */ true))
                           .EndingAt(Bound({Value("SFO"), Value(2000)}, /* is_before= */ false));
  XC_ASSERT_THAT(
      bounds,
      HasCanonicalId("airports|f:|ob:nameascscoredesc__name__desc|lb:b:OAK1000|ub:a:SFO2000"));
}

@end

NS_ASSUME_NONNULL_END
