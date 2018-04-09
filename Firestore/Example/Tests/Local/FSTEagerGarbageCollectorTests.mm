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

#import "Firestore/Source/Local/FSTEagerGarbageCollector.h"

#import <XCTest/XCTest.h>

#include <set>

#import "Firestore/Source/Local/FSTReferenceSet.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::DocumentKey;

NS_ASSUME_NONNULL_BEGIN

@interface FSTEagerGarbageCollectorTests : XCTestCase
@end

@implementation FSTEagerGarbageCollectorTests

- (void)testAddOrRemoveReferences {
  FSTEagerGarbageCollector *gc = [[FSTEagerGarbageCollector alloc] init];
  FSTReferenceSet *referenceSet = [[FSTReferenceSet alloc] init];
  [gc addGarbageSource:referenceSet];

  DocumentKey key = testutil::Key("foo/bar");
  [referenceSet addReferenceToKey:key forID:1];
  XCTAssertEqual([gc collectGarbage], std::set<DocumentKey>({}));
  XCTAssertFalse([referenceSet isEmpty]);

  [referenceSet removeReferenceToKey:key forID:1];
  XCTAssertEqual([gc collectGarbage], std::set<DocumentKey>({key}));
  XCTAssertTrue([referenceSet isEmpty]);
}

- (void)testRemoveAllReferencesForID {
  FSTEagerGarbageCollector *gc = [[FSTEagerGarbageCollector alloc] init];
  FSTReferenceSet *referenceSet = [[FSTReferenceSet alloc] init];
  [gc addGarbageSource:referenceSet];

  DocumentKey key1 = testutil::Key("foo/bar");
  DocumentKey key2 = testutil::Key("foo/baz");
  DocumentKey key3 = testutil::Key("foo/blah");
  [referenceSet addReferenceToKey:key1 forID:1];
  [referenceSet addReferenceToKey:key2 forID:1];
  [referenceSet addReferenceToKey:key3 forID:2];
  XCTAssertFalse([referenceSet isEmpty]);

  [referenceSet removeReferencesForID:1];
  XCTAssertEqual([gc collectGarbage], std::set<DocumentKey>({key1, key2}));
  XCTAssertFalse([referenceSet isEmpty]);

  [referenceSet removeReferencesForID:2];
  XCTAssertEqual([gc collectGarbage], std::set<DocumentKey>({key3}));
  XCTAssertTrue([referenceSet isEmpty]);
}

- (void)testTwoReferenceSetsAtTheSameTime {
  FSTReferenceSet *remoteTargets = [[FSTReferenceSet alloc] init];
  FSTReferenceSet *localViews = [[FSTReferenceSet alloc] init];
  FSTReferenceSet *mutations = [[FSTReferenceSet alloc] init];

  FSTEagerGarbageCollector *gc = [[FSTEagerGarbageCollector alloc] init];
  [gc addGarbageSource:remoteTargets];
  [gc addGarbageSource:localViews];
  [gc addGarbageSource:mutations];

  DocumentKey key1 = testutil::Key("foo/bar");
  [remoteTargets addReferenceToKey:key1 forID:1];
  [localViews addReferenceToKey:key1 forID:1];
  [mutations addReferenceToKey:key1 forID:10];

  DocumentKey key2 = testutil::Key("foo/baz");
  [mutations addReferenceToKey:key2 forID:10];

  XCTAssertFalse([remoteTargets isEmpty]);
  XCTAssertFalse([localViews isEmpty]);
  XCTAssertFalse([mutations isEmpty]);

  [localViews removeReferencesForID:1];
  XCTAssertEqual([gc collectGarbage], std::set<DocumentKey>({}));

  [remoteTargets removeReferencesForID:1];
  XCTAssertEqual([gc collectGarbage], std::set<DocumentKey>({}));

  [mutations removeReferenceToKey:key1 forID:10];
  XCTAssertEqual([gc collectGarbage], std::set<DocumentKey>({key1}));

  [mutations removeReferenceToKey:key2 forID:10];
  XCTAssertEqual([gc collectGarbage], std::set<DocumentKey>({key2}));

  XCTAssertTrue([remoteTargets isEmpty]);
  XCTAssertTrue([localViews isEmpty]);
  XCTAssertTrue([mutations isEmpty]);
}

@end

NS_ASSUME_NONNULL_END
