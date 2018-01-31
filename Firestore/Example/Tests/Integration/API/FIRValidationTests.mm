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

#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

// We have tests for passing nil when nil is not supposed to be allowed. So suppress the warnings.
#pragma clang diagnostic ignored "-Wnonnull"

@interface FIRValidationTests : FSTIntegrationTestCase
@end

@implementation FIRValidationTests

#pragma mark - FIRFirestoreSettings Validation

- (void)testNilHostFails {
  FIRFirestoreSettings *settings = self.db.settings;
  FSTAssertThrows(settings.host = nil,
                  @"host setting may not be nil. You should generally just use the default value "
                   "(which is firestore.googleapis.com)");
}

- (void)testNilDispatchQueueFails {
  FIRFirestoreSettings *settings = self.db.settings;
  FSTAssertThrows(settings.dispatchQueue = nil,
                  @"dispatch queue setting may not be nil. Create a new dispatch queue with "
                   "dispatch_queue_create(\"com.example.MyQueue\", NULL) or just use the default "
                   "(which is the main queue, returned from dispatch_get_main_queue())");
}

- (void)testChangingSettingsAfterUseFails {
  FIRFirestoreSettings *settings = self.db.settings;
  [[self.db documentWithPath:@"foo/bar"] setData:@{ @"a" : @42 }];
  settings.host = @"example.com";
  FSTAssertThrows(self.db.settings = settings,
                  @"Firestore instance has already been started and its settings can no longer be "
                  @"changed. You can only set settings before calling any other methods on "
                  @"a Firestore instance.");
}

#pragma mark - FIRFirestore Validation

- (void)testNilFIRAppFails {
  FSTAssertThrows(
      [FIRFirestore firestoreForApp:nil],
      @"FirebaseApp instance may not be nil. Use FirebaseApp.app() if you'd like to use the "
       "default FirebaseApp instance.");
}

// TODO(b/62410906): Test for firestoreForApp:database: with nil DatabaseID.

- (void)testNilTransactionBlocksFail {
  FSTAssertThrows([self.db runTransactionWithBlock:nil
                                        completion:^(id result, NSError *error) {
                                          XCTFail(@"Completion shouldn't run.");
                                        }],
                  @"Transaction block cannot be nil.");

  FSTAssertThrows(
      [self.db runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **pError) {
        XCTFail(@"Transaction block shouldn't run.");
        return nil;
      }
                            completion:nil],
      @"Transaction completion block cannot be nil.");
}

#pragma mark - Collection and Document Path Validation

- (void)testNilCollectionPathsFail {
  FIRDocumentReference *baseDocRef = [self.db documentWithPath:@"foo/bar"];
  NSString *nilError = @"Collection path cannot be nil.";
  FSTAssertThrows([self.db collectionWithPath:nil], nilError);
  FSTAssertThrows([baseDocRef collectionWithPath:nil], nilError);
}

- (void)testWrongLengthCollectionPathsFail {
  FIRDocumentReference *baseDocRef = [self.db documentWithPath:@"foo/bar"];
  NSArray *badAbsolutePaths = @[ @"foo/bar", @"foo/bar/baz/quu" ];
  NSArray *badRelativePaths = @[ @"", @"baz/quu" ];
  NSArray *badPathLengths = @[ @2, @4 ];
  NSString *errorFormat =
      @"Invalid collection reference. Collection references must have an odd "
      @"number of segments, but %@ has %@";
  for (NSUInteger i = 0; i < badAbsolutePaths.count; i++) {
    NSString *error =
        [NSString stringWithFormat:errorFormat, badAbsolutePaths[i], badPathLengths[i]];
    FSTAssertThrows([self.db collectionWithPath:badAbsolutePaths[i]], error);
    FSTAssertThrows([baseDocRef collectionWithPath:badRelativePaths[i]], error);
  }
}

- (void)testNilDocumentPathsFail {
  FIRCollectionReference *baseCollectionRef = [self.db collectionWithPath:@"foo"];
  NSString *nilError = @"Document path cannot be nil.";
  FSTAssertThrows([self.db documentWithPath:nil], nilError);
  FSTAssertThrows([baseCollectionRef documentWithPath:nil], nilError);
}

