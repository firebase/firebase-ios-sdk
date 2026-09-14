/*
 * Copyright 2019 Google
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

#include <cmath>

#import "Firestore/Source/API/FIRFieldValue+Internal.h"

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

double DOUBLE_EPSILON = 0.000001;

@interface FIRNumericTransformTests : FSTIntegrationTestCase
@end

@implementation FIRNumericTransformTests {
  // A document reference to read and write to.
  FIRDocumentReference *_docRef;

  // Accumulator used to capture events during the test.
  FSTEventAccumulator<FIRDocumentSnapshot *> *_accumulator;

  // Listener registration for a listener maintained during the course of the test.
  id<FIRListenerRegistration> _listenerRegistration;
}

- (void)setUp {
  [super setUp];

  _docRef = [self documentRef];
  _accumulator = [FSTEventAccumulator accumulatorForTest:self];
  _listenerRegistration =
      [_docRef addSnapshotListenerWithIncludeMetadataChanges:YES
                                                    listener:_accumulator.valueEventHandler];

  // Wait for initial nil snapshot to avoid potential races.
  FIRDocumentSnapshot *initialSnapshot = [_accumulator awaitEventWithName:@"initial event"];
  XCTAssertFalse(initialSnapshot.exists);
}

- (void)tearDown {
  [_listenerRegistration remove];

  [super tearDown];
}

#pragma mark - Test Helpers

/** Writes some initial data and consumes the events generated. */
- (void)writeInitialData:(NSDictionary<NSString *, id> *)data {
  [self writeDocumentRef:_docRef data:data];
  XCTAssertEqualObjects([_accumulator awaitLocalEvent].data, data);
  XCTAssertEqualObjects([_accumulator awaitRemoteEvent].data, data);
}

- (void)expectLocalAndRemoteValue:(int64_t)expectedSum {
  FIRDocumentSnapshot *snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects(@(expectedSum), snap[@"sum"]);
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualObjects(@(expectedSum), snap[@"sum"]);
}

- (void)expectApproximateLocalAndRemoteValue:(double)expectedSum {
  FIRDocumentSnapshot *snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualWithAccuracy(expectedSum, [snap[@"sum"] doubleValue], DOUBLE_EPSILON);
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualWithAccuracy(expectedSum, [snap[@"sum"] doubleValue], DOUBLE_EPSILON);
}

#pragma mark - Test Cases

- (void)testCreateDocumentWithIncrement {
  [self writeDocumentRef:_docRef
                    data:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1337]}];
  [self expectLocalAndRemoteValue:1337];
}

- (void)testMergeOnNonExistingDocumentWithIncrement {
  [self mergeDocumentRef:_docRef
                    data:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1337]}];
  [self expectLocalAndRemoteValue:1337];
}

- (void)testIntegerIncrementWithExistingInteger {
  [self writeInitialData:@{@"sum" : @1337}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]}];
  [self expectLocalAndRemoteValue:1338];
}

- (void)testDoubleIncrementWithExistingDouble {
  [self writeInitialData:@{@"sum" : @13.37}];
  [self updateDocumentRef:_docRef
                     data:@{@"sum" : [FIRFieldValue fieldValueForDoubleIncrement:0.1]}];
  [self expectApproximateLocalAndRemoteValue:13.47];
}

- (void)testIntegerIncrementWithExistingDouble {
  [self writeInitialData:@{@"sum" : @13.37}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]}];
  [self expectApproximateLocalAndRemoteValue:14.37];
}

- (void)testDoubleIncrementWithExistingInteger {
  [self writeInitialData:@{@"sum" : @1337}];
  [self updateDocumentRef:_docRef
                     data:@{@"sum" : [FIRFieldValue fieldValueForDoubleIncrement:0.1]}];
  [self expectApproximateLocalAndRemoteValue:1337.1];
}

- (void)testIntegerIncrementWithExistingString {
  [self writeInitialData:@{@"sum" : @"overwrite"}];
  [self updateDocumentRef:_docRef
                     data:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1337]}];
  [self expectLocalAndRemoteValue:1337];
}

