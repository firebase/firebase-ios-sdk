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

#include <limits>

#import "FirebaseCore/Extension/FIROptionsInternal.h"
#import "Firestore/Source/API/FIRFieldValue+Internal.h"
#import "Firestore/Source/API/FIRQuery+Internal.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

#import "Firestore/Source/API/FIRFilter+Internal.h"
#include "Firestore/core/test/unit/testutil/app_testing.h"

using firebase::firestore::testutil::AppForUnitTesting;
using firebase::firestore::testutil::OptionsForUnitTesting;

// We have tests for passing nil when nil is not supposed to be allowed. So suppress the warnings.
#pragma clang diagnostic ignored "-Wnonnull"

@interface FIRValidationTests : FSTIntegrationTestCase
@end

@implementation FIRValidationTests

#pragma mark - FIRFirestoreSettings Validation

- (void)testNilHostFails {
  FIRFirestoreSettings *settings = self.db.settings;
  FSTAssertThrows(settings.host = nil,
                  @"Host setting may not be nil. You should generally just use the default value "
                   "(which is firestore.googleapis.com)");
}

- (void)testNilDispatchQueueFails {
  FIRFirestoreSettings *settings = self.db.settings;
  FSTAssertThrows(settings.dispatchQueue = nil,
                  @"Dispatch queue setting may not be nil. Create a new dispatch queue with "
                   "dispatch_queue_create(\"com.example.MyQueue\", NULL) or just use the default "
                   "(which is the main queue, returned from dispatch_get_main_queue())");
}