- (void)testWrongLengthDocumentPathsFail {
  FIRCollectionReference *baseCollectionRef = [self.db collectionWithPath:@"foo"];
  NSArray *badAbsolutePaths = @[ @"foo", @"foo/bar/baz" ];
  NSArray *badRelativePaths = @[ @"", @"bar/baz" ];
  NSArray *badPathLengths = @[ @1, @3 ];
  NSString *errorFormat =
      @"Invalid document reference. Document references must have an even "
      @"number of segments, but %@ has %@";
  for (NSUInteger i = 0; i < badAbsolutePaths.count; i++) {
    NSString *error =
        [NSString stringWithFormat:errorFormat, badAbsolutePaths[i], badPathLengths[i]];
    FSTAssertThrows([self.db documentWithPath:badAbsolutePaths[i]], error);
    FSTAssertThrows([baseCollectionRef documentWithPath:badRelativePaths[i]], error);
  }
}

- (void)testPathsWithEmptySegmentsFail {
  // We're only testing using collectionWithPath since the validation happens in FSTPath which is
  // shared by all methods that accept paths.

  // leading / trailing slashes are okay.
  [self.db collectionWithPath:@"/foo/"];
  [self.db collectionWithPath:@"/foo"];
  [self.db collectionWithPath:@"foo/"];

  FSTAssertThrows([self.db collectionWithPath:@"foo//bar/baz"],
                  @"Invalid path (foo//bar/baz). Paths must not contain // in them.");
  FSTAssertThrows([self.db collectionWithPath:@"//foo"],
                  @"Invalid path (//foo). Paths must not contain // in them.");
  FSTAssertThrows([self.db collectionWithPath:@"foo//"],
                  @"Invalid path (foo//). Paths must not contain // in them.");
}

#pragma mark - Write Validation

- (void)testWritesWithNonDictionaryValuesFail {
  NSArray *badData = @[
    @42, @"test", @[ @1 ], [NSDate date], [NSNull null], [FIRFieldValue fieldValueForDelete],
    [FIRFieldValue fieldValueForServerTimestamp]
  ];

  for (id data in badData) {
    [self expectWrite:data toFailWithReason:@"Data to be written must be an NSDictionary."];
  }
}

- (void)testWritesWithDirectlyNestedArraysFail {
  [self expectWrite:@{
    @"nested-array" : @[ @1, @[ @2 ] ]
  }
      toFailWithReason:@"Nested arrays are not supported"];
}

