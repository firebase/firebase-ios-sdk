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

@import FirebaseFirestore;

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FIRWriteBatchTests : FSTIntegrationTestCase
@end

@implementation FIRWriteBatchTests

- (void)testSupportEmptyBatches {
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  [[[self firestore] batch] commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self awaitExpectations];
}

- (void)testSetDocuments {
  FIRDocumentReference *doc = [self documentRef];
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch setData:@{@"a" : @"b"} forDocument:doc];
  [batch setData:@{@"c" : @"d"} forDocument:doc];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(snapshot.data, @{@"c" : @"d"});
}

- (void)testSetDocumentWithMerge {
  FIRDocumentReference *doc = [self documentRef];
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch setData:@{ @"a" : @"b", @"nested" : @{@"a" : @"b"} } forDocument:doc];
  [batch setData:@{
    @"c" : @"d",
    @"nested" : @{@"c" : @"d"}
  }
      forDocument:doc
          options:[FIRSetOptions merge]];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(
      snapshot.data, (
                         @{ @"a" : @"b",
                            @"c" : @"d",
                            @"nested" : @{@"a" : @"b", @"c" : @"d"} }));
}

- (void)testUpdateDocuments {
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch updateData:@{ @"baz" : @42 } forDocument:doc];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];
  XCTAssertTrue(snapshot.exists);
  XCTAssertEqualObjects(snapshot.data, (@{ @"foo" : @"bar", @"baz" : @42 }));
}

- (void)testCannotUpdateNonexistentDocuments {
  FIRDocumentReference *doc = [self documentRef];
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch updateData:@{ @"baz" : @42 } forDocument:doc];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNotNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  FIRDocumentSnapshot *result = [self readDocumentForRef:doc];
  XCTAssertFalse(result.exists);
}

- (void)testDeleteDocuments {
  FIRDocumentReference *doc = [self documentRef];
  [self writeDocumentRef:doc data:@{@"foo" : @"bar"}];
  FIRDocumentSnapshot *snapshot = [self readDocumentForRef:doc];

  XCTAssertTrue(snapshot.exists);
  XCTestExpectation *batchExpectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch deleteDocument:doc];
  [batch commitWithCompletion:^(NSError *error) {
    XCTAssertNil(error);
    [batchExpectation fulfill];
  }];
  [self awaitExpectations];
  snapshot = [self readDocumentForRef:doc];
  XCTAssertFalse(snapshot.exists);
}

- (void)testBatchesCommitAtomicallyRaisingCorrectEvents {
  FIRCollectionReference *collection = [self collectionRef];
  FIRDocumentReference *docA = [collection documentWithPath:@"a"];
  FIRDocumentReference *docB = [collection documentWithPath:@"b"];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [collection addSnapshotListenerWithOptions:[[FIRQueryListenOptions options]
                                                 includeQueryMetadataChanges:YES]
                                    listener:accumulator.handler];
  FIRQuerySnapshot *initialSnap = [accumulator awaitEventWithName:@"initial event"];
  XCTAssertEqual(initialSnap.count, 0);

  // Atomically write two documents.
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [collection.firestore batch];
  [batch setData:@{ @"a" : @1 } forDocument:docA];
  [batch setData:@{ @"b" : @2 } forDocument:docB];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  FIRQuerySnapshot *localSnap = [accumulator awaitEventWithName:@"local event"];
  XCTAssertTrue(localSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(localSnap), (@[ @{ @"a" : @1 }, @{ @"b" : @2 } ]));

  FIRQuerySnapshot *serverSnap = [accumulator awaitEventWithName:@"server event"];
  XCTAssertFalse(serverSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(serverSnap), (@[ @{ @"a" : @1 }, @{ @"b" : @2 } ]));
}

- (void)testBatchesFailAtomicallyRaisingCorrectEvents {
  FIRCollectionReference *collection = [self collectionRef];
  FIRDocumentReference *docA = [collection documentWithPath:@"a"];
  FIRDocumentReference *docB = [collection documentWithPath:@"b"];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [collection addSnapshotListenerWithOptions:[[FIRQueryListenOptions options]
                                                 includeQueryMetadataChanges:YES]
                                    listener:accumulator.handler];
  FIRQuerySnapshot *initialSnap = [accumulator awaitEventWithName:@"initial event"];
  XCTAssertEqual(initialSnap.count, 0);

  // Atomically write 1 document and update a nonexistent document.
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch failed"];
  FIRWriteBatch *batch = [collection.firestore batch];
  [batch setData:@{ @"a" : @1 } forDocument:docA];
  [batch updateData:@{ @"b" : @2 } forDocument:docB];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNotNil(error);
    XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
    XCTAssertEqual(error.code, FIRFirestoreErrorCodeNotFound);
    [expectation fulfill];
  }];

  // Local event with the set document.
  FIRQuerySnapshot *localSnap = [accumulator awaitEventWithName:@"local event"];
  XCTAssertTrue(localSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(localSnap), (@[ @{ @"a" : @1 } ]));

  // Server event with the set reverted.
  FIRQuerySnapshot *serverSnap = [accumulator awaitEventWithName:@"server event"];
  XCTAssertFalse(serverSnap.metadata.hasPendingWrites);
  XCTAssertEqual(serverSnap.count, 0);
}

