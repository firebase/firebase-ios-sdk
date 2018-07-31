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

#import "Firestore/Source/Core/FSTView.h"

#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::DocumentKeySet;

NS_ASSUME_NONNULL_BEGIN

@interface FSTViewTests : XCTestCase
@end

@implementation FSTViewTests

/** Returns a new empty query to use for testing. */
- (FSTQuery *)queryForMessages {
  return [FSTQuery queryWithPath:ResourcePath{"rooms", "eros", "messages"}];
}

- (void)testAddsDocumentsBasedOnQuery {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/other/messages/1", 0, @{@"text" : @"msg3"}, NO);

  FSTViewSnapshot *_Nullable snapshot = FSTTestApplyChanges(
      view, @[ doc1, doc2, doc3 ], FSTTestTargetChangeAckDocuments({doc1.key, doc2.key, doc3.key}));

  XCTAssertEqual(snapshot.query, query);

  XCTAssertEqualObjects(snapshot.documents.arrayValue, (@[ doc1, doc2 ]));

  XCTAssertEqualObjects(
      snapshot.documentChanges, (@[
        [FSTDocumentViewChange changeWithDocument:doc1 type:FSTDocumentViewChangeTypeAdded],
        [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeAdded]
      ]));

  XCTAssertFalse(snapshot.isFromCache);
  XCTAssertFalse(snapshot.hasPendingWrites);
  XCTAssertTrue(snapshot.syncStateChanged);
}

- (void)testRemovesDocuments {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/3", 0, @{@"text" : @"msg3"}, NO);

  // initial state
  FSTTestApplyChanges(view, @[ doc1, doc2 ], nil);

  // delete doc2, add doc3
  FSTViewSnapshot *snapshot =
      FSTTestApplyChanges(view, @[ FSTTestDeletedDoc("rooms/eros/messages/2", 0), doc3 ],
                          FSTTestTargetChangeAckDocuments({doc1.key, doc3.key}));

  XCTAssertEqual(snapshot.query, query);

  XCTAssertEqualObjects(snapshot.documents.arrayValue, (@[ doc1, doc3 ]));

  XCTAssertEqualObjects(
      snapshot.documentChanges, (@[
        [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeRemoved],
        [FSTDocumentViewChange changeWithDocument:doc3 type:FSTDocumentViewChangeTypeAdded]
      ]));

  XCTAssertFalse(snapshot.isFromCache);
  XCTAssertTrue(snapshot.syncStateChanged);
}

- (void)testReturnsNilIfThereAreNoChanges {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, NO);

  // initial state
  FSTTestApplyChanges(view, @[ doc1, doc2 ], nil);

  // reapply same docs, no changes
  FSTViewSnapshot *snapshot = FSTTestApplyChanges(view, @[ doc1, doc2 ], nil);
  XCTAssertNil(snapshot);
}

- (void)testDoesNotReturnNilForFirstChanges {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTViewSnapshot *snapshot = FSTTestApplyChanges(view, @[], nil);
  XCTAssertNotNil(snapshot);
}