- (void)testWritesWithIndirectlyNestedArraysSucceed {
  NSDictionary<NSString *, id> *data = @{ @"nested-array" : @[ @1, @{ @"foo" : @[ @2 ] } ] };

  FIRDocumentReference *ref = [self documentRef];
  FIRDocumentReference *ref2 = [self documentRef];

  XCTestExpectation *expectation = [self expectationWithDescription:@"setData"];
  [ref setData:data
      completion:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  expectation = [self expectationWithDescription:@"batch.setData"];
  [[[ref.firestore batch] setData:data forDocument:ref]
      commitWithCompletion:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  expectation = [self expectationWithDescription:@"updateData"];
  [ref updateData:data
       completion:^(NSError *_Nullable error) {
         XCTAssertNil(error);
         [expectation fulfill];
       }];
  [self awaitExpectations];

  expectation = [self expectationWithDescription:@"batch.updateData"];
  [[[ref.firestore batch] updateData:data forDocument:ref]
      commitWithCompletion:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];

  XCTestExpectation *transactionDone = [self expectationWithDescription:@"transaction done"];
  [ref.firestore runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **pError) {
    // Note ref2 does not exist at this point so set that and update ref.
    [transaction updateData:data forDocument:ref];
    [transaction setData:data forDocument:ref2];
    return nil;
  }
      completion:^(id result, NSError *error) {
        // ends up being a no-op transaction.
        XCTAssertNil(error);
        [transactionDone fulfill];
      }];
  [self awaitExpectations];
}

- (void)testWritesWithInvalidTypesFail {
  [self expectWrite:@{
    @"foo" : @{@"bar" : self}
  }
      toFailWithReason:@"Unsupported type: FIRValidationTests (found in field foo.bar)"];
}

- (void)testWritesWithLargeNumbersFail {
  NSNumber *num = @((unsigned long long)LONG_MAX + 1);
  NSString *reason =
      [NSString stringWithFormat:@"NSNumber (%@) is too large (found in field num)", num];
  [self expectWrite:@{@"num" : num} toFailWithReason:reason];
}

- (void)testWritesWithReferencesToADifferentDatabaseFail {
  FIRDocumentReference *ref =
      [[self firestoreWithProjectID:@"different-db"] documentWithPath:@"baz/quu"];
  id data = @{@"foo" : ref};
  [self expectWrite:data
      toFailWithReason:
          [NSString
              stringWithFormat:@"Document Reference is for database different-db/(default) but "
                                "should be for database %@/(default) (found in field foo)",
                               [FSTIntegrationTestCase projectID]]];
}

- (void)testWritesWithReservedFieldsFail {
  [self expectWrite:@{
    @"__baz__" : @1
  }
      toFailWithReason:@"Document fields cannot begin and end with __ (found in field __baz__)"];
  [self expectWrite:@{
    @"foo" : @{@"__baz__" : @1}
  }
      toFailWithReason:
          @"Document fields cannot begin and end with __ (found in field foo.__baz__)"];
  [self expectWrite:@{
    @"__baz__" : @{@"foo" : @1}
  }
      toFailWithReason:@"Document fields cannot begin and end with __ (found in field __baz__)"];

  [self expectUpdate:@{
    @"foo.__baz__" : @1
  }
      toFailWithReason:
          @"Document fields cannot begin and end with __ (found in field foo.__baz__)"];
  [self expectUpdate:@{
    @"__baz__.foo" : @1
  }
      toFailWithReason:
          @"Document fields cannot begin and end with __ (found in field __baz__.foo)"];
  [self expectUpdate:@{
    @1 : @1
  }
      toFailWithReason:@"Dictionary keys in updateData: must be NSStrings or FIRFieldPaths."];
}

- (void)testSetsWithFieldValueDeleteFail {
  [self expectSet:@{@"foo" : [FIRFieldValue fieldValueForDelete]}
      toFailWithReason:
          @"FieldValue.delete() can only be used with updateData() and setData() with "
          @"SetOptions.merge()."];
}

- (void)testUpdatesWithNestedFieldValueDeleteFail {
  [self expectUpdate:@{
    @"foo" : @{@"bar" : [FIRFieldValue fieldValueForDelete]}
  }
      toFailWithReason:
          @"FieldValue.delete() can only appear at the top level of your update data "
           "(found in field foo.bar)"];
}

- (void)testBatchWritesWithIncorrectReferencesFail {
  FIRFirestore *db1 = [self firestore];
  FIRFirestore *db2 = [self firestore];
  XCTAssertNotEqual(db1, db2);

  NSString *reason = @"Provided document reference is from a different Firestore instance.";
  id data = @{ @"foo" : @1 };
  FIRDocumentReference *badRef = [db2 documentWithPath:@"foo/bar"];
  FIRWriteBatch *batch = [db1 batch];
  FSTAssertThrows([batch setData:data forDocument:badRef], reason);
  FSTAssertThrows([batch setData:data forDocument:badRef options:[FIRSetOptions merge]], reason);
  FSTAssertThrows([batch updateData:data forDocument:badRef], reason);
  FSTAssertThrows([batch deleteDocument:badRef], reason);
}

- (void)testTransactionWritesWithIncorrectReferencesFail {
  FIRFirestore *db1 = [self firestore];
  FIRFirestore *db2 = [self firestore];
  XCTAssertNotEqual(db1, db2);

  NSString *reason = @"Provided document reference is from a different Firestore instance.";
  id data = @{ @"foo" : @1 };
  FIRDocumentReference *badRef = [db2 documentWithPath:@"foo/bar"];

  XCTestExpectation *transactionDone = [self expectationWithDescription:@"transaction done"];
  [db1 runTransactionWithBlock:^id(FIRTransaction *txn, NSError **pError) {
    FSTAssertThrows([txn getDocument:badRef error:nil], reason);
    FSTAssertThrows([txn setData:data forDocument:badRef], reason);
    FSTAssertThrows([txn setData:data forDocument:badRef options:[FIRSetOptions merge]], reason);
    FSTAssertThrows([txn updateData:data forDocument:badRef], reason);
    FSTAssertThrows([txn deleteDocument:badRef], reason);
    return nil;
  }
      completion:^(id result, NSError *error) {
        // ends up being a no-op transaction.
        XCTAssertNil(error);
        [transactionDone fulfill];
      }];
  [self awaitExpectations];
}

#pragma mark - Field Path validation
// TODO(b/37244157): More validation for invalid field paths.

- (void)testFieldPathsWithEmptySegmentsFail {
  NSArray *badFieldPaths = @[ @"", @"foo..baz", @".foo", @"foo." ];

  for (NSString *fieldPath in badFieldPaths) {
    NSString *reason =
        [NSString stringWithFormat:
                      @"Invalid field path (%@). Paths must not be empty, begin with "
                      @"'.', end with '.', or contain '..'",
                      fieldPath];
    [self expectFieldPath:fieldPath toFailWithReason:reason];
  }
}

- (void)testFieldPathsWithInvalidSegmentsFail {
  NSArray *badFieldPaths = @[ @"foo~bar", @"foo*bar", @"foo/bar", @"foo[1", @"foo]1", @"foo[1]" ];

  for (NSString *fieldPath in badFieldPaths) {
    NSString *reason =
        [NSString stringWithFormat:
                      @"Invalid field path (%@). Paths must not contain '~', '*', '/', '[', or ']'",
                      fieldPath];
    [self expectFieldPath:fieldPath toFailWithReason:reason];
  }
}

#pragma mark - Query Validation

- (void)testQueryWithNonPositiveLimitFails {
  FSTAssertThrows([[self collectionRef] queryLimitedTo:0],
                  @"Invalid Query. Query limit (0) is invalid. Limit must be positive.");
  FSTAssertThrows([[self collectionRef] queryLimitedTo:-1],
                  @"Invalid Query. Query limit (-1) is invalid. Limit must be positive.");
}

- (void)testQueryInequalityOnNullOrNaNFails {
  FSTAssertThrows([[self collectionRef] queryWhereField:@"a" isGreaterThan:nil],
                  @"Invalid Query. You can only perform equality comparisons on nil / NSNull.");
  FSTAssertThrows([[self collectionRef] queryWhereField:@"a" isGreaterThan:[NSNull null]],
                  @"Invalid Query. You can only perform equality comparisons on nil / NSNull.");

  FSTAssertThrows([[self collectionRef] queryWhereField:@"a" isGreaterThan:@(NAN)],
                  @"Invalid Query. You can only perform equality comparisons on NaN.");
}

- (void)testQueryCannotBeCreatedFromDocumentsMissingSortValues {
  FIRCollectionReference *testCollection = [self collectionRefWithDocuments:@{
    @"f" : @{@"v" : @"f", @"nosort" : @1.0}
  }];

  FIRQuery *query = [testCollection queryOrderedByField:@"sort"];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:[testCollection documentWithPath:@"f"]];
  XCTAssertTrue(snapshot.exists);

  NSString *reason =
      @"Invalid query. You are trying to start or end a query using a document for "
       "which the field 'sort' (used as the order by) does not exist.";
  FSTAssertThrows([query queryStartingAtDocument:snapshot], reason);
  FSTAssertThrows([query queryStartingAfterDocument:snapshot], reason);
  FSTAssertThrows([query queryEndingBeforeDocument:snapshot], reason);
  FSTAssertThrows([query queryEndingAtDocument:snapshot], reason);
}