- (void)testWriteTheSameServerTimestampAcrossWrites {
  FIRCollectionReference *collection = [self collectionRef];
  FIRDocumentReference *docA = [collection documentWithPath:@"a"];
  FIRDocumentReference *docB = [collection documentWithPath:@"b"];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [collection addSnapshotListenerWithOptions:[[FIRQueryListenOptions options]
                                                 includeQueryMetadataChanges:YES]
                                    listener:accumulator.handler];
  FIRQuerySnapshot *initialSnap = [accumulator awaitEventWithName:@"initial event"];
  XCTAssertEqual(initialSnap.count, 0);

  // Atomically write 2 documents with server timestamps.
  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [collection.firestore batch];
  [batch setData:@{@"when" : [FIRFieldValue fieldValueForServerTimestamp]} forDocument:docA];
  [batch setData:@{@"when" : [FIRFieldValue fieldValueForServerTimestamp]} forDocument:docB];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  FIRQuerySnapshot *localSnap = [accumulator awaitEventWithName:@"local event"];
  XCTAssertTrue(localSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(localSnap),
                        (@[ @{@"when" : [NSNull null]}, @{@"when" : [NSNull null]} ]));

  FIRQuerySnapshot *serverSnap = [accumulator awaitEventWithName:@"server event"];
  XCTAssertFalse(serverSnap.metadata.hasPendingWrites);
  XCTAssertEqual(serverSnap.count, 2);
  NSDate *when = serverSnap.documents[0][@"when"];
  XCTAssertEqualObjects(FIRQuerySnapshotGetData(serverSnap),
                        (@[ @{@"when" : when}, @{@"when" : when} ]));
}

- (void)testCanWriteTheSameDocumentMultipleTimes {
  FIRDocumentReference *doc = [self documentRef];
  FSTEventAccumulator *accumulator = [FSTEventAccumulator accumulatorForTest:self];
  [doc
      addSnapshotListenerWithOptions:[[FIRDocumentListenOptions options] includeMetadataChanges:YES]
                            listener:accumulator.handler];
  FIRDocumentSnapshot *initialSnap = [accumulator awaitEventWithName:@"initial event"];
  XCTAssertFalse(initialSnap.exists);

  XCTestExpectation *expectation = [self expectationWithDescription:@"batch written"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch deleteDocument:doc];
  [batch setData:@{ @"a" : @1, @"b" : @1, @"when" : @"when" } forDocument:doc];
  [batch updateData:@{
    @"b" : @2,
    @"when" : [FIRFieldValue fieldValueForServerTimestamp]
  }
        forDocument:doc];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];

  FIRDocumentSnapshot *localSnap = [accumulator awaitEventWithName:@"local event"];
  XCTAssertTrue(localSnap.metadata.hasPendingWrites);
  XCTAssertEqualObjects(localSnap.data, (@{ @"a" : @1, @"b" : @2, @"when" : [NSNull null] }));

  FIRDocumentSnapshot *serverSnap = [accumulator awaitEventWithName:@"server event"];
  XCTAssertFalse(serverSnap.metadata.hasPendingWrites);
  NSDate *when = serverSnap[@"when"];
  XCTAssertEqualObjects(serverSnap.data, (@{ @"a" : @1, @"b" : @2, @"when" : when }));
}

- (void)testUpdateFieldsWithDots {
  FIRDocumentReference *doc = [self documentRef];

  XCTestExpectation *expectation = [self expectationWithDescription:@"testUpdateFieldsWithDots"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch setData:@{@"a.b" : @"old", @"c.d" : @"old"} forDocument:doc];
  [batch updateData:@{
    [[FIRFieldPath alloc] initWithFields:@[ @"a.b" ]] : @"new"
  }
        forDocument:doc];

  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(snapshot.data, (@{@"a.b" : @"new", @"c.d" : @"old"}));
    }];
    [expectation fulfill];
  }];

  [self awaitExpectations];
}

- (void)testUpdateNestedFields {
  FIRDocumentReference *doc = [self documentRef];

  XCTestExpectation *expectation = [self expectationWithDescription:@"testUpdateNestedFields"];
  FIRWriteBatch *batch = [doc.firestore batch];
  [batch setData:@{
    @"a" : @{@"b" : @"old"},
    @"c" : @{@"d" : @"old"},
    @"e" : @{@"f" : @"old"}
  }
      forDocument:doc];
  [batch updateData:@{
    @"a.b" : @"new",
    [[FIRFieldPath alloc] initWithFields:@[ @"c", @"d" ]] : @"new"
  }
        forDocument:doc];
  [batch commitWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [doc getDocumentWithCompletion:^(FIRDocumentSnapshot *snapshot, NSError *error) {
      XCTAssertNil(error);
      XCTAssertEqualObjects(snapshot.data, (@{
                              @"a" : @{@"b" : @"new"},
                              @"c" : @{@"d" : @"new"},
                              @"e" : @{@"f" : @"old"}
                            }));
    }];
    [expectation fulfill];
  }];

  [self awaitExpectations];
}

@end
