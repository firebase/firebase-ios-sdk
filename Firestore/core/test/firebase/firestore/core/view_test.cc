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

#import <XCTest/XCTest.h>

#include <initializer_list>
#include <utility>
#include <vector>

#import "Firestore/Source/API/FIRFirestore+Internal.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/core/field_filter.h"
#include "Firestore/core/src/firebase/firestore/core/filter.h"
#include "Firestore/core/src/firebase/firestore/core/view.h"
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
using firebase::firestore::core::LimboDocumentChange;
using firebase::firestore::core::Query;
using firebase::firestore::core::View;
using firebase::firestore::core::ViewChange;
using firebase::firestore::core::ViewDocumentChanges;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::FieldValue;
using firebase::firestore::model::ResourcePath;

using testing::ElementsAre;
using testutil::DeletedDoc;
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
  return ContainsDocsMatcherP<std::vector<Document>>(std::move(docs));
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
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/other/messages/1", 0, Map("text", "msg3"));

  absl::optional<ViewSnapshot> maybe_snapshot =
      FSTTestApplyChanges(&view, {doc1, doc2, doc3},
                          FSTTestTargetChangeAckDocuments({doc1.key(), doc2.key(), doc3.key()}));
  XCTAssertTrue(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc2));

  XCTAssertTrue(
      (snapshot.document_changes() ==
       std::vector<DocumentViewChange>{DocumentViewChange{doc1, DocumentViewChange::Type::Added},
                                       DocumentViewChange{doc2, DocumentViewChange::Type::Added}}));

  XCTAssertFalse(snapshot.from_cache());
  XCTAssertFalse(snapshot.has_pending_writes());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testRemovesDocuments {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("text", "msg3"));

  // initial state
  FSTTestApplyChanges(&view, {doc1, doc2}, absl::nullopt);

  // delete doc2, add doc3
  absl::optional<ViewSnapshot> maybe_snapshot =
      FSTTestApplyChanges(&view, {DeletedDoc("rooms/eros/messages/2"), doc3},
                          FSTTestTargetChangeAckDocuments({doc1.key(), doc3.key()}));
  XCTAssertTrue(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  XCTAssertTrue(
      (snapshot.document_changes() ==
       std::vector<DocumentViewChange>{DocumentViewChange{doc2, DocumentViewChange::Type::Removed},
                                       DocumentViewChange{doc3, DocumentViewChange::Type::Added}}));

  XCTAssertFalse(snapshot.from_cache());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testReturnsNilIfThereAreNoChanges {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));

  // initial state
  FSTTestApplyChanges(&view, {doc1, doc2}, absl::nullopt);

  // reapply same docs, no changes
  absl::optional<ViewSnapshot> snapshot = FSTTestApplyChanges(&view, {doc1, doc2}, absl::nullopt);
  XCTAssertFalse(snapshot.has_value());
}

- (void)testDoesNotReturnNilForFirstChanges {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  absl::optional<ViewSnapshot> snapshot = FSTTestApplyChanges(&view, {}, absl::nullopt);
  XCTAssertTrue(snapshot.has_value());
}