- (void)testQueryBoundMustNotHaveMoreComponentsThanSortOrders {
  FIRCollectionReference *testCollection = [self collectionRef];
  FIRQuery *query = [testCollection queryOrderedByField:@"foo"];

  NSString *reason =
      @"Invalid query. You are trying to start or end a query using more values "
       "than were specified in the order by.";
  // More elements than order by
  FSTAssertThrows(([query queryStartingAtValues:@[ @1, @2 ]]), reason);
  FSTAssertThrows(([[query queryOrderedByField:@"bar"] queryStartingAtValues:@[ @1, @2, @3 ]]),
                  reason);
}

- (void)testQueryOrderedByKeyBoundMustBeAStringWithoutSlashes {
  FIRCollectionReference *testCollection = [self collectionRef];
  FIRQuery *query = [testCollection queryOrderedByFieldPath:[FIRFieldPath documentID]];
  FSTAssertThrows([query queryStartingAtValues:@[ @1 ]],
                  @"Invalid query. Expected a string for the document ID.");
  FSTAssertThrows([query queryStartingAtValues:@[ @"foo/bar" ]],
                  @"Invalid query. Document ID 'foo/bar' contains a slash.");
}

- (void)testQueryMustNotSpecifyStartingOrEndingPointAfterOrder {
  FIRCollectionReference *testCollection = [self collectionRef];
  FIRQuery *query = [testCollection queryOrderedByField:@"foo"];
  NSString *reason =
      @"Invalid query. You must not specify a starting point before specifying the order by.";
  FSTAssertThrows([[query queryStartingAtValues:@[ @1 ]] queryOrderedByField:@"bar"], reason);
  FSTAssertThrows([[query queryStartingAfterValues:@[ @1 ]] queryOrderedByField:@"bar"], reason);
  reason = @"Invalid query. You must not specify an ending point before specifying the order by.";
  FSTAssertThrows([[query queryEndingAtValues:@[ @1 ]] queryOrderedByField:@"bar"], reason);
  FSTAssertThrows([[query queryEndingBeforeValues:@[ @1 ]] queryOrderedByField:@"bar"], reason);
}

