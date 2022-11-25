/*
 * Copyright 2018 Google
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

#import "Firestore/Source/API/FIRFieldValue+Internal.h"

#import "Firestore/Example/Tests/Util/FSTEventAccumulator.h"
#import "Firestore/Example/Tests/Util/FSTIntegrationTestCase.h"

/**
 * Note: Transforms are tested pretty thoroughly in FIRServerTimestampTests (via set, update,
 * transactions, nested in documents, multiple transforms together, etc.) and so these tests
 * mostly focus on the array transform semantics.
 */
@interface FIRArrayTransformTests : FSTIntegrationTestCase
@end

@implementation FIRArrayTransformTests {
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

#pragma mark - Test Cases

- (void)testCreateDocumentWithArrayUnion {
  [self writeDocumentRef:_docRef
                    data:@{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @1, @2 ]]}];
  id expected = @{@"array" : @[ @1, @2 ]};
  XCTAssertEqualObjects([_accumulator awaitLocalEvent].data, expected);
  XCTAssertEqualObjects([_accumulator awaitRemoteEvent].data, expected);
}

- (void)testAppendToArrayViaUpdate {
  [self writeInitialData:@{@"array" : @[ @1, @3 ]}];

  [self updateDocumentRef:_docRef
                     data:@{@"array" : [FIRFieldValue fieldValueForArrayUnion:@[ @2, @1, @4 ]]}];

  id expected = @{@"array" : @[ @1, @3, @2, @4 ]};
  XCTAssertEqualObjects([_accumulator awaitLocalEvent].data, expected);
  XCTAssertEqualObjects([_accumulator awaitRemoteEvent].data, expected);
}

@end