- (void)testFiltersDocumentsBasedOnQueryWithFilter {
  Query query = QueryForMessages().AddingFilter(Filter("sort", "<=", 2));

  View view(query, DocumentKeySet{});
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("sort", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("sort", 2));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("sort", 3));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map());  // no sort, no match
  Document doc5 = Doc("rooms/eros/messages/5", 0, Map("sort", 1));

  absl::optional<ViewSnapshot> maybe_snapshot =
      FSTTestApplyChanges(&view, {doc1, doc2, doc3, doc4, doc5}, absl::nullopt);
  XCTAssertTrue(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc5, doc2));

  XCTAssertTrue(
      (snapshot.document_changes() ==
       std::vector<DocumentViewChange>{DocumentViewChange{doc1, DocumentViewChange::Type::Added},
                                       DocumentViewChange{doc5, DocumentViewChange::Type::Added},
                                       DocumentViewChange{doc2, DocumentViewChange::Type::Added}}));

  XCTAssertTrue(snapshot.from_cache());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testUpdatesDocumentsBasedOnQueryWithFilter {
  Query query = QueryForMessages().AddingFilter(Filter("sort", "<=", 2));

  View view(query, DocumentKeySet{});
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("sort", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("sort", 3));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("sort", 2));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map());

  ViewSnapshot snapshot =
      FSTTestApplyChanges(&view, {doc1, doc2, doc3, doc4}, absl::nullopt).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  Document newDoc2 = Doc("rooms/eros/messages/2", 1, Map("sort", 2));
  Document newDoc3 = Doc("rooms/eros/messages/3", 1, Map("sort", 3));
  Document newDoc4 = Doc("rooms/eros/messages/4", 1, Map("sort", 0));

  snapshot = FSTTestApplyChanges(&view, {newDoc2, newDoc3, newDoc4}, absl::nullopt).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(newDoc4, doc1, newDoc2));

  XC_ASSERT_THAT(snapshot.document_changes(),
                 ElementsAre(DocumentViewChange{doc3, DocumentViewChange::Type::Removed},
                             DocumentViewChange{newDoc4, DocumentViewChange::Type::Added},
                             DocumentViewChange{newDoc2, DocumentViewChange::Type::Added}));

  XCTAssertTrue(snapshot.from_cache());
  XCTAssertFalse(snapshot.sync_state_changed());
}

- (void)testRemovesDocumentsForQueryWithLimit {
  Query query = QueryForMessages().WithLimit(2);
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("text", "msg3"));

  // initial state
  FSTTestApplyChanges(&view, {doc1, doc3}, absl::nullopt);

  // add doc2, which should push out doc3
  ViewSnapshot snapshot =
      FSTTestApplyChanges(&view, {doc2},
                          FSTTestTargetChangeAckDocuments({doc1.key(), doc2.key(), doc3.key()}))
          .value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc2));

  XCTAssertTrue(
      (snapshot.document_changes() ==
       std::vector<DocumentViewChange>{DocumentViewChange{doc3, DocumentViewChange::Type::Removed},
                                       DocumentViewChange{doc2, DocumentViewChange::Type::Added}}));

  XCTAssertFalse(snapshot.from_cache());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testDoesntReportChangesForDocumentBeyondLimitOfQuery {
  Query query = QueryForMessages().AddingOrderBy(OrderBy("num")).WithLimit(2);
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("num", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("num", 2));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("num", 3));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map("num", 4));

  // initial state
  FSTTestApplyChanges(&view, {doc1, doc2}, absl::nullopt);

  // change doc2 to 5, and add doc3 and doc4.
  // doc2 will be modified + removed = removed
  // doc3 will be added
  // doc4 will be added + removed = nothing
  doc2 = Doc("rooms/eros/messages/2", 1, Map("num", 5));
  ViewDocumentChanges viewDocChanges =
      view.ComputeDocumentChanges(FSTTestDocUpdates({doc2, doc3, doc4}));
  XCTAssertTrue(viewDocChanges.needs_refill());
  // Verify that all the docs still match.
  viewDocChanges =
      view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2, doc3, doc4}), viewDocChanges);
  absl::optional<ViewSnapshot> maybe_snapshot =
      view.ApplyChanges(viewDocChanges, FSTTestTargetChangeAckDocuments(
                                            {doc1.key(), doc2.key(), doc3.key(), doc4.key()}))
          .snapshot();
  XCTAssertTrue(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  XCTAssertEqual(snapshot.query(), query);

  XC_ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  XC_ASSERT_THAT(snapshot.document_changes(),
                 ElementsAre(DocumentViewChange{doc2, DocumentViewChange::Type::Removed},
                             DocumentViewChange{doc3, DocumentViewChange::Type::Added}));

  XCTAssertFalse(snapshot.from_cache());
  XCTAssertTrue(snapshot.sync_state_changed());
}