- (void)testQueriesFilteredByDocumentIDMustUseStringsOrDocumentReferences {
  FIRCollectionReference *collection = [self collectionRef];
  NSString *reason =
      @"Invalid query. When querying by document ID you must provide a valid "
       "document ID, but it was an empty string.";
  FSTAssertThrows([collection queryWhereFieldPath:[FIRFieldPath documentID] isEqualTo:@""], reason);

  reason =
      @"Invalid query. When querying by document ID you must provide a valid document ID, "
       "but 'foo/bar/baz' contains a '/' character.";
  FSTAssertThrows(
      [collection queryWhereFieldPath:[FIRFieldPath documentID] isEqualTo:@"foo/bar/baz"], reason);

  reason =
      @"Invalid query. When querying by document ID you must provide a valid string or "
       "DocumentReference, but it was of type: __NSCFNumber";
  FSTAssertThrows([collection queryWhereFieldPath:[FIRFieldPath documentID] isEqualTo:@1], reason);
}

- (void)testQueryInequalityFieldMustMatchFirstOrderByField {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];
  FIRQuery *base = [coll queryWhereField:@"x" isGreaterThanOrEqualTo:@32];

  FSTAssertThrows([base queryWhereField:@"y" isLessThan:@"cat"],
                  @"Invalid Query. All where filters with an inequality (lessThan, "
                   "lessThanOrEqual, greaterThan, or greaterThanOrEqual) must be on the same "
                   "field. But you have inequality filters on 'x' and 'y'");

  NSString *reason =
      @"Invalid query. You have a where filter with "
       "an inequality (lessThan, lessThanOrEqual, greaterThan, or greaterThanOrEqual) "
       "on field 'x' and so you must also use 'x' as your first queryOrderedBy field, "
       "but your first queryOrderedBy is currently on field 'y' instead.";
  FSTAssertThrows([base queryOrderedByField:@"y"], reason);
  FSTAssertThrows([[coll queryOrderedByField:@"y"] queryWhereField:@"x" isGreaterThan:@32], reason);
  FSTAssertThrows([[base queryOrderedByField:@"y"] queryOrderedByField:@"x"], reason);
  FSTAssertThrows([[[coll queryOrderedByField:@"y"] queryOrderedByField:@"x"] queryWhereField:@"x"
                                                                                isGreaterThan:@32],
                  reason);

  XCTAssertNoThrow([base queryWhereField:@"x" isLessThanOrEqualTo:@"cat"],
                   @"Same inequality fields work");

  XCTAssertNoThrow([base queryWhereField:@"y" isEqualTo:@"cat"],
                   @"Inequality and equality on different fields works");

  XCTAssertNoThrow([base queryOrderedByField:@"x"], @"inequality same as order by works");
  XCTAssertNoThrow([[coll queryOrderedByField:@"x"] queryWhereField:@"x" isGreaterThan:@32],
                   @"inequality same as order by works");
  XCTAssertNoThrow([[base queryOrderedByField:@"x"] queryOrderedByField:@"y"],
                   @"inequality same as first order by works.");
  XCTAssertNoThrow([[[coll queryOrderedByField:@"x"] queryOrderedByField:@"y"] queryWhereField:@"x"
                                                                                 isGreaterThan:@32],
                   @"inequality same as first order by works.");
}

#pragma mark - GeoPoint Validation

- (void)testInvalidGeoPointParameters {
  [self verifyExceptionForInvalidLatitude:NAN];
  [self verifyExceptionForInvalidLatitude:-INFINITY];
  [self verifyExceptionForInvalidLatitude:INFINITY];
  [self verifyExceptionForInvalidLatitude:-90.1];
  [self verifyExceptionForInvalidLatitude:90.1];

  [self verifyExceptionForInvalidLongitude:NAN];
  [self verifyExceptionForInvalidLongitude:-INFINITY];
  [self verifyExceptionForInvalidLongitude:INFINITY];
  [self verifyExceptionForInvalidLongitude:-180.1];
  [self verifyExceptionForInvalidLongitude:180.1];
}

#pragma mark - Helpers

