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

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Core/FSTFirestoreClient.h"

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

  // Snapshot options that return the previous value for pending server timestamps.
  FIRSnapshotOptions *_returnPreviousValue;
  FIRSnapshotOptions *_returnEstimatedValue;
}

- (void)setUp {
  [super setUp];

  _returnPreviousValue =
      [FIRSnapshotOptions serverTimestampBehavior:FIRServerTimestampBehaviorPrevious];
  _returnEstimatedValue =
      [FIRSnapshotOptions serverTimestampBehavior:FIRServerTimestampBehaviorEstimate];

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
  return @{ @"a" : @42, @"when" : timestamp, @"deep" : @{@"when" : timestamp} };
}

/** Writes _initialData and waits for the corresponding snapshot. */
- (void)writeInitialData {
  [self writeDocumentRef:_docRef data:_initialData];
  FIRDocumentSnapshot *initialDataSnap = [_accumulator awaitEventWithName:@"Initial data event."];
  XCTAssertEqualObjects(initialDataSnap.data, _initialData);
}

/** Waits for a snapshot with local writes. */
- (FIRDocumentSnapshot *)waitForLocalEvent {
  FIRDocumentSnapshot *snapshot;
  do {
    snapshot = [_accumulator awaitEventWithName:@"Local event."];
  } while (!snapshot.metadata.hasPendingWrites);
  return snapshot;
}

/** Waits for a snapshot that has no pending writes */
- (FIRDocumentSnapshot *)waitForRemoteEvent {
  FIRDocumentSnapshot *snapshot;
  do {
    snapshot = [_accumulator awaitEventWithName:@"Remote event."];
  } while (snapshot.metadata.hasPendingWrites);
  return snapshot;
}

/** Verifies a snapshot containing _setData but with NSNull for the timestamps. */
- (void)verifyTimestampsAreNullInSnapshot:(FIRDocumentSnapshot *)snapshot {
  XCTAssertEqualObjects(snapshot.data, [self expectedDataWithTimestamp:[NSNull null]]);
}

/** Verifies a snapshot  containing _setData but with a local estimate for the timestamps. */
- (void)verifyTimestampsAreEstimatedInSnapshot:(FIRDocumentSnapshot *)snapshot {
  id timestamp = [snapshot valueForField:@"when" options:_returnEstimatedValue];
  XCTAssertTrue([timestamp isKindOfClass:[NSDate class]]);
  XCTAssertEqualObjects([snapshot dataWithOptions:_returnEstimatedValue],
                        [self expectedDataWithTimestamp:timestamp]);
}

/**
 * Verifies a snapshot containing _setData but using the previous field value for server
 * timestamps.
 */
- (void)verifyTimestampsInSnapshot:(FIRDocumentSnapshot *)snapshot
              fromPreviousSnapshot:(nullable FIRDocumentSnapshot *)previousSnapshot {
  if (previousSnapshot == nil) {
    XCTAssertEqualObjects([snapshot dataWithOptions:_returnPreviousValue],
                          [self expectedDataWithTimestamp:[NSNull null]]);
  } else {
    XCTAssertEqualObjects([snapshot dataWithOptions:_returnPreviousValue],
                          [self expectedDataWithTimestamp:previousSnapshot[@"when"]]);
  }
}

/** Verifies a snapshot containing _setData but with resolved server timestamps. */
- (void)verifySnapshotWithResolvedTimestamps:(FIRDocumentSnapshot *)snapshot {
  XCTAssertTrue(snapshot.exists);
  NSDate *when = snapshot[@"when"];
  XCTAssertTrue([when isKindOfClass:[NSDate class]]);
  // Tolerate up to 10 seconds of clock skew between client and server.
  XCTAssertEqualWithAccuracy(when.timeIntervalSinceNow, 0, 10);

  // Validate the rest of the document.
  XCTAssertEqualObjects(snapshot.data, [self expectedDataWithTimestamp:when]);
}

/** Runs a transaction block. */
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

#pragma mark - Test Cases

- (void)testServerTimestampsWorkViaSet {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsAreNullInSnapshot:[self waitForLocalEvent]];
  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];
}

