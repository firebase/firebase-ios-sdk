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

#include <initializer_list>
#include <utility>
#include <vector>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Model/FSTDocument.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "Firestore/core/test/firebase/firestore/testutil/xcgmock.h"
#include "absl/types/optional.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::Filter;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::ResourcePath;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using testing::ElementsAre;

NS_ASSUME_NONNULL_BEGIN

/**
 * A custom matcher that verifies that the subject has the same keys as the given documents without
 * verifying that the contents are the same.
 */
MATCHER_P(ContainsDocs, expected, "") {
  if (expected.size() != arg.size()) {
    return false;
  }
  for (FSTDocument *doc : expected) {
    if (!arg.ContainsKey(doc.key)) {
      return false;
    }
  }
  return true;
}

/** Constructs `ContainsDocs` instances with an initializer list. */
inline ContainsDocsMatcherP<std::vector<FSTDocument *>> ContainsDocs(
    std::vector<FSTDocument *> docs) {
  return ContainsDocsMatcherP<std::vector<FSTDocument *>>(docs);
}

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

  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/other/messages/1", 0, @{@"text" : @"msg3"}, DocumentState::kSynced);

  absl::optional<ViewSnapshot> maybe_snapshot = FSTTestApplyChanges(
      view, @[ doc1, doc2, doc3 ], FSTTestTargetChangeAckDocuments({doc1.key, doc2.key, doc3.key}));
  XCTAssertTrue(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc2));

  XCTAssertTrue((
      snapshot.document_changes() ==
      std::vector<DocumentViewChange>{DocumentViewChange{doc1, DocumentViewChange::Type::kAdded},
                                      DocumentViewChange{doc2, DocumentViewChange::Type::kAdded}}));

  XCTAssertFalse(snapshot.from_cache());
  XCTAssertFalse(snapshot.has_pending_writes());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testRemovesDocuments {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/eros/messages/3", 0, @{@"text" : @"msg3"}, DocumentState::kSynced);

  // initial state
  FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt);

  // delete doc2, add doc3
  absl::optional<ViewSnapshot> maybe_snapshot =
      FSTTestApplyChanges(view, @[ FSTTestDeletedDoc("rooms/eros/messages/2", 0, NO), doc3 ],
                          FSTTestTargetChangeAckDocuments({doc1.key, doc3.key}));
  XCTAssertTrue(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  XCTAssertTrue((
      snapshot.document_changes() ==
      std::vector<DocumentViewChange>{DocumentViewChange{doc2, DocumentViewChange::Type::kRemoved},
                                      DocumentViewChange{doc3, DocumentViewChange::Type::kAdded}}));

  XCTAssertFalse(snapshot.from_cache());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testReturnsNilIfThereAreNoChanges {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, DocumentState::kSynced);

  // initial state
  FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt);

  // reapply same docs, no changes
  absl::optional<ViewSnapshot> snapshot = FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt);
  XCTAssertFalse(snapshot.has_value());
}

- (void)testDoesNotReturnNilForFirstChanges {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  absl::optional<ViewSnapshot> snapshot = FSTTestApplyChanges(view, @[], absl::nullopt);
  XCTAssertTrue(snapshot.has_value());
}

