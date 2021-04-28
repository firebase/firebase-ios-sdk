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

#include "Firestore/core/src/core/view.h"

#include <initializer_list>
#include <utility>
#include <vector>

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "Firestore/core/test/unit/testutil/view_testing.h"
#include "absl/types/optional.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using model::Document;
using model::DocumentKeySet;
using model::DocumentSet;
using model::ResourcePath;

using testing::ElementsAre;
using testutil::AckTarget;
using testutil::ApplyChanges;
using testutil::DeletedDoc;
using testutil::Doc;
using testutil::DocUpdates;
using testutil::Field;
using testutil::Filter;
using testutil::Map;
using testutil::MarkCurrent;
using testutil::OrderBy;

/**
 * A custom matcher that verifies that the subject has the same keys as the
 * given documents without verifying that the contents are the same.
 */
MATCHER_P(ContainsDocs, expected, "") {
  if (expected.size() != arg.size()) {
    return false;
  }
  for (const Document& doc : expected) {
    if (!arg.ContainsKey(doc->key())) {
      return false;
    }
  }
  return true;
}

/** Constructs `ContainsDocs` instances with an initializer list. */
inline ContainsDocsMatcherP<std::vector<Document>> ContainsDocs(
    std::vector<Document> docs) {
  return ContainsDocsMatcherP<std::vector<Document>>(std::move(docs));
}

/** Returns a new empty query to use for testing. */
inline Query QueryForMessages() {
  return testutil::Query("rooms/eros/messages");
}

TEST(ViewTest, AddsDocumentsBasedOnQuery) {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/other/messages/1", 0, Map("text", "msg3"));

  absl::optional<ViewSnapshot> maybe_snapshot =
      ApplyChanges(&view, {doc1, doc2, doc3}, AckTarget({doc1, doc2, doc3}));
  ASSERT_TRUE(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  ASSERT_EQ(snapshot.query(), query);

  ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc2));

  ASSERT_TRUE((snapshot.document_changes() ==
               std::vector<DocumentViewChange>{
                   DocumentViewChange{doc1, DocumentViewChange::Type::Added},
                   DocumentViewChange{doc2, DocumentViewChange::Type::Added}}));

  ASSERT_FALSE(snapshot.from_cache());
  ASSERT_FALSE(snapshot.has_pending_writes());
  ASSERT_TRUE(snapshot.sync_state_changed());
}

TEST(ViewTest, RemovesDocuments) {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("text", "msg3"));

  // initial state
  ApplyChanges(&view, {doc1, doc2}, absl::nullopt);

  // delete doc2, add doc3
  absl::optional<ViewSnapshot> maybe_snapshot =
      ApplyChanges(&view, {DeletedDoc("rooms/eros/messages/2"), doc3},
                   AckTarget({doc1, doc3}));
  ASSERT_TRUE(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  ASSERT_EQ(snapshot.query(), query);

  ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  ASSERT_TRUE((snapshot.document_changes() ==
               std::vector<DocumentViewChange>{
                   DocumentViewChange{doc2, DocumentViewChange::Type::Removed},
                   DocumentViewChange{doc3, DocumentViewChange::Type::Added}}));

  ASSERT_FALSE(snapshot.from_cache());
  ASSERT_TRUE(snapshot.sync_state_changed());
}

TEST(ViewTest, ReturnsNilIfThereAreNoChanges) {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));

  // initial state
  ApplyChanges(&view, {doc1, doc2}, absl::nullopt);

  // reapply same docs, no changes
  absl::optional<ViewSnapshot> snapshot =
      ApplyChanges(&view, {doc1, doc2}, absl::nullopt);
  ASSERT_FALSE(snapshot.has_value());
}

TEST(ViewTest, DoesNotReturnNilForFirstChanges) {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  absl::optional<ViewSnapshot> snapshot =
      ApplyChanges(&view, {}, absl::nullopt);
  ASSERT_TRUE(snapshot.has_value());
}

