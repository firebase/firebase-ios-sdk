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

#import "FirebaseCore/Sources/Public/FirebaseCore/FIRTimestamp.h"

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"

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
  _initialData = @{@"a" : @42};
  _updateData = @{
    @"when" : [FIRFieldValue fieldValueForServerTimestamp],
    @"deep" : @{@"when" : [FIRFieldValue fieldValueForServerTimestamp]}
  };

  _docRef = [self documentRef];
  _accumulator = [FSTEventAccumulator accumulatorForTest:self];
  _listenerRegistration = [_docRef addSnapshotListener:_accumulator.valueEventHandler];

  // Wait for initial nil snapshot to avoid potential races.
  FIRDocumentSnapshot *initialSnapshot = [_accumulator awaitEventWithName:@"initial event"];
  XCTAssertFalse(initialSnapshot.exists);
}

- (void)tearDown {
  [_listenerRegistration remove];

  [super tearDown];
}

#pragma mark - Test Helpers

/** Returns the expected data, with the specified timestamp substituted in. */
- (NSDictionary *)expectedDataWithTimestamp:(nullable id)timestamp {
  return @{@"a" : @42, @"when" : timestamp, @"deep" : @{@"when" : timestamp}};
}

/** Writes _initialData and waits for the corresponding snapshot. */
- (void)writeInitialData {
  [self writeDocumentRef:_docRef data:_initialData];
  FIRDocumentSnapshot *initialDataSnap = [_accumulator awaitEventWithName:@"Initial data event."];
  XCTAssertEqualObjects(initialDataSnap.data, _initialData);
}

/** Verifies a snapshot containing _setData but with NSNull for the timestamps. */
- (void)verifyTimestampsAreNullInSnapshot:(FIRDocumentSnapshot *)snapshot {
  XCTAssertEqualObjects(snapshot.data, [self expectedDataWithTimestamp:[NSNull null]]);
}

/** Verifies a snapshot  containing _setData but with a local estimate for the timestamps. */
- (void)verifyTimestampsAreEstimatedInSnapshot:(FIRDocumentSnapshot *)snapshot {
  id timestamp = [snapshot valueForField:@"when"
                 serverTimestampBehavior:FIRServerTimestampBehaviorEstimate];
  XCTAssertTrue([timestamp isKindOfClass:[FIRTimestamp class]]);
  XCTAssertEqualObjects(
      [snapshot dataWithServerTimestampBehavior:FIRServerTimestampBehaviorEstimate],
      [self expectedDataWithTimestamp:timestamp]);
}

/**
 * Verifies a snapshot containing _setData but using the previous field value for server
 * timestamps.
 */
- (void)verifyTimestampsInSnapshot:(FIRDocumentSnapshot *)snapshot
              fromPreviousSnapshot:(nullable FIRDocumentSnapshot *)previousSnapshot {
  if (previousSnapshot == nil) {
    XCTAssertEqualObjects(
        [snapshot dataWithServerTimestampBehavior:FIRServerTimestampBehaviorPrevious],
        [self expectedDataWithTimestamp:[NSNull null]]);
  } else {
    XCTAssertEqualObjects(
        [snapshot dataWithServerTimestampBehavior:FIRServerTimestampBehaviorPrevious],
        [self expectedDataWithTimestamp:previousSnapshot[@"when"]]);
  }
}

/** Verifies a snapshot containing _setData but with resolved server timestamps. */
- (void)verifySnapshotWithResolvedTimestamps:(FIRDocumentSnapshot *)snapshot {
  // Tolerate up to 200 seconds of clock skew between client and server.
  NSInteger tolerance = 200;

  XCTAssertTrue(snapshot.exists);
  FIRTimestamp *when = snapshot[@"when"];
  XCTAssertTrue([when isKindOfClass:[FIRTimestamp class]]);
  XCTAssertEqualWithAccuracy(when.seconds, [FIRTimestamp timestamp].seconds, tolerance);

  // Validate the rest of the document.
  XCTAssertEqualObjects(snapshot.data, [self expectedDataWithTimestamp:when]);
}

/** Runs a transaction block. */
- (void)runTransactionBlock:(void (^)(FIRTransaction *transaction))transactionBlock {
  XCTestExpectation *expectation = [self expectationWithDescription:@"transaction complete"];
  [_docRef.firestore
      runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **) {
        transactionBlock(transaction);
        return nil;
      }
      completion:^(id, NSError *error) {
        XCTAssertNil(error);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

#pragma mark - Test Cases

- (void)testServerTimestampsWorkViaSet {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsAreNullInSnapshot:[_accumulator awaitLocalEvent]];
  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];
}

- (void)testServerTimestampsWorkViaUpdate {
  [self writeInitialData];
  [self updateDocumentRef:_docRef data:_updateData];
  [self verifyTimestampsAreNullInSnapshot:[_accumulator awaitLocalEvent]];
  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];
}