- (void)testFiltersDocumentsBasedOnQueryWithFilter {
  FSTQuery *query = [self queryForMessages];
  FSTRelationFilter *filter =
      [FSTRelationFilter filterWithField:testutil::Field("sort")
                          filterOperator:FSTRelationFilterOperatorLessThanOrEqual
                                   value:[FSTDoubleValue doubleValue:2]];
  query = [query queryByAddingFilter:filter];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/1", 0, @{ @"sort" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/2", 0, @{ @"sort" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/3", 0, @{ @"sort" : @3 }, NO);
  FSTDocument *doc4 = FSTTestDoc("rooms/eros/messages/4", 0, @{}, NO);  // no sort, no match
  FSTDocument *doc5 = FSTTestDoc("rooms/eros/messages/5", 0, @{ @"sort" : @1 }, NO);

  FSTViewSnapshot *snapshot = FSTTestApplyChanges(view, @[ doc1, doc2, doc3, doc4, doc5 ], nil);

  XCTAssertEqual(snapshot.query, query);

  XCTAssertEqualObjects(snapshot.documents.arrayValue, (@[ doc1, doc5, doc2 ]));

  XCTAssertEqualObjects(
      snapshot.documentChanges, (@[
        [FSTDocumentViewChange changeWithDocument:doc1 type:FSTDocumentViewChangeTypeAdded],
        [FSTDocumentViewChange changeWithDocument:doc5 type:FSTDocumentViewChangeTypeAdded],
        [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeAdded]
      ]));

  XCTAssertTrue(snapshot.isFromCache);
  XCTAssertTrue(snapshot.syncStateChanged);
}

- (void)testUpdatesDocumentsBasedOnQueryWithFilter {
  FSTQuery *query = [self queryForMessages];
  FSTRelationFilter *filter =
      [FSTRelationFilter filterWithField:testutil::Field("sort")
                          filterOperator:FSTRelationFilterOperatorLessThanOrEqual
                                   value:[FSTDoubleValue doubleValue:2]];
  query = [query queryByAddingFilter:filter];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/1", 0, @{ @"sort" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/2", 0, @{ @"sort" : @3 }, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/3", 0, @{ @"sort" : @2 }, NO);
  FSTDocument *doc4 = FSTTestDoc("rooms/eros/messages/4", 0, @{}, NO);

  FSTViewSnapshot *snapshot = FSTTestApplyChanges(view, @[ doc1, doc2, doc3, doc4 ], nil);

  XCTAssertEqual(snapshot.query, query);

  XCTAssertEqualObjects(snapshot.documents.arrayValue, (@[ doc1, doc3 ]));

  FSTDocument *newDoc2 = FSTTestDoc("rooms/eros/messages/2", 1, @{ @"sort" : @2 }, NO);
  FSTDocument *newDoc3 = FSTTestDoc("rooms/eros/messages/3", 1, @{ @"sort" : @3 }, NO);
  FSTDocument *newDoc4 = FSTTestDoc("rooms/eros/messages/4", 1, @{ @"sort" : @0 }, NO);

  snapshot = FSTTestApplyChanges(view, @[ newDoc2, newDoc3, newDoc4 ], nil);

  XCTAssertEqual(snapshot.query, query);

  XCTAssertEqualObjects(snapshot.documents.arrayValue, (@[ newDoc4, doc1, newDoc2 ]));

  XCTAssertEqualObjects(
      snapshot.documentChanges, (@[
        [FSTDocumentViewChange changeWithDocument:doc3 type:FSTDocumentViewChangeTypeRemoved],
        [FSTDocumentViewChange changeWithDocument:newDoc4 type:FSTDocumentViewChangeTypeAdded],
        [FSTDocumentViewChange changeWithDocument:newDoc2 type:FSTDocumentViewChangeTypeAdded]
      ]));

  XCTAssertTrue(snapshot.isFromCache);
  XCTAssertFalse(snapshot.syncStateChanged);
}

- (void)testRemovesDocumentsForQueryWithLimit {
  FSTQuery *query = [self queryForMessages];
  query = [query queryBySettingLimit:2];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/3", 0, @{@"text" : @"msg3"}, NO);

  // initial state
  FSTTestApplyChanges(view, @[ doc1, doc3 ], nil);

  // add doc2, which should push out doc3
  FSTViewSnapshot *snapshot = FSTTestApplyChanges(
      view, @[ doc2 ], FSTTestTargetChangeAckDocuments({doc1.key, doc2.key, doc3.key}));

  XCTAssertEqual(snapshot.query, query);

  XCTAssertEqualObjects(snapshot.documents.arrayValue, (@[ doc1, doc2 ]));

  XCTAssertEqualObjects(
      snapshot.documentChanges, (@[
        [FSTDocumentViewChange changeWithDocument:doc3 type:FSTDocumentViewChangeTypeRemoved],
        [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeAdded]
      ]));

  XCTAssertFalse(snapshot.isFromCache);
  XCTAssertTrue(snapshot.syncStateChanged);
}

- (void)testDoesntReportChangesForDocumentBeyondLimitOfQuery {
  FSTQuery *query = [self queryForMessages];
  query = [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("num")
                                                                   ascending:YES]];
  query = [query queryBySettingLimit:2];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/1", 0, @{ @"num" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/2", 0, @{ @"num" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/3", 0, @{ @"num" : @3 }, NO);
  FSTDocument *doc4 = FSTTestDoc("rooms/eros/messages/4", 0, @{ @"num" : @4 }, NO);

  // initial state
  FSTTestApplyChanges(view, @[ doc1, doc2 ], nil);

  // change doc2 to 5, and add doc3 and doc4.
  // doc2 will be modified + removed = removed
  // doc3 will be added
  // doc4 will be added + removed = nothing
  doc2 = FSTTestDoc("rooms/eros/messages/2", 1, @{ @"num" : @5 }, NO);
  FSTViewDocumentChanges *viewDocChanges =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2, doc3, doc4 ])];
  XCTAssertTrue(viewDocChanges.needsRefill);
  // Verify that all the docs still match.
  viewDocChanges = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3, doc4 ])
                                     previousChanges:viewDocChanges];
  FSTViewSnapshot *snapshot =
      [view applyChangesToDocuments:viewDocChanges
                       targetChange:FSTTestTargetChangeAckDocuments(
                                        {doc1.key, doc2.key, doc3.key, doc4.key})]
          .snapshot;

  XCTAssertEqual(snapshot.query, query);

  XCTAssertEqualObjects(snapshot.documents.arrayValue, (@[ doc1, doc3 ]));

  XCTAssertEqualObjects(
      snapshot.documentChanges, (@[
        [FSTDocumentViewChange changeWithDocument:doc2 type:FSTDocumentViewChangeTypeRemoved],
        [FSTDocumentViewChange changeWithDocument:doc3 type:FSTDocumentViewChangeTypeAdded]
      ]));

  XCTAssertFalse(snapshot.isFromCache);
  XCTAssertTrue(snapshot.syncStateChanged);
}

