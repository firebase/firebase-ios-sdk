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

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/core/field_filter.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/resource_path.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "Firestore/core/test/firebase/firestore/testutil/xcgmock.h"
#include "absl/types/optional.h"

namespace testutil = firebase::firestore::testutil;
using firebase::firestore::core::Direction;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::FieldFilter;
using firebase::firestore::core::Filter;
using firebase::firestore::core::Query;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ResourcePath;

using testing::ElementsAre;
using testutil::Doc;
using testutil::Field;
using testutil::Filter;
using testutil::Map;
using testutil::OrderBy;

NS_ASSUME_NONNULL_BEGIN

/**
 * A custom matcher that verifies that the subject has the same keys as the given documents without
 * verifying that the contents are the same.
 */
MATCHER_P(ContainsDocs, expected, "") {
  if (expected.size() != arg.size()) {
    return false;
  }
  for (const Document &doc : expected) {
    if (!arg.ContainsKey(doc.key())) {
      return false;
    }
  }
  return true;
}

/** Constructs `ContainsDocs` instances with an initializer list. */
inline ContainsDocsMatcherP<std::vector<Document>> ContainsDocs(std::vector<Document> docs) {
  return ContainsDocsMatcherP<std::vector<Document>>(docs);
}

/** Returns a new empty query to use for testing. */
inline Query QueryForMessages() {
  return testutil::Query("rooms/eros/messages");
}

@interface FSTViewTests : XCTestCase
@end

@implementation FSTViewTests

- (void)testAddsDocumentsBasedOnQuery {
  Query query = QueryForMessages();
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/other/messages/1", 0, Map("text", "msg3"));

  absl::optional<ViewSnapshot> maybe_snapshot =
      FSTTestApplyChanges(view, {doc1, doc2, doc3},
                          FSTTestTargetChangeAckDocuments({doc1.key(), doc2.key(), doc3.key()}));
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
  Query query = QueryForMessages();
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("text", "msg3"));

  // initial state
  FSTTestApplyChanges(view, {doc1, doc2}, absl::nullopt);

  // delete doc2, add doc3
  absl::optional<ViewSnapshot> maybe_snapshot =
      FSTTestApplyChanges(view, {FSTTestDeletedDoc("rooms/eros/messages/2", 0, NO), doc3},
                          FSTTestTargetChangeAckDocuments({doc1.key(), doc3.key()}));
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
  Query query = QueryForMessages();
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));

  // initial state
  FSTTestApplyChanges(view, {doc1, doc2}, absl::nullopt);

  // reapply same docs, no changes
  absl::optional<ViewSnapshot> snapshot = FSTTestApplyChanges(view, {doc1, doc2}, absl::nullopt);
  XCTAssertFalse(snapshot.has_value());
}

- (void)testDoesNotReturnNilForFirstChanges {
  Query query = QueryForMessages();
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  absl::optional<ViewSnapshot> snapshot = FSTTestApplyChanges(view, {}, absl::nullopt);
  XCTAssertTrue(snapshot.has_value());
}

