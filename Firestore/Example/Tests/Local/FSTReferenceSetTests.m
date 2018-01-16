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

#import "Firestore/Source/Local/FSTReferenceSet.h"

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTReferenceSetTests : XCTestCase
@end

@implementation FSTReferenceSetTests

- (void)testAddOrRemoveReferences {
  FSTDocumentKey *key = FSTTestDocKey(@"foo/bar");

  FSTReferenceSet *referenceSet = [[FSTReferenceSet alloc] init];
  XCTAssertTrue([referenceSet isEmpty]);
  XCTAssertFalse([referenceSet containsKey:key]);

  [referenceSet addReferenceToKey:key forID:1];
  XCTAssertTrue([referenceSet containsKey:key]);
  XCTAssertFalse([referenceSet isEmpty]);

  [referenceSet addReferenceToKey:key forID:2];
  XCTAssertTrue([referenceSet containsKey:key]);

  [referenceSet removeReferenceToKey:key forID:1];
  XCTAssertTrue([referenceSet containsKey:key]);

  [referenceSet removeReferenceToKey:key forID:3];
  XCTAssertTrue([referenceSet containsKey:key]);

  [referenceSet removeReferenceToKey:key forID:2];
  XCTAssertFalse([referenceSet containsKey:key]);
  XCTAssertTrue([referenceSet isEmpty]);
}

- (void)testRemoveAllReferencesForTargetID {
  FSTDocumentKey *key1 = FSTTestDocKey(@"foo/bar");
  FSTDocumentKey *key2 = FSTTestDocKey(@"foo/baz");
  FSTDocumentKey *key3 = FSTTestDocKey(@"foo/blah");
  FSTReferenceSet *referenceSet = [[FSTReferenceSet alloc] init];

  [referenceSet addReferenceToKey:key1 forID:1];
  [referenceSet addReferenceToKey:key2 forID:1];
  [referenceSet addReferenceToKey:key3 forID:2];
  XCTAssertFalse([referenceSet isEmpty]);
  XCTAssertTrue([referenceSet containsKey:key1]);
  XCTAssertTrue([referenceSet containsKey:key2]);
  XCTAssertTrue([referenceSet containsKey:key3]);

  [referenceSet removeReferencesForID:1];
  XCTAssertFalse([referenceSet isEmpty]);
  XCTAssertFalse([referenceSet containsKey:key1]);
  XCTAssertFalse([referenceSet containsKey:key2]);
  XCTAssertTrue([referenceSet containsKey:key3]);

  [referenceSet removeReferencesForID:2];
  XCTAssertTrue([referenceSet isEmpty]);
  XCTAssertFalse([referenceSet containsKey:key1]);
  XCTAssertFalse([referenceSet containsKey:key2]);
  XCTAssertFalse([referenceSet containsKey:key3]);
}

@end

NS_ASSUME_NONNULL_END
