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

#import <FirebaseFirestore/FIRDecimal128Value.h>
#import <FirebaseFirestore/FIRInt32Value.h>
#import <FirebaseFirestore/FirebaseFirestore.h>

#import <XCTest/XCTest.h>

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

- (void)testNumericIncrementWithBsonTypes {
  [self writeInitialData:@{
    @"i32" : [[FIRInt32Value alloc] initWithValue:10],
    @"d128" : [[FIRDecimal128Value alloc] initWithValue:@"10.5"]
  }];
  [self updateDocumentRef:_docRef
                     data:@{
                       @"i32" : [FIRFieldValue
                           fieldValueForInt32Increment:[[FIRInt32Value alloc] initWithValue:5]],
                       @"d128" : [FIRFieldValue
                           fieldValueForDecimal128Increment:[[FIRDecimal128Value alloc]
                                                                initWithValue:@"5.5"]]
                     }];
  FIRDocumentSnapshot *snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:15], snap[@"i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"16"], snap[@"d128"]);
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:15], snap[@"i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"16"], snap[@"d128"]);
}

- (void)testNumericMinimumAndMaximumWithBsonTypes {
  [self writeInitialData:@{
    @"min_i32" : [[FIRInt32Value alloc] initWithValue:10],
    @"min_d128" : [[FIRDecimal128Value alloc] initWithValue:@"10.5"],
    @"max_i32" : [[FIRInt32Value alloc] initWithValue:10],
    @"max_d128" : [[FIRDecimal128Value alloc] initWithValue:@"10.5"]
  }];

  // First pass: larger operand for min (retains base), smaller operand for max (retains base)
  [self
      updateDocumentRef:_docRef
                   data:@{
                     @"min_i32" : [FIRFieldValue
                         fieldValueForInt32Minimum:[[FIRInt32Value alloc] initWithValue:15]],
                     @"min_d128" :
                         [FIRFieldValue fieldValueForDecimal128Minimum:[[FIRDecimal128Value alloc]
                                                                           initWithValue:@"15.5"]],
                     @"max_i32" : [FIRFieldValue
                         fieldValueForInt32Maximum:[[FIRInt32Value alloc] initWithValue:5]],
                     @"max_d128" :
                         [FIRFieldValue fieldValueForDecimal128Maximum:[[FIRDecimal128Value alloc]
                                                                           initWithValue:@"5.5"]]
                   }];
  FIRDocumentSnapshot *snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:10], snap[@"min_i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"10.5"], snap[@"min_d128"]);
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:10], snap[@"max_i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"10.5"], snap[@"max_d128"]);
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:10], snap[@"min_i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"10.5"], snap[@"min_d128"]);
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:10], snap[@"max_i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"10.5"], snap[@"max_d128"]);

  // Second pass: smaller operand for min (replaces base), larger operand for max (replaces base)
  [self updateDocumentRef:_docRef
                     data:@{
                       @"min_i32" : [FIRFieldValue
                           fieldValueForInt32Minimum:[[FIRInt32Value alloc] initWithValue:5]],
                       @"min_d128" :
                           [FIRFieldValue fieldValueForDecimal128Minimum:[[FIRDecimal128Value alloc]
                                                                             initWithValue:@"5.5"]],
                       @"max_i32" : [FIRFieldValue
                           fieldValueForInt32Maximum:[[FIRInt32Value alloc] initWithValue:15]],
                       @"max_d128" : [FIRFieldValue
                           fieldValueForDecimal128Maximum:[[FIRDecimal128Value alloc]
                                                              initWithValue:@"15.5"]]
                     }];
  snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:5], snap[@"min_i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"5.5"], snap[@"min_d128"]);
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:15], snap[@"max_i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"15.5"], snap[@"max_d128"]);
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:5], snap[@"min_i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"5.5"], snap[@"min_d128"]);
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:15], snap[@"max_i32"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"15.5"], snap[@"max_d128"]);
}

- (void)testNumericTransformsConcurrentMixed {
  [self writeInitialData:@{
    @"min_field" : [[FIRInt32Value alloc] initWithValue:10],
    @"max_field" : [[FIRDecimal128Value alloc] initWithValue:@"10.5"],
    @"inc_field" : [[FIRInt32Value alloc] initWithValue:20]
  }];

  [self updateDocumentRef:_docRef
                     data:@{
                       @"min_field" : [FIRFieldValue fieldValueForDoubleMinimum:5.5],
                       @"max_field" : [FIRFieldValue fieldValueForIntegerMaximum:15],
                       @"inc_field" : [FIRFieldValue
                           fieldValueForDecimal128Increment:[[FIRDecimal128Value alloc]
                                                                initWithValue:@"2.5"]]
                     }];
  FIRDocumentSnapshot *snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualWithAccuracy(5.5, [snap[@"min_field"] doubleValue], DOUBLE_EPSILON);
  XCTAssertEqualObjects(@15, snap[@"max_field"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"22.5"], snap[@"inc_field"]);
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualWithAccuracy(5.5, [snap[@"min_field"] doubleValue], DOUBLE_EPSILON);
  XCTAssertEqualObjects(@15, snap[@"max_field"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"22.5"], snap[@"inc_field"]);

  [self updateDocumentRef:_docRef
                     data:@{
                       @"min_field" :
                           [FIRFieldValue fieldValueForDecimal128Minimum:[[FIRDecimal128Value alloc]
                                                                             initWithValue:@"2.5"]],
                       @"max_field" : [FIRFieldValue
                           fieldValueForInt32Maximum:[[FIRInt32Value alloc] initWithValue:20]],
                       @"inc_field" : [FIRFieldValue
                           fieldValueForInt32Increment:[[FIRInt32Value alloc] initWithValue:10]]
                     }];
  snap = [_accumulator awaitLocalEvent];
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"2.5"], snap[@"min_field"]);
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:20], snap[@"max_field"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"32.5"], snap[@"inc_field"]);
  snap = [_accumulator awaitRemoteEvent];
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"2.5"], snap[@"min_field"]);
  XCTAssertEqualObjects([[FIRInt32Value alloc] initWithValue:20], snap[@"max_field"]);
  XCTAssertEqualObjects([[FIRDecimal128Value alloc] initWithValue:@"32.5"], snap[@"inc_field"]);
}

@end
