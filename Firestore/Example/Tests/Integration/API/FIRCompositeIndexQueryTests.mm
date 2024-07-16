/*
 * Copyright 2023 Google LLC
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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import "FirebaseCore/Sources/Public/FirebaseCore/FIRTimestamp.h"

#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#include "Firestore/core/src/util/autoid.h"

using firebase::firestore::util::CreateAutoId;

NS_ASSUME_NONNULL_BEGIN

static NSString *const TEST_ID_FIELD = @"testId";
static NSString *const TTL_FIELD = @"expireAt";
static NSString *const COMPOSITE_INDEX_TEST_COLLECTION = @"composite-index-test-collection";

/**
 * This FIRCompositeIndexQueryTests class is designed to facilitate integration
 * testing of Firestore queries that require composite indexes within a
 * controlled testing environment.
 *
 * Key Features:
 * <ul>
 *   <li>Runs tests against the dedicated test collection with predefined composite indexes.
 *   <li>Automatically associates a test ID with documents for data isolation.
 *   <li>Utilizes TTL policy for automatic test data cleanup.
 *   <li>Constructs Firestore queries with test ID filters.
 * </ul>
 */
@interface FIRCompositeIndexQueryTests : FSTIntegrationTestCase
// Creates a new unique identifier for each test case to ensure data isolation.
@property(nonatomic, strong) NSString *testId;
@end

@implementation FIRCompositeIndexQueryTests

- (void)setUp {
  [super setUp];
  _testId = [NSString stringWithFormat:@"test-id-%s", CreateAutoId().c_str()];
}

#pragma mark - Test Helpers

// Return reference to the static test collection: composite-index-test-collection
- (FIRCollectionReference *)testCollectionRef {
  return [self.db collectionWithPath:COMPOSITE_INDEX_TEST_COLLECTION];
}

// Runs a test with specified documents in the COMPOSITE_INDEX_TEST_COLLECTION.
- (FIRCollectionReference *)collectionRefwithTestDocs:
    (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)docs {
  FIRCollectionReference *writer = [self testCollectionRef];
  // Use a different instance to write the documents
  [self writeAllDocuments:[self prepareTestDocuments:docs]
             toCollection:[self.firestore collectionWithPath:writer.path]];
  return self.testCollectionRef;
}

// Hash the document key with testId.
- (NSString *)toHashedId:(NSString *)docId {
  return [NSString stringWithFormat:@"%@-%@", docId, self.testId];
}

- (NSArray<NSString *> *)toHashedIds:(NSArray<NSString *> *)docs {
  NSMutableArray<NSString *> *hashedIds = [NSMutableArray arrayWithCapacity:docs.count];
  for (NSString *doc in docs) {
    [hashedIds addObject:[self toHashedId:doc]];
  }
  return hashedIds;
}

// Adds test-specific fields to a document, including the testId and expiration date.
- (NSDictionary<NSString *, id> *)addTestSpecificFieldsToDoc:(NSDictionary<NSString *, id> *)doc {
  NSMutableDictionary<NSString *, id> *updatedDoc = [doc mutableCopy];
  updatedDoc[TEST_ID_FIELD] = self.testId;
  int64_t expirationTime =
      [[FIRTimestamp timestamp] seconds] + 24 * 60 * 60;  // Expire test data after 24 hours
  updatedDoc[TTL_FIELD] = [FIRTimestamp timestampWithSeconds:expirationTime nanoseconds:0];
  return [updatedDoc copy];
}

// Remove test-specific fields from a Firestore document.
- (NSDictionary<NSString *, id> *)removeTestSpecificFieldsFromDoc:
    (NSDictionary<NSString *, id> *)doc {
  NSMutableDictionary<NSString *, id> *mutableDoc = [doc mutableCopy];
  [mutableDoc removeObjectForKey:TEST_ID_FIELD];
  [mutableDoc removeObjectForKey:TTL_FIELD];

  // Update the document with the modified data.
  return [mutableDoc copy];
}

// Helper method to hash document keys and add test-specific fields for the provided documents.
- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)prepareTestDocuments:
    (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)docs {
  NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *result =
      [NSMutableDictionary dictionaryWithCapacity:docs.count];
  for (NSString *key in docs.allKeys) {
    NSDictionary<NSString *, id> *doc = docs[key];
    NSDictionary<NSString *, id> *updatedDoc = [self addTestSpecificFieldsToDoc:doc];
    result[[self toHashedId:key]] = updatedDoc;
  }
  return [result copy];
}

// Asserts that the result of running the query while online (against the backend/emulator) is
// the same as running it while offline. The expected document Ids are hashed to match the
// actual document IDs created by the test helper.
- (void)assertOnlineAndOfflineResultsMatch:(FIRQuery *)query
                              expectedDocs:(NSArray<NSString *> *)expectedDocs {
  [self checkOnlineAndOfflineQuery:query matchesResult:[self toHashedIds:expectedDocs]];
}

// Asserts that the IDs in the query snapshot matches the expected Ids. The expected document
// IDs are hashed to match the actual document IDs created by the test helper.
- (void)assertSnapshotResultIdsMatch:(FIRQuerySnapshot *)snapshot
                         expectedIds:(NSArray<NSString *> *)expectedIds {
  XCTAssertEqualObjects(FIRQuerySnapshotGetIDs(snapshot), [self toHashedIds:expectedIds]);
}