- (void)testChangingSettingsAfterUseFails {
  FIRFirestoreSettings *settings = self.db.settings;
  [[self.db documentWithPath:@"foo/bar"] setData:@{@"a" : @42}];
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

- (void)testNilProjectIDFails {
  FIROptions *options = OptionsForUnitTesting("ignored");
  options.projectID = nil;
  FIRApp *app = AppForUnitTesting(options);
  FSTAssertThrows([FIRFirestore firestoreForApp:app],
                  @"FIROptions.projectID must be set to a valid project ID.");
}

// TODO(b/62410906): Test for firestoreForApp:database: with nil DatabaseID.

- (void)testNilTransactionBlocksFail {
  FSTAssertThrows([self.db runTransactionWithBlock:nil
                                        completion:^(id, NSError *) {
                                          XCTFail(@"Completion shouldn't run.");
                                        }],
                  @"Transaction block cannot be nil.");

  FSTAssertThrows([self.db
                      runTransactionWithBlock:^id(FIRTransaction *, NSError **) {
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

- (void)testEmptyCollectionPathsFail {
  FIRDocumentReference *baseDocRef = [self.db documentWithPath:@"foo/bar"];
  NSString *emptyError = @"Collection path cannot be empty.";
  FSTAssertThrows([self.db collectionWithPath:@""], emptyError);
  FSTAssertThrows([baseDocRef collectionWithPath:@""], emptyError);
}

- (void)testWrongLengthCollectionPathsFail {
  FIRDocumentReference *baseDocRef = [self.db documentWithPath:@"foo/bar"];
  NSArray *badAbsolutePaths = @[ @"foo/bar/baz/quu", @"foo/bar/baz/quu/x/y" ];
  NSArray *badRelativePaths = @[ @"baz/quu", @"baz/quu/x/y" ];
  NSArray *badPathLengths = @[ @4, @6 ];
  NSString *errorFormat = @"Invalid collection reference. Collection references must have an odd "
                          @"number of segments, but %@ has %@";
  for (NSUInteger i = 0; i < badAbsolutePaths.count; i++) {
    NSString *error =
        [NSString stringWithFormat:errorFormat, badAbsolutePaths[i], badPathLengths[i]];
    FSTAssertThrows([self.db collectionWithPath:badAbsolutePaths[i]], error);
    FSTAssertThrows([baseDocRef collectionWithPath:badRelativePaths[i]], error);
  }
}

- (void)testNilCollectionGroupPathsFail {
  NSString *nilError = @"Collection ID cannot be nil.";
  FSTAssertThrows([self.db collectionGroupWithID:nil], nilError);
}

- (void)testEmptyCollectionGroupPathsFail {
  NSString *emptyError = @"Collection ID cannot be empty.";
  FSTAssertThrows([self.db collectionGroupWithID:@""], emptyError);
}

- (void)testNilDocumentPathsFail {
  FIRCollectionReference *baseCollectionRef = [self.db collectionWithPath:@"foo"];
  NSString *nilError = @"Document path cannot be nil.";
  FSTAssertThrows([self.db documentWithPath:nil], nilError);
  FSTAssertThrows([baseCollectionRef documentWithPath:nil], nilError);
}

- (void)testEmptyDocumentPathsFail {
  FIRCollectionReference *baseCollectionRef = [self.db collectionWithPath:@"foo"];
  NSString *emptyError = @"Document path cannot be empty.";
  FSTAssertThrows([self.db documentWithPath:@""], emptyError);
  FSTAssertThrows([baseCollectionRef documentWithPath:@""], emptyError);
}

- (void)testWrongLengthDocumentPathsFail {
  FIRCollectionReference *baseCollectionRef = [self.db collectionWithPath:@"foo"];
  NSArray *badAbsolutePaths = @[ @"foo/bar/baz", @"foo/bar/baz/x/y" ];
  NSArray *badRelativePaths = @[ @"bar/baz", @"bar/baz/x/y" ];
  NSArray *badPathLengths = @[ @3, @5 ];
  NSString *errorFormat = @"Invalid document reference. Document references must have an even "
                          @"number of segments, but %@ has %@";
  for (NSUInteger i = 0; i < badAbsolutePaths.count; i++) {
    NSString *error =
        [NSString stringWithFormat:errorFormat, badAbsolutePaths[i], badPathLengths[i]];
    FSTAssertThrows([self.db documentWithPath:badAbsolutePaths[i]], error);
    FSTAssertThrows([baseCollectionRef documentWithPath:badRelativePaths[i]], error);
  }
}

- (void)testPathsWithEmptySegmentsFail {
  // We're only testing using collectionWithPath since the validation happens in BasePath which is
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
  [self expectWrite:@{@"nested-array" : @[ @1, @[ @2 ] ]}
      toFailWithReason:@"Nested arrays are not supported"];
}

- (void)testWritesWithIndirectlyNestedArraysSucceed {
  NSDictionary<NSString *, id> *data = @{@"nested-array" : @[ @1, @{@"foo" : @[ @2 ]} ]};

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
  [[[ref.firestore batch] setData:data
                      forDocument:ref] commitWithCompletion:^(NSError *_Nullable error) {
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
  [[[ref.firestore batch] updateData:data
                         forDocument:ref] commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];

  XCTestExpectation *transactionDone = [self expectationWithDescription:@"transaction done"];
  [ref.firestore
      runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **) {
        // Note ref2 does not exist at this point so set that and update ref.
        [transaction updateData:data forDocument:ref];
        [transaction setData:data forDocument:ref2];
        return nil;
      }
      completion:^(id, NSError *error) {
        // ends up being a no-op transaction.
        XCTAssertNil(error);
        [transactionDone fulfill];
      }];
  [self awaitExpectations];
}

- (void)testWritesWithInvalidTypesFail {
  [self expectWrite:@{@"foo" : @{@"bar" : self}}
      toFailWithReason:@"Unsupported type: FIRValidationTests (found in field foo.bar)"];
}

- (void)testWritesWithLargeNumbersFail {
  NSNumber *num = @(static_cast<uint64_t>(std::numeric_limits<int64_t>::max()) + 1);
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
  [self expectWrite:@{@"__baz__" : @1}
      toFailWithReason:@"Invalid data. Document fields cannot begin and end with \"__\" (found in "
                       @"field __baz__)"];
  [self expectWrite:@{@"foo" : @{@"__baz__" : @1}}
      toFailWithReason:@"Invalid data. Document fields cannot begin and end with \"__\" (found in "
                       @"field foo.__baz__)"];
  [self expectWrite:@{@"__baz__" : @{@"foo" : @1}}
      toFailWithReason:@"Invalid data. Document fields cannot begin and end with \"__\" (found in "
                       @"field __baz__)"];

  [self expectUpdate:@{@"foo.__baz__" : @1}
      toFailWithReason:@"Invalid data. Document fields cannot begin and end with \"__\" (found in "
                       @"field foo.__baz__)"];
  [self expectUpdate:@{@"__baz__.foo" : @1}
      toFailWithReason:@"Invalid data. Document fields cannot begin and end with \"__\" (found in "
                       @"field __baz__.foo)"];
  [self expectUpdate:@{@1 : @1}
      toFailWithReason:@"Dictionary keys in updateData: must be NSStrings or FIRFieldPaths."];
}

- (void)testWritesMustNotContainEmptyFieldNames {
  [self expectSet:@{@"" : @"foo"}
      toFailWithReason:@"Invalid data. Document fields must not be empty (found in field ``)"];
}

- (void)testSetsWithFieldValueDeleteFail {
  [self expectSet:@{@"foo" : [FIRFieldValue fieldValueForDelete]}
      toFailWithReason:@"FieldValue.delete() can only be used with updateData() and setData() with "
                       @"merge:true (found in field foo)"];
}

- (void)testUpdatesWithNestedFieldValueDeleteFail {
  [self expectUpdate:@{@"foo" : @{@"bar" : [FIRFieldValue fieldValueForDelete]}}
      toFailWithReason:@"FieldValue.delete() can only appear at the top level of your update data "
                        "(found in field foo.bar)"];
}

- (void)testBatchWritesWithIncorrectReferencesFail {
  FIRFirestore *db1 = [self firestore];
  FIRFirestore *db2 = [self firestore];
  XCTAssertNotEqual(db1, db2);

  NSString *reason = @"Provided document reference is from a different Cloud Firestore instance.";
  id data = @{@"foo" : @1};
  FIRDocumentReference *badRef = [db2 documentWithPath:@"foo/bar"];
  FIRWriteBatch *batch = [db1 batch];
  FSTAssertThrows([batch setData:data forDocument:badRef], reason);
  FSTAssertThrows([batch setData:data forDocument:badRef merge:YES], reason);
  FSTAssertThrows([batch updateData:data forDocument:badRef], reason);
  FSTAssertThrows([batch deleteDocument:badRef], reason);
}

- (void)testTransactionWritesWithIncorrectReferencesFail {
  FIRFirestore *db1 = [self firestore];
  FIRFirestore *db2 = [self firestore];
  XCTAssertNotEqual(db1, db2);

  NSString *reason = @"Provided document reference is from a different Cloud Firestore instance.";
  id data = @{@"foo" : @1};
  FIRDocumentReference *badRef = [db2 documentWithPath:@"foo/bar"];

  XCTestExpectation *transactionDone = [self expectationWithDescription:@"transaction done"];
  [db1
      runTransactionWithBlock:^id(FIRTransaction *txn, NSError **) {
        FSTAssertThrows([txn getDocument:badRef error:nil], reason);
        FSTAssertThrows([txn setData:data forDocument:badRef], reason);
        FSTAssertThrows([txn setData:data forDocument:badRef merge:YES], reason);
        FSTAssertThrows([txn updateData:data forDocument:badRef], reason);
        FSTAssertThrows([txn deleteDocument:badRef], reason);
        return nil;
      }
      completion:^(id, NSError *error) {
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
        [NSString stringWithFormat:@"Invalid field path (%@). Paths must not be empty, begin with "
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

#pragma mark - ArrayUnion / ArrayRemove Validation

- (void)testArrayTransformsInQueriesFail {
  FSTAssertThrows(
      [[self collectionRef]
          queryWhereField:@"test"
                isEqualTo:@{@"test" : [FIRFieldValue fieldValueForArrayUnion:@[ @1 ]]}],
      @"FieldValue.arrayUnion() can only be used with updateData() and setData() (found in field "
       "test)");

  FSTAssertThrows(
      [[self collectionRef]
          queryWhereField:@"test"
                isEqualTo:@{@"test" : [FIRFieldValue fieldValueForArrayRemove:@[ @1 ]]}],
      @"FieldValue.arrayRemove() can only be used with updateData() and setData() (found in field "
      @"test)");
}

- (void)testInvalidArrayTransformElementFails {
  [self expectWrite:@{@"foo" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, self ]]}
      toFailWithReason:@"Unsupported type: FIRValidationTests"];

  [self expectWrite:@{@"foo" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, self ]]}
      toFailWithReason:@"Unsupported type: FIRValidationTests"];
}

- (void)testArraysInArrayTransformsFail {
  // This would result in a directly nested array which is not supported.
  [self expectWrite:@{@"foo" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @[ @"nested" ] ]]}
      toFailWithReason:@"Nested arrays are not supported"];

  [self expectWrite:@{@"foo" : [FIRFieldValue fieldValueForArrayRemove:@[ @1, @[ @"nested" ] ]]}
      toFailWithReason:@"Nested arrays are not supported"];
}

#pragma mark - Query Validation

- (void)testQueryWithNonPositiveLimitFails {
  FSTAssertThrows([[self collectionRef] queryLimitedTo:0],
                  @"Invalid Query. Query limit (0) is invalid. Limit must be positive.");
  FSTAssertThrows([[self collectionRef] queryLimitedTo:-1],
                  @"Invalid Query. Query limit (-1) is invalid. Limit must be positive.");
  FSTAssertThrows([[self collectionRef] queryLimitedToLast:0],
                  @"Invalid Query. Query limit (0) is invalid. Limit must be positive.");
  FSTAssertThrows([[self collectionRef] queryLimitedToLast:-1],
                  @"Invalid Query. Query limit (-1) is invalid. Limit must be positive.");
}

- (void)testQueryCannotBeCreatedFromDocumentsMissingSortValues {
  FIRCollectionReference *testCollection =
      [self collectionRefWithDocuments:@{@"f" : @{@"v" : @"f", @"nosort" : @1.0}}];

  FIRQuery *query = [testCollection queryOrderedByField:@"sort"];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:[testCollection documentWithPath:@"f"]];
  XCTAssertTrue(snapshot.exists);

  NSString *reason = @"Invalid query. You are trying to start or end a query using a document for "
                      "which the field 'sort' (used as the order by) does not exist.";
  FSTAssertThrows([query queryStartingAtDocument:snapshot], reason);
  FSTAssertThrows([query queryStartingAfterDocument:snapshot], reason);
  FSTAssertThrows([query queryEndingBeforeDocument:snapshot], reason);
  FSTAssertThrows([query queryEndingAtDocument:snapshot], reason);
}

- (void)testQueriesCannotBeSortedByAnUncommittedServerTimestamp {
  __weak FIRCollectionReference *collection = [self collectionRef];
  FIRFirestore *db = [self firestore];

  [db disableNetworkWithCompletion:[self completionForExpectationWithName:@"Disable network"]];
  [self awaitExpectations];

  XCTestExpectation *offlineCallbackDone =
      [self expectationWithDescription:@"offline callback done"];
  XCTestExpectation *onlineCallbackDone = [self expectationWithDescription:@"online callback done"];

  [collection addSnapshotListener:^(FIRQuerySnapshot *snapshot, NSError *error) {
    XCTAssertNil(error);

    // Skip the initial empty snapshot.
    if (snapshot.empty) return;

    XCTAssertEqual(snapshot.count, 1);
    FIRQueryDocumentSnapshot *docSnap = snapshot.documents[0];

    if (snapshot.metadata.pendingWrites) {
      // Offline snapshot. Since the server timestamp is uncommitted, we
      // shouldn't be able to query by it.
      NSString *reason =
          @"Invalid query. You are trying to start or end a query using a document for which the "
          @"field 'timestamp' is an uncommitted server timestamp. (Since the value of this field "
          @"is unknown, you cannot start/end a query with it.)";
      FSTAssertThrows([[[collection queryOrderedByField:@"timestamp"] queryEndingAtDocument:docSnap]
                          addSnapshotListener:^(FIRQuerySnapshot *, NSError *){
                          }],
                      reason);
      [offlineCallbackDone fulfill];
    } else {
      // Online snapshot. Since the server timestamp is committed, we should be able to query by it.
      [[[collection queryOrderedByField:@"timestamp"] queryEndingAtDocument:docSnap]
          addSnapshotListener:^(FIRQuerySnapshot *, NSError *){
          }];
      [onlineCallbackDone fulfill];
    }
  }];

  FIRDocumentReference *document = [collection documentWithAutoID];
  [document setData:@{@"timestamp" : [FIRFieldValue fieldValueForServerTimestamp]}];
  [self awaitExpectations];

  [db enableNetworkWithCompletion:[self completionForExpectationWithName:@"Enable network"]];
  [self awaitExpectations];
}

- (void)testQueryBoundMustNotHaveMoreComponentsThanSortOrders {
  FIRCollectionReference *testCollection = [self collectionRef];
  FIRQuery *query = [testCollection queryOrderedByField:@"foo"];

  NSString *reason = @"Invalid query. You are trying to start or end a query using more values "
                      "than were specified in the order by.";
  // More elements than order by
  FSTAssertThrows(([query queryStartingAtValues:@[ @1, @2 ]]), reason);
  FSTAssertThrows(([[query queryOrderedByField:@"bar"] queryStartingAtValues:@[ @1, @2, @3 ]]),
                  reason);
}

- (void)testQueryOrderedByKeyBoundMustBeAStringWithoutSlashes {
  FIRQuery *query = [[self.db collectionWithPath:@"collection"]
      queryOrderedByFieldPath:[FIRFieldPath documentID]];
  FIRQuery *cgQuery = [[self.db collectionGroupWithID:@"collection"]
      queryOrderedByFieldPath:[FIRFieldPath documentID]];
  FSTAssertThrows([query queryStartingAtValues:@[ @1 ]],
                  @"Invalid query. Expected a string for the document ID.");
  FSTAssertThrows([query queryStartingAtValues:@[ @"foo/bar" ]],
                  @"Invalid query. When querying a collection and ordering by document "
                   "ID, you must pass a plain document ID, but 'foo/bar' contains a slash.");
  FSTAssertThrows([cgQuery queryStartingAtValues:@[ @"foo" ]],
                  @"Invalid query. When querying a collection group and ordering by "
                   "document ID, you must pass a value that results in a valid document path, "
                   "but 'foo' is not because it contains an odd number of segments.");
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

- (void)testQueriesFilteredByDocumentIdMustUseStringsOrDocumentReferences {
  FIRCollectionReference *collection = [self collectionRef];
  NSString *reason = @"Invalid query. When querying by document ID you must provide a valid "
                      "document ID, but it was an empty string.";
  FSTAssertThrows([collection queryWhereFieldPath:[FIRFieldPath documentID] isEqualTo:@""], reason);

  reason = @"Invalid query. When querying a collection by document ID you must provide a "
            "plain document ID, but 'foo/bar/baz' contains a '/' character.";
  FSTAssertThrows(
      [collection queryWhereFieldPath:[FIRFieldPath documentID] isEqualTo:@"foo/bar/baz"], reason);

  reason = @"Invalid query. When querying by document ID you must provide a valid string or "
            "DocumentReference, but it was of type:";
  FSTAssertExceptionPrefix([collection queryWhereFieldPath:[FIRFieldPath documentID] isEqualTo:@1],
                           reason);

  reason = @"Invalid query. When querying a collection group by document ID, the value "
            "provided must result in a valid document path, but 'foo/bar/baz' is not because it "
            "has an odd number of segments.";
  FSTAssertThrows(
      [[self.db collectionGroupWithID:@"collection"] queryWhereFieldPath:[FIRFieldPath documentID]
                                                               isEqualTo:@"foo/bar/baz"],
      reason);

  reason =
      @"Invalid query. You can't perform arrayContains queries on document ID since document IDs "
       "are not arrays.";
  FSTAssertThrows([collection queryWhereFieldPath:[FIRFieldPath documentID] arrayContains:@1],
                  reason);
}

- (void)testQueriesUsingInAndDocumentIdMustHaveProperDocumentReferencesInArray {
  FIRCollectionReference *collection = [self collectionRef];
  NSString *reason = @"Invalid query. When querying by document ID you must provide a valid "
                      "document ID, but it was an empty string.";
  FSTAssertThrows([collection queryWhereFieldPath:[FIRFieldPath documentID] in:@[ @"" ]], reason);

  reason = @"Invalid query. When querying a collection by document ID you must provide a "
            "plain document ID, but 'foo/bar/baz' contains a '/' character.";
  FSTAssertThrows([collection queryWhereFieldPath:[FIRFieldPath documentID] in:@[ @"foo/bar/baz" ]],
                  reason);

  reason = @"Invalid query. When querying by document ID you must provide a valid string or "
            "DocumentReference, but it was of type:";
  NSArray *value = @[ @1, @2 ];
  FSTAssertExceptionPrefix([collection queryWhereFieldPath:[FIRFieldPath documentID] in:value],
                           reason);

  reason = @"Invalid query. When querying a collection group by document ID, the value "
            "provided must result in a valid document path, but 'foo' is not because it "
            "has an odd number of segments.";
  FSTAssertThrows(
      [[self.db collectionGroupWithID:@"collection"] queryWhereFieldPath:[FIRFieldPath documentID]
                                                                      in:@[ @"foo" ]],
      reason);
}

- (void)testInvalidQueryFilters {
  FIRCollectionReference *collection = [self collectionRef];

  // Multiple inequalities, one of which is inside a nested composite filter.
  NSString *reason = @"Invalid Query. All where filters with an inequality (notEqual, lessThan, "
                      "lessThanOrEqual, greaterThan, or greaterThanOrEqual) must be on the same "
                      "field. But you have inequality filters on 'c' and 'r'";

  NSArray<FIRFilter *> *array1 = @[
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"a" isEqualTo:@"b"], [FIRFilter filterWhereField:@"c"
                                                                      isGreaterThan:@"d"]
    ]],
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"e" isEqualTo:@"f"], [FIRFilter filterWhereField:@"g"
                                                                          isEqualTo:@"h"]
    ]]
  ];

  FSTAssertThrows(
      [[collection queryWhereFilter:[FIRFilter orFilterWithFilters:array1]] queryWhereField:@"r"
                                                                              isGreaterThan:@"s"],
      reason);

  // OrderBy and inequality on different fields. Inequality inside a nested composite filter.
  reason = @"Invalid query. You have a where filter with an inequality (notEqual, lessThan, "
            "lessThanOrEqual, greaterThan, or greaterThanOrEqual) on field 'c' and so you must "
            "also use 'c' as your first queryOrderedBy field, but your first queryOrderedBy is "
            "currently on field 'r' instead.";

  FSTAssertThrows([[collection queryWhereFilter:[FIRFilter orFilterWithFilters:array1]]
                      queryOrderedByField:@"r"],
                  reason);

  // Conflicting operations within a composite filter.
  reason = @"Invalid Query. You cannot use 'notIn' filters with 'in' filters.";

  NSArray<FIRFilter *> *array2 = @[
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"a" isEqualTo:@"b"], [FIRFilter filterWhereField:@"c"
                                                                                 in:@[ @"d", @"e" ]]
    ]],
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"e" isEqualTo:@"f"], [FIRFilter filterWhereField:@"c"
                                                                              notIn:@[ @"f", @"g" ]]
    ]]
  ];

  FSTAssertThrows([collection queryWhereFilter:[FIRFilter orFilterWithFilters:array2]], reason);

  // Conflicting operations between a field filter and a composite filter.
  NSArray<FIRFilter *> *array3 = @[
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"a" isEqualTo:@"b"], [FIRFilter filterWhereField:@"c"
                                                                                 in:@[ @"d", @"e" ]]
    ]],
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"e" isEqualTo:@"f"], [FIRFilter filterWhereField:@"g"
                                                                          isEqualTo:@"h"]
    ]]
  ];

  NSArray<NSString *> *array4 = @[ @"j", @"k" ];

  FSTAssertThrows(
      [[collection queryWhereFilter:[FIRFilter orFilterWithFilters:array3]] queryWhereField:@"i"
                                                                                      notIn:array4],
      reason);

  // Conflicting operations between two composite filters.
  NSArray<FIRFilter *> *array5 = @[
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"i" isEqualTo:@"j"], [FIRFilter filterWhereField:@"l"
                                                                              notIn:@[ @"m", @"n" ]]
    ]],
    [FIRFilter andFilterWithFilters:@[
      [FIRFilter filterWhereField:@"o" isEqualTo:@"p"], [FIRFilter filterWhereField:@"q"
                                                                          isEqualTo:@"r"]
    ]]
  ];

  FSTAssertThrows([[collection queryWhereFilter:[FIRFilter orFilterWithFilters:array3]]
                      queryWhereFilter:[FIRFilter orFilterWithFilters:array5]],
                  reason);
}