- (void)testFiltersDocumentsBasedOnQueryWithFilter {
  FSTQuery *query = [self queryForMessages];
  FSTRelationFilter *filter = [FSTRelationFilter filterWithField:testutil::Field("sort")
                                                  filterOperator:Filter::Operator::LessThanOrEqual
                                                           value:FieldValue::FromDouble(2)];
  query = [query queryByAddingFilter:filter];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"sort" : @1}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"sort" : @2}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/eros/messages/3", 0, @{@"sort" : @3}, DocumentState::kSynced);
  FSTDocument *doc4 =
      FSTTestDoc("rooms/eros/messages/4", 0, @{}, DocumentState::kSynced);  // no sort, no match
  FSTDocument *doc5 =
      FSTTestDoc("rooms/eros/messages/5", 0, @{@"sort" : @1}, DocumentState::kSynced);

  absl::optional<ViewSnapshot> maybe_snapshot =
      FSTTestApplyChanges(view, @[ doc1, doc2, doc3, doc4, doc5 ], absl::nullopt);
  XCTAssertTrue(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc5, doc2));

  XCTAssertTrue((
      snapshot.document_changes() ==
      std::vector<DocumentViewChange>{DocumentViewChange{doc1, DocumentViewChange::Type::kAdded},
                                      DocumentViewChange{doc5, DocumentViewChange::Type::kAdded},
                                      DocumentViewChange{doc2, DocumentViewChange::Type::kAdded}}));

  XCTAssertTrue(snapshot.from_cache());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testUpdatesDocumentsBasedOnQueryWithFilter {
  FSTQuery *query = [self queryForMessages];
  FSTRelationFilter *filter = [FSTRelationFilter filterWithField:testutil::Field("sort")
                                                  filterOperator:Filter::Operator::LessThanOrEqual
                                                           value:FieldValue::FromDouble(2)];
  query = [query queryByAddingFilter:filter];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"sort" : @1}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"sort" : @3}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/eros/messages/3", 0, @{@"sort" : @2}, DocumentState::kSynced);
  FSTDocument *doc4 = FSTTestDoc("rooms/eros/messages/4", 0, @{}, DocumentState::kSynced);

  ViewSnapshot snapshot =
      FSTTestApplyChanges(view, @[ doc1, doc2, doc3, doc4 ], absl::nullopt).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  FSTDocument *newDoc2 =
      FSTTestDoc("rooms/eros/messages/2", 1, @{@"sort" : @2}, DocumentState::kSynced);
  FSTDocument *newDoc3 =
      FSTTestDoc("rooms/eros/messages/3", 1, @{@"sort" : @3}, DocumentState::kSynced);
  FSTDocument *newDoc4 =
      FSTTestDoc("rooms/eros/messages/4", 1, @{@"sort" : @0}, DocumentState::kSynced);

  snapshot = FSTTestApplyChanges(view, @[ newDoc2, newDoc3, newDoc4 ], absl::nullopt).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(newDoc4, doc1, newDoc2));

  XC_ASSERT_THAT(snapshot.document_changes(),
                 ElementsAre(DocumentViewChange{doc3, DocumentViewChange::Type::kRemoved},
                             DocumentViewChange{newDoc4, DocumentViewChange::Type::kAdded},
                             DocumentViewChange{newDoc2, DocumentViewChange::Type::kAdded}));

  XCTAssertTrue(snapshot.from_cache());
  XCTAssertFalse(snapshot.sync_state_changed());
}

- (void)testRemovesDocumentsForQueryWithLimit {
  FSTQuery *query = [self queryForMessages];
  query = [query queryBySettingLimit:2];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"text" : @"msg1"}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"text" : @"msg2"}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/eros/messages/3", 0, @{@"text" : @"msg3"}, DocumentState::kSynced);

  // initial state
  FSTTestApplyChanges(view, @[ doc1, doc3 ], absl::nullopt);

  // add doc2, which should push out doc3
  ViewSnapshot snapshot =
      FSTTestApplyChanges(view, @[ doc2 ],
                          FSTTestTargetChangeAckDocuments({doc1.key, doc2.key, doc3.key}))
          .value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc2));

  XCTAssertTrue((
      snapshot.document_changes() ==
      std::vector<DocumentViewChange>{DocumentViewChange{doc3, DocumentViewChange::Type::kRemoved},
                                      DocumentViewChange{doc2, DocumentViewChange::Type::kAdded}}));

  XCTAssertFalse(snapshot.from_cache());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testDoesntReportChangesForDocumentBeyondLimitOfQuery {
  FSTQuery *query = [self queryForMessages];
  query = [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("num")
                                                                   ascending:YES]];
  query = [query queryBySettingLimit:2];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"num" : @1}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"num" : @2}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/eros/messages/3", 0, @{@"num" : @3}, DocumentState::kSynced);
  FSTDocument *doc4 =
      FSTTestDoc("rooms/eros/messages/4", 0, @{@"num" : @4}, DocumentState::kSynced);

  // initial state
  FSTTestApplyChanges(view, @[ doc1, doc2 ], absl::nullopt);

  // change doc2 to 5, and add doc3 and doc4.
  // doc2 will be modified + removed = removed
  // doc3 will be added
  // doc4 will be added + removed = nothing
  doc2 = FSTTestDoc("rooms/eros/messages/2", 1, @{@"num" : @5}, DocumentState::kSynced);
  FSTViewDocumentChanges *viewDocChanges =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2, doc3, doc4 ])];
  XCTAssertTrue(viewDocChanges.needsRefill);
  // Verify that all the docs still match.
  viewDocChanges = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3, doc4 ])
                                     previousChanges:viewDocChanges];
  absl::optional<ViewSnapshot> maybe_snapshot =
      [view applyChangesToDocuments:viewDocChanges
                       targetChange:FSTTestTargetChangeAckDocuments(
                                        {doc1.key, doc2.key, doc3.key, doc4.key})]
          .snapshot;
  XCTAssertTrue(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  XC_ASSERT_THAT(snapshot.document_changes(),
                 ElementsAre(DocumentViewChange{doc2, DocumentViewChange::Type::kRemoved},
                             DocumentViewChange{doc3, DocumentViewChange::Type::kAdded}));

  XCTAssertFalse(snapshot.from_cache());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testKeepsTrackOfLimboDocuments {
  FSTQuery *query = [self queryForMessages];
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{}, DocumentState::kSynced);

  FSTViewChange *change = [view
      applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1 ])]];
  XCTAssertEqualObjects(change.limboChanges, @[]);

  change = [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[])]
                            targetChange:FSTTestTargetChangeMarkCurrent()];
  XCTAssertEqualObjects(change.limboChanges,
                        @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeAdded
                                                              key:doc1.key] ]);

  change = [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[])]
                            targetChange:FSTTestTargetChangeAckDocuments({doc1.key})];
  XCTAssertEqualObjects(change.limboChanges,
                        @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeRemoved
                                                              key:doc1.key] ]);

  change =
      [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2 ])]
                       targetChange:FSTTestTargetChangeAckDocuments({doc2.key})];
  XCTAssertEqualObjects(change.limboChanges, @[]);

  change = [view
      applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ])]];
  XCTAssertEqualObjects(change.limboChanges,
                        @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeAdded
                                                              key:doc3.key] ]);

  change = [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates(@[
                                                 FSTTestDeletedDoc("rooms/eros/messages/2", 1, NO)
                                               ])]];  // remove
  XCTAssertEqualObjects(change.limboChanges,
                        @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeRemoved
                                                              key:doc3.key] ]);
}