// Adds a filter on test id for a query.
- (FIRQuery *)compositeIndexQuery:(FIRQuery *)query_ {
  return [query_ queryWhereField:TEST_ID_FIELD isEqualTo:self.testId];
}

// Get a document reference from a document key.
- (FIRDocumentReference *)getDocRef:(FIRCollectionReference *)collection docId:(NSString *)docId {
  if (![docId containsString:@"test-id-"]) {
    docId = [self toHashedId:docId];
  }
  return [collection documentWithPath:docId];
}

// Adds a document to a Firestore collection with test-specific fields.
- (FIRDocumentReference *)addDoc:(FIRCollectionReference *)collection
                            data:(NSDictionary<NSString *, id> *)data {
  NSDictionary<NSString *, id> *updatedData = [self addTestSpecificFieldsToDoc:data];
  return [self addDocumentRef:collection data:updatedData];
}

// Sets a document in Firestore with test-specific fields.
- (void)setDoc:(FIRDocumentReference *)document data:(NSDictionary<NSString *, id> *)data {
  NSDictionary<NSString *, id> *updatedData = [self addTestSpecificFieldsToDoc:data];
  return [self mergeDocumentRef:document data:updatedData];
}

- (void)updateDoc:(FIRDocumentReference *)document data:(NSDictionary<NSString *, id> *)data {
  [self updateDocumentRef:document data:data];
}

- (void)deleteDoc:(FIRDocumentReference *)document {
  [self deleteDocumentRef:document];
}

// Retrieve a single document from Firestore with test-specific fields removed.
// TODO(composite-index-testing) Return sanitized DocumentSnapshot instead of its data.
- (NSDictionary<NSString *, id> *)getSanitizedDocumentData:(FIRDocumentReference *)document {
  FIRDocumentSnapshot *docSnapshot = [self readDocumentForRef:document];
  return [self removeTestSpecificFieldsFromDoc:docSnapshot.data];
}

// Retrieve multiple documents from Firestore with test-specific fields removed.
// TODO(composite-index-testing) Return sanitized QuerySnapshot instead of its data.
- (NSArray<NSDictionary<NSString *, id> *> *)getSanitizedQueryData:(FIRQuery *)query {
  FIRQuerySnapshot *querySnapshot = [self readDocumentSetForRef:query];
  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
  for (FIRDocumentSnapshot *doc in querySnapshot.documents) {
    [result addObject:[self removeTestSpecificFieldsFromDoc:doc.data]];
  }
  return result;
}

#pragma mark - Test Cases

/*
 * Guidance for Creating Tests:
 * ----------------------------
 * When creating tests that require composite indexes, it is recommended to utilize the
 * test helpers in this class. This utility class provides methods for creating
 * and setting test documents and running queries with ease, ensuring proper data
 * isolation and query construction.
 *
 * To get started, please refer to the instructions provided in the README file. This will
 * guide you through setting up your local testing environment and updating the Terraform
 * configuration with any new composite indexes required for your testing scenarios.
 *
 * Note: Whenever feasible, make use of the current document fields (such as 'a,' 'b,' 'author,'
 * 'title') to avoid introducing new composite indexes and surpassing the limit. Refer to the
 * guidelines at https://firebase.google.com/docs/firestore/quotas#indexes for further information.
 */

- (void)testOrQueriesWithCompositeIndexes {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"a" : @1, @"b" : @0},
    @"doc2" : @{@"a" : @2, @"b" : @1},
    @"doc3" : @{@"a" : @3, @"b" : @2},
    @"doc4" : @{@"a" : @1, @"b" : @3},
    @"doc5" : @{@"a" : @1, @"b" : @1}
  }];
  // with one inequality: a>2 || b==1.
  FIRQuery *query1 = [collRef
      queryWhereFilter:[FIRFilter orFilterWithFilters:@[
        [FIRFilter filterWhereField:@"a" isGreaterThan:@2], [FIRFilter filterWhereField:@"b"
                                                                              isEqualTo:@1]
      ]]];
  [self assertOnlineAndOfflineResultsMatch:[self compositeIndexQuery:query1]
                              expectedDocs:@[ @"doc5", @"doc2", @"doc3" ]];

  // Test with limits (implicit order by ASC): (a==1) || (b > 0) LIMIT 2
  FIRQuery *query2 =
      [collRef queryWhereFilter:[FIRFilter orFilterWithFilters:@[
                 [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter filterWhereField:@"b"
                                                                               isGreaterThan:@0]
               ]]];
  [self assertOnlineAndOfflineResultsMatch:[[self compositeIndexQuery:query2] queryLimitedTo:2]
                              expectedDocs:@[ @"doc1", @"doc2" ]];

  // Test with limits (explicit order by): (a==1) || (b > 0) LIMIT_TO_LAST 2
  // Note: The public query API does not allow implicit ordering when limitToLast is used.
  FIRQuery *query3 =
      [collRef queryWhereFilter:[FIRFilter orFilterWithFilters:@[
                 [FIRFilter filterWhereField:@"a" isEqualTo:@1], [FIRFilter filterWhereField:@"b"
                                                                               isGreaterThan:@0]
               ]]];
  [self assertOnlineAndOfflineResultsMatch:[[[self compositeIndexQuery:query3] queryLimitedToLast:2]
                                               queryOrderedByField:@"b"]
                              expectedDocs:@[ @"doc3", @"doc4" ]];

  // Test with limits (explicit order by ASC): (a==2) || (b == 1) ORDER BY a LIMIT 1
  FIRQuery *query4 =
      [collRef queryWhereFilter:[FIRFilter orFilterWithFilters:@[
                 [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b"
                                                                                   isEqualTo:@1]
               ]]];
  [self assertOnlineAndOfflineResultsMatch:[[[self compositeIndexQuery:query4] queryLimitedTo:1]
                                               queryOrderedByField:@"a"]
                              expectedDocs:@[ @"doc5" ]];

  // Test with limits (explicit order by DESC): (a==2) || (b == 1) ORDER BY a LIMIT_TO_LAST 1
  FIRQuery *query5 =
      [collRef queryWhereFilter:[FIRFilter orFilterWithFilters:@[
                 [FIRFilter filterWhereField:@"a" isEqualTo:@2], [FIRFilter filterWhereField:@"b"
                                                                                   isEqualTo:@1]
               ]]];
  [self assertOnlineAndOfflineResultsMatch:[[[self compositeIndexQuery:query5] queryLimitedToLast:1]
                                               queryOrderedByField:@"a"]
                              expectedDocs:@[ @"doc2" ]];
}

