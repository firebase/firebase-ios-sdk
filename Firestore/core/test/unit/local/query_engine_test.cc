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

#include "Firestore/core/src/local/query_engine.h"

#include <functional>
#include <memory>

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/view.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/local_documents_view.h"
#include "Firestore/core/src/local/memory_index_manager.h"
#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/local/target_cache.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/util/string_util.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

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
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::DocumentSet;
using model::MutableDocument;
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

const SnapshotVersion kLastLimboFreeSnapshot = Version(10);
const SnapshotVersion kMissingLastLimboFreeSnapshot = SnapshotVersion::None();

}  // namespace

class TestLocalDocumentsView : public LocalDocumentsView {
 public:
  using LocalDocumentsView::LocalDocumentsView;

  DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const SnapshotVersion& since_read_time) override {
    bool full_collection_scan = since_read_time == SnapshotVersion::None();

    EXPECT_TRUE(expect_full_collection_scan_.has_value());
    EXPECT_EQ(expect_full_collection_scan_.value(), full_collection_scan);

    return LocalDocumentsView::GetDocumentsMatchingQuery(query,
                                                         since_read_time);
  }

  void ExpectFullCollectionScan(bool full_collection_scan) {
    expect_full_collection_scan_ = full_collection_scan;
  }

 private:
  absl::optional<bool> expect_full_collection_scan_;
};

class QueryEngineTest : public ::testing::Test {
 public:
  QueryEngineTest()
      : persistence_(MemoryPersistence::WithEagerGarbageCollector()),
        remote_document_cache_(dynamic_cast<MemoryRemoteDocumentCache*>(
            persistence_->remote_document_cache())),
        target_cache_(persistence_->target_cache()),
        index_manager_(dynamic_cast<MemoryIndexManager*>(
            persistence_->GetIndexManager(User::Unauthenticated()))),
        local_documents_view_(
            remote_document_cache_,
            persistence_->GetMutationQueue(User::Unauthenticated(),
                                           index_manager_),
            persistence_->GetDocumentOverlayCache(User::Unauthenticated()),
            index_manager_) {
    remote_document_cache_->SetIndexManager(index_manager_);
    query_engine_.SetLocalDocumentsView(&local_documents_view_);
  }

  /** Adds the provided documents to the query target mapping. */
  void PersistQueryMapping(const std::vector<DocumentKey>& keys) {
    persistence_->Run("PersistQueryMapping", [&] {
      DocumentKeySet remote_keys;
      for (const DocumentKey& key : keys) {
        remote_keys = remote_keys.insert(key);
      }
      target_cache_->AddMatchingKeys(remote_keys, kTestTargetId);
    });
  }

  /** Adds the provided documents to the remote document cache. */
  void AddDocuments(const std::vector<MutableDocument>& docs) {
    persistence_->Run("AddDocuments", [&] {
      for (const MutableDocument& doc : docs) {
        remote_document_cache_->Add(doc, doc.version());
      }
    });
  }

  DocumentSet ExpectOptimizedCollectionScan(
      const std::function<DocumentSet(void)>& f) {
    local_documents_view_.ExpectFullCollectionScan(false);
    return f();
  }

  DocumentSet ExpectFullCollectionScan(
      const std::function<DocumentSet(void)>& f) {
    local_documents_view_.ExpectFullCollectionScan(true);
    return f();
  }

  DocumentSet RunQuery(
      const core::Query& query,
      const SnapshotVersion& last_limbo_free_snapshot_version) {
    DocumentKeySet remote_keys = target_cache_->GetMatchingKeys(kTestTargetId);
    DocumentMap docs = query_engine_.GetDocumentsMatchingQuery(
        query, last_limbo_free_snapshot_version, remote_keys);
    View view(query, DocumentKeySet());
    ViewDocumentChanges view_doc_changes =
        view.ComputeDocumentChanges(docs, {});
    return view.ApplyChanges(view_doc_changes).snapshot()->documents();
  }

 private:
  std::unique_ptr<Persistence> persistence_;
  MemoryRemoteDocumentCache* remote_document_cache_ = nullptr;
  TargetCache* target_cache_ = nullptr;
  MemoryIndexManager* index_manager_;
  QueryEngine query_engine_;
  TestLocalDocumentsView local_documents_view_;
};

TEST_F(QueryEngineTest, UsesTargetMappingForInitialView) {
  core::Query query = Query("coll").AddingFilter(Filter("matches", "==", true));

  AddDocuments({kMatchingDocA, kMatchingDocB});
  PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

  DocumentSet docs = ExpectOptimizedCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocA, kMatchingDocB}));
}

TEST_F(QueryEngineTest, FiltersNonMatchingInitialResults) {
  core::Query query = Query("coll").AddingFilter(Filter("matches", "==", true));

  AddDocuments({kMatchingDocA, kMatchingDocB});
  PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

  // Add a mutated document that is not yet part of query's set of remote keys.
  AddDocuments({kPendingNonMatchingDocA});

  DocumentSet docs = ExpectOptimizedCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(QueryEngineTest, IncludesChangesSinceInitialResults) {
  core::Query query = Query("coll").AddingFilter(Filter("matches", "==", true));

  AddDocuments({kMatchingDocA, kMatchingDocB});
  PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

  DocumentSet docs = ExpectOptimizedCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocA, kMatchingDocB}));

  AddDocuments({kUpdatedMatchingDocB});

  docs = ExpectOptimizedCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs,
            DocSet(query.Comparator(), {kMatchingDocA, kUpdatedMatchingDocB}));
}