/** Performs a write using each write API and makes sure it fails with the expected reason. */
- (void)expectWrite:(id)data toFailWithReason:(NSString *)reason {
  [self expectWrite:data toFailWithReason:reason includeSets:YES includeUpdates:YES];
}

/** Performs a write using each set API and makes sure it fails with the expected reason. */
- (void)expectSet:(id)data toFailWithReason:(NSString *)reason {
  [self expectWrite:data toFailWithReason:reason includeSets:YES includeUpdates:NO];
}

/** Performs a write using each update API and makes sure it fails with the expected reason. */
- (void)expectUpdate:(id)data toFailWithReason:(NSString *)reason {
  [self expectWrite:data toFailWithReason:reason includeSets:NO includeUpdates:YES];
}

/**
 * Performs a write using each set and/or update API and makes sure it fails with the expected
 * reason.
 */
- (void)expectWrite:(id)data
    toFailWithReason:(NSString *)reason
         includeSets:(BOOL)includeSets
      includeUpdates:(BOOL)includeUpdates {
  FIRDocumentReference *ref = [self documentRef];
  if (includeSets) {
    FSTAssertThrows([ref setData:data], reason, @"for %@", data);
    FSTAssertThrows([[ref.firestore batch] setData:data forDocument:ref], reason, @"for %@", data);
  }

  if (includeUpdates) {
    FSTAssertThrows([ref updateData:data], reason, @"for %@", data);
    FSTAssertThrows([[ref.firestore batch] updateData:data forDocument:ref], reason, @"for %@",
                    data);
  }

  XCTestExpectation *transactionDone = [self expectationWithDescription:@"transaction done"];
  [ref.firestore runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **pError) {
    if (includeSets) {
      FSTAssertThrows([transaction setData:data forDocument:ref], reason, @"for %@", data);
    }
    if (includeUpdates) {
      FSTAssertThrows([transaction updateData:data forDocument:ref], reason, @"for %@", data);
    }
    return nil;
  }
      completion:^(id result, NSError *error) {
        // ends up being a no-op transaction.
        XCTAssertNil(error);
        [transactionDone fulfill];
      }];
  [self awaitExpectations];
}

- (void)testFieldNamesMustNotBeEmpty {
  NSString *reason = @"Invalid field path. Provided names must not be empty.";
  FSTAssertThrows([[FIRFieldPath alloc] initWithFields:@[]], reason);

  reason = @"Invalid field name at index 0. Field names must not be empty.";
  FSTAssertThrows([[FIRFieldPath alloc] initWithFields:@[ @"" ]], reason);

  reason = @"Invalid field name at index 1. Field names must not be empty.";
  FSTAssertThrows(([[FIRFieldPath alloc] initWithFields:@[ @"foo", @"" ]]), reason);
}

/**
 * Tests a field path with all of our APIs that accept field paths and ensures they fail with the
 * specified reason.
 */
- (void)expectFieldPath:(NSString *)fieldPath toFailWithReason:(NSString *)reason {
  // Get an arbitrary snapshot we can use for testing.
  FIRDocumentReference *docRef = [self documentRef];
  [self writeDocumentRef:docRef data:@{ @"test" : @1 }];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:docRef];

  // Update paths.
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  dict[fieldPath] = @1;
  [self expectUpdate:dict toFailWithReason:reason];

  // Snapshot fields.
  FSTAssertThrows(snapshot[fieldPath], reason);

  // Query filter / order fields.
  FIRCollectionReference *collection = [self collectionRef];
  FSTAssertThrows([collection queryWhereField:fieldPath isEqualTo:@1], reason);
  // isLessThan, etc. omitted for brevity since the code path is trivially shared.
  FSTAssertThrows([collection queryOrderedByField:fieldPath], reason);
}

- (void)verifyExceptionForInvalidLatitude:(double)latitude {
  NSString *reason = [NSString
      stringWithFormat:@"GeoPoint requires a latitude value in the range of [-90, 90], but was %f",
                       latitude];
  FSTAssertThrows([[FIRGeoPoint alloc] initWithLatitude:latitude longitude:0], reason);
}

- (void)verifyExceptionForInvalidLongitude:(double)longitude {
  NSString *reason =
      [NSString stringWithFormat:
                    @"GeoPoint requires a longitude value in the range of [-180, 180], but was %f",
                    longitude];
  FSTAssertThrows([[FIRGeoPoint alloc] initWithLatitude:0 longitude:longitude], reason);
}

@end