- (void)testCanRunAggregateCollectionGroupQuery {
  NSString *collectionGroup = [[self testCollectionRef] collectionID];
  NSArray *docPathFormats = @[
    @"abc/123/%@/cg-doc1", @"abc/123/%@/cg-doc2", @"%@/cg-doc3", @"%@/cg-doc4",
    @"def/456/%@/cg-doc5", @"%@/virtual-doc/nested-coll/not-cg-doc", @"x%@/not-cg-doc",
    @"%@x/not-cg-doc", @"abc/123/%@x/not-cg-doc", @"abc/123/x%@/not-cg-doc", @"abc/%@"
  ];

  FIRWriteBatch *batch = self.db.batch;
  for (NSString *format in docPathFormats) {
    NSString *path = [NSString stringWithFormat:format, collectionGroup];
    [batch setData:[self addTestSpecificFieldsToDoc:@{@"a" : @2}]
        forDocument:[self.db documentWithPath:path]];
  }
  [self commitWriteBatch:batch];

  FIRAggregateQuerySnapshot *snapshot = [self
      readSnapshotForAggregate:[[self
                                   compositeIndexQuery:[self.db
                                                           collectionGroupWithID:collectionGroup]]
                                   aggregate:@[
                                     [FIRAggregateField aggregateFieldForCount],
                                     [FIRAggregateField aggregateFieldForSumOfField:@"a"],
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"a"]
                                   ]]];
  // "cg-doc1", "cg-doc2", "cg-doc3", "cg-doc4", "cg-doc5",
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:5L]);
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"a"]],
      [NSNumber numberWithLong:10L]);
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForAverageOfField:@"a"]],
      [NSNumber numberWithDouble:2.0]);
}

- (void)testCanPerformMaxAggregations {
  FIRCollectionReference *testCollection = [self collectionRefwithTestDocs:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @5.0,
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @4.0,
    }
  }];

  // Max is 5, do not exceed
  FIRAggregateQuerySnapshot *snapshot =
      [self readSnapshotForAggregate:[[self compositeIndexQuery:testCollection] aggregate:@[
              [FIRAggregateField aggregateFieldForCount],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForSumOfField:@"year"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"]
            ]]];

  // Assert
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:2L]);
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]],
      [NSNumber numberWithLong:150L]);
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"year"]],
      [NSNumber numberWithLong:4000L]);
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField
                                                      aggregateFieldForAverageOfField:@"pages"]],
                 [NSNumber numberWithDouble:75.0]);
  XCTAssertEqual([[snapshot valueForAggregateField:[FIRAggregateField
                                                       aggregateFieldForAverageOfField:@"rating"]]
                     doubleValue],
                 4.5);
}

- (void)testPerformsAggregationsWhenNaNExistsForSomeFieldValues {
  FIRCollectionReference *testCollection = [self collectionRefwithTestDocs:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @5
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @4
    },
    @"c" : @{
      @"author" : @"authorC",
      @"title" : @"titleC",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : [NSNumber numberWithFloat:NAN]
    },
    @"d" : @{
      @"author" : @"authorD",
      @"title" : @"titleD",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @0
    }
  }];

  FIRAggregateQuerySnapshot *snapshot =
      [self readSnapshotForAggregate:[[self compositeIndexQuery:testCollection] aggregate:@[
              [FIRAggregateField aggregateFieldForSumOfField:@"rating"],
              [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"rating"],
              [FIRAggregateField aggregateFieldForAverageOfField:@"year"]
            ]]];

  // Sum
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]],
      [NSNumber numberWithDouble:NAN]);
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]]
          longValue],
      300L);

  // Average
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField
                                                      aggregateFieldForAverageOfField:@"rating"]],
                 [NSNumber numberWithDouble:NAN]);
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForAverageOfField:@"year"]]
          doubleValue],
      2000.0);
}

