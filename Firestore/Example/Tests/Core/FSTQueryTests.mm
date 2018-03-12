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

#import "Firestore/Source/Core/FSTQuery.h"

#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/field_path.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldPath;
using firebase::firestore::model::ResourcePath;

NS_ASSUME_NONNULL_BEGIN

/** Convenience methods for building test queries. */
@interface FSTQuery (Tests)
- (FSTQuery *)queryByAddingSortBy:(NSString *)key ascending:(BOOL)ascending;
@end

@implementation FSTQuery (Tests)

- (FSTQuery *)queryByAddingSortBy:(NSString *)key ascending:(BOOL)ascending {
  return [self
      queryByAddingSortOrder:[FSTSortOrder
                                 sortOrderWithFieldPath:testutil::Field(util::MakeStringView(key))
                                              ascending:ascending]];
}

@end

@interface FSTQueryTests : XCTestCase
@end

@implementation FSTQueryTests

- (void)testConstructor {
  FSTResourcePath *path =
      [FSTResourcePath pathWithSegments:@[ @"rooms", @"Firestore", @"messages", @"0001" ]];
  FSTQuery *query = [FSTQuery queryWithPath:[path toCPPResourcePath]];
  XCTAssertNotNil(query);

  XCTAssertEqual(query.sortOrders.count, 1);
  XCTAssertEqual(query.sortOrders[0].field.CanonicalString(), FieldPath::kDocumentKeyPath);
  XCTAssertEqual(query.sortOrders[0].ascending, YES);

  XCTAssertEqual(query.explicitSortOrders.count, 0);
}

- (void)testOrderBy {
  FSTQuery *query = FSTTestQuery(@"rooms/Firestore/messages");
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("length")
                                                               ascending:NO]];

  XCTAssertEqual(query.sortOrders.count, 2);
  XCTAssertEqual(query.sortOrders[0].field.CanonicalString(), "length");
  XCTAssertEqual(query.sortOrders[0].ascending, NO);
  XCTAssertEqual(query.sortOrders[1].field.CanonicalString(), FieldPath::kDocumentKeyPath);
  XCTAssertEqual(query.sortOrders[1].ascending, NO);

  XCTAssertEqual(query.explicitSortOrders.count, 1);
  XCTAssertEqual(query.explicitSortOrders[0].field.CanonicalString(), "length");
  XCTAssertEqual(query.explicitSortOrders[0].ascending, NO);
}

