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

#import "Firestore/Source/Core/FSTFirestoreClient.h"

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

@interface FIRServerTimestampTests : FSTIntegrationTestCase
@end

@implementation FIRServerTimestampTests {
  // Data written in tests via set.
  NSDictionary *_setData;

  // Base and update data used for update tests.
  NSDictionary *_initialData;
  NSDictionary *_updateData;

  // A document reference to read and write to.
  FIRDocumentReference *_docRef;

  // Accumulator used to capture events during the test.
  FSTEventAccumulator *_accumulator;

  // Listener registration for a listener maintained during the course of the test.
  id<FIRListenerRegistration> _listenerRegistration;
}

- (void)setUp {
  [super setUp];

  // Data written in tests via set.
  _setData = @{
    @"a" : @42,
    @"when" : [FIRFieldValue fieldValueForServerTimestamp],
    @"deep" : @{@"when" : [FIRFieldValue fieldValueForServerTimestamp]}
  };

  // Base and update data used for update tests.
  _initialData = @{ @"a" : @42 };
  _updateData = @{
    @"when" : [FIRFieldValue fieldValueForServerTimestamp],
    @"deep" : @{@"when" : [FIRFieldValue fieldValueForServerTimestamp]}
  };

  _docRef = [self documentRef];
  _accumulator = [FSTEventAccumulator accumulatorForTest:self];
  _listenerRegistration = [_docRef addSnapshotListener:_accumulator.handler];

  // Wait for initial nil snapshot to avoid potential races.
  FIRDocumentSnapshot *initialSnapshot = [_accumulator awaitEventWithName:@"initial event"];
  XCTAssertFalse(initialSnapshot.exists);
}

- (void)tearDown {
  [_listenerRegistration remove];

  [super tearDown];
}

// Returns the expected data, with an arbitrary timestamp substituted in.
- (NSDictionary *)expectedDataWithTimestamp:(id _Nullable)timestamp {
  return @{ @"a" : @42, @"when" : timestamp, @"deep" : @{@"when" : timestamp} };
}

/** Writes _initialData and waits for the corresponding snapshot. */
- (void)writeInitialData {
  [self writeDocumentRef:_docRef data:_initialData];
  FIRDocumentSnapshot *initialDataSnap = [_accumulator awaitEventWithName:@"Initial data event."];
  XCTAssertEqualObjects(initialDataSnap.data, _initialData);
}

/** Waits for a snapshot containing _setData but with NSNull for the timestamps. */
- (void)waitForLocalEvent {
  FIRDocumentSnapshot *localSnap = [_accumulator awaitEventWithName:@"Local event."];
  XCTAssertEqualObjects(localSnap.data, [self expectedDataWithTimestamp:[NSNull null]]);
}

/** Waits for a snapshot containing _setData but with resolved server timestamps. */
- (void)waitForRemoteEvent {
  // server event should have a resolved timestamp; verify it.
  FIRDocumentSnapshot *remoteSnap = [_accumulator awaitEventWithName:@"Remote event"];
  XCTAssertTrue(remoteSnap.exists);
  NSDate *when = remoteSnap[@"when"];
  XCTAssertTrue([when isKindOfClass:[NSDate class]]);
  // Tolerate up to 10 seconds of clock skew between client and server.
  XCTAssertEqualWithAccuracy(when.timeIntervalSinceNow, 0, 10);

  // Validate the rest of the document.
  XCTAssertEqualObjects(remoteSnap.data, [self expectedDataWithTimestamp:when]);
}

- (void)runTransactionBlock:(void (^)(FIRTransaction *transaction))transactionBlock {
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction complete"];
  [_docRef.firestore runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **pError) {
    transactionBlock(transaction);
    return nil;
  }
      completion:^(id result, NSError *error) {
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

- (void)testServerTimestampsWorkViaSet {
  [self writeDocumentRef:_docRef data:_setData];
  [self waitForLocalEvent];
  [self waitForRemoteEvent];
}

- (void)testServerTimestampsWorkViaUpdate {
  [self writeInitialData];
  [self updateDocumentRef:_docRef data:_updateData];
  [self waitForLocalEvent];
  [self waitForRemoteEvent];
}

- (void)testServerTimestampsWorkViaTransactionSet {
  [self runTransactionBlock:^(FIRTransaction *transaction) {
    [transaction setData:_setData forDocument:_docRef];
  }];

  [self waitForRemoteEvent];
}

- (void)testServerTimestampsWorkViaTransactionUpdate {
  [self writeInitialData];
  [self runTransactionBlock:^(FIRTransaction *transaction) {
    [transaction updateData:_updateData forDocument:_docRef];
  }];
  [self waitForRemoteEvent];
}

- (void)testServerTimestampsFailViaUpdateOnNonexistentDocument {
  XCTestExpectation *expectation = [self expectationWithDescription:@"update complete"];
  [_docRef updateData:_updateData
           completion:^(NSError *error) {
             XCTAssertNotNil(error);
             XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
             XCTAssertEqual(error.code, FIRFirestoreErrorCodeNotFound);
             [expectation fulfill];
           }];
  [self awaitExpectations];
}

- (void)testServerTimestampsFailViaTransactionUpdateOnNonexistentDocument {
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction complete"];
  [_docRef.firestore runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **pError) {
    [transaction updateData:_updateData forDocument:_docRef];
    return nil;
  }
      completion:^(id result, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
        // TODO(b/35201829): This should be NotFound, but right now we retry transactions on any
        // error and so this turns into Aborted instead.
        // TODO(mikelehen): Actually it's FailedPrecondition, unlike Android. What do we want???
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeFailedPrecondition);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

@end
