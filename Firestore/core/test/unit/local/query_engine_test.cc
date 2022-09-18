/*
 * Copyright 2019 Google
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

#include "Firestore/core/test/unit/local/query_engine_test.h"

#include "Firestore/core/src/local/query_engine.h"

#include <functional>
#include <memory>

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/view.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/memory_index_manager.h"
#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/local/target_cache.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/src/model/object_value.h"
#include "Firestore/core/src/model/precondition.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/test/unit/testutil/testutil.h"

namespace firebase {
namespace firestore {
namespace local {

namespace {

using core::View;
using core::ViewDocumentChanges;
using credentials::User;
using local::LocalDocumentsView;
using local::MemoryIndexManager;
using local::Persistence;
using local::QueryEngine;
using local::RemoteDocumentCache;
using local::TargetCache;
using model::BatchId;
using model::DeleteMutation;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::DocumentSet;
using model::FieldMask;
using model::MutableDocument;
using model::Mutation;
using model::MutationBatch;
using model::ObjectValue;
using model::PatchMutation;
using model::Precondition;
using model::SnapshotVersion;
using model::TargetId;
using testutil::Doc;
using testutil::DocSet;
using testutil::Filter;
using testutil::Key;
using testutil::Map;
using testutil::OrderBy;
using testutil::Query;
using testutil::Version;

const int kTestTargetId = 1;
const MutableDocument kMatchingDocA =
    Doc("coll/a", 1, Map("matches", true, "order", 1));
const MutableDocument kNonMatchingDocA =
    Doc("coll/a", 1, Map("matches", false, "order", 1));
const MutableDocument pPendingMatchingDocA =
    Doc("coll/a", 1, Map("matches", true, "order", 1)).SetHasLocalMutations();
const MutableDocument kPendingNonMatchingDocA =
    Doc("coll/a", 1, Map("matches", false, "order", 1)).SetHasLocalMutations();
const MutableDocument kUpdatedDocA =
    Doc("coll/a", 11, Map("matches", true, "order", 1));
const MutableDocument kMatchingDocB =
    Doc("coll/b", 1, Map("matches", true, "order", 2));
const MutableDocument kUpdatedMatchingDocB =
    Doc("coll/b", 11, Map("matches", true, "order", 2));
const PatchMutation kDocAEmptyPatch = PatchMutation(
    Key("coll/a"), ObjectValue(), FieldMask(), Precondition::None());

const SnapshotVersion kLastLimboFreeSnapshot = Version(10);
const SnapshotVersion kMissingLastLimboFreeSnapshot = SnapshotVersion::None();

}  // namespace

DocumentMap TestLocalDocumentsView::GetDocumentsMatchingQuery(
    const core::Query& query, const model::IndexOffset& offset) {
  bool full_collection_scan = offset.read_time() == SnapshotVersion::None();

  EXPECT_TRUE(expect_full_collection_scan_.has_value());
  EXPECT_EQ(expect_full_collection_scan_.value(), full_collection_scan);

  return LocalDocumentsView::GetDocumentsMatchingQuery(query, offset);
}

void TestLocalDocumentsView::ExpectFullCollectionScan(
    bool full_collection_scan) {
  expect_full_collection_scan_ = full_collection_scan;
}

QueryEngineTestBase::QueryEngineTestBase(
    std::unique_ptr<Persistence>&& persistence)
    : persistence_(std::move(persistence)),
      remote_document_cache_(persistence_->remote_document_cache()),
      document_overlay_cache_(
          persistence_->GetDocumentOverlayCache(User::Unauthenticated())),
      index_manager_(persistence_->GetIndexManager(User::Unauthenticated())),
      mutation_queue_(persistence_->GetMutationQueue(User::Unauthenticated(),
                                                     index_manager_)),
      local_documents_view_(remote_document_cache_,
                            mutation_queue_,
                            document_overlay_cache_,
                            index_manager_),
      target_cache_(persistence_->target_cache()) {
  remote_document_cache_->SetIndexManager(index_manager_);
  query_engine_.Initialize(&local_documents_view_);
}

void QueryEngineTestBase::PersistQueryMapping(
    const std::vector<model::DocumentKey>& keys) {
  DocumentKeySet remote_keys;
  for (const DocumentKey& key : keys) {
    remote_keys = remote_keys.insert(key);
  }
  target_cache_->AddMatchingKeys(remote_keys, kTestTargetId);
}

void QueryEngineTestBase::AddDocuments(
    const std::vector<model::MutableDocument>& docs) {
  for (const MutableDocument& doc : docs) {
    remote_document_cache_->Add(doc, doc.version());
  }
}

void QueryEngineTestBase::AddDocumentWithEventVersion(
    const SnapshotVersion& event_version,
    const std::vector<MutableDocument>& docs) {
  for (const MutableDocument& doc : docs) {
    remote_document_cache_->Add(doc, event_version);
  }
}

void QueryEngineTestBase::AddMutation(Mutation mutation) {
  MutationBatch batch =
      mutation_queue_->AddMutationBatch(Timestamp::Now(), {}, {mutation});
  model::MutationByDocumentKeyMap overlayMap{{mutation.key(), mutation}};
  document_overlay_cache_->SaveOverlays(batch.batch_id(), overlayMap);
}

DocumentSet QueryEngineTestBase::ExpectOptimizedCollectionScan(
    const std::function<DocumentSet(void)>& f) {
  local_documents_view_.ExpectFullCollectionScan(false);
  return f();
}

template <typename T>
T QueryEngineTestBase::ExpectFullCollectionScan(
    const std::function<T(void)>& f) {
  local_documents_view_.ExpectFullCollectionScan(true);
  return f();
}

DocumentSet QueryEngineTestBase::RunQuery(
    const core::Query& query,
    const SnapshotVersion& last_limbo_free_snapshot_version) {
  DocumentKeySet remote_keys = target_cache_->GetMatchingKeys(kTestTargetId);
  const auto docs = query_engine_.GetDocumentsMatchingQuery(
      query, last_limbo_free_snapshot_version, remote_keys);
  View view(query, DocumentKeySet());
  ViewDocumentChanges view_doc_changes = view.ComputeDocumentChanges(docs, {});
  return view.ApplyChanges(view_doc_changes).snapshot()->documents();
}

QueryEngineTest::QueryEngineTest() : QueryEngineTestBase(GetParam()()) {
}

TEST_P(QueryEngineTest, UsesTargetMappingForInitialView) {
  persistence_->Run("UsesTargetMappingForInitialView", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    core::Query query =
        Query("coll").AddingFilter(Filter("matches", "==", true));

    AddDocuments({kMatchingDocA, kMatchingDocB});
    PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

    DocumentSet docs = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
    EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocA, kMatchingDocB}));
  });
}

TEST_P(QueryEngineTest, FiltersNonMatchingInitialResults) {
  persistence_->Run("FiltersNonMatchingInitialResults", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    core::Query query =
        Query("coll").AddingFilter(Filter("matches", "==", true));

    AddDocuments({kMatchingDocA, kMatchingDocB});
    PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

    // Add a mutated document that is not yet part of query's set of remote
    // keys.
    AddDocumentWithEventVersion(Version(1), {kPendingNonMatchingDocA});

    DocumentSet docs = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
    EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
  });
}

TEST_P(QueryEngineTest, IncludesChangesSinceInitialResults) {
  persistence_->Run("IncludesChangesSinceInitialResults", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    core::Query query =
        Query("coll").AddingFilter(Filter("matches", "==", true));

    AddDocuments({kMatchingDocA, kMatchingDocB});
    PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

    DocumentSet docs = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
    EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocA, kMatchingDocB}));

    AddDocuments({kUpdatedMatchingDocB});

    docs = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
    EXPECT_EQ(docs, DocSet(query.Comparator(),
                           {kMatchingDocA, kUpdatedMatchingDocB}));
  });
}

TEST_P(QueryEngineTest,
       DoesNotUseInitialResultsWithoutLimboFreeSnapshotVersion) {
  persistence_->Run(
      "DoesNotUseInitialResultsWithoutLimboFreeSnapshotVersion", [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query =
            Query("coll").AddingFilter(Filter("matches", "==", true));

        DocumentSet docs = ExpectFullCollectionScan<DocumentSet>(
            [&] { return RunQuery(query, kMissingLastLimboFreeSnapshot); });
        EXPECT_EQ(docs, DocSet(query.Comparator(), {}));
      });
}

TEST_P(QueryEngineTest, DoesNotUseInitialResultsForUnfilteredCollectionQuery) {
  persistence_->Run(
      "DoesNotUseInitialResultsForUnfilteredCollectionQuery", [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query = Query("coll");

        DocumentSet docs = ExpectFullCollectionScan<DocumentSet>(
            [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
        EXPECT_EQ(docs, DocSet(query.Comparator(), {}));
      });
}

TEST_P(QueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWithDocumentRemoval) {
  persistence_->Run(
      "DoesNotUseInitialResultsForLimitQueryWithDocumentRemoval", [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query = Query("coll")
                                .AddingFilter(Filter("matches", "==", true))
                                .WithLimitToFirst(1);

        // While the backend would never add DocA to the set of remote keys,
        // this allows us to easily simulate what would happen when a document
        // no longer matches due to an out-of-band update.
        AddDocuments({kNonMatchingDocA});
        PersistQueryMapping({kMatchingDocA.key()});

        AddDocuments({kMatchingDocB});

        DocumentSet docs = ExpectFullCollectionScan<DocumentSet>(
            [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
        EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
      });
}

TEST_P(QueryEngineTest,
       DoesNotUseInitialResultsForLimitToLastWithDocumentRemoval) {
  persistence_->Run(
      "DoesNotUseInitialResultsForLimitToLastWithDocumentRemoval", [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query = Query("coll")
                                .AddingFilter(Filter("matches", "==", true))
                                .AddingOrderBy(OrderBy("order", "desc"))
                                .WithLimitToLast(1);

        // While the backend would never add DocA to the set of remote keys,
        // this allows us to easily simulate what would happen when a document
        // no longer matches due to an out-of-band update.
        AddDocuments({kNonMatchingDocA});
        PersistQueryMapping({kMatchingDocA.key()});

        AddDocuments({kMatchingDocB});

        DocumentSet docs = ExpectFullCollectionScan<DocumentSet>(
            [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
        EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
      });
}

TEST_P(QueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWhenLastDocumentHasPendingWrite) {
  persistence_->Run(
      "DoesNotUseInitialResultsForLimitQueryWhenLastDocumentHasPendingWrite",
      [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query = Query("coll")
                                .AddingFilter(Filter("matches", "==", true))
                                .AddingOrderBy(OrderBy("order", "desc"))
                                .WithLimitToFirst(1);

        // Add a query mapping for a document that matches, but that sorts below
        // another document due to a pending write.
        AddDocumentWithEventVersion(Version(1), {pPendingMatchingDocA});
        AddMutation(kDocAEmptyPatch);
        PersistQueryMapping({pPendingMatchingDocA.key()});

        AddDocuments({kMatchingDocB});

        DocumentSet docs = ExpectFullCollectionScan<DocumentSet>(
            [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
        EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
      });
}

TEST_P(QueryEngineTest,
       DoesNotUseInitialResultsForLimitToLastWhenLastDocumentHasPendingWrite) {
  persistence_->Run(
      "DoesNotUseInitialResultsForLimitToLastWhenLastDocumentHasPendingWrite",
      [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query = Query("coll")
                                .AddingFilter(Filter("matches", "==", true))
                                .AddingOrderBy(OrderBy("order", "asc"))
                                .WithLimitToLast(1);

        // Add a query mapping for a document that matches, but that sorts below
        // another document due to a pending write.
        AddDocumentWithEventVersion(Version(1), {pPendingMatchingDocA});
        AddMutation(kDocAEmptyPatch);
        PersistQueryMapping({pPendingMatchingDocA.key()});

        AddDocuments({kMatchingDocB});

        DocumentSet docs = ExpectFullCollectionScan<DocumentSet>(
            [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
        EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
      });
}

TEST_P(QueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWhenLastDocumentUpdatedOutOfBand) {
  persistence_->Run(
      "DoesNotUseInitialResultsForLimitQueryWhenLastDocumentUpdatedOutOfBand",
      [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query = Query("coll")
                                .AddingFilter(Filter("matches", "==", true))
                                .AddingOrderBy(OrderBy("order", "desc"))
                                .WithLimitToFirst(1);

        // Add a query mapping for a document that matches, but that sorts below
        // another document based due to an update that the SDK received after
        // the query's snapshot was persisted.
        AddDocuments({kUpdatedDocA});
        PersistQueryMapping({kUpdatedDocA.key()});

        AddDocuments({kMatchingDocB});

        DocumentSet docs = ExpectFullCollectionScan<DocumentSet>(
            [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
        EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
      });
}

TEST_P(QueryEngineTest,
       DoesNotUseInitialResultsForLimitToLastWhenLastDocumentUpdatedOutOfBand) {
  persistence_->Run(
      "DoesNotUseInitialResultsForLimitToLastWhenLastDocumentUpdatedOutOfBand",
      [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query = Query("coll")
                                .AddingFilter(Filter("matches", "==", true))
                                .AddingOrderBy(OrderBy("order", "asc"))
                                .WithLimitToLast(1);

        // Add a query mapping for a document that matches, but that sorts below
        // another document based due to an update that the SDK received after
        // the query's snapshot was persisted.
        AddDocuments({kUpdatedDocA});
        PersistQueryMapping({kUpdatedDocA.key()});

        AddDocuments({kMatchingDocB});

        DocumentSet docs = ExpectFullCollectionScan<DocumentSet>(
            [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
        EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
      });
}

TEST_P(QueryEngineTest,
       LimitQueriesUseInitialResultsIfLastDocumentInLimitIsUnchanged) {
  persistence_->Run(
      "LimitQueriesUseInitialResultsIfLastDocumentInLimitIsUnchanged", [&] {
        mutation_queue_->Start();
        index_manager_->Start();

        core::Query query =
            Query("coll").AddingOrderBy(OrderBy("order")).WithLimitToFirst(2);

        AddDocuments({Doc("coll/a", 1, Map("order", 1)),
                      Doc("coll/b", 1, Map("order", 3))});
        PersistQueryMapping({Key("coll/a"), Key("coll/b")});

        // Update "coll/a" but make sure it still sorts before "coll/b"
        AddDocumentWithEventVersion(
            Version(1),
            {Doc("coll/a", 1, Map("order", 2)).SetHasLocalMutations()});
        AddMutation(kDocAEmptyPatch);

        // Since the last document in the limit didn't change (and hence we know
        // that all documents written prior to query execution still sort after
        // "coll/b"), we should use an Index-Free query.
        DocumentSet docs = ExpectOptimizedCollectionScan(
            [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
        EXPECT_EQ(
            docs,
            DocSet(query.Comparator(),
                   {Doc("coll/a", 1, Map("order", 2)).SetHasLocalMutations(),
                    Doc("coll/b", 1, Map("order", 3))}));
      });
}

TEST_P(QueryEngineTest, DoesNotIncludeDocumentsDeletedByMutation) {
  persistence_->Run("DoesNotIncludeDocumentsDeletedByMutation", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    core::Query query = Query("coll");

    AddDocuments({kMatchingDocA, kMatchingDocB});
    PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

    // Add an unacknowledged mutation
    AddMutation(DeleteMutation(Key("coll/b"), Precondition::None()));
    auto docs = ExpectFullCollectionScan<DocumentMap>([&] {
      return query_engine_.GetDocumentsMatchingQuery(
          query, kLastLimboFreeSnapshot,
          target_cache_->GetMatchingKeys(kTestTargetId));
    });
    DocumentMap result;
    result = result.insert(kMatchingDocA.key(), kMatchingDocA);
    EXPECT_EQ(1u, result.size());
    EXPECT_TRUE(result.find(kMatchingDocA.key()) != result.end());
    EXPECT_EQ(result.get(kMatchingDocA.key()), kMatchingDocA);
  });
}

// TODO(orquery): Port test canPerformOrQueriesUsingFullCollectionScan

}  // namespace local
}  // namespace firestore
}  // namespace firebase
