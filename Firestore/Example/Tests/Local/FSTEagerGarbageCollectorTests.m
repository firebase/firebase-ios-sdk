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

#import "Local/FSTEagerGarbageCollector.h"

#import <XCTest/XCTest.h>

#import "Local/FSTReferenceSet.h"
#import "Model/FSTDocumentKey.h"

#import "FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTEagerGarbageCollectorTests : XCTestCase
@end

@implementation FSTEagerGarbageCollectorTests

- (void)testAddOrRemoveReferences {
  FSTEagerGarbageCollector *gc = [[FSTEagerGarbageCollector alloc] init];
  FSTReferenceSet *referenceSet = [[FSTReferenceSet alloc] init];
  [gc addGarbageSource:referenceSet];

  FSTDocumentKey *key = [FSTDocumentKey keyWithPathString:@"foo/bar"];
  [referenceSet addReferenceToKey:key forID:1];
  FSTAssertEqualSets([gc collectGarbage], @[]);
  XCTAssertFalse([referenceSet isEmpty]);

  [referenceSet removeReferenceToKey:key forID:1];
  FSTAssertEqualSets([gc collectGarbage], @[ key ]);
  XCTAssertTrue([referenceSet isEmpty]);
}

- (void)testRemoveAllReferencesForID {
  FSTEagerGarbageCollector *gc = [[FSTEagerGarbageCollector alloc] init];
  FSTReferenceSet *referenceSet = [[FSTReferenceSet alloc] init];
  [gc addGarbageSource:referenceSet];

  FSTDocumentKey *key1 = [FSTDocumentKey keyWithPathString:@"foo/bar"];
  FSTDocumentKey *key2 = [FSTDocumentKey keyWithPathString:@"foo/baz"];
  FSTDocumentKey *key3 = [FSTDocumentKey keyWithPathString:@"foo/blah"];
  [referenceSet addReferenceToKey:key1 forID:1];
  [referenceSet addReferenceToKey:key2 forID:1];
  [referenceSet addReferenceToKey:key3 forID:2];
  XCTAssertFalse([referenceSet isEmpty]);

  [referenceSet removeReferencesForID:1];
  FSTAssertEqualSets([gc collectGarbage], (@[ key1, key2 ]));
  XCTAssertFalse([referenceSet isEmpty]);

  [referenceSet removeReferencesForID:2];
  FSTAssertEqualSets([gc collectGarbage], @[ key3 ]);
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

  FSTDocumentKey *key1 = [FSTDocumentKey keyWithPathString:@"foo/bar"];
  [remoteTargets addReferenceToKey:key1 forID:1];
  [localViews addReferenceToKey:key1 forID:1];
  [mutations addReferenceToKey:key1 forID:10];

  FSTDocumentKey *key2 = [FSTDocumentKey keyWithPathString:@"foo/baz"];
  [mutations addReferenceToKey:key2 forID:10];

  XCTAssertFalse([remoteTargets isEmpty]);
  XCTAssertFalse([localViews isEmpty]);
  XCTAssertFalse([mutations isEmpty]);

  [localViews removeReferencesForID:1];
  FSTAssertEqualSets([gc collectGarbage], @[]);

  [remoteTargets removeReferencesForID:1];
  FSTAssertEqualSets([gc collectGarbage], @[]);

  [mutations removeReferenceToKey:key1 forID:10];
  FSTAssertEqualSets([gc collectGarbage], @[ key1 ]);

  [mutations removeReferenceToKey:key2 forID:10];
  FSTAssertEqualSets([gc collectGarbage], @[ key2 ]);

  XCTAssertTrue([remoteTargets isEmpty]);
  XCTAssertTrue([localViews isEmpty]);
  XCTAssertTrue([mutations isEmpty]);
}

@end

NS_ASSUME_NONNULL_END