- (void)testQueryInequalityFieldMustMatchFirstOrderByField {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];
  FIRQuery *base = [coll queryWhereField:@"x" isGreaterThanOrEqualTo:@32];

  FSTAssertThrows([base queryWhereField:@"y" isLessThan:@"cat"],
                  @"Invalid Query. All where filters with an inequality (notEqual, lessThan, "
                   "lessThanOrEqual, greaterThan, or greaterThanOrEqual) must be on the same "
                   "field. But you have inequality filters on 'x' and 'y'");

  NSString *reason =
      @"Invalid query. You have a where filter with "
       "an inequality (notEqual, lessThan, lessThanOrEqual, greaterThan, or greaterThanOrEqual) "
       "on field 'x' and so you must also use 'x' as your first queryOrderedBy field, "
       "but your first queryOrderedBy is currently on field 'y' instead.";
  FSTAssertThrows([base queryOrderedByField:@"y"], reason);
  FSTAssertThrows([[coll queryOrderedByField:@"y"] queryWhereField:@"x" isGreaterThan:@32], reason);
  FSTAssertThrows([[base queryOrderedByField:@"y"] queryOrderedByField:@"x"], reason);
  FSTAssertThrows([[[coll queryOrderedByField:@"y"] queryOrderedByField:@"x"] queryWhereField:@"x"
                                                                                isGreaterThan:@32],
                  reason);
  FSTAssertThrows([[coll queryOrderedByField:@"y"] queryWhereField:@"x" isNotEqualTo:@32], reason);

  XCTAssertNoThrow([base queryWhereField:@"x" isLessThanOrEqualTo:@"cat"],
                   @"Same inequality fields work");

  XCTAssertNoThrow([base queryWhereField:@"y" isEqualTo:@"cat"],
                   @"Inequality and equality on different fields works");
  XCTAssertNoThrow([base queryWhereField:@"y" arrayContains:@"cat"],
                   @"Inequality and array_contains on different fields works");
  XCTAssertNoThrow([base queryWhereField:@"y" arrayContainsAny:@[ @"cat" ]],
                   @"array-contains-any on different fields works");
  XCTAssertNoThrow([base queryWhereField:@"y" in:@[ @"cat" ]], @"IN on different fields works");

  XCTAssertNoThrow([base queryOrderedByField:@"x"], @"inequality same as order by works");
  XCTAssertNoThrow([[coll queryOrderedByField:@"x"] queryWhereField:@"x" isGreaterThan:@32],
                   @"inequality same as order by works");
  XCTAssertNoThrow([[base queryOrderedByField:@"x"] queryOrderedByField:@"y"],
                   @"inequality same as first order by works.");
  XCTAssertNoThrow([[[coll queryOrderedByField:@"x"] queryOrderedByField:@"y"] queryWhereField:@"x"
                                                                                 isGreaterThan:@32],
                   @"inequality same as first order by works.");

  XCTAssertNoThrow([[coll queryOrderedByField:@"x"] queryWhereField:@"y" isEqualTo:@"cat"],
                   @"equality different than orderBy works.");
  XCTAssertNoThrow([[coll queryOrderedByField:@"x"] queryWhereField:@"y" arrayContains:@"cat"],
                   @"array_contains different than orderBy works.");
}