- (void)testKeepsTrackOfLimboDocuments {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());

  ViewChange change = view.ApplyChanges(view.ComputeDocumentChanges(FSTTestDocUpdates({doc1})));
  XC_ASSERT_THAT(change.limbo_changes(), ElementsAre());

  change = view.ApplyChanges(view.ComputeDocumentChanges(FSTTestDocUpdates({})),
                             FSTTestTargetChangeMarkCurrent());
  XC_ASSERT_THAT(change.limbo_changes(), ElementsAre(LimboDocumentChange::Added(doc1.key())));

  change = view.ApplyChanges(view.ComputeDocumentChanges(FSTTestDocUpdates({})),
                             FSTTestTargetChangeAckDocuments({doc1.key()}));
  XC_ASSERT_THAT(change.limbo_changes(), ElementsAre(LimboDocumentChange::Removed(doc1.key())));

  change = view.ApplyChanges(view.ComputeDocumentChanges(FSTTestDocUpdates({doc2})),
                             FSTTestTargetChangeAckDocuments({doc2.key()}));
  XC_ASSERT_THAT(change.limbo_changes(), ElementsAre());

  change = view.ApplyChanges(view.ComputeDocumentChanges(FSTTestDocUpdates({doc3})));
  XC_ASSERT_THAT(change.limbo_changes(), ElementsAre(LimboDocumentChange::Added(doc3.key())));

  change = view.ApplyChanges(view.ComputeDocumentChanges(
      FSTTestDocUpdates({DeletedDoc("rooms/eros/messages/2")})));  // remove
  XC_ASSERT_THAT(change.limbo_changes(), ElementsAre(LimboDocumentChange::Removed(doc3.key())));
}

- (void)testResumingQueryCreatesNoLimbos {
  Query query = QueryForMessages();

  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());

  // Unlike other cases, here the view is initialized with a set of previously synced documents
  // which happens when listening to a previously listened-to query.
  View view(query, DocumentKeySet{doc1.key(), doc2.key()});

  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({}));
  ViewChange change = view.ApplyChanges(changes, FSTTestTargetChangeMarkCurrent());
  XC_ASSERT_THAT(change.limbo_changes(), ElementsAre());
}

- (void)testReturnsNeedsRefillOnDeleteInLimitQuery {
  Query query = QueryForMessages().WithLimit(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Remove one of the docs.
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({DeletedDoc("rooms/eros/messages/0")}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc2}));
  XCTAssertTrue(changes.needs_refill());
  XCTAssertEqual(1, changes.change_set().GetChanges().size());
  // Refill it with just the one doc remaining.
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc2}), changes);
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc2}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(1, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

- (void)testReturnsNeedsRefillOnReorderInLimitQuery {
  Query query = QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimit(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2, doc3}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Move one of the docs.
  doc2 = Doc("rooms/eros/messages/1", 1, Map("order", 2000));
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc2}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  XCTAssertTrue(changes.needs_refill());
  XCTAssertEqual(1, changes.change_set().GetChanges().size());
  // Refill it with all three current docs.
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2, doc3}), changes);
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc3}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