TEST(ViewTest, FiltersDocumentsBasedOnQueryWithFilter) {
  Query query = QueryForMessages().AddingFilter(Filter("sort", "<=", 2));

  View view(query, DocumentKeySet{});
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("sort", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("sort", 2));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("sort", 3));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map());  // no sort, no match
  Document doc5 = Doc("rooms/eros/messages/5", 0, Map("sort", 1));

  absl::optional<ViewSnapshot> maybe_snapshot =
      ApplyChanges(&view, {doc1, doc2, doc3, doc4, doc5}, absl::nullopt);
  ASSERT_TRUE(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  ASSERT_EQ(snapshot.query(), query);

  ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc5, doc2));

  ASSERT_TRUE((snapshot.document_changes() ==
               std::vector<DocumentViewChange>{
                   DocumentViewChange{doc1, DocumentViewChange::Type::Added},
                   DocumentViewChange{doc5, DocumentViewChange::Type::Added},
                   DocumentViewChange{doc2, DocumentViewChange::Type::Added}}));

  ASSERT_TRUE(snapshot.from_cache());
  ASSERT_TRUE(snapshot.sync_state_changed());
}

TEST(ViewTest, UpdatesDocumentsBasedOnQueryWithFilter) {
  Query query = QueryForMessages().AddingFilter(Filter("sort", "<=", 2));

  View view(query, DocumentKeySet{});
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("sort", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("sort", 3));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("sort", 2));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map());

  ViewSnapshot snapshot =
      ApplyChanges(&view, {doc1, doc2, doc3, doc4}, absl::nullopt).value();

  ASSERT_EQ(snapshot.query(), query);

  ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  Document new_doc2 = Doc("rooms/eros/messages/2", 1, Map("sort", 2));
  Document new_doc3 = Doc("rooms/eros/messages/3", 1, Map("sort", 3));
  Document new_doc4 = Doc("rooms/eros/messages/4", 1, Map("sort", 0));

  snapshot = ApplyChanges(&view, {new_doc2, new_doc3, new_doc4}, absl::nullopt)
                 .value();

  ASSERT_EQ(snapshot.query(), query);

  ASSERT_THAT(snapshot.documents(), ElementsAre(new_doc4, doc1, new_doc2));

  ASSERT_THAT(
      snapshot.document_changes(),
      ElementsAre(
          DocumentViewChange{doc3, DocumentViewChange::Type::Removed},
          DocumentViewChange{new_doc4, DocumentViewChange::Type::Added},
          DocumentViewChange{new_doc2, DocumentViewChange::Type::Added}));

  ASSERT_TRUE(snapshot.from_cache());
  ASSERT_FALSE(snapshot.sync_state_changed());
}

TEST(ViewTest, RemovesDocumentsForQueryWithLimit) {
  Query query = QueryForMessages().WithLimitToFirst(2);
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("text", "msg1"));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("text", "msg2"));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("text", "msg3"));

  // initial state
  ApplyChanges(&view, {doc1, doc3}, absl::nullopt);

  // add doc2, which should push out doc3
  ViewSnapshot snapshot =
      ApplyChanges(&view, {doc2}, AckTarget({doc1, doc2, doc3})).value();

  ASSERT_EQ(snapshot.query(), query);

  ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc2));

  ASSERT_TRUE((snapshot.document_changes() ==
               std::vector<DocumentViewChange>{
                   DocumentViewChange{doc3, DocumentViewChange::Type::Removed},
                   DocumentViewChange{doc2, DocumentViewChange::Type::Added}}));

  ASSERT_FALSE(snapshot.from_cache());
  ASSERT_TRUE(snapshot.sync_state_changed());
}