- (void)testResumingQueryCreatesNoLimbos {
  FSTQuery *query = [self queryForMessages];

  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kSynced);

  // Unlike other cases, here the view is initialized with a set of previously synced documents
  // which happens when listening to a previously listened-to query.
  FSTView *view = [[FSTView alloc] initWithQuery:query
                                 remoteDocuments:DocumentKeySet{doc1.key, doc2.key}];

  FSTViewDocumentChanges *changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[])];
  FSTViewChange *change = [view applyChangesToDocuments:changes
                                           targetChange:FSTTestTargetChangeMarkCurrent()];
  XCTAssertEqualObjects(change.limboChanges, @[]);
}

- (void)testReturnsNeedsRefillOnDeleteInLimitQuery {
  FSTQuery *query = [[self queryForMessages] queryBySettingLimit:2];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Remove one of the docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ FSTTestDeletedDoc(
                                                  "rooms/eros/messages/0", 0, NO) ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc2}));
  XCTAssertTrue(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  // Refill it with just the one doc remaining.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2 ]) previousChanges:changes];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testReturnsNeedsRefillOnReorderInLimitQuery {
  FSTQuery *query = [self queryForMessages];
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("order")
                                                               ascending:YES]];
  query = [query queryBySettingLimit:2];
  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/0", 0, @{@"order" : @1}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"order" : @2}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"order" : @3}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc2 = FSTTestDoc("rooms/eros/messages/1", 1, @{@"order" : @2000}, DocumentState::kSynced);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertTrue(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  // Refill it with all three current docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3 ])
                              previousChanges:changes];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc3}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillOnReorderWithinLimit {
  FSTQuery *query = [self queryForMessages];
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("order")
                                                               ascending:YES]];
  query = [query queryBySettingLimit:3];
  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/0", 0, @{@"order" : @1}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"order" : @2}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"order" : @3}, DocumentState::kSynced);
  FSTDocument *doc4 =
      FSTTestDoc("rooms/eros/messages/3", 0, @{@"order" : @4}, DocumentState::kSynced);
  FSTDocument *doc5 =
      FSTTestDoc("rooms/eros/messages/4", 0, @{@"order" : @5}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3, doc4, doc5 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(3, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc1 = FSTTestDoc("rooms/eros/messages/0", 1, @{@"order" : @3}, DocumentState::kSynced);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc2, doc3, doc1}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillOnReorderAfterLimitQuery {
  FSTQuery *query = [self queryForMessages];
  query =
      [query queryByAddingSortOrder:[FSTSortOrder sortOrderWithFieldPath:testutil::Field("order")
                                                               ascending:YES]];
  query = [query queryBySettingLimit:3];
  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/0", 0, @{@"order" : @1}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{@"order" : @2}, DocumentState::kSynced);
  FSTDocument *doc3 =
      FSTTestDoc("rooms/eros/messages/2", 0, @{@"order" : @3}, DocumentState::kSynced);
  FSTDocument *doc4 =
      FSTTestDoc("rooms/eros/messages/3", 0, @{@"order" : @4}, DocumentState::kSynced);
  FSTDocument *doc5 =
      FSTTestDoc("rooms/eros/messages/4", 0, @{@"order" : @5}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2, doc3, doc4, doc5 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(3, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc4 = FSTTestDoc("rooms/eros/messages/3", 1, @{@"order" : @6}, DocumentState::kSynced);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc4 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillForAdditionAfterTheLimit {
  FSTQuery *query = [[self queryForMessages] queryBySettingLimit:2];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Add a doc that is past the limit.
  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 1, @{}, DocumentState::kSynced);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillForDeletionsWhenNotNearTheLimit {
  FSTQuery *query = [[self queryForMessages] queryBySettingLimit:20];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Remove one of the docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ FSTTestDeletedDoc(
                                                  "rooms/eros/messages/1", 0, NO) ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testHandlesApplyingIrrelevantDocs {
  FSTQuery *query = [[self queryForMessages] queryBySettingLimit:2];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Remove a doc that isn't even in the results.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ FSTTestDeletedDoc(
                                                  "rooms/eros/messages/2", 0, NO) ])];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testComputesMutatedKeys {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{});

  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{}, DocumentState::kLocalMutations);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ])];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{doc3.key});
}