- (void)testServerTimestampsWithEstimatedValue {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsAreEstimatedInSnapshot:[_accumulator awaitLocalEvent]];
  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];
}

- (void)testServerTimestampsWithPreviousValue {
  // The following test includes an update of the nested map "deep", which updates it to contain
  // a single ServerTimestamp. This update is split into two mutations: One that sets "deep" to
  // an empty map and overwrites the previous ServerTimestamp value and a second transform that
  // writes the new ServerTimestamp. This step in the test verifies that we can still access the
  // old ServerTimestamp value (from `previousSnapshot`) even though it was removed in an
  // intermediate step.
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsInSnapshot:[_accumulator awaitLocalEvent] fromPreviousSnapshot:nil];
  FIRDocumentSnapshot *remoteSnapshot = [_accumulator awaitRemoteEvent];

  [_docRef updateData:_updateData];
  [self verifyTimestampsInSnapshot:[_accumulator awaitLocalEvent]
              fromPreviousSnapshot:remoteSnapshot];

  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];
}

- (void)testServerTimestampsWithPreviousValueOfDifferentType {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsInSnapshot:[_accumulator awaitLocalEvent] fromPreviousSnapshot:nil];
  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  FIRDocumentSnapshot *localSnapshot = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"], [NSNull null]);
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"
                             serverTimestampBehavior:FIRServerTimestampBehaviorPrevious],
                        @42);
  XCTAssertTrue([[localSnapshot valueForField:@"a"
                      serverTimestampBehavior:FIRServerTimestampBehaviorEstimate]
      isKindOfClass:[FIRTimestamp class]]);

  FIRDocumentSnapshot *remoteSnapshot = [_accumulator awaitRemoteEvent];
  XCTAssertTrue([[remoteSnapshot valueForField:@"a"] isKindOfClass:[FIRTimestamp class]]);
  XCTAssertTrue([[remoteSnapshot valueForField:@"a"
                       serverTimestampBehavior:FIRServerTimestampBehaviorPrevious]
      isKindOfClass:[FIRTimestamp class]]);
  XCTAssertTrue([[remoteSnapshot valueForField:@"a"
                       serverTimestampBehavior:FIRServerTimestampBehaviorEstimate]
      isKindOfClass:[FIRTimestamp class]]);
}

- (void)testServerTimestampsWithConsecutiveUpdates {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsInSnapshot:[_accumulator awaitLocalEvent] fromPreviousSnapshot:nil];
  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];

  [self disableNetwork];

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  FIRDocumentSnapshot *localSnapshot = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"
                             serverTimestampBehavior:FIRServerTimestampBehaviorPrevious],
                        @42);

  // include b=1 to ensure there's a change resulting in a new snapshot.
  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp], @"b" : @1}];
  localSnapshot = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"
                             serverTimestampBehavior:FIRServerTimestampBehaviorPrevious],
                        @42);

  [self enableNetwork];

  FIRDocumentSnapshot *remoteSnapshot = [_accumulator awaitRemoteEvent];
  XCTAssertTrue([[remoteSnapshot valueForField:@"a"] isKindOfClass:[FIRTimestamp class]]);
}

- (void)testServerTimestampsPreviousValueFromLocalMutation {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsInSnapshot:[_accumulator awaitLocalEvent] fromPreviousSnapshot:nil];
  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];

  [self disableNetwork];

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  FIRDocumentSnapshot *localSnapshot = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"
                             serverTimestampBehavior:FIRServerTimestampBehaviorPrevious],
                        @42);

  [_docRef updateData:@{@"a" : @1337}];
  localSnapshot = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"], @1337);

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  localSnapshot = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"
                             serverTimestampBehavior:FIRServerTimestampBehaviorPrevious],
                        @1337);

  [self enableNetwork];

  FIRDocumentSnapshot *remoteSnapshot = [_accumulator awaitRemoteEvent];
  XCTAssertTrue([[remoteSnapshot valueForField:@"a"] isKindOfClass:[FIRTimestamp class]]);
}

- (void)testServerTimestampsWorkViaTransactionSet {
  [self runTransactionBlock:^(FIRTransaction *transaction) {
    [transaction setData:self->_setData forDocument:self->_docRef];
  }];

  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];
}

- (void)testServerTimestampsWorkViaTransactionUpdate {
  [self writeInitialData];
  [self runTransactionBlock:^(FIRTransaction *transaction) {
    [transaction updateData:self->_updateData forDocument:self->_docRef];
  }];
  [self verifySnapshotWithResolvedTimestamps:[_accumulator awaitRemoteEvent]];
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
  [_docRef.firestore
      runTransactionWithBlock:^id(FIRTransaction *transaction, NSError **) {
        [transaction updateData:self->_updateData forDocument:self->_docRef];
        return nil;
      }
      completion:^(id, NSError *error) {
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, FIRFirestoreErrorDomain);
        XCTAssertEqual(error.code, FIRFirestoreErrorCodeNotFound);
        [expectation fulfill];
      }];
  [self awaitExpectations];
}

@end