- (void)testPerformsAggregationWhenUsingArrayContainsAnyOperator {
  FIRCollectionReference *testCollection = [self collectionRefwithTestDocs:@{
    @"a" : @{
      @"author" : @"authorA",
      @"title" : @"titleA",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @[ @5, @1000 ]
    },
    @"b" : @{
      @"author" : @"authorB",
      @"title" : @"titleB",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @[ @4 ]
    },
    @"c" : @{
      @"author" : @"authorC",
      @"title" : @"titleC",
      @"pages" : @100,
      @"year" : @1980,
      @"rating" : @[ @2222, @3 ]
    },
    @"d" : @{
      @"author" : @"authorD",
      @"title" : @"titleD",
      @"pages" : @50,
      @"year" : @2020,
      @"rating" : @[ @0 ]
    }
  }];

  FIRAggregateQuerySnapshot *snapshot = [self
      readSnapshotForAggregate:[[self
                                   compositeIndexQuery:[testCollection queryWhereField:@"rating"
                                                                      arrayContainsAny:@[ @5, @3 ]]]
                                   aggregate:@[
                                     [FIRAggregateField aggregateFieldForSumOfField:@"rating"],
                                     [FIRAggregateField aggregateFieldForSumOfField:@"pages"],
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"rating"],
                                     [FIRAggregateField aggregateFieldForAverageOfField:@"pages"],
                                     [FIRAggregateField aggregateFieldForCount]
                                   ]]];

  // Count
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]] longValue], 2L);

  // Sum
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"rating"]]
          longValue],
      0L);
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"pages"]]
          longValue],
      200L);

  // Average
  XCTAssertEqualObjects(
      [snapshot
          valueForAggregateField:[FIRAggregateField aggregateFieldForAverageOfField:@"rating"]],
      [NSNull null]);
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField
                                            aggregateFieldForAverageOfField:@"pages"]] doubleValue],
      100.0);
}

// Multiple Inequality
- (void)testMultipleInequalityOnDifferentFields {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @0, @"v" : @0},
    @"doc2" : @{@"key" : @"b", @"sort" : @3, @"v" : @1},
    @"doc3" : @{@"key" : @"c", @"sort" : @1, @"v" : @3},
    @"doc4" : @{@"key" : @"d", @"sort" : @2, @"v" : @2}
  }];

  // Multiple inequality fields
  FIRQuery *query = [[[collRef queryWhereField:@"key"
                                  isNotEqualTo:@"a"] queryWhereField:@"sort"
                                                 isLessThanOrEqualTo:@2] queryWhereField:@"v"
                                                                           isGreaterThan:@2];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc3" ])];

  // Duplicate inequality fields
  query = [[[collRef queryWhereField:@"key"
                        isNotEqualTo:@"a"] queryWhereField:@"sort"
                                       isLessThanOrEqualTo:@2] queryWhereField:@"sort"
                                                                 isGreaterThan:@1];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc4" ])];

  // With multiple IN
  query = [[[[collRef queryWhereField:@"key" isGreaterThanOrEqualTo:@"a"] queryWhereField:@"sort"
                                                                      isLessThanOrEqualTo:@2]
      queryWhereField:@"v"
                   in:@[ @2, @3, @4 ]] queryWhereField:@"sort" in:@[ @2, @3 ]];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc4" ])];

  // With NOT-IN
  query = [[[collRef queryWhereField:@"key"
              isGreaterThanOrEqualTo:@"a"] queryWhereField:@"sort"
                                       isLessThanOrEqualTo:@2] queryWhereField:@"v"
                                                                         notIn:@[ @2, @4, @5 ]];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc1", @"doc3" ])];

  // With orderby
  query = [[[collRef queryWhereField:@"key"
              isGreaterThanOrEqualTo:@"a"] queryWhereField:@"sort"
                                       isLessThanOrEqualTo:@2] queryOrderedByField:@"v"
                                                                        descending:YES];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc3", @"doc4", @"doc1" ])];

  // With limit
  query = [[[[collRef queryWhereField:@"key" isGreaterThanOrEqualTo:@"a"]
          queryWhereField:@"sort"
      isLessThanOrEqualTo:@2] queryOrderedByField:@"v" descending:YES] queryLimitedTo:2];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc3", @"doc4" ])];

  // With limitedToLast
  query = [[[[collRef queryWhereField:@"key" isGreaterThanOrEqualTo:@"a"]
          queryWhereField:@"sort"
      isLessThanOrEqualTo:@2] queryOrderedByField:@"v" descending:YES] queryLimitedToLast:2];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc4", @"doc1" ])];
}