- (void)testDoesntNeedRefillOnReorderWithinLimit {
  Query query = QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimit(3);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  Document doc4 = Doc("rooms/eros/messages/3", 0, Map("order", 4));
  Document doc5 = Doc("rooms/eros/messages/4", 0, Map("order", 5));
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2, doc3, doc4, doc5}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(3, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Move one of the docs.
  doc1 = Doc("rooms/eros/messages/0", 1, Map("order", 3));
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc2, doc3, doc1}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(1, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

- (void)testDoesntNeedRefillOnReorderAfterLimitQuery {
  Query query = QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimit(3);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  Document doc4 = Doc("rooms/eros/messages/3", 0, Map("order", 4));
  Document doc5 = Doc("rooms/eros/messages/4", 0, Map("order", 5));
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2, doc3, doc4, doc5}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(3, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Move one of the docs.
  doc4 = Doc("rooms/eros/messages/3", 1, Map("order", 6));
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc4}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2, doc3}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(0, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

- (void)testDoesntNeedRefillForAdditionAfterTheLimit {
  Query query = QueryForMessages().WithLimit(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Add a doc that is past the limit.
  Document doc3 = Doc("rooms/eros/messages/2", 1, Map());
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc3}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(0, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

- (void)testDoesntNeedRefillForDeletionsWhenNotNearTheLimit {
  Query query = QueryForMessages().WithLimit(20);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Remove one of the docs.
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({DeletedDoc("rooms/eros/messages/1")}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(1, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

- (void)testHandlesApplyingIrrelevantDocs {
  Query query = QueryForMessages().WithLimit(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Remove a doc that isn't even in the results.
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({DeletedDoc("rooms/eros/messages/2")}));
  XC_ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  XCTAssertFalse(changes.needs_refill());
  XCTAssertEqual(0, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

- (void)testComputesMutatedKeys {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  view.ApplyChanges(changes);
  XCTAssertEqual(changes.mutated_keys(), DocumentKeySet{});

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map(), DocumentState::kLocalMutations);
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc3}));
  XCTAssertEqual(changes.mutated_keys(), DocumentKeySet{doc3.key()});
}

- (void)testRemovesKeysFromMutatedKeysWhenNewDocHasNoLocalChanges {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kLocalMutations);
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  view.ApplyChanges(changes);
  XCTAssertEqual(changes.mutated_keys(), (DocumentKeySet{doc2.key()}));

  Document doc2Prime = Doc("rooms/eros/messages/1", 0, Map());
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc2Prime}));
  view.ApplyChanges(changes);
  XCTAssertEqual(changes.mutated_keys(), DocumentKeySet{});
}

- (void)testRemembersLocalMutationsFromPreviousSnapshot {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kLocalMutations);
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  view.ApplyChanges(changes);
  XCTAssertEqual(changes.mutated_keys(), (DocumentKeySet{doc2.key()}));

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc3}));
  view.ApplyChanges(changes);
  XCTAssertEqual(changes.mutated_keys(), (DocumentKeySet{doc2.key()}));
}

- (void)testRemembersLocalMutationsFromPreviousCallToComputeDocumentChanges {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kLocalMutations);
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  XCTAssertEqual(changes.mutated_keys(), (DocumentKeySet{doc2.key()}));

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());
  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc3}), changes);
  XCTAssertEqual(changes.mutated_keys(), (DocumentKeySet{doc2.key()}));
}

- (void)testRaisesHasPendingWritesForPendingMutationsInInitialSnapshot {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kLocalMutations);
  View view(query, DocumentKeySet{});
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1}));
  ViewChange viewChange = view.ApplyChanges(changes);
  XCTAssertTrue(viewChange.snapshot()->has_pending_writes());
}

- (void)testDoesntRaiseHasPendingWritesForCommittedMutationsInInitialSnapshot {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map(), DocumentState::kCommittedMutations);
  View view(query, DocumentKeySet{});
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1}));
  ViewChange viewChange = view.ApplyChanges(changes);
  XCTAssertFalse(viewChange.snapshot()->has_pending_writes());
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
  View view(query, DocumentKeySet{});
  ViewDocumentChanges changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1, doc2}));
  ViewChange viewChange = view.ApplyChanges(changes);

  XC_ASSERT_THAT(viewChange.snapshot()->document_changes(),
                 ElementsAre(DocumentViewChange{doc1, DocumentViewChange::Type::Added},
                             DocumentViewChange{doc2, DocumentViewChange::Type::Added}));

  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1Committed, doc2Modified}));
  viewChange = view.ApplyChanges(changes);
  // The 'doc1Committed' update is suppressed
  XC_ASSERT_THAT(viewChange.snapshot()->document_changes(),
                 ElementsAre(DocumentViewChange{doc2Modified, DocumentViewChange::Type::Modified}));

  changes = view.ComputeDocumentChanges(FSTTestDocUpdates({doc1Acknowledged, doc2Acknowledged}));
  viewChange = view.ApplyChanges(changes);
  XC_ASSERT_THAT(
      viewChange.snapshot()->document_changes(),
      ElementsAre(DocumentViewChange{doc1Acknowledged, DocumentViewChange::Type::Modified},
                  DocumentViewChange{doc2Acknowledged, DocumentViewChange::Type::Metadata}));
}

@end

NS_ASSUME_NONNULL_END