TEST(ViewTest, DoesntReportChangesForDocumentBeyondLimitOfQuery) {
  Query query =
      QueryForMessages().AddingOrderBy(OrderBy("num")).WithLimitToFirst(2);
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/1", 0, Map("num", 1));
  Document doc2 = Doc("rooms/eros/messages/2", 0, Map("num", 2));
  Document doc3 = Doc("rooms/eros/messages/3", 0, Map("num", 3));
  Document doc4 = Doc("rooms/eros/messages/4", 0, Map("num", 4));

  // initial state
  ApplyChanges(&view, {doc1, doc2}, absl::nullopt);

  // change doc2 to 5, and add doc3 and doc4.
  // doc2 will be modified + removed = removed
  // doc3 will be added
  // doc4 will be added + removed = nothing
  doc2 = Doc("rooms/eros/messages/2", 1, Map("num", 5));
  ViewDocumentChanges view_doc_changes =
      view.ComputeDocumentChanges(DocUpdates({doc2, doc3, doc4}));
  ASSERT_TRUE(view_doc_changes.needs_refill());
  // Verify that all the docs still match.
  view_doc_changes = view.ComputeDocumentChanges(
      DocUpdates({doc1, doc2, doc3, doc4}), view_doc_changes);
  absl::optional<ViewSnapshot> maybe_snapshot =
      view.ApplyChanges(view_doc_changes, AckTarget({doc1, doc2, doc3, doc4}))
          .snapshot();
  ASSERT_TRUE(maybe_snapshot.has_value());
  ViewSnapshot snapshot = std::move(maybe_snapshot).value();

  ASSERT_EQ(snapshot.query(), query);

  ASSERT_THAT(snapshot.documents(), ElementsAre(doc1, doc3));

  ASSERT_THAT(
      snapshot.document_changes(),
      ElementsAre(DocumentViewChange{doc2, DocumentViewChange::Type::Removed},
                  DocumentViewChange{doc3, DocumentViewChange::Type::Added}));

  ASSERT_FALSE(snapshot.from_cache());
  ASSERT_TRUE(snapshot.sync_state_changed());
}

TEST(ViewTest, KeepsTrackOfLimboDocuments) {
  Query query = QueryForMessages();
  View view(query, DocumentKeySet{});

  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());

  ViewChange change =
      view.ApplyChanges(view.ComputeDocumentChanges(DocUpdates({doc1})));
  ASSERT_THAT(change.limbo_changes(), ElementsAre());

  change = view.ApplyChanges(view.ComputeDocumentChanges(DocUpdates({})),
                             MarkCurrent());
  ASSERT_THAT(change.limbo_changes(),
              ElementsAre(LimboDocumentChange::Added(doc1->key())));

  change = view.ApplyChanges(view.ComputeDocumentChanges(DocUpdates({})),
                             AckTarget({doc1}));
  ASSERT_THAT(change.limbo_changes(),
              ElementsAre(LimboDocumentChange::Removed(doc1->key())));

  change = view.ApplyChanges(view.ComputeDocumentChanges(DocUpdates({doc2})),
                             AckTarget({doc2}));
  ASSERT_THAT(change.limbo_changes(), ElementsAre());

  change = view.ApplyChanges(view.ComputeDocumentChanges(DocUpdates({doc3})));
  ASSERT_THAT(change.limbo_changes(),
              ElementsAre(LimboDocumentChange::Added(doc3->key())));

  change = view.ApplyChanges(view.ComputeDocumentChanges(
      DocUpdates({DeletedDoc("rooms/eros/messages/2")})));  // remove
  ASSERT_THAT(change.limbo_changes(),
              ElementsAre(LimboDocumentChange::Removed(doc3->key())));
}

TEST(ViewTest, ResumingQueryCreatesNoLimbos) {
  Query query = QueryForMessages();

  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());

  // Unlike other cases, here the view is initialized with a set of previously
  // synced documents which happens when listening to a previously listened-to
  // query.
  View view(query, DocumentKeySet{doc1->key(), doc2->key()});

  ViewDocumentChanges changes = view.ComputeDocumentChanges(DocUpdates({}));
  ViewChange change = view.ApplyChanges(changes, MarkCurrent());
  ASSERT_THAT(change.limbo_changes(), ElementsAre());
}

TEST(ViewTest, ReturnsNeedsRefillOnDeleteInLimitQuery) {
  Query query = QueryForMessages().WithLimitToFirst(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Remove one of the docs.
  changes = view.ComputeDocumentChanges(
      DocUpdates({DeletedDoc("rooms/eros/messages/0")}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc2}));
  ASSERT_TRUE(changes.needs_refill());
  ASSERT_EQ(1, changes.change_set().GetChanges().size());
  // Refill it with just the one doc remaining.
  changes = view.ComputeDocumentChanges(DocUpdates({doc2}), changes);
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc2}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(1, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

TEST(ViewTest, ReturnsNeedsRefillOnReorderInLimitQuery) {
  Query query =
      QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimitToFirst(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2, doc3}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Move one of the docs.
  doc2 = Doc("rooms/eros/messages/1", 1, Map("order", 2000));
  changes = view.ComputeDocumentChanges(DocUpdates({doc2}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  ASSERT_TRUE(changes.needs_refill());
  ASSERT_EQ(1, changes.change_set().GetChanges().size());
  // Refill it with all three current docs.
  changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2, doc3}), changes);
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc3}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