- (void)testRemovesKeysFromMutatedKeysWhenNewDocHasNoLocalChanges {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kLocalMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));

  FSTDocument *doc2Prime = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kSynced);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc2Prime ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{});
}

- (void)testRemembersLocalMutationsFromPreviousSnapshot {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kLocalMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));

  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{}, DocumentState::kSynced);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ])];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));
}

- (void)testRemembersLocalMutationsFromPreviousCallToComputeChangesWithDocuments {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/0", 0, @{}, DocumentState::kSynced);
  FSTDocument *doc2 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kLocalMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));

  FSTDocument *doc3 = FSTTestDoc("rooms/eros/messages/2", 0, @{}, DocumentState::kSynced);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc3 ]) previousChanges:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key}));
}

- (void)testRaisesHasPendingWritesForPendingMutationsInInitialSnapshot {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 = FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kLocalMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewDocumentChanges *changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1 ])];
  FSTViewChange *viewChange = [view applyChangesToDocuments:changes];
  XCTAssertTrue(viewChange.snapshot.value().has_pending_writes());
}

- (void)testDoesntRaiseHasPendingWritesForCommittedMutationsInInitialSnapshot {
  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 0, @{}, DocumentState::kCommittedMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewDocumentChanges *changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1 ])];
  FSTViewChange *viewChange = [view applyChangesToDocuments:changes];
  XCTAssertFalse(viewChange.snapshot.value().has_pending_writes());
}

- (void)testSuppressesWriteAcknowledgementIfWatchHasNotCaughtUp {
  // This test verifies that we don't get three events for an FSTServerTimestamp mutation. We
  // suppress the event generated by the write acknowledgement and instead wait for Watch to catch
  // up.

  FSTQuery *query = [self queryForMessages];
  FSTDocument *doc1 =
      FSTTestDoc("rooms/eros/messages/1", 1, @{@"time" : @1}, DocumentState::kLocalMutations);
  FSTDocument *doc1Committed =
      FSTTestDoc("rooms/eros/messages/1", 2, @{@"time" : @2}, DocumentState::kCommittedMutations);
  FSTDocument *doc1Acknowledged =
      FSTTestDoc("rooms/eros/messages/1", 2, @{@"time" : @2}, DocumentState::kSynced);
  FSTDocument *doc2 =
      FSTTestDoc("rooms/eros/messages/2", 1, @{@"time" : @1}, DocumentState::kLocalMutations);
  FSTDocument *doc2Modified =
      FSTTestDoc("rooms/eros/messages/2", 2, @{@"time" : @3}, DocumentState::kLocalMutations);
  FSTDocument *doc2Acknowledged =
      FSTTestDoc("rooms/eros/messages/2", 2, @{@"time" : @3}, DocumentState::kSynced);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1, doc2 ])];
  FSTViewChange *viewChange = [view applyChangesToDocuments:changes];

  XC_ASSERT_THAT(viewChange.snapshot.value().document_changes(),
                 ElementsAre(DocumentViewChange{doc1, DocumentViewChange::Type::kAdded},
                             DocumentViewChange{doc2, DocumentViewChange::Type::kAdded}));

  changes = [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1Committed, doc2Modified ])];
  viewChange = [view applyChangesToDocuments:changes];
  // The 'doc1Committed' update is suppressed
  XC_ASSERT_THAT(
      viewChange.snapshot.value().document_changes(),
      ElementsAre(DocumentViewChange{doc2Modified, DocumentViewChange::Type::kModified}));

  changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates(@[ doc1Acknowledged, doc2Acknowledged ])];
  viewChange = [view applyChangesToDocuments:changes];
  XC_ASSERT_THAT(
      viewChange.snapshot.value().document_changes(),
      ElementsAre(DocumentViewChange{doc1Acknowledged, DocumentViewChange::Type::kModified},
                  DocumentViewChange{doc2Acknowledged, DocumentViewChange::Type::kMetadata}));
}

@end

NS_ASSUME_NONNULL_END