- (void)testMatchesBasedOnDocumentKey {
  FSTDocument *doc1 = FSTTestDoc(@"rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, NO);
  FSTDocument *doc3 = FSTTestDoc(@"rooms/other/messages/1", 0, @{@"text" : @"msg3"}, NO);

  // document query
  FSTQuery *query = FSTTestQuery(@"rooms/eros/messages/1");
  XCTAssertTrue([query matchesDocument:doc1]);
  XCTAssertFalse([query matchesDocument:doc2]);
  XCTAssertFalse([query matchesDocument:doc3]);
}

- (void)testMatchesCorrectlyForShallowAncestorQuery {
  FSTDocument *doc1 = FSTTestDoc(@"rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, NO);
  FSTDocument *doc1Meta = FSTTestDoc(@"rooms/eros/messages/1/meta/1", 0, @{@"meta" : @"mv"}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, NO);
  FSTDocument *doc3 = FSTTestDoc(@"rooms/other/messages/1", 0, @{@"text" : @"msg3"}, NO);

  // shallow ancestor query
  FSTQuery *query = FSTTestQuery(@"rooms/eros/messages");
  XCTAssertTrue([query matchesDocument:doc1]);
  XCTAssertFalse([query matchesDocument:doc1Meta]);
  XCTAssertTrue([query matchesDocument:doc2]);
  XCTAssertFalse([query matchesDocument:doc3]);
}

- (void)testEmptyFieldsAreAllowedForQueries {
  FSTDocument *doc1 = FSTTestDoc(@"rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"rooms/eros/messages/2", 0, @{}, NO);

  FSTQuery *query = [FSTTestQuery(@"rooms/eros/messages")
      queryByAddingFilter:FSTTestFilter(@"text", @"==", @"msg1")];
  XCTAssertTrue([query matchesDocument:doc1]);
  XCTAssertFalse([query matchesDocument:doc2]);
}

- (void)testMatchesPrimitiveValuesForFilters {
  FSTQuery *query1 =
      [FSTTestQuery(@"collection") queryByAddingFilter:FSTTestFilter(@"sort", @">=", @(2))];
  FSTQuery *query2 =
      [FSTTestQuery(@"collection") queryByAddingFilter:FSTTestFilter(@"sort", @"<=", @(2))];

  FSTDocument *doc1 = FSTTestDoc(@"collection/1", 0, @{ @"sort" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"collection/2", 0, @{ @"sort" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc(@"collection/3", 0, @{ @"sort" : @3 }, NO);
  FSTDocument *doc4 = FSTTestDoc(@"collection/4", 0, @{ @"sort" : @NO }, NO);
  FSTDocument *doc5 = FSTTestDoc(@"collection/5", 0, @{@"sort" : @"string"}, NO);
  FSTDocument *doc6 = FSTTestDoc(@"collection/6", 0, @{}, NO);

  XCTAssertFalse([query1 matchesDocument:doc1]);
  XCTAssertTrue([query1 matchesDocument:doc2]);
  XCTAssertTrue([query1 matchesDocument:doc3]);
  XCTAssertFalse([query1 matchesDocument:doc4]);
  XCTAssertFalse([query1 matchesDocument:doc5]);
  XCTAssertFalse([query1 matchesDocument:doc6]);

  XCTAssertTrue([query2 matchesDocument:doc1]);
  XCTAssertTrue([query2 matchesDocument:doc2]);
  XCTAssertFalse([query2 matchesDocument:doc3]);
  XCTAssertFalse([query2 matchesDocument:doc4]);
  XCTAssertFalse([query2 matchesDocument:doc5]);
  XCTAssertFalse([query2 matchesDocument:doc6]);
}

- (void)testNullFilter {
  FSTQuery *query = [FSTTestQuery(@"collection")
      queryByAddingFilter:FSTTestFilter(@"sort", @"==", [NSNull null])];
  FSTDocument *doc1 = FSTTestDoc(@"collection/1", 0, @{@"sort" : [NSNull null]}, NO);
  FSTDocument *doc2 = FSTTestDoc(@"collection/2", 0, @{ @"sort" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc(@"collection/2", 0, @{ @"sort" : @3.1 }, NO);
  FSTDocument *doc4 = FSTTestDoc(@"collection/4", 0, @{ @"sort" : @NO }, NO);
  FSTDocument *doc5 = FSTTestDoc(@"collection/5", 0, @{@"sort" : @"string"}, NO);

  XCTAssertTrue([query matchesDocument:doc1]);
  XCTAssertFalse([query matchesDocument:doc2]);
  XCTAssertFalse([query matchesDocument:doc3]);
  XCTAssertFalse([query matchesDocument:doc4]);
  XCTAssertFalse([query matchesDocument:doc5]);
}

- (void)testNanFilter {
  FSTQuery *query =
      [FSTTestQuery(@"collection") queryByAddingFilter:FSTTestFilter(@"sort", @"==", @(NAN))];
  FSTDocument *doc1 = FSTTestDoc(@"collection/1", 0, @{ @"sort" : @(NAN) }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"collection/2", 0, @{ @"sort" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc(@"collection/2", 0, @{ @"sort" : @3.1 }, NO);
  FSTDocument *doc4 = FSTTestDoc(@"collection/4", 0, @{ @"sort" : @NO }, NO);
  FSTDocument *doc5 = FSTTestDoc(@"collection/5", 0, @{@"sort" : @"string"}, NO);

  XCTAssertTrue([query matchesDocument:doc1]);
  XCTAssertFalse([query matchesDocument:doc2]);
  XCTAssertFalse([query matchesDocument:doc3]);
  XCTAssertFalse([query matchesDocument:doc4]);
  XCTAssertFalse([query matchesDocument:doc5]);
}

- (void)testDoesNotMatchComplexObjectsForFilters {
  FSTQuery *query1 =
      [FSTTestQuery(@"collection") queryByAddingFilter:FSTTestFilter(@"sort", @"<=", @(2))];
  FSTQuery *query2 =
      [FSTTestQuery(@"collection") queryByAddingFilter:FSTTestFilter(@"sort", @">=", @(2))];

  FSTDocument *doc1 = FSTTestDoc(@"collection/1", 0, @{ @"sort" : @2 }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"collection/2", 0, @{ @"sort" : @[] }, NO);
  FSTDocument *doc3 = FSTTestDoc(@"collection/3", 0, @{ @"sort" : @[ @1 ] }, NO);
  FSTDocument *doc4 = FSTTestDoc(@"collection/4", 0, @{ @"sort" : @{@"foo" : @2} }, NO);
  FSTDocument *doc5 = FSTTestDoc(@"collection/5", 0, @{ @"sort" : @{@"foo" : @"bar"} }, NO);
  FSTDocument *doc6 = FSTTestDoc(@"collection/6", 0, @{ @"sort" : @{} }, NO);  // no sort field
  FSTDocument *doc7 = FSTTestDoc(@"collection/7", 0, @{ @"sort" : @[ @3, @1 ] }, NO);

  XCTAssertTrue([query1 matchesDocument:doc1]);
  XCTAssertFalse([query1 matchesDocument:doc2]);
  XCTAssertFalse([query1 matchesDocument:doc3]);
  XCTAssertFalse([query1 matchesDocument:doc4]);
  XCTAssertFalse([query1 matchesDocument:doc5]);
  XCTAssertFalse([query1 matchesDocument:doc6]);
  XCTAssertFalse([query1 matchesDocument:doc7]);

  XCTAssertTrue([query2 matchesDocument:doc1]);
  XCTAssertFalse([query2 matchesDocument:doc2]);
  XCTAssertFalse([query2 matchesDocument:doc3]);
  XCTAssertFalse([query2 matchesDocument:doc4]);
  XCTAssertFalse([query2 matchesDocument:doc5]);
  XCTAssertFalse([query2 matchesDocument:doc6]);
  XCTAssertFalse([query2 matchesDocument:doc7]);
}

- (void)testDoesntRemoveComplexObjectsWithOrderBy {
  FSTQuery *query1 = [FSTTestQuery(@"collection")
      queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("sort")
                                                        ascending:YES]];

  FSTDocument *doc1 = FSTTestDoc(@"collection/1", 0, @{ @"sort" : @2 }, NO);
  FSTDocument *doc2 = FSTTestDoc(@"collection/2", 0, @{ @"sort" : @[] }, NO);
  FSTDocument *doc3 = FSTTestDoc(@"collection/3", 0, @{ @"sort" : @[ @1 ] }, NO);
  FSTDocument *doc4 = FSTTestDoc(@"collection/4", 0, @{ @"sort" : @{@"foo" : @2} }, NO);
  FSTDocument *doc5 = FSTTestDoc(@"collection/5", 0, @{ @"sort" : @{@"foo" : @"bar"} }, NO);
  FSTDocument *doc6 = FSTTestDoc(@"collection/6", 0, @{}, NO);

  XCTAssertTrue([query1 matchesDocument:doc1]);
  XCTAssertTrue([query1 matchesDocument:doc2]);
  XCTAssertTrue([query1 matchesDocument:doc3]);
  XCTAssertTrue([query1 matchesDocument:doc4]);
  XCTAssertTrue([query1 matchesDocument:doc5]);
  XCTAssertFalse([query1 matchesDocument:doc6]);
}

- (void)testFiltersBasedOnArrayValue {
  FSTQuery *baseQuery = FSTTestQuery(@"collection");
  FSTDocument *doc1 = FSTTestDoc(@"collection/doc", 0, @{ @"tags" : @[ @"foo", @1, @YES ] }, NO);

  NSArray<id<FSTFilter>> *matchingFilters =
      @[ FSTTestFilter(@"tags", @"==", @[ @"foo", @1, @YES ]) ];

  NSArray<id<FSTFilter>> *nonMatchingFilters = @[
    FSTTestFilter(@"tags", @"==", @"foo"),
    FSTTestFilter(@"tags", @"==", @[ @"foo", @1 ]),
    FSTTestFilter(@"tags", @"==", @[ @"foo", @YES, @1 ]),
  ];

  for (id<FSTFilter> filter in matchingFilters) {
    XCTAssertTrue([[baseQuery queryByAddingFilter:filter] matchesDocument:doc1]);
  }

  for (id<FSTFilter> filter in nonMatchingFilters) {
    XCTAssertFalse([[baseQuery queryByAddingFilter:filter] matchesDocument:doc1]);
  }
}

- (void)testFiltersBasedOnObjectValue {
  FSTQuery *baseQuery = FSTTestQuery(@"collection");
  FSTDocument *doc1 =
      FSTTestDoc(@"collection/doc", 0,
                 @{ @"tags" : @{@"foo" : @"foo", @"a" : @0, @"b" : @YES, @"c" : @(NAN)} }, NO);

  NSArray<id<FSTFilter>> *matchingFilters = @[
    FSTTestFilter(@"tags", @"==",
                  @{ @"foo" : @"foo",
                     @"a" : @0,
                     @"b" : @YES,
                     @"c" : @(NAN) }),
    FSTTestFilter(@"tags", @"==",
                  @{ @"b" : @YES,
                     @"a" : @0,
                     @"foo" : @"foo",
                     @"c" : @(NAN) }),
    FSTTestFilter(@"tags.foo", @"==", @"foo")
  ];

  NSArray<id<FSTFilter>> *nonMatchingFilters = @[
    FSTTestFilter(@"tags", @"==", @"foo"), FSTTestFilter(@"tags", @"==", @{
      @"foo" : @"foo",
      @"a" : @0,
      @"b" : @YES,
    })
  ];

  for (id<FSTFilter> filter in matchingFilters) {
    XCTAssertTrue([[baseQuery queryByAddingFilter:filter] matchesDocument:doc1]);
  }

  for (id<FSTFilter> filter in nonMatchingFilters) {
    XCTAssertFalse([[baseQuery queryByAddingFilter:filter] matchesDocument:doc1]);
  }
}

/**
 * Checks that an ordered array of elements yields the correct pair-wise comparison result for the
 * supplied comparator.
 */
- (void)assertCorrectComparisonsWithArray:(NSArray *)array comparator:(NSComparator)comp {
  [array enumerateObjectsUsingBlock:^(id iObj, NSUInteger i, BOOL *outerStop) {
    [array enumerateObjectsUsingBlock:^(id _Nonnull jObj, NSUInteger j, BOOL *innerStop) {
      NSComparisonResult expected = [@(i) compare:@(j)];
      NSComparisonResult actual = comp(iObj, jObj);
      XCTAssertEqual(actual, expected, @"Compared %@ to %@ at (%lu, %lu).", iObj, jObj,
                     (unsigned long)i, (unsigned long)j);
    }];
  }];
}

- (void)testSortsDocumentsInTheCorrectOrder {
  FSTQuery *query = FSTTestQuery(@"collection");
  query = [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("sort")
                                                                   ascending:YES]];

  // clang-format off
  NSArray<FSTDocument *> *docs = @[
      FSTTestDoc(@"collection/1", 0, @{@"sort": [NSNull null]}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @NO}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @YES}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @1}, NO),
      FSTTestDoc(@"collection/2", 0, @{@"sort": @1}, NO),  // by key
      FSTTestDoc(@"collection/3", 0, @{@"sort": @1}, NO),  // by key
      FSTTestDoc(@"collection/1", 0, @{@"sort": @1.9}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @2}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @2.1}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @""}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @"a"}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @"ab"}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort": @"b"}, NO),
      FSTTestDoc(@"collection/1", 0, @{@"sort":
          FSTTestRef("project", DatabaseId::kDefault, @"collection/id1")}, NO),
  ];
  // clang-format on

  [self assertCorrectComparisonsWithArray:docs comparator:query.comparator];
}

- (void)testSortsDocumentsUsingMultipleFields {
  FSTQuery *query = FSTTestQuery(@"collection");
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("sort1")
                                                               ascending:YES]];
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("sort2")
                                                               ascending:YES]];

  // clang-format off
  NSArray<FSTDocument *> *docs =
      @[FSTTestDoc(@"collection/1", 0, @{@"sort1": @1, @"sort2": @1}, NO),
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @1, @"sort2": @2}, NO),
        FSTTestDoc(@"collection/2", 0, @{@"sort1": @1, @"sort2": @2}, NO),  // by key
        FSTTestDoc(@"collection/3", 0, @{@"sort1": @1, @"sort2": @2}, NO),  // by key
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @1, @"sort2": @3}, NO),
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @2, @"sort2": @1}, NO),
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @2, @"sort2": @2}, NO),
        FSTTestDoc(@"collection/2", 0, @{@"sort1": @2, @"sort2": @2}, NO),  // by key
        FSTTestDoc(@"collection/3", 0, @{@"sort1": @2, @"sort2": @2}, NO),  // by key
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @2, @"sort2": @3}, NO),
        ];
  // clang-format on

  [self assertCorrectComparisonsWithArray:docs comparator:query.comparator];
}

