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

#import <FirebaseFirestore/FIRQuerySnapshot.h>

#import <XCTest/XCTest.h>

#include <utility>
#include <vector>

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"
#import "Firestore/Source/API/FIRDocumentChange+Internal.h"
#import "Firestore/Source/API/FIRDocumentSnapshot+Internal.h"
#import "Firestore/Source/API/FIRQuerySnapshot+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace util = firebase::firestore::util;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DocumentKeySet;

NS_ASSUME_NONNULL_BEGIN

@interface FIRDocumentChange ()

// Expose initializer for testing.
- (instancetype)initWithType:(FIRDocumentChangeType)type
                    document:(FIRQueryDocumentSnapshot *)document
                    oldIndex:(NSUInteger)oldIndex
                    newIndex:(NSUInteger)newIndex;

@end

@interface FIRQuerySnapshotTests : XCTestCase
@end

@implementation FIRQuerySnapshotTests

- (void)testEquals {
  FIRQuerySnapshot *foo = FSTTestQuerySnapshot("foo", @{}, @{@"a" : @{@"a" : @1}}, YES, NO);
  FIRQuerySnapshot *fooDup = FSTTestQuerySnapshot("foo", @{}, @{@"a" : @{@"a" : @1}}, YES, NO);
  FIRQuerySnapshot *differentPath =
      FSTTestQuerySnapshot("bar", @{}, @{@"a" : @{@"a" : @1}}, YES, NO);
  FIRQuerySnapshot *differentDoc =
      FSTTestQuerySnapshot("foo", @{@"a" : @{@"b" : @1}}, @{}, YES, NO);
  FIRQuerySnapshot *noPendingWrites =
      FSTTestQuerySnapshot("foo", @{}, @{@"a" : @{@"a" : @1}}, NO, NO);
  FIRQuerySnapshot *fromCache = FSTTestQuerySnapshot("foo", @{}, @{@"a" : @{@"a" : @1}}, YES, YES);
  XCTAssertEqualObjects(foo, fooDup);
  XCTAssertNotEqualObjects(foo, differentPath);
  XCTAssertNotEqualObjects(foo, differentDoc);
  XCTAssertNotEqualObjects(foo, noPendingWrites);
  XCTAssertNotEqualObjects(foo, fromCache);

  XCTAssertEqual([foo hash], [fooDup hash]);
  XCTAssertNotEqual([foo hash], [differentPath hash]);
  XCTAssertNotEqual([foo hash], [differentDoc hash]);
  XCTAssertNotEqual([foo hash], [noPendingWrites hash]);
  XCTAssertNotEqual([foo hash], [fromCache hash]);
}

- (void)testIncludeMetadataChanges {
  FSTDocument *doc1Old = FSTTestDoc("foo/bar", 1, @{@"a" : @"b"}, FSTDocumentStateLocalMutations);
  FSTDocument *doc1New = FSTTestDoc("foo/bar", 1, @{@"a" : @"b"}, FSTDocumentStateSynced);

  FSTDocument *doc2Old = FSTTestDoc("foo/baz", 1, @{@"a" : @"b"}, FSTDocumentStateSynced);
  FSTDocument *doc2New = FSTTestDoc("foo/baz", 1, @{@"a" : @"c"}, FSTDocumentStateSynced);

  FSTDocumentSet *oldDocuments = FSTTestDocSet(FSTDocumentComparatorByKey, @[ doc1Old, doc2Old ]);
  FSTDocumentSet *newDocuments = FSTTestDocSet(FSTDocumentComparatorByKey, @[ doc2New, doc2New ]);
  std::vector<DocumentViewChange> documentChanges{
      DocumentViewChange{doc1New, DocumentViewChange::Type::kMetadata},
      DocumentViewChange{doc2New, DocumentViewChange::Type::kModified},
  };

  FIRFirestore *firestore = FSTTestFirestore();
  FSTQuery *query = FSTTestQuery("foo");
  ViewSnapshot viewSnapshot{query,
                            newDocuments,
                            oldDocuments,
                            std::move(documentChanges),
                            /*from_cache=*/false,
                            /*sync_state_changed=*/true,
                            /*excludes_metadata_changes=*/false,
                            /*mutated_keys=*/DocumentKeySet{}};
  FIRSnapshotMetadata *metadata = [FIRSnapshotMetadata snapshotMetadataWithPendingWrites:NO
                                                                               fromCache:NO];
  FIRQuerySnapshot *snapshot = [FIRQuerySnapshot snapshotWithFirestore:firestore
                                                         originalQuery:query
                                                              snapshot:std::move(viewSnapshot)
                                                              metadata:metadata];

  FIRQueryDocumentSnapshot *doc1Snap = [FIRQueryDocumentSnapshot snapshotWithFirestore:firestore
                                                                           documentKey:doc1New.key
                                                                              document:doc1New
                                                                             fromCache:NO
                                                                      hasPendingWrites:NO];
  FIRQueryDocumentSnapshot *doc2Snap = [FIRQueryDocumentSnapshot snapshotWithFirestore:firestore
                                                                           documentKey:doc2New.key
                                                                              document:doc2New
                                                                             fromCache:NO
                                                                      hasPendingWrites:NO];

  NSArray<FIRDocumentChange *> *changesWithoutMetadata = @[
    [[FIRDocumentChange alloc] initWithType:FIRDocumentChangeTypeModified
                                   document:doc2Snap
                                   oldIndex:1
                                   newIndex:1],
  ];
  XCTAssertEqualObjects(snapshot.documentChanges, changesWithoutMetadata);

  NSArray<FIRDocumentChange *> *changesWithMetadata = @[
    [[FIRDocumentChange alloc] initWithType:FIRDocumentChangeTypeModified
                                   document:doc1Snap
                                   oldIndex:0
                                   newIndex:0],
    [[FIRDocumentChange alloc] initWithType:FIRDocumentChangeTypeModified
                                   document:doc2Snap
                                   oldIndex:1
                                   newIndex:1],
  ];
  XCTAssertEqualObjects([snapshot documentChangesWithIncludeMetadataChanges:YES],
                        changesWithMetadata);
}

@end

NS_ASSUME_NONNULL_END