- (void)testFiltersDocumentsBasedOnQueryWithFilter {
  Query query = QueryForMessages().AddingFilter(Filter("sort", "<=", 2));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("sort", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("sort", 2));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("sort", 3));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map());  // no sort, no match
  Document doc5 = Doc("rooms/eros/messages/5", 0, Map("sort", 1));

  absl::optional<ViewSnapshot> maybe_snapshot =
      FSTTestApplyChanges(view, {doc1, doc2, doc3, doc4, doc5}, absl::nullopt);
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
  Query query = QueryForMessages().AddingFilter(Filter("sort", "<=", 2));

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("sort", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("sort", 3));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("sort", 2));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map());

  ViewSnapshot snapshot =
      FSTTestApplyChanges(view, {doc1, doc2, doc3, doc4}, absl::nullopt).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  Document newDoc2 = Doc("rooms/eros/messages/2", 1, Map("sort", 2));
  Document newDoc3 = Doc("rooms/eros/messages/3", 1, Map("sort", 3));
  Document newDoc4 = Doc("rooms/eros/messages/4", 1, Map("sort", 0));

  snapshot = FSTTestApplyChanges(view, {newDoc2, newDoc3, newDoc4}, absl::nullopt).value();

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
  Query query = QueryForMessages().WithLimit(2);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("text", "msg3"));

  // initial state
  FSTTestApplyChanges(view, {doc1, doc3}, absl::nullopt);

  // add doc2, which should push out doc3
  ViewSnapshot snapshot =
      FSTTestApplyChanges(view, {doc2},
                          FSTTestTargetChangeAckDocuments({doc1.key(), doc2.key(), doc3.key()}))
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
  Query query = QueryForMessages().AddingOrderBy(OrderBy("num")).WithLimit(2);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("num", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("num", 2));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("num", 3));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map("num", 4));

  // initial state
  FSTTestApplyChanges(view, {doc1, doc2}, absl::nullopt);

  // change doc2 to 5, and add doc3 and doc4.
  // doc2 will be modified + removed = removed
  // doc3 will be added
  // doc4 will be added + removed = nothing
  doc2 = Doc("rooms/eros/messages/2", 1, Map("num", 5));
  FSTViewDocumentChanges *viewDocChanges =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc2, doc3, doc4})];
  XCTAssertTrue(viewDocChanges.needsRefill);
  // Verify that all the docs still match.
  viewDocChanges = [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2, doc3, doc4})
                                     previousChanges:viewDocChanges];
  absl::optional<ViewSnapshot> maybe_snapshot =
      [view applyChangesToDocuments:viewDocChanges
                       targetChange:FSTTestTargetChangeAckDocuments(
                                        {doc1.key(), doc2.key(), doc3.key(), doc4.key()})]
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
  Query query = QueryForMessages();
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());

  FSTViewChange *change =
      [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates({doc1})]];
  XCTAssertEqualObjects(change.limboChanges, @[]);

  change = [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates({})]
                            targetChange:FSTTestTargetChangeMarkCurrent()];
  XCTAssertEqualObjects(change.limboChanges,
                        @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeAdded
                                                              key:doc1.key()] ]);

  change = [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates({})]
                            targetChange:FSTTestTargetChangeAckDocuments({doc1.key()})];
  XCTAssertEqualObjects(change.limboChanges,
                        @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeRemoved
                                                              key:doc1.key()] ]);

  change =
      [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates({doc2})]
                       targetChange:FSTTestTargetChangeAckDocuments({doc2.key()})];
  XCTAssertEqualObjects(change.limboChanges, @[]);

  change =
      [view applyChangesToDocuments:[view computeChangesWithDocuments:FSTTestDocUpdates({doc3})]];
  XCTAssertEqualObjects(change.limboChanges,
                        @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeAdded
                                                              key:doc3.key()] ]);

  change = [view
      applyChangesToDocuments:[view
                                  computeChangesWithDocuments:FSTTestDocUpdates({FSTTestDeletedDoc(
                                                                  "rooms/eros/messages/2", 1,
                                                                  NO)})]];  // remove
  XCTAssertEqualObjects(change.limboChanges,
                        @[ [FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeRemoved
                                                              key:doc3.key()] ]);
}

- (void)testResumingQueryCreatesNoLimbos {
  Query query = QueryForMessages();

  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());

  // Unlike other cases, here the view is initialized with a set of previously synced documents
  // which happens when listening to a previously listened-to query.
  FSTView *view = [[FSTView alloc] initWithQuery:query
                                 remoteDocuments:DocumentKeySet{doc1.key(), doc2.key()}];

  FSTViewDocumentChanges *changes = [view computeChangesWithDocuments:FSTTestDocUpdates({})];
  FSTViewChange *change = [view applyChangesToDocuments:changes
                                           targetChange:FSTTestTargetChangeMarkCurrent()];
  XCTAssertEqualObjects(change.limboChanges, @[]);
}

- (void)testReturnsNeedsRefillOnDeleteInLimitQuery {
  Query query = QueryForMessages().WithLimit(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Remove one of the docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({FSTTestDeletedDoc(
                                                  "rooms/eros/messages/0", 0, NO)})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc2}));
  XCTAssertTrue(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  // Refill it with just the one doc remaining.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc2}) previousChanges:changes];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testReturnsNeedsRefillOnReorderInLimitQuery {
  Query query = QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimit(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2, doc3})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc2 = Doc("rooms/eros/messages/1", 1, Map("order", 2000));
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc2})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertTrue(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  // Refill it with all three current docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2, doc3})
                              previousChanges:changes];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc3}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillOnReorderWithinLimit {
  Query query = QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimit(3);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  Document doc4 = Doc("rooms/eros/messages/3", 0, Map("order", 4));
  Document doc5 = Doc("rooms/eros/messages/4", 0, Map("order", 5));
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2, doc3, doc4, doc5})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(3, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc1 = Doc("rooms/eros/messages/0", 1, Map("order", 3));
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc1})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc2, doc3, doc1}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillOnReorderAfterLimitQuery {
  Query query = QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimit(3);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  Document doc4 = Doc("rooms/eros/messages/3", 0, Map("order", 4));
  Document doc5 = Doc("rooms/eros/messages/4", 0, Map("order", 5));
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2, doc3, doc4, doc5})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(3, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Move one of the docs.
  doc4 = Doc("rooms/eros/messages/3", 1, Map("order", 6));
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc4})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillForAdditionAfterTheLimit {
  Query query = QueryForMessages().WithLimit(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Add a doc that is past the limit.
  Document doc3 = Doc("rooms/eros/messages/2", 1, Map());
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc3})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testDoesntNeedRefillForDeletionsWhenNotNearTheLimit {
  Query query = QueryForMessages().WithLimit(20);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Remove one of the docs.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({FSTTestDeletedDoc(
                                                  "rooms/eros/messages/1", 0, NO)})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(1, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testHandlesApplyingIrrelevantDocs {
  Query query = QueryForMessages().WithLimit(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(2, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];

  // Remove a doc that isn't even in the results.
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({FSTTestDeletedDoc(
                                                  "rooms/eros/messages/2", 0, NO)})];
  XC_ASSERT_THAT(changes.documentSet, ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needsRefill);
  XCTAssertEqual(0, changes.changeSet.GetChanges().size());
  [view applyChangesToDocuments:changes];
}

- (void)testComputesMutatedKeys {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{});

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map(), DocumentState::kLocalMutations);
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc3})];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{doc3.key()});
}