- (void)testKeepsTrackOfLimboDocuments {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{}, NO);

  FSTViewChange *change = [view
      applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1 ])]];
  XCTAssertEqualObjects(change.limboChanges, @[]);

  change = [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[])]
                            targetChange:FSTTestTargetChangeMarkCurrent()];
  XCTAssertEqualObjects(
      change.limboChanges,
      @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeAdded key:doc1.key] ]);

  change = [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[])]
                            targetChange:FSTTestTargetChangeAckDocuments({doc1.key})];
  XCTAssertEqualObjects(
      change.limboChanges,
      @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeRemoved key:doc1.key] ]);

  change =
      [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2 ])]
                       targetChange:FSTTestTargetChangeAckDocuments({doc2.key})];
  XCTAssertEqualObjects(change.limboChanges, @[]);

  change = [view
      applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ])]];
  XCTAssertEqualObjects(
      change.limboChanges,
      @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeAdded key:doc3.key] ]);

  change = [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[
                                                 FSTTestDeletedDoc("rooms/eros/messages/2",
                                                                   1)
                                               ])]];  // remove
  XCTAssertEqualObjects(
      change.limboChanges,
      @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeRemoved key:doc3.key] ]);
}

- (void)testResumingQueryCreatesNoLimbos {
  FSTQuery *query = [self queryForMessages];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, NO);

  // Unlike other cases, here the view is initialized with a set of previously synced documents
  // which happens when listening to a previously listened-to query.
  FSTView *view =
      [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{doc1.key, doc2.key}];

  FSTViewDocumentChanges *changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[])];
  FSTViewChange *change =
      [view applyChangesToDocuments:changes targetChange:FSTTestTargetChangeMarkCurrent()];
  XCTAssertEqualObjects(change.limboChanges, @[]);
}

- (void)assertDocSet:(FSTDocumentSet *)docSet containsDocs:(NSArray<FSTDocument *> *)docs {
  XCTAssertEqual(docs.count, docSet.count);
  for (FSTDocument *doc in docs) {
    XCTAssertTrue([docSet containsKey:doc.key]);
  }
}