- (void)testSortsDocumentsWithDescendingToo {
  FSTQuery *query = FSTTestQuery(@"collection");
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("sort1")
                                                               ascending:NO]];
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("sort2")
                                                               ascending:NO]];

  // clang-format off
  NSArray<FSTDocument *> *docs =
      @[FSTTestDoc(@"collection/1", 0, @{@"sort1": @2, @"sort2": @3}, NO),
        FSTTestDoc(@"collection/3", 0, @{@"sort1": @2, @"sort2": @2}, NO),
        FSTTestDoc(@"collection/2", 0, @{@"sort1": @2, @"sort2": @2}, NO),  // by key
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @2, @"sort2": @2}, NO),  // by key
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @2, @"sort2": @1}, NO),
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @1, @"sort2": @3}, NO),
        FSTTestDoc(@"collection/3", 0, @{@"sort1": @1, @"sort2": @2}, NO),
        FSTTestDoc(@"collection/2", 0, @{@"sort1": @1, @"sort2": @2}, NO),  // by key
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @1, @"sort2": @2}, NO),  // by key
        FSTTestDoc(@"collection/1", 0, @{@"sort1": @1, @"sort2": @1}, NO),
        ];
  // clang-format on

  [self assertCorrectComparisonsWithArray:docs comparator:query.comparator];
}