- (void)testMultipleInequalityOnSpecialValues {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @0, @"v" : @0},
    @"doc2" : @{@"key" : @"b", @"sort" : @(NAN), @"v" : @1},
    @"doc3" : @{@"key" : @"c", @"sort" : [NSNull null], @"v" : @3},
    @"doc4" : @{@"key" : @"d", @"v" : @0},
    @"doc5" : @{@"key" : @"e", @"sort" : @1},
    @"doc6" : @{@"key" : @"f", @"sort" : @1, @"v" : @1}
  }];

  FIRQuery *query = [[collRef queryWhereField:@"key" isNotEqualTo:@"a"] queryWhereField:@"sort"
                                                                    isLessThanOrEqualTo:@2];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc5", @"doc6" ])];

  query = [[[collRef queryWhereField:@"key"
                        isNotEqualTo:@"a"] queryWhereField:@"sort"
                                       isLessThanOrEqualTo:@2] queryWhereField:@"v"
                                                           isLessThanOrEqualTo:@1];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc6" ])];
}

- (void)testMultipleInequalityWithArrayMembership {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @0, @"v" : @[ @0 ]},
    @"doc2" : @{@"key" : @"b", @"sort" : @1, @"v" : @[ @0, @1, @3 ]},
    @"doc3" : @{@"key" : @"c", @"sort" : @1, @"v" : @[]},
    @"doc4" : @{@"key" : @"d", @"sort" : @2, @"v" : @[ @1 ]},
    @"doc5" : @{@"key" : @"e", @"sort" : @3, @"v" : @[ @2, @4 ]},
    @"doc6" : @{@"key" : @"f", @"sort" : @4, @"v" : @[ @(NAN) ]},
    @"doc7" : @{@"key" : @"g", @"sort" : @4, @"v" : @[ [NSNull null] ]}

  }];

  FIRQuery *query = [[[collRef queryWhereField:@"key"
                                  isNotEqualTo:@"a"] queryWhereField:@"sort"
                                              isGreaterThanOrEqualTo:@1] queryWhereField:@"v"
                                                                           arrayContains:@0];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc2" ])];

  query = [[[collRef queryWhereField:@"key"
                        isNotEqualTo:@"a"] queryWhereField:@"sort"
                                    isGreaterThanOrEqualTo:@1] queryWhereField:@"v"
                                                              arrayContainsAny:@[ @0, @1 ]];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc2", @"doc4" ])];
}

- (NSDictionary<NSString *, id> *)nestedData:(int)number {
  return @{
    @"name" : [NSString stringWithFormat:@"room %d", number],
    @"metadata" : @{@"createdAt" : @(number)},
    @"field" : [NSString stringWithFormat:@"field %d", number],
    @"field.dot" : @(number),
    @"field\\slash" : @(number)
  };
}

- (void)testMultipleInequalityWithNestedField {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : [self nestedData:400],
    @"doc2" : [self nestedData:200],
    @"doc3" : [self nestedData:100],
    @"doc4" : [self nestedData:300]
  }];

  FIRQuery *query = [[[[collRef queryWhereField:@"metadata.createdAt" isLessThanOrEqualTo:@500]
      queryWhereField:@"metadata.createdAt"
        isGreaterThan:@100] queryWhereField:@"name"
                               isNotEqualTo:@"room 200"] queryOrderedByField:@"name" descending:NO];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc4", @"doc1" ])];

  query = [[[[collRef queryWhereField:@"field" isGreaterThanOrEqualTo:@"field 100"]
      queryWhereFieldPath:[[FIRFieldPath alloc] initWithFields:@[ @"field.dot" ]]
             isNotEqualTo:@300] queryWhereField:@"field\\slash"
                                     isLessThan:@400] queryOrderedByField:@"name" descending:YES];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc2", @"doc3" ])];
}