- (void)testReturnsNeedsRefillOnDeleteInLimitQuery {
  FSTQuery *query = [[self queryForMessages] queryBySettingLimit:2];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, NO);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];

  // Remove one of the docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ FSTTestDeletedDoc(
                                                  "rooms/eros/messages/0", 0) ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc2 ]];
  XCTAssertTrue(changes.needsRefill);
  XCTAssertEqual(1, [changes.changeSet changes].count);
  // Refill it with just the one doc remaining.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2 ]) previousChanges:changes];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc2 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];
}

- (void)testReturnsNeedsRefillOnReorderInLimitQuery {
  FSTQuery *query = [self queryForMessages];
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("order")
                                                               ascending:YES]];
  query = [query queryBySettingLimit:2];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{ @"order" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{ @"order" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{ @"order" : @3 }, NO);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc2 = FSTTestDoc("rooms/eros/messages/1", 1, @{ @"order" : @2000 }, NO);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2 ]];
  XCTAssertTrue(changes.needsRefill);
  XCTAssertEqual(1, [changes.changeSet changes].count);
  // Refill it with all three current docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3 ])
                              previousChanges:changes];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc3 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillOnReorderWithinLimit {
  FSTQuery *query = [self queryForMessages];
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("order")
                                                               ascending:YES]];
  query = [query queryBySettingLimit:3];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{ @"order" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{ @"order" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{ @"order" : @3 }, NO);
  FSTDocument *doc4 = FSTTestDoc("rooms/eros/messages/3", 0, @{ @"order" : @4 }, NO);
  FSTDocument *doc5 = FSTTestDoc("rooms/eros/messages/4", 0, @{ @"order" : @5 }, NO);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3, doc4, doc5 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2, doc3 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(3, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc1 = FSTTestDoc("rooms/eros/messages/0", 1, @{ @"order" : @3 }, NO);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc2, doc3, doc1 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillOnReorderAfterLimitQuery {
  FSTQuery *query = [self queryForMessages];
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("order")
                                                               ascending:YES]];
  query = [query queryBySettingLimit:3];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{ @"order" : @1 }, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{ @"order" : @2 }, NO);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{ @"order" : @3 }, NO);
  FSTDocument *doc4 = FSTTestDoc("rooms/eros/messages/3", 0, @{ @"order" : @4 }, NO);
  FSTDocument *doc5 = FSTTestDoc("rooms/eros/messages/4", 0, @{ @"order" : @5 }, NO);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3, doc4, doc5 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2, doc3 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(3, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc4 = FSTTestDoc("rooms/eros/messages/3", 1, @{ @"order" : @6 }, NO);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc4 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2, doc3 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillForAdditionAfterTheLimit {
  FSTQuery *query = [[self queryForMessages] queryBySettingLimit:2];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, NO);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];

  // Add a doc that is past the limit.
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 1, @{}, NO);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillForDeletionsWhenNotNearTheLimit {
  FSTQuery *query = [[self queryForMessages] queryBySettingLimit:20];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, NO);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];

  // Remove one of the docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ FSTTestDeletedDoc(
                                                  "rooms/eros/messages/1", 0) ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];
}

- (void)testHandlesApplyingIrrelevantDocs {
  FSTQuery *query = [[self queryForMessages] queryBySettingLimit:2];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, NO);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];

  // Remove a doc that isn't even in the results.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ FSTTestDeletedDoc(
                                                  "rooms/eros/messages/2", 0) ])];
  [self assertDocSet:changes.documentSet containsDocs:@[ doc1, doc2 ]];
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, [changes.changeSet changes].count);
  [view applyChangesToDocuments:changes];
}

- (void)testComputesMutatedKeys {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, NO);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{});

  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{}, YES);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ])];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{doc3.key});
}

- (void)testRemovesKeysFromMutatedKeysWhenNewDocHasNoLocalChanges {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, YES);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));

  FSTDocument *doc2Prime = FSTTestDoc("rooms/eros/messages/1", 0, @{}, NO);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2Prime ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{});
}

- (void)testRemembersLocalMutationsFromPreviousSnapshot {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, YES);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));

  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{}, NO);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));
}

- (void)testRemembersLocalMutationsFromPreviousCallToComputeChangesWithDocuments {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, NO);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, YES);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));

  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{}, NO);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ]) previousChanges:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));
}

@end

NS_ASSUME_NONNULL_END