TEST_F(QueryEngineTest,
       DoesNotUseInitialResultsWithoutLimboFreeSnapshotVersion) {
  core::Query query = Query("coll").AddingFilter(Filter("matches", "==", true));

  DocumentSet docs = ExpectFullCollectionScan(
      [&] { return RunQuery(query, kMissingLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {}));
}

TEST_F(QueryEngineTest, DoesNotUseInitialResultsForUnfilteredCollectionQuery) {
  core::Query query = Query("coll");

  DocumentSet docs = ExpectFullCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {}));
}

TEST_F(QueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWithDocumentRemoval) {
  core::Query query = Query("coll")
                          .AddingFilter(Filter("matches", "==", true))
                          .WithLimitToFirst(1);

  // While the backend would never add DocA to the set of remote keys, this
  // allows us to easily simulate what would happen when a document no longer
  // matches due to an out-of-band update.
  AddDocuments({kNonMatchingDocA});
  PersistQueryMapping({kMatchingDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(QueryEngineTest,
       DoesNotUseInitialResultsForLimitToLastWithDocumentRemoval) {
  core::Query query = Query("coll")
                          .AddingFilter(Filter("matches", "==", true))
                          .AddingOrderBy(OrderBy("order", "desc"))
                          .WithLimitToLast(1);

  // While the backend would never add DocA to the set of remote keys, this
  // allows us to easily simulate what would happen when a document no longer
  // matches due to an out-of-band update.
  AddDocuments({kNonMatchingDocA});
  PersistQueryMapping({kMatchingDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(QueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWhenLastDocumentHasPendingWrite) {
  core::Query query = Query("coll")
                          .AddingFilter(Filter("matches", "==", true))
                          .AddingOrderBy(OrderBy("order", "desc"))
                          .WithLimitToFirst(1);

  // Add a query mapping for a document that matches, but that sorts below
  // another document due to a pending write.
  AddDocuments({pPendingMatchingDocA});
  PersistQueryMapping({pPendingMatchingDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(QueryEngineTest,
       DoesNotUseInitialResultsForLimitToLastWhenLastDocumentHasPendingWrite) {
  core::Query query = Query("coll")
                          .AddingFilter(Filter("matches", "==", true))
                          .AddingOrderBy(OrderBy("order", "asc"))
                          .WithLimitToLast(1);

  // Add a query mapping for a document that matches, but that sorts below
  // another document due to a pending write.
  AddDocuments({pPendingMatchingDocA});
  PersistQueryMapping({pPendingMatchingDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(QueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWhenLastDocumentUpdatedOutOfBand) {
  core::Query query = Query("coll")
                          .AddingFilter(Filter("matches", "==", true))
                          .AddingOrderBy(OrderBy("order", "desc"))
                          .WithLimitToFirst(1);

  // Add a query mapping for a document that matches, but that sorts below
  // another document based due to an update that the SDK received after the
  // query's snapshot was persisted.
  AddDocuments({kUpdatedDocA});
  PersistQueryMapping({kUpdatedDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(QueryEngineTest,
       DoesNotUseInitialResultsForLimitToLastWhenLastDocumentUpdatedOutOfBand) {
  core::Query query = Query("coll")
                          .AddingFilter(Filter("matches", "==", true))
                          .AddingOrderBy(OrderBy("order", "asc"))
                          .WithLimitToLast(1);

  // Add a query mapping for a document that matches, but that sorts below
  // another document based due to an update that the SDK received after the
  // query's snapshot was persisted.
  AddDocuments({kUpdatedDocA});
  PersistQueryMapping({kUpdatedDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(QueryEngineTest,
       LimitQueriesUseInitialResultsIfLastDocumentInLimitIsUnchanged) {
  core::Query query =
      Query("coll").AddingOrderBy(OrderBy("order")).WithLimitToFirst(2);

  AddDocuments(
      {Doc("coll/a", 1, Map("order", 1)), Doc("coll/b", 1, Map("order", 3))});
  PersistQueryMapping({Key("coll/a"), Key("coll/b")});

  // Update "coll/a" but make sure it still sorts before "coll/b"
  AddDocuments({Doc("coll/a", 1, Map("order", 2)).SetHasLocalMutations()});

  // Since the last document in the limit didn't change (and hence we know that
  // all documents written prior to query execution still sort after "coll/b"),
  // we should use an Index-Free query.
  DocumentSet docs = ExpectOptimizedCollectionScan(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs,
            DocSet(query.Comparator(),
                   {Doc("coll/a", 1, Map("order", 2)).SetHasLocalMutations(),
                    Doc("coll/b", 1, Map("order", 3))}));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