- (void)testMultipleInequalityWithCompositeFilters {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @0, @"v" : @5},
    @"doc2" : @{@"key" : @"aa", @"sort" : @4, @"v" : @4},
    @"doc3" : @{@"key" : @"c", @"sort" : @3, @"v" : @3},
    @"doc4" : @{@"key" : @"b", @"sort" : @2, @"v" : @2},
    @"doc5" : @{@"key" : @"b", @"sort" : @2, @"v" : @1},
    @"doc6" : @{@"key" : @"b", @"sort" : @0, @"v" : @0}
  }];

  FIRQuery *query = [collRef
      queryWhereFilter:[FIRFilter orFilterWithFilters:@[
        [FIRFilter andFilterWithFilters:@[
          [FIRFilter filterWhereField:@"key" isEqualTo:@"b"], [FIRFilter filterWhereField:@"sort"
                                                                      isLessThanOrEqualTo:@2]
        ]],
        [FIRFilter andFilterWithFilters:@[
          [FIRFilter filterWhereField:@"key" isNotEqualTo:@"b"], [FIRFilter filterWhereField:@"v"
                                                                               isGreaterThan:@4]
        ]]
      ]]];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Implicitly ordered by: 'key' asc, 'sort' asc, 'v' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot
                         expectedIds:(@[ @"doc1", @"doc6", @"doc5", @"doc4" ])];

  query = [[[collRef
      queryWhereFilter:[FIRFilter orFilterWithFilters:@[
        [FIRFilter andFilterWithFilters:@[
          [FIRFilter filterWhereField:@"key" isEqualTo:@"b"], [FIRFilter filterWhereField:@"sort"
                                                                      isLessThanOrEqualTo:@2]
        ]],
        [FIRFilter andFilterWithFilters:@[
          [FIRFilter filterWhereField:@"key" isNotEqualTo:@"b"], [FIRFilter filterWhereField:@"v"
                                                                               isGreaterThan:@4]
        ]]
      ]]] queryOrderedByField:@"sort" descending:YES] queryOrderedByField:@"key"];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Ordered by: 'sort' desc, 'key' asc, 'v' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot
                         expectedIds:(@[ @"doc5", @"doc4", @"doc1", @"doc6" ])];

  query = [collRef
      queryWhereFilter:[FIRFilter andFilterWithFilters:@[

        [FIRFilter orFilterWithFilters:@[
          [FIRFilter andFilterWithFilters:@[
            [FIRFilter filterWhereField:@"key" isEqualTo:@"b"], [FIRFilter filterWhereField:@"sort"
                                                                        isLessThanOrEqualTo:@4]
          ]],
          [FIRFilter andFilterWithFilters:@[
            [FIRFilter filterWhereField:@"key" isNotEqualTo:@"b"], [FIRFilter filterWhereField:@"v"
                                                                        isGreaterThanOrEqualTo:@4]
          ]]
        ]],
        [FIRFilter orFilterWithFilters:@[
          [FIRFilter andFilterWithFilters:@[
            [FIRFilter filterWhereField:@"key" isGreaterThan:@"b"],
            [FIRFilter filterWhereField:@"sort" isGreaterThanOrEqualTo:@1]
          ]],
          [FIRFilter andFilterWithFilters:@[
            [FIRFilter filterWhereField:@"key" isLessThan:@"b"], [FIRFilter filterWhereField:@"v"
                                                                               isGreaterThan:@0]
          ]]
        ]]

      ]]];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Implicitly ordered by: 'key' asc, 'sort' asc, 'v' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc1", @"doc2" ])];
}

- (void)testMultipleInequalityFieldsWillBeImplicitlyOrderedLexicographically {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @0, @"v" : @5},
    @"doc2" : @{@"key" : @"aa", @"sort" : @4, @"v" : @4},
    @"doc3" : @{@"key" : @"b", @"sort" : @3, @"v" : @3},
    @"doc4" : @{@"key" : @"b", @"sort" : @2, @"v" : @2},
    @"doc5" : @{@"key" : @"b", @"sort" : @2, @"v" : @1},
    @"doc6" : @{@"key" : @"b", @"sort" : @0, @"v" : @0}
  }];

  FIRQuery *query = [[[collRef queryWhereField:@"key" isNotEqualTo:@"a"]
      queryWhereField:@"sort"
        isGreaterThan:@1] queryWhereField:@"v" in:@[ @1, @2, @3, @4 ]];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Implicitly ordered by: 'key' asc, 'sort' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot
                         expectedIds:(@[ @"doc2", @"doc4", @"doc5", @"doc3" ])];

  query = [[[collRef queryWhereField:@"sort"
                       isGreaterThan:@1] queryWhereField:@"key"
                                            isNotEqualTo:@"a"] queryWhereField:@"v"
                                                                            in:@[ @1, @2, @3, @4 ]];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Implicitly ordered by: 'key' asc, 'sort' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot
                         expectedIds:(@[ @"doc2", @"doc4", @"doc5", @"doc3" ])];
}

- (void)testMultipleInequalityWithMultipleExplicitOrderBy {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @5, @"v" : @0},
    @"doc2" : @{@"key" : @"aa", @"sort" : @4, @"v" : @0},
    @"doc3" : @{@"key" : @"b", @"sort" : @3, @"v" : @1},
    @"doc4" : @{@"key" : @"b", @"sort" : @2, @"v" : @1},
    @"doc5" : @{@"key" : @"bb", @"sort" : @1, @"v" : @1},
    @"doc6" : @{@"key" : @"c", @"sort" : @0, @"v" : @2}
  }];

  FIRQuery *query = [[[collRef queryWhereField:@"key"
                                 isGreaterThan:@"a"] queryWhereField:@"sort"
                                              isGreaterThanOrEqualTo:@1] queryOrderedByField:@"v"
                                                                                  descending:NO];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Ordered by: 'v' asc, 'key' asc, 'sort' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot
                         expectedIds:(@[ @"doc2", @"doc4", @"doc3", @"doc5" ])];

  query = [[[[collRef queryWhereField:@"key" isGreaterThan:@"a"] queryWhereField:@"sort"
                                                          isGreaterThanOrEqualTo:@1]
      queryOrderedByField:@"v"
               descending:NO] queryOrderedByField:@"sort" descending:NO];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Ordered by: 'v asc, 'sort' asc, 'key' asc,  __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot
                         expectedIds:(@[ @"doc2", @"doc5", @"doc4", @"doc3" ])];

  query = [[[collRef queryWhereField:@"key"
                       isGreaterThan:@"a"] queryWhereField:@"sort"
                                    isGreaterThanOrEqualTo:@1] queryOrderedByField:@"v"
                                                                        descending:YES];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Implicit order by matches the direction of last explicit order by.
  // Ordered by: 'v' desc, 'key' desc, 'sort' desc, __name__ desc
  [self assertSnapshotResultIdsMatch:snapshot
                         expectedIds:(@[ @"doc5", @"doc3", @"doc4", @"doc2" ])];

  query = [[[[collRef queryWhereField:@"key" isGreaterThan:@"a"] queryWhereField:@"sort"
                                                          isGreaterThanOrEqualTo:@1]
      queryOrderedByField:@"v"
               descending:YES] queryOrderedByField:@"sort" descending:NO];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Ordered by: 'v desc, 'sort' asc, 'key' asc,  __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot
                         expectedIds:(@[ @"doc5", @"doc4", @"doc3", @"doc2" ])];
}