- (void)testServerTimestampsWorkViaUpdate {
  [self writeInitialData];
  [self updateDocumentRef:_docRef data:_updateData];
  [self verifyTimestampsAreNullInSnapshot:[self waitForLocalEvent]];
  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];
}

- (void)testServerTimestampsWithEstimatedValue {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsAreEstimatedInSnapshot:[self waitForLocalEvent]];
  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];
}

- (void)testServerTimestampsWithPreviousValue {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsInSnapshot:[self waitForLocalEvent] fromPreviousSnapshot:nil];
  FIRDocumentSnapshot *remoteSnapshot = [self waitForRemoteEvent];

  [_docRef updateData:_updateData];
  [self verifyTimestampsInSnapshot:[self waitForLocalEvent] fromPreviousSnapshot:remoteSnapshot];

  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];
}

- (void)testServerTimestampsWithPreviousValueOfDifferentType {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsInSnapshot:[self waitForLocalEvent] fromPreviousSnapshot:nil];
  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  FIRDocumentSnapshot *localSnapshot = [self waitForLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"], [NSNull null]);
  XCTAssertEqualObjects([localSnapshot valueForField:@"a" options:_returnPreviousValue], @42);
  XCTAssertTrue([[localSnapshot valueForField:@"a" options:_returnEstimatedValue]
      isKindOfClass:[NSDate class]]);

  FIRDocumentSnapshot *remoteSnapshot = [self waitForRemoteEvent];
  XCTAssertTrue([[remoteSnapshot valueForField:@"a"] isKindOfClass:[NSDate class]]);
  XCTAssertTrue([[remoteSnapshot valueForField:@"a" options:_returnPreviousValue]
      isKindOfClass:[NSDate class]]);
  XCTAssertTrue([[remoteSnapshot valueForField:@"a" options:_returnEstimatedValue]
      isKindOfClass:[NSDate class]]);
}

- (void)testServerTimestampsWithConsecutiveUpdates {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsInSnapshot:[self waitForLocalEvent] fromPreviousSnapshot:nil];
  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];

  [self disableNetwork];

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  FIRDocumentSnapshot *localSnapshot = [self waitForLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a" options:_returnPreviousValue], @42);

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  localSnapshot = [self waitForLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a" options:_returnPreviousValue], @42);

  [self enableNetwork];

  FIRDocumentSnapshot *remoteSnapshot = [self waitForRemoteEvent];
  XCTAssertTrue([[remoteSnapshot valueForField:@"a"] isKindOfClass:[NSDate class]]);
}

- (void)testServerTimestampsPreviousValueFromLocalMutation {
  [self writeDocumentRef:_docRef data:_setData];
  [self verifyTimestampsInSnapshot:[self waitForLocalEvent] fromPreviousSnapshot:nil];
  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];

  [self disableNetwork];

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  FIRDocumentSnapshot *localSnapshot = [self waitForLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a" options:_returnPreviousValue], @42);

  [_docRef updateData:@{ @"a" : @1337 }];
  localSnapshot = [self waitForLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a"], @1337);

  [_docRef updateData:@{@"a" : [FIRFieldValue fieldValueForServerTimestamp]}];
  localSnapshot = [self waitForLocalEvent];
  XCTAssertEqualObjects([localSnapshot valueForField:@"a" options:_returnPreviousValue], @1337);

  [self enableNetwork];

  FIRDocumentSnapshot *remoteSnapshot = [self waitForRemoteEvent];
  XCTAssertTrue([[remoteSnapshot valueForField:@"a"] isKindOfClass:[NSDate class]]);
}

- (void)testServerTimestampsWorkViaTransactionSet {
  [self runTransactionBlock:^(FIRTransaction *transaction) {
    [transaction setData:_setData forDocument:_docRef];
  }];

  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];
}

- (void)testServerTimestampsWorkViaTransactionUpdate {
  [self writeInitialData];
  [self runTransactionBlock:^(FIRTransaction *transaction) {
    [transaction updateData:_updateData forDocument:_docRef];
  }];
  [self verifySnapshotWithResolvedTimestamps:[self waitForRemoteEvent]];
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