- (void)testQueriesWithMultipleNotEqualAndInequalitiesFail {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];

  FSTAssertThrows([[coll queryWhereField:@"x" isNotEqualTo:@1] queryWhereField:@"x"
                                                                  isNotEqualTo:@2],
                  @"Invalid Query. You cannot use more than one 'notEqual' filter.");

  FSTAssertThrows([[coll queryWhereField:@"x" isNotEqualTo:@1] queryWhereField:@"y"
                                                                  isNotEqualTo:@2],
                  @"Invalid Query. All where filters with an inequality (notEqual, lessThan, "
                   "lessThanOrEqual, greaterThan, or greaterThanOrEqual) must be on "
                   "the same field. But you have inequality filters on 'x' and 'y'");
}

- (void)testQueriesWithMultipleArrayFiltersFail {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];
  FSTAssertThrows([[coll queryWhereField:@"foo" arrayContains:@1] queryWhereField:@"foo"
                                                                    arrayContains:@2],
                  @"Invalid Query. You cannot use more than one 'arrayContains' filter.");

  FSTAssertThrows(
      [[coll queryWhereField:@"foo" arrayContains:@1] queryWhereField:@"foo"
                                                     arrayContainsAny:@[ @2 ]],
      @"Invalid Query. You cannot use 'arrayContainsAny' filters with 'arrayContains' filters.");

  FSTAssertThrows(
      [[coll queryWhereField:@"foo" arrayContainsAny:@[ @1 ]] queryWhereField:@"foo"
                                                                arrayContains:@2],
      @"Invalid Query. You cannot use 'arrayContains' filters with 'arrayContainsAny' filters.");
}