- (void)testMultipleInequalityInAggregateQuery {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @5, @"v" : @0},
    @"doc2" : @{@"key" : @"aa", @"sort" : @4, @"v" : @0},
    @"doc3" : @{@"key" : @"b", @"sort" : @3, @"v" : @1},
    @"doc4" : @{@"key" : @"b", @"sort" : @2, @"v" : @1},
    @"doc5" : @{@"key" : @"bb", @"sort" : @1, @"v" : @1},
  }];

  FIRAggregateQuerySnapshot *snapshot =
      [self readSnapshotForAggregate:[[self compositeIndexQuery:[[[collRef queryWhereField:@"key"
                                                                             isGreaterThan:@"a"]
                                                                           queryWhereField:@"sort"
                                                                    isGreaterThanOrEqualTo:@1]
                                                                    queryOrderedByField:@"v"
                                                                             descending:NO]]
                                         aggregate:@[
                                           [FIRAggregateField aggregateFieldForCount],
                                           [FIRAggregateField aggregateFieldForSumOfField:@"sort"],
                                           [FIRAggregateField aggregateFieldForAverageOfField:@"v"]
                                         ]]];
  XCTAssertEqual([snapshot count], [NSNumber numberWithLong:4L]);

  snapshot =
      [self readSnapshotForAggregate:[[self compositeIndexQuery:[[[collRef queryWhereField:@"key"
                                                                             isGreaterThan:@"a"]
                                                                           queryWhereField:@"sort"
                                                                    isGreaterThanOrEqualTo:@1]
                                                                    queryWhereField:@"v"
                                                                       isNotEqualTo:@0]]
                                         aggregate:@[
                                           [FIRAggregateField aggregateFieldForCount],
                                           [FIRAggregateField aggregateFieldForSumOfField:@"sort"],
                                           [FIRAggregateField aggregateFieldForAverageOfField:@"v"],
                                         ]]];
  XCTAssertEqual([snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForCount]],
                 [NSNumber numberWithLong:3L]);
  XCTAssertEqual(
      [[snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForSumOfField:@"sort"]]
          longValue],
      6L);
  XCTAssertEqual(
      [snapshot valueForAggregateField:[FIRAggregateField aggregateFieldForAverageOfField:@"v"]],
      [NSNumber numberWithDouble:1.0]);
}

- (void)testMultipleInequalityFieldsWithDocumentKey {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @5},
    @"doc2" : @{@"key" : @"aa", @"sort" : @4},
    @"doc3" : @{@"key" : @"b", @"sort" : @3},
    @"doc4" : @{@"key" : @"b", @"sort" : @2},
    @"doc5" : @{@"key" : @"bb", @"sort" : @1}
  }];

  FIRQuery *query = [[[collRef queryWhereField:@"sort" isGreaterThan:@1]
      queryWhereField:@"key"
         isNotEqualTo:@"a"] queryWhereFieldPath:[FIRFieldPath documentID] isLessThan:@"doc5"];
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Document Key in inequality field will implicitly ordered to the last.
  // Implicitly ordered by: 'key' asc, 'sort' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc2", @"doc4", @"doc3" ])];

  query = [[[collRef queryWhereFieldPath:[FIRFieldPath documentID]
                              isLessThan:@"doc5"] queryWhereField:@"sort"
                                                    isGreaterThan:@1] queryWhereField:@"key"
                                                                         isNotEqualTo:@"a"];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Changing filters order will not effect implicit order.
  // Implicitly ordered by: 'key' asc, 'sort' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc2", @"doc4", @"doc3" ])];

  query = [[[[collRef queryWhereFieldPath:[FIRFieldPath documentID]
                               isLessThan:@"doc5"] queryWhereField:@"sort" isGreaterThan:@1]
      queryWhereField:@"key"
         isNotEqualTo:@"a"] queryOrderedByField:@"sort" descending:YES];
  snapshot = [self readDocumentSetForRef:[self compositeIndexQuery:query]];
  // Ordered by: 'sort' desc,'key' desc,  __name__ desc
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc2", @"doc3", @"doc4" ])];
}

