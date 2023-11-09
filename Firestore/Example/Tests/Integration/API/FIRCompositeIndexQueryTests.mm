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
- (FIRCollectionReference *)withTestDocs:
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
  FIRCollectionReference *collRef = [self withTestDocs:@{
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
  FIRCollectionReference *testCollection = [self withTestDocs:@{
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
  FIRCollectionReference *testCollection = [self withTestDocs:@{
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
  FIRCollectionReference *testCollection = [self withTestDocs:@{
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

@end

NS_ASSUME_NONNULL_END