- (void)testDoubleIncrementWithExistingString {
  [self writeInitialData:@{@"sum" : @"overwrite"}];
  [self updateDocumentRef:_docRef
                     data:@{@"sum" : [FIRFieldValue fieldValueForDoubleIncrement:13.37]}];
  [self expectApproximateLocalAndRemoteValue:13.37];
}

- (void)testIncrementTwiceInABatch {
  [self writeInitialData:@{@"sum" : @"overwrite"}];

  FIRWriteBatch *batch = _docRef.firestore.batch;
  [batch updateData:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]}
        forDocument:_docRef];
  [batch updateData:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]}
        forDocument:_docRef];
  [batch
      commitWithCompletion:[self completionForExpectationWithName:@"testIncrementTwiceInABatch"]];
  [self awaitExpectations];

  [self expectApproximateLocalAndRemoteValue:2];
}

- (void)testIncrementDeleteIncrementInABatch {
  [self writeInitialData:@{@"sum" : @"overwrite"}];

  FIRWriteBatch *batch = _docRef.firestore.batch;
  [batch updateData:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:1]}
        forDocument:_docRef];
  [batch updateData:@{@"sum" : [FIRFieldValue fieldValueForDelete]} forDocument:_docRef];
  [batch updateData:@{@"sum" : [FIRFieldValue fieldValueForIntegerIncrement:3]}
        forDocument:_docRef];
  [batch commitWithCompletion:
             [self completionForExpectationWithName:@"testIncrementDeleteIncrementInABatch"]];
  [self awaitExpectations];

  [self expectApproximateLocalAndRemoteValue:3];
}

- (void)testServerTimestampAndIncrement {
  // This test stacks two pending transforms (a ServerTimestamp and an Increment transform)
  // and reproduces the setup that was reported in
  // https://github.com/firebase/firebase-android-sdk/issues/491
  // In our original code, a NumericIncrementTransform could cause us to decode the
  // ServerTimestamp as part of a FSTPatchMutation, which triggered an assertion failure.
  [self writeInitialData:@{@"val" : @"overwrite"}];

  [self disableNetwork];

  [_docRef updateData:@{@"val" : [FIRFieldValue fieldValueForServerTimestamp]}];
  [_docRef updateData:@{@"val" : [FIRFieldValue fieldValueForIntegerIncrement:1]}];

  FIRDocumentSnapshot *snap = [_accumulator awaitLocalEvent];
  XCTAssertNotNil([snap valueForField:@"val"
              serverTimestampBehavior:FIRServerTimestampBehaviorEstimate]);

  snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects(@1, snap[@"val"]);

  [self enableNetwork];

  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualObjects(@1, snap[@"val"]);
}

- (void)testMultipleDoubleIncrements {
  [self writeInitialData:@{@"sum" : @"0.0"}];

  [self disableNetwork];

  [_docRef updateData:@{@"sum" : [FIRFieldValue fieldValueForDoubleIncrement:0.1]}];
  [_docRef updateData:@{@"sum" : [FIRFieldValue fieldValueForDoubleIncrement:0.01]}];
  [_docRef updateData:@{@"sum" : [FIRFieldValue fieldValueForDoubleIncrement:0.001]}];

  FIRDocumentSnapshot *snap = [_accumulator awaitLocalEvent];

  XCTAssertEqualWithAccuracy(0.1, [snap[@"sum"] doubleValue], DOUBLE_EPSILON);
  snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualWithAccuracy(0.11, [snap[@"sum"] doubleValue], DOUBLE_EPSILON);
  snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualWithAccuracy(0.111, [snap[@"sum"] doubleValue], DOUBLE_EPSILON);

  [self enableNetwork];
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualWithAccuracy(0.111, [snap[@"sum"] doubleValue], DOUBLE_EPSILON);
}

- (void)testCreateDocumentWithMinimum {
  [self writeDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMinimum:1337]}];
  [self expectLocalAndRemoteValue:1337];
}

- (void)testCreateDocumentWithMaximum {
  [self writeDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMaximum:1337]}];
  [self expectLocalAndRemoteValue:1337];
}