- (void)testQueriesWithNotEqualAndNotInFiltersFail {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];

  FSTAssertThrows([[coll queryWhereField:@"foo" notIn:@[ @1 ]] queryWhereField:@"foo"
                                                                  isNotEqualTo:@2],
                  @"Invalid Query. You cannot use 'notEqual' filters with 'notIn' filters.");

  FSTAssertThrows([[coll queryWhereField:@"foo" isNotEqualTo:@2] queryWhereField:@"foo"
                                                                           notIn:@[ @1 ]],
                  @"Invalid Query. You cannot use 'notIn' filters with 'notEqual' filters.");
}

- (void)testQueriesWithMultipleDisjunctiveFiltersFail {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];
  FSTAssertThrows([[coll queryWhereField:@"foo" in:@[ @1 ]] queryWhereField:@"foo" in:@[ @2 ]],
                  @"Invalid Query. You cannot use more than one 'in' filter.");

  FSTAssertThrows([[coll queryWhereField:@"foo" arrayContainsAny:@[ @1 ]] queryWhereField:@"foo"
                                                                         arrayContainsAny:@[ @2 ]],
                  @"Invalid Query. You cannot use more than one 'arrayContainsAny' filter.");

  FSTAssertThrows([[coll queryWhereField:@"foo" notIn:@[ @1 ]] queryWhereField:@"foo"
                                                                         notIn:@[ @2 ]],
                  @"Invalid Query. You cannot use more than one 'notIn' filter.");

  FSTAssertThrows([[coll queryWhereField:@"foo" arrayContainsAny:@[ @1 ]] queryWhereField:@"foo"
                                                                                       in:@[ @2 ]],
                  @"Invalid Query. You cannot use 'in' filters with 'arrayContainsAny' filters.");

  FSTAssertThrows([[coll queryWhereField:@"foo" in:@[ @1 ]] queryWhereField:@"foo"
                                                           arrayContainsAny:@[ @2 ]],
                  @"Invalid Query. You cannot use 'arrayContainsAny' filters with 'in' filters.");

  FSTAssertThrows(
      [[coll queryWhereField:@"foo" arrayContainsAny:@[ @1 ]] queryWhereField:@"foo" notIn:@[ @2 ]],
      @"Invalid Query. You cannot use 'notIn' filters with 'arrayContainsAny' filters.");

  FSTAssertThrows(
      [[coll queryWhereField:@"foo" notIn:@[ @1 ]] queryWhereField:@"foo" arrayContainsAny:@[ @2 ]],
      @"Invalid Query. You cannot use 'arrayContainsAny' filters with 'notIn' filters.");

  FSTAssertThrows([[coll queryWhereField:@"foo" in:@[ @1 ]] queryWhereField:@"foo" notIn:@[ @2 ]],
                  @"Invalid Query. You cannot use 'notIn' filters with 'in' filters.");

  FSTAssertThrows([[coll queryWhereField:@"foo" notIn:@[ @1 ]] queryWhereField:@"foo" in:@[ @2 ]],
                  @"Invalid Query. You cannot use 'in' filters with 'notIn' filters.");

  // This is redundant with the above tests, but makes sure our validation doesn't get confused.
  FSTAssertThrows([[[coll queryWhereField:@"foo"
                                       in:@[ @1 ]] queryWhereField:@"foo"
                                                     arrayContains:@2] queryWhereField:@"foo"
                                                                      arrayContainsAny:@[ @2 ]],
                  @"Invalid Query. You cannot use 'arrayContainsAny' filters with 'in' filters.");

  FSTAssertThrows(
      [[[coll queryWhereField:@"foo"
                arrayContains:@1] queryWhereField:@"foo" in:@[ @2 ]] queryWhereField:@"foo"
                                                                    arrayContainsAny:@[ @2 ]],
      @"Invalid Query. You cannot use 'arrayContainsAny' filters with 'arrayContains' filters.");

  FSTAssertThrows([[[coll queryWhereField:@"foo"
                                    notIn:@[ @1 ]] queryWhereField:@"foo"
                                                     arrayContains:@2] queryWhereField:@"foo"
                                                                      arrayContainsAny:@[ @2 ]],
                  @"Invalid Query. You cannot use 'arrayContains' filters with 'notIn' filters.");

  FSTAssertThrows([[[coll queryWhereField:@"foo"
                            arrayContains:@1] queryWhereField:@"foo"
                                                           in:@[ @2 ]] queryWhereField:@"foo"
                                                                                 notIn:@[ @2 ]],
                  @"Invalid Query. You cannot use 'notIn' filters with 'arrayContains' filters.");
}