TEST(ViewTest, DoesntNeedRefillOnReorderWithinLimit) {
  Query query =
      QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimitToFirst(3);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  Document doc4 = Doc("rooms/eros/messages/3", 0, Map("order", 4));
  Document doc5 = Doc("rooms/eros/messages/4", 0, Map("order", 5));
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2, doc3, doc4, doc5}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2, doc3}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(3, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Move one of the docs.
  doc1 = Doc("rooms/eros/messages/0", 1, Map("order", 3));
  changes = view.ComputeDocumentChanges(DocUpdates({doc1}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc2, doc3, doc1}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(1, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

TEST(ViewTest, DoesntNeedRefillOnReorderAfterLimitQuery) {
  Query query =
      QueryForMessages().AddingOrderBy(OrderBy("order")).WithLimitToFirst(3);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map("order", 1));
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map("order", 2));
  Document doc3 = Doc("rooms/eros/messages/2", 0, Map("order", 3));
  Document doc4 = Doc("rooms/eros/messages/3", 0, Map("order", 4));
  Document doc5 = Doc("rooms/eros/messages/4", 0, Map("order", 5));
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2, doc3, doc4, doc5}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2, doc3}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(3, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Move one of the docs.
  doc4 = Doc("rooms/eros/messages/3", 1, Map("order", 6));
  changes = view.ComputeDocumentChanges(DocUpdates({doc4}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2, doc3}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(0, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

TEST(ViewTest, DoesntNeedRefillForAdditionAfterTheLimit) {
  Query query = QueryForMessages().WithLimitToFirst(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Add a doc that is past the limit.
  Document doc3 = Doc("rooms/eros/messages/2", 1, Map());
  changes = view.ComputeDocumentChanges(DocUpdates({doc3}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(0, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

TEST(ViewTest, DoesntNeedRefillForDeletionsWhenNotNearTheLimit) {
  Query query = QueryForMessages().WithLimitToFirst(20);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Remove one of the docs.
  changes = view.ComputeDocumentChanges(
      DocUpdates({DeletedDoc("rooms/eros/messages/1")}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(1, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

TEST(ViewTest, HandlesApplyingIrrelevantDocs) {
  Query query = QueryForMessages().WithLimitToFirst(2);
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(2, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);

  // Remove a doc that isn't even in the results.
  changes = view.ComputeDocumentChanges(
      DocUpdates({DeletedDoc("rooms/eros/messages/2")}));
  ASSERT_THAT(changes.document_set(), ContainsDocs({doc1, doc2}));
  ASSERT_FALSE(changes.needs_refill());
  ASSERT_EQ(0, changes.change_set().GetChanges().size());
  view.ApplyChanges(changes);
}

TEST(ViewTest, ComputesMutatedKeys) {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map());
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  view.ApplyChanges(changes);
  ASSERT_EQ(changes.mutated_keys(), DocumentKeySet{});

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map()).SetHasLocalMutations();
  changes = view.ComputeDocumentChanges(DocUpdates({doc3}));
  ASSERT_EQ(changes.mutated_keys(), DocumentKeySet{doc3->key()});
}

TEST(ViewTest, RemovesKeysFromMutatedKeysWhenNewDocHasNoLocalChanges) {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map()).SetHasLocalMutations();
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  view.ApplyChanges(changes);
  ASSERT_EQ(changes.mutated_keys(), (DocumentKeySet{doc2->key()}));

  Document doc2_prime = Doc("rooms/eros/messages/1", 0, Map());
  changes = view.ComputeDocumentChanges(DocUpdates({doc2_prime}));
  view.ApplyChanges(changes);
  ASSERT_EQ(changes.mutated_keys(), DocumentKeySet{});
}

TEST(ViewTest, RemembersLocalMutationsFromPreviousSnapshot) {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map()).SetHasLocalMutations();
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  view.ApplyChanges(changes);
  ASSERT_EQ(changes.mutated_keys(), (DocumentKeySet{doc2->key()}));

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());
  changes = view.ComputeDocumentChanges(DocUpdates({doc3}));
  view.ApplyChanges(changes);
  ASSERT_EQ(changes.mutated_keys(), (DocumentKeySet{doc2->key()}));
}

TEST(ViewTest,
     RemembersLocalMutationsFromPreviousCallToComputeDocumentChanges) {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/0", 0, Map());
  Document doc2 = Doc("rooms/eros/messages/1", 0, Map()).SetHasLocalMutations();
  View view(query, DocumentKeySet{});

  // Start with a full view.
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  ASSERT_EQ(changes.mutated_keys(), (DocumentKeySet{doc2->key()}));

  Document doc3 = Doc("rooms/eros/messages/2", 0, Map());
  changes = view.ComputeDocumentChanges(DocUpdates({doc3}), changes);
  ASSERT_EQ(changes.mutated_keys(), (DocumentKeySet{doc2->key()}));
}

TEST(ViewTest, RaisesHasPendingWritesForPendingMutationsInInitialSnapshot) {
  Query query = QueryForMessages();
  Document doc1 = Doc("rooms/eros/messages/1", 0, Map()).SetHasLocalMutations();
  View view(query, DocumentKeySet{});
  ViewDocumentChanges changes = view.ComputeDocumentChanges(DocUpdates({doc1}));
  ViewChange view_change = view.ApplyChanges(changes);
  ASSERT_TRUE(view_change.snapshot()->has_pending_writes());
}

TEST(ViewTest,
     DoesntRaiseHasPendingWritesForCommittedMutationsInInitialSnapshot) {
  Query query = QueryForMessages();
  Document doc1 =
      Doc("rooms/eros/messages/1", 0, Map()).SetHasCommittedMutations();
  View view(query, DocumentKeySet{});
  ViewDocumentChanges changes = view.ComputeDocumentChanges(DocUpdates({doc1}));
  ViewChange view_change = view.ApplyChanges(changes);
  ASSERT_FALSE(view_change.snapshot()->has_pending_writes());
}

TEST(ViewTest, SuppressesWriteAcknowledgementIfWatchHasNotCaughtUp) {
  // This test verifies that we don't get three events for an FSTServerTimestamp
  // mutation. We suppress the event generated by the write acknowledgement and
  // instead wait for Watch to catch up.

  Query query = QueryForMessages();
  Document doc1 =
      Doc("rooms/eros/messages/1", 1, Map("time", 1)).SetHasLocalMutations();
  Document doc1_committed = Doc("rooms/eros/messages/1", 2, Map("time", 2))
                                .SetHasCommittedMutations();
  Document doc1_acknowledged = Doc("rooms/eros/messages/1", 2, Map("time", 2));
  Document doc2 =
      Doc("rooms/eros/messages/2", 1, Map("time", 1)).SetHasLocalMutations();
  Document doc2_modified =
      Doc("rooms/eros/messages/2", 2, Map("time", 3)).SetHasLocalMutations();
  Document doc2_acknowledged = Doc("rooms/eros/messages/2", 2, Map("time", 3));
  View view(query, DocumentKeySet{});
  ViewDocumentChanges changes =
      view.ComputeDocumentChanges(DocUpdates({doc1, doc2}));
  ViewChange view_change = view.ApplyChanges(changes);

  ASSERT_THAT(
      view_change.snapshot()->document_changes(),
      ElementsAre(DocumentViewChange{doc1, DocumentViewChange::Type::Added},
                  DocumentViewChange{doc2, DocumentViewChange::Type::Added}));

  changes =
      view.ComputeDocumentChanges(DocUpdates({doc1_committed, doc2_modified}));
  view_change = view.ApplyChanges(changes);
  // The 'doc1_committed' update is suppressed
  ASSERT_THAT(view_change.snapshot()->document_changes(),
              ElementsAre(DocumentViewChange{
                  doc2_modified, DocumentViewChange::Type::Modified}));

  changes = view.ComputeDocumentChanges(
      DocUpdates({doc1_acknowledged, doc2_acknowledged}));
  view_change = view.ApplyChanges(changes);
  ASSERT_THAT(
      view_change.snapshot()->document_changes(),
      ElementsAre(DocumentViewChange{doc1_acknowledged,
                                     DocumentViewChange::Type::Modified},
                  DocumentViewChange{doc2_acknowledged,
                                     DocumentViewChange::Type::Metadata}));
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