- (void)testEquality {
  FSTQuery *q11 = FSTTestQuery(@"foo");
  q11 = [q11 queryByAddingFilter:FSTTestFilter(@"i1", @"<", @(2))];
  q11 = [q11 queryByAddingFilter:FSTTestFilter(@"i2", @"==", @(3))];
  FSTQuery *q12 = FSTTestQuery(@"foo");
  q12 = [q12 queryByAddingFilter:FSTTestFilter(@"i2", @"==", @(3))];
  q12 = [q12 queryByAddingFilter:FSTTestFilter(@"i1", @"<", @(2))];

  FSTQuery *q21 = FSTTestQuery(@"foo");
  FSTQuery *q22 = FSTTestQuery(@"foo");

  FSTQuery *q31 = FSTTestQuery(@"foo/bar");
  FSTQuery *q32 = FSTTestQuery(@"foo/bar");

  FSTQuery *q41 = FSTTestQuery(@"foo");
  q41 = [q41 queryByAddingSortBy:@"foo" ascending:YES];
  q41 = [q41 queryByAddingSortBy:@"bar" ascending:YES];
  FSTQuery *q42 = FSTTestQuery(@"foo");
  q42 = [q42 queryByAddingSortBy:@"foo" ascending:YES];
  q42 = [q42 queryByAddingSortBy:@"bar" ascending:YES];
  FSTQuery *q43Diff = FSTTestQuery(@"foo");
  q43Diff = [q43Diff queryByAddingSortBy:@"bar" ascending:YES];
  q43Diff = [q43Diff queryByAddingSortBy:@"foo" ascending:YES];

  FSTQuery *q51 = FSTTestQuery(@"foo");
  q51 = [q51 queryByAddingSortBy:@"foo" ascending:YES];
  q51 = [q51 queryByAddingFilter:FSTTestFilter(@"foo", @">", @(2))];
  FSTQuery *q52 = FSTTestQuery(@"foo");
  q52 = [q52 queryByAddingFilter:FSTTestFilter(@"foo", @">", @(2))];
  q52 = [q52 queryByAddingSortBy:@"foo" ascending:YES];
  FSTQuery *q53Diff = FSTTestQuery(@"foo");
  q53Diff = [q53Diff queryByAddingFilter:FSTTestFilter(@"bar", @">", @(2))];
  q53Diff = [q53Diff queryByAddingSortBy:@"bar" ascending:YES];

  FSTQuery *q61 = FSTTestQuery(@"foo");
  q61 = [q61 queryBySettingLimit:10];

  // XCTAssertEqualObjects(q11, q12);  // TODO(klimt): not canonical yet
  XCTAssertNotEqualObjects(q11, q21);
  XCTAssertNotEqualObjects(q11, q31);
  XCTAssertNotEqualObjects(q11, q41);
  XCTAssertNotEqualObjects(q11, q51);
  XCTAssertNotEqualObjects(q11, q61);

  XCTAssertEqualObjects(q21, q22);
  XCTAssertNotEqualObjects(q21, q31);
  XCTAssertNotEqualObjects(q21, q41);
  XCTAssertNotEqualObjects(q21, q51);
  XCTAssertNotEqualObjects(q21, q61);

  XCTAssertEqualObjects(q31, q32);
  XCTAssertNotEqualObjects(q31, q41);
  XCTAssertNotEqualObjects(q31, q51);
  XCTAssertNotEqualObjects(q31, q61);

  XCTAssertEqualObjects(q41, q42);
  XCTAssertNotEqualObjects(q41, q43Diff);
  XCTAssertNotEqualObjects(q41, q51);
  XCTAssertNotEqualObjects(q41, q61);

  XCTAssertEqualObjects(q51, q52);
  XCTAssertNotEqualObjects(q51, q53Diff);
  XCTAssertNotEqualObjects(q51, q61);
}