- (void)testQueriesCanUseInWithArrayContain {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];
  XCTAssertNoThrow([[coll queryWhereField:@"foo" arrayContains:@1] queryWhereField:@"foo"
                                                                                in:@[ @2 ]],
                   @"arrayContains with IN works.");

  XCTAssertNoThrow([[coll queryWhereField:@"foo" in:@[ @1 ]] queryWhereField:@"foo"
                                                               arrayContains:@2],
                   @"IN with arrayContains works.");

  FSTAssertThrows([[[coll queryWhereField:@"foo"
                                       in:@[ @1 ]] queryWhereField:@"foo"
                                                     arrayContains:@2] queryWhereField:@"foo"
                                                                         arrayContains:@3],
                  @"Invalid Query. You cannot use more than one 'arrayContains' filter.");

  FSTAssertThrows([[[coll queryWhereField:@"foo"
                            arrayContains:@1] queryWhereField:@"foo"
                                                           in:@[ @2 ]] queryWhereField:@"foo"
                                                                                    in:@[ @3 ]],
                  @"Invalid Query. You cannot use more than one 'in' filter.");
}

- (void)testQueriesInAndArrayContainsAnyArrayRules {
  FIRCollectionReference *coll = [self.db collectionWithPath:@"collection"];

  FSTAssertThrows([coll queryWhereField:@"foo" in:@[]],
                  @"Invalid Query. A non-empty array is required for 'in' filters.");

  FSTAssertThrows([coll queryWhereField:@"foo" notIn:@[]],
                  @"Invalid Query. A non-empty array is required for 'notIn' filters.");

  FSTAssertThrows([coll queryWhereField:@"foo" arrayContainsAny:@[]],
                  @"Invalid Query. A non-empty array is required for 'arrayContainsAny' filters.");

  // The 10 element max includes duplicates.
  NSArray *values = @[ @1, @2, @3, @4, @5, @6, @7, @8, @9, @9, @9 ];
  FSTAssertThrows(
      [coll queryWhereField:@"foo" in:values],
      @"Invalid Query. 'in' filters support a maximum of 10 elements in the value array.");
  FSTAssertThrows([coll queryWhereField:@"foo" arrayContainsAny:values],
                  @"Invalid Query. 'arrayContainsAny' filters support a maximum of 10 elements"
                   " in the value array.");
  FSTAssertThrows(
      [coll queryWhereField:@"foo" notIn:values],
      @"Invalid Query. 'notIn' filters support a maximum of 10 elements in the value array.");
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
  [ref.firestore
      runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **) {
        if (includeSets) {
          FSTAssertThrows([transaction setData:data forDocument:ref], reason, @"for %@", data);
        }
        if (includeUpdates) {
          FSTAssertThrows([transaction updateData:data forDocument:ref], reason, @"for %@", data);
        }
        return nil;
      }
      completion:^(id, NSError *error) {
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
  [self writeDocumentRef:docRef data:@{@"test" : @1}];
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
      stringWithFormat:@"GeoPoint requires a latitude value in the range of [-90, 90], but was %g",
                       latitude];
  FSTAssertThrows([[FIRGeoPoint alloc] initWithLatitude:latitude longitude:0], reason);
}

- (void)verifyExceptionForInvalidLongitude:(double)longitude {
  NSString *reason =
      [NSString stringWithFormat:
                    @"GeoPoint requires a longitude value in the range of [-180, 180], but was %g",
                    longitude];
  FSTAssertThrows([[FIRGeoPoint alloc] initWithLatitude:0 longitude:longitude], reason);
}

@end