- (void)testRemovesKeysFromMutatedKeysWhenNewDocHasNoLocalChanges {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kLocalMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key()}));

  Document doc2Prime = Doc("rooms/eros/messages/1", 0, Map());
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc2Prime})];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, DocumentKeySet{});
}

- (void)testRemembersLocalMutationsFromPreviousSnapshot {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kLocalMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key()}));

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc3})];
  [view applyChangesToDocuments:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key()}));
}

- (void)testRemembersLocalMutationsFromPreviousCallToComputeChangesWithDocuments {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kLocalMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];

  // Start with a full view.
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key()}));

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());
  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc3}) previousChanges:changes];
  XCTAssertEqual(changes.mutatedKeys, (DocumentKeySet{doc2.key()}));
}

- (void)testRaisesHasPendingWritesForPendingMutationsInInitialSnapshot {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kLocalMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewDocumentChanges *changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc1})];
  FSTViewChange *viewChange = [view applyChangesToDocuments:changes];
  XCTAssertTrue(viewChange.snapshot.value().has_pending_writes());
}

- (void)testDoesntRaiseHasPendingWritesForCommittedMutationsInInitialSnapshot {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kCommittedMutations);
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewDocumentChanges *changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc1})];
  FSTViewChange *viewChange = [view applyChangesToDocuments:changes];
  XCTAssertFalse(viewChange.snapshot.value().has_pending_writes());
}

- (void)testSuppressesWriteAcknowledgementIfWatchHasNotCaughtUp {
  // This test verifies that we don't get three events for an FSTServerTimestamp mutation. We
  // suppress the event generated by the write acknowledgement and instead wait for Watch to catch
  // up.

  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/1", 1, Map("time", 1), DocumentState::kLocalMutations);
  Document doc1Committed =
      Doc("rooms/eros/messages/1", 2, Map("time", 2), DocumentState::kCommittedMutations);
  Document doc1Acknowledged = Doc("rooms/eros/messages/1", 2, Map("time", 2));
  Document doc2 = Doc("rooms/eros/messages/2", 1, Map("time", 1), DocumentState::kLocalMutations);
  Document doc2Modified =
      Doc("rooms/eros/messages/2", 2, Map("time", 3), DocumentState::kLocalMutations);
  Document doc2Acknowledged = Doc("rooms/eros/messages/2", 2, Map("time", 3));
  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:DocumentKeySet{}];
  FSTViewDocumentChanges *changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1, doc2})];
  FSTViewChange *viewChange = [view applyChangesToDocuments:changes];

  XC_ASSERT_THAT(viewChange.snapshot.value().document_changes(),
                 ElementsAre(DocumentViewChange{doc1, DocumentViewChange::Type::kAdded},
                             DocumentViewChange{doc2, DocumentViewChange::Type::kAdded}));

  changes = [view computeChangesWithDocuments:FSTTestDocUpdates({doc1Committed, doc2Modified})];
  viewChange = [view applyChangesToDocuments:changes];
  // The 'doc1Committed' update is suppressed
  XC_ASSERT_THAT(
      viewChange.snapshot.value().document_changes(),
      ElementsAre(DocumentViewChange{doc2Modified, DocumentViewChange::Type::kModified}));

  changes =
      [view computeChangesWithDocuments:FSTTestDocUpdates({doc1Acknowledged, doc2Acknowledged})];
  viewChange = [view applyChangesToDocuments:changes];
  XC_ASSERT_THAT(
      viewChange.snapshot.value().document_changes(),
      ElementsAre(DocumentViewChange{doc1Acknowledged, DocumentViewChange::Type::kModified},
                  DocumentViewChange{doc2Acknowledged, DocumentViewChange::Type::kMetadata}));
}

@end

NS_ASSUME_NONNULL_END