- (void)testUniqueIds {
  FSTQuery *q11 = FSTTestQuery(@"foo");
  q11 = [q11 queryByAddingFilter:FSTTestFilter(@"i1", @"<", @(2))];
  q11 = [q11 queryByAddingFilter:FSTTestFilter(@"i2", @"==", @(3))];
  FSTQuery *q12 = FSTTestQuery(@"foo");
  q12 = [q12 queryByAddingFilter:FSTTestFilter(@"i2", @"==", @(3))];
  q12 = [q12 queryByAddingFilter:FSTTestFilter(@"i1", @"<", @(2))];

  FSTQuery *q21 = FSTTestQuery(@"foo");
  FSTQuery *q22 = FSTTestQuery(@"foo");

  FSTQuery *q31 = FSTTestQuery(@"foo/bar");
  FSTQuery *q32 = FSTTestQuery(@"foo/bar");

  FSTQuery *q41 = FSTTestQuery(@"foo");
  q41 = [q41 queryByAddingSortBy:@"foo" ascending:YES];
  q41 = [q41 queryByAddingSortBy:@"bar" ascending:YES];
  FSTQuery *q42 = FSTTestQuery(@"foo");
  q42 = [q42 queryByAddingSortBy:@"foo" ascending:YES];
  q42 = [q42 queryByAddingSortBy:@"bar" ascending:YES];
  FSTQuery *q43Diff = FSTTestQuery(@"foo");
  q43Diff = [q43Diff queryByAddingSortBy:@"bar" ascending:YES];
  q43Diff = [q43Diff queryByAddingSortBy:@"foo" ascending:YES];

  FSTQuery *q51 = FSTTestQuery(@"foo");
  q51 = [q51 queryByAddingSortBy:@"foo" ascending:YES];
  q51 = [q51 queryByAddingFilter:FSTTestFilter(@"foo", @">", @(2))];
  FSTQuery *q52 = FSTTestQuery(@"foo");
  q52 = [q52 queryByAddingFilter:FSTTestFilter(@"foo", @">", @(2))];
  q52 = [q52 queryByAddingSortBy:@"foo" ascending:YES];
  FSTQuery *q53Diff = FSTTestQuery(@"foo");
  q53Diff = [q53Diff queryByAddingFilter:FSTTestFilter(@"bar", @">", @(2))];
  q53Diff = [q53Diff queryByAddingSortBy:@"bar" ascending:YES];

  FSTQuery *q61 = FSTTestQuery(@"foo");
  q61 = [q61 queryBySettingLimit:10];

  // XCTAssertEqual(q11.hash, q12.hash);  // TODO(klimt): not canonical yet
  XCTAssertNotEqual(q11.hash, q21.hash);
  XCTAssertNotEqual(q11.hash, q31.hash);
  XCTAssertNotEqual(q11.hash, q41.hash);
  XCTAssertNotEqual(q11.hash, q51.hash);
  XCTAssertNotEqual(q11.hash, q61.hash);

  XCTAssertEqual(q21.hash, q22.hash);
  XCTAssertNotEqual(q21.hash, q31.hash);
  XCTAssertNotEqual(q21.hash, q41.hash);
  XCTAssertNotEqual(q21.hash, q51.hash);
  XCTAssertNotEqual(q21.hash, q61.hash);

  XCTAssertEqual(q31.hash, q32.hash);
  XCTAssertNotEqual(q31.hash, q41.hash);
  XCTAssertNotEqual(q31.hash, q51.hash);
  XCTAssertNotEqual(q31.hash, q61.hash);

  XCTAssertEqual(q41.hash, q42.hash);
  XCTAssertNotEqual(q41.hash, q43Diff.hash);
  XCTAssertNotEqual(q41.hash, q51.hash);
  XCTAssertNotEqual(q41.hash, q61.hash);

  XCTAssertEqual(q51.hash, q52.hash);
  XCTAssertNotEqual(q51.hash, q53Diff.hash);
  XCTAssertNotEqual(q51.hash, q61.hash);
}