- (void)testMinimumWithExistingInteger {
  [self writeInitialData:@{@"sum" : @10}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMinimum:5]}];
  [self expectLocalAndRemoteValue:5];

  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMinimum:20]}];
  [self expectLocalAndRemoteValue:5];
}

- (void)testMaximumWithExistingInteger {
  [self writeInitialData:@{@"sum" : @10}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMaximum:5]}];
  [self expectLocalAndRemoteValue:10];

  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMaximum:20]}];
  [self expectLocalAndRemoteValue:20];
}

- (void)testMinimumWithExistingDouble {
  [self writeInitialData:@{@"sum" : @10.5}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMinimum:5.5]}];
  [self expectApproximateLocalAndRemoteValue:5.5];

  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMinimum:20.5]}];
  [self expectApproximateLocalAndRemoteValue:5.5];
}

- (void)testMaximumWithExistingDouble {
  [self writeInitialData:@{@"sum" : @10.5}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMaximum:5.5]}];
  [self expectApproximateLocalAndRemoteValue:10.5];

  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMaximum:20.5]}];
  [self expectApproximateLocalAndRemoteValue:20.5];
}

- (void)testMixedTypesPreserveOperandTypeForMinimum {
  // field and input value of mixed types: field takes on type of smaller operand
  [self writeInitialData:@{@"sum" : @10}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMinimum:5.5]}];
  [self expectApproximateLocalAndRemoteValue:5.5];

  [self writeInitialData:@{@"sum" : @10.5}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMinimum:5]}];
  [self expectLocalAndRemoteValue:5];
}

- (void)testMixedTypesPreserveOperandTypeForMaximum {
  // field and input value of mixed types: field takes on type of larger operand
  [self writeInitialData:@{@"sum" : @10}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMaximum:20.5]}];
  [self expectApproximateLocalAndRemoteValue:20.5];

  [self writeInitialData:@{@"sum" : @10.5}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMaximum:20]}];
  [self expectLocalAndRemoteValue:20];
}

- (void)testEquivalentValuesDoNotChangeTypeForMinimum {
  // equivalent (e.g. 3 and 3.0), field does not change type
  [self writeInitialData:@{@"sum" : @3}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMinimum:3.0]}];
  [self expectLocalAndRemoteValue:3];

  [self writeInitialData:@{@"sum" : @3.0}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMinimum:3]}];
  [self expectApproximateLocalAndRemoteValue:3.0];
}

- (void)testEquivalentValuesDoNotChangeTypeForMaximum {
  // equivalent (e.g. 3 and 3.0), field does not change type
  [self writeInitialData:@{@"sum" : @3}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMaximum:3.0]}];
  [self expectLocalAndRemoteValue:3];

  [self writeInitialData:@{@"sum" : @3.0}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMaximum:3]}];
  [self expectApproximateLocalAndRemoteValue:3.0];
}

- (void)expectLocalAndRemoteNaN {
  FIRDocumentSnapshot *snap = [_accumulator awaitLocalEvent];
  XCTAssertTrue([snap[@"sum"] isKindOfClass:[NSNumber class]]);
  XCTAssertTrue(std::isnan([snap[@"sum"] doubleValue]));
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertTrue([snap[@"sum"] isKindOfClass:[NSNumber class]]);
  XCTAssertTrue(std::isnan([snap[@"sum"] doubleValue]));
}

- (void)testMinimumWithNaN {
  // If one of the values is NaN, minimum is NaN
  [self writeInitialData:@{@"sum" : @(NAN)}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMinimum:5]}];
  [self expectLocalAndRemoteNaN];

  [self writeInitialData:@{@"sum" : @5}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMinimum:NAN]}];
  [self expectLocalAndRemoteNaN];
}

- (void)testMaximumWithNaN {
  // If one of the values is NaN, maximum is NaN
  [self writeInitialData:@{@"sum" : @(NAN)}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForIntegerMaximum:5]}];
  [self expectLocalAndRemoteNaN];

  [self writeInitialData:@{@"sum" : @5}];
  [self updateDocumentRef:_docRef data:@{@"sum" : [FIRFieldValue fieldValueForDoubleMaximum:NAN]}];
  [self expectLocalAndRemoteNaN];
}

@end