- (void)testMultipleInequalityReadFromCacheWhenOffline {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"key" : @"a", @"sort" : @1},
    @"doc2" : @{@"key" : @"aa", @"sort" : @4},
    @"doc3" : @{@"key" : @"b", @"sort" : @3},
    @"doc4" : @{@"key" : @"b", @"sort" : @2},
  }];

  FIRQuery *query = [self compositeIndexQuery:[[collRef queryWhereField:@"key" isNotEqualTo:@"a"]
                                                      queryWhereField:@"sort"
                                                  isLessThanOrEqualTo:@3]];
  // populate the cache.
  FIRQuerySnapshot *snapshot = [self readDocumentSetForRef:query];
  XCTAssertEqual(snapshot.count, 2L);
  XCTAssertEqual(snapshot.metadata.isFromCache, NO);

  [self disableNetwork];

  snapshot = [self readDocumentSetForRef:query];
  XCTAssertEqual(snapshot.count, 2L);
  XCTAssertEqual(snapshot.metadata.isFromCache, YES);
  // Implicitly ordered by: 'key' asc, 'sort' asc, __name__ asc
  [self assertSnapshotResultIdsMatch:snapshot expectedIds:(@[ @"doc4", @"doc3" ])];
}

- (void)testMultipleInequalityFromCacheAndFromServer {
  FIRCollectionReference *collRef = [self collectionRefwithTestDocs:@{
    @"doc1" : @{@"a" : @1, @"b" : @0},
    @"doc2" : @{@"a" : @2, @"b" : @1},
    @"doc3" : @{@"a" : @3, @"b" : @2},
    @"doc4" : @{@"a" : @1, @"b" : @3},
    @"doc5" : @{@"a" : @1, @"b" : @1},
  }];

  // implicit AND: a != 1 && b < 2
  FIRQuery *query = [[collRef queryWhereField:@"a" isNotEqualTo:@1] queryWhereField:@"b"
                                                                         isLessThan:@2];
  [self assertOnlineAndOfflineResultsMatch:[self compositeIndexQuery:query]
                              expectedDocs:@[ @"doc2" ]];

  // explicit AND: a != 1 && b < 2
  query =
      [collRef queryWhereFilter:[FIRFilter andFilterWithFilters:@[
                 [FIRFilter filterWhereField:@"a" isNotEqualTo:@1], [FIRFilter filterWhereField:@"b"
                                                                                     isLessThan:@2]
               ]]];
  [self assertOnlineAndOfflineResultsMatch:[self compositeIndexQuery:query]
                              expectedDocs:@[ @"doc2" ]];

  // explicit AND: a < 3 && b not-in [2, 3]
  // Implicitly ordered by: a asc, b asc, __name__ asc
  query = [collRef
      queryWhereFilter:[FIRFilter andFilterWithFilters:@[
        [FIRFilter filterWhereField:@"a" isLessThan:@3], [FIRFilter filterWhereField:@"b"
                                                                               notIn:@[ @2, @3 ]]
      ]]];
  [self assertOnlineAndOfflineResultsMatch:[self compositeIndexQuery:query]
                              expectedDocs:@[ @"doc1", @"doc5", @"doc2" ]];

  // a <3 && b != 0, ordered by: b desc, a desc, __name__ desc
  query = [[[[collRef queryWhereField:@"a" isLessThan:@3] queryWhereField:@"b" isNotEqualTo:@0]
      queryOrderedByField:@"b"
               descending:YES] queryLimitedTo:2];
  [self assertOnlineAndOfflineResultsMatch:[self compositeIndexQuery:query]
                              expectedDocs:@[ @"doc4", @"doc2" ]];

  // explicit OR: a>2 || b<1.
  query = [collRef
      queryWhereFilter:[FIRFilter orFilterWithFilters:@[
        [FIRFilter filterWhereField:@"a" isGreaterThan:@2], [FIRFilter filterWhereField:@"b"
                                                                             isLessThan:@1]
      ]]];
  [self assertOnlineAndOfflineResultsMatch:[self compositeIndexQuery:query]
                              expectedDocs:@[ @"doc1", @"doc3" ]];
}

- (void)testMultipleInequalityRejectsIfDocumentKeyIsNotTheLastOrderByField {
  FIRCollectionReference *collRef = [self collectionRef];

  FIRQuery *query = [[collRef queryWhereField:@"key" isNotEqualTo:@42]
      queryOrderedByFieldPath:[FIRFieldPath documentID]];

  XCTestExpectation *queryCompletion = [self expectationWithDescription:@"query"];
  [query getDocumentsWithCompletion:^(FIRQuerySnapshot *results, NSError *error) {
    XCTAssertNil(results);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
    [queryCompletion fulfill];
  }];
  [self awaitExpectations];
}

- (void)testMultipleInequalityRejectsIfDocumentKeyAppearsOnlyInEqualityFilter {
  FIRCollectionReference *collRef = [self collectionRef];

  FIRQuery *query = [[collRef queryWhereField:@"key"
                                 isNotEqualTo:@42] queryWhereFieldPath:[FIRFieldPath documentID]
                                                             isEqualTo:@"doc1"];

  XCTestExpectation *queryCompletion = [self expectationWithDescription:@"query"];
  [query getDocumentsWithCompletion:^(FIRQuerySnapshot *results, NSError *error) {
    XCTAssertNil(results);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeInvalidArgument);
    [queryCompletion fulfill];
  }];
  [self awaitExpectations];
}

@end

NS_ASSUME_NONNULL_END