- (void)testImplicitOrderBy {
  FSTQuery *baseQuery = FSTTestQuery(@"foo");
  // Default is ascending
  XCTAssertEqualObjects(baseQuery.sortOrders, @[ FSTTestOrderBy(kDocumentKeyPath, @"asc") ]);

  // Explicit key ordering is respected
  XCTAssertEqualObjects(
      [baseQuery queryByAddingSortOrder:FSTTestOrderBy(kDocumentKeyPath, @"asc")].sortOrders,
      @[ FSTTestOrderBy(kDocumentKeyPath, @"asc") ]);
  XCTAssertEqualObjects(
      [baseQuery queryByAddingSortOrder:FSTTestOrderBy(kDocumentKeyPath, @"desc")].sortOrders,
      @[ FSTTestOrderBy(kDocumentKeyPath, @"desc") ]);

  XCTAssertEqualObjects(
      [[baseQuery queryByAddingSortOrder:FSTTestOrderBy(@"foo", @"asc")]
          queryByAddingSortOrder:FSTTestOrderBy(kDocumentKeyPath, @"asc")]
          .sortOrders,
      (@[ FSTTestOrderBy(@"foo", @"asc"), FSTTestOrderBy(kDocumentKeyPath, @"asc") ]));

  XCTAssertEqualObjects(
      [[baseQuery queryByAddingSortOrder:FSTTestOrderBy(@"foo", @"asc")]
          queryByAddingSortOrder:FSTTestOrderBy(kDocumentKeyPath, @"desc")]
          .sortOrders,
      (@[ FSTTestOrderBy(@"foo", @"asc"), FSTTestOrderBy(kDocumentKeyPath, @"desc") ]));

  // Inequality filters add order bys
  XCTAssertEqualObjects(
      [baseQuery queryByAddingFilter:FSTTestFilter(@"foo", @"<", @5)].sortOrders,
      (@[ FSTTestOrderBy(@"foo", @"asc"), FSTTestOrderBy(kDocumentKeyPath, @"asc") ]));

  // Descending order by applies to implicit key ordering
  XCTAssertEqualObjects(
      [baseQuery queryByAddingSortOrder:FSTTestOrderBy(@"foo", @"desc")].sortOrders,
      (@[ FSTTestOrderBy(@"foo", @"desc"), FSTTestOrderBy(kDocumentKeyPath, @"desc") ]));
  XCTAssertEqualObjects([[baseQuery queryByAddingSortOrder:FSTTestOrderBy(@"foo", @"asc")]
                            queryByAddingSortOrder:FSTTestOrderBy(@"bar", @"desc")]
                            .sortOrders,
                        (@[
                          FSTTestOrderBy(@"foo", @"asc"), FSTTestOrderBy(@"bar", @"desc"),
                          FSTTestOrderBy(kDocumentKeyPath, @"desc")
                        ]));
  XCTAssertEqualObjects([[baseQuery queryByAddingSortOrder:FSTTestOrderBy(@"foo", @"desc")]
                            queryByAddingSortOrder:FSTTestOrderBy(@"bar", @"asc")]
                            .sortOrders,
                        (@[
                          FSTTestOrderBy(@"foo", @"desc"), FSTTestOrderBy(@"bar", @"asc"),
                          FSTTestOrderBy(kDocumentKeyPath, @"asc")
                        ]));
}

@end

NS_ASSUME_NONNULL_END
