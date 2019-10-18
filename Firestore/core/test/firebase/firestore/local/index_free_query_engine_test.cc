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

#include "Firestore/core/src/firebase/firestore/local/index_free_query_engine.h"

#include <functional>
#include <memory>

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/view.h"
#include "Firestore/core/src/firebase/firestore/local/local_documents_view.h"
#include "Firestore/core/src/firebase/firestore/local/memory_index_manager.h"
#include "Firestore/core/src/firebase/firestore/local/memory_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/local/query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/util/string_util.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

namespace {

using auth::User;
using core::View;
using core::ViewDocumentChanges;
using local::IndexFreeQueryEngine;
using local::LocalDocumentsView;
using local::MemoryIndexManager;
using local::Persistence;
using local::QueryCache;
using local::QueryEngine;
using local::RemoteDocumentCache;
using model::BatchId;
using model::Document;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::DocumentSet;
using model::DocumentState;
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

const Document kMatchingDocA =
    Doc("coll/a", 1, Map("matches", true, "order", 1));
const Document kNonMatchingDocA =
    Doc("coll/a", 1, Map("matches", false, "order", 1));
const Document pPendingMatchingDocA = Doc("coll/a",
                                          1,
                                          Map("matches", true, "order", 1),
                                          DocumentState::kLocalMutations);
const Document kPendingNonMatchingDocA = Doc("coll/a",
                                             1,
                                             Map("matches", false, "order", 1),
                                             DocumentState::kLocalMutations);
const Document kUpdatedDocA =
    Doc("coll/a", 11, Map("matches", true, "order", 1));
const Document kMatchingDocB =
    Doc("coll/b", 1, Map("matches", true, "order", 2));
const Document kUpdatedMatchingDocB =
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
    bool is_index_free = since_read_time != SnapshotVersion::None();

    EXPECT_TRUE(expect_index_free_execution.has_value());
    EXPECT_EQ(expect_index_free_execution.value(), is_index_free);

    return LocalDocumentsView::GetDocumentsMatchingQuery(query,
                                                         since_read_time);
  }

  void ExpectIndexFreeExecution(bool index_free) {
    expect_index_free_execution = index_free;
  }

 private:
  absl::optional<bool> expect_index_free_execution;
};

class IndexFreeQueryEngineTest : public ::testing::Test {
 public:
  IndexFreeQueryEngineTest()
      : persistence_(MemoryPersistence::WithEagerGarbageCollector()),
        remote_document_cache_(persistence_->remote_document_cache()),
        query_cache_(persistence_->query_cache()),
        index_manager_(absl::make_unique<MemoryIndexManager>()),
        local_documents_view_(
            remote_document_cache_,
            persistence_->GetMutationQueueForUser(User::Unauthenticated()),
            index_manager_.get()) {
    query_engine_.SetLocalDocumentsView(&local_documents_view_);
  }

  /** Adds the provided documents to the query target mapping. */
  void PersistQueryMapping(const std::vector<DocumentKey>& keys) {
    persistence_->Run("PersistQueryMapping", [&] {
      DocumentKeySet remote_keys;
      for (const DocumentKey& key : keys) {
        remote_keys = remote_keys.insert(key);
      }
      query_cache_->AddMatchingKeys(remote_keys, kTestTargetId);
    });
  }

  /** Adds the provided documents to the remote document cache. */
  void AddDocuments(const std::vector<Document>& docs) {
    persistence_->Run("AddDocuments", [&] {
      for (const Document& doc : docs) {
        remote_document_cache_->Add(doc, doc.version());
      }
    });
  }

  DocumentSet ExpectIndexFreeQuery(const std::function<DocumentSet(void)>& f) {
    local_documents_view_.ExpectIndexFreeExecution(true);
    return f();
  }

  DocumentSet ExpectFullCollectionQuery(
      const std::function<DocumentSet(void)>& f) {
    local_documents_view_.ExpectIndexFreeExecution(false);
    return f();
  }

  DocumentSet RunQuery(
      const core::Query& query,
      const SnapshotVersion& last_limbo_free_snapshot_version) {
    DocumentKeySet remote_keys = query_cache_->GetMatchingKeys(kTestTargetId);
    DocumentMap docs = query_engine_.GetDocumentsMatchingQuery(
        query, last_limbo_free_snapshot_version, remote_keys);
    View view(query, DocumentKeySet());
    ViewDocumentChanges view_doc_changes =
        view.ComputeDocumentChanges(docs.underlying_map(), {});
    return view.ApplyChanges(view_doc_changes).snapshot()->documents();
  }

 private:
  std::unique_ptr<Persistence> persistence_;
  RemoteDocumentCache* remote_document_cache_ = nullptr;
  QueryCache* query_cache_ = nullptr;
  std::unique_ptr<MemoryIndexManager> index_manager_;
  IndexFreeQueryEngine query_engine_;
  TestLocalDocumentsView local_documents_view_;
};

TEST_F(IndexFreeQueryEngineTest, UsesTargetMappingForInitialView) {
  core::Query query = Query("coll").AddingFilter(Filter("matches", "==", true));

  AddDocuments({kMatchingDocA, kMatchingDocB});
  PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

  DocumentSet docs = ExpectIndexFreeQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocA, kMatchingDocB}));
}

TEST_F(IndexFreeQueryEngineTest, FiltersNonMatchingInitialResults) {
  core::Query query = Query("coll").AddingFilter(Filter("matches", "==", true));

  AddDocuments({kMatchingDocA, kMatchingDocB});
  PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

  // Add a mutated document that is not yet part of query's set of remote keys.
  AddDocuments({kPendingNonMatchingDocA});

  DocumentSet docs = ExpectIndexFreeQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(IndexFreeQueryEngineTest, IncludesChangesSinceInitialResults) {
  core::Query query = Query("coll").AddingFilter(Filter("matches", "==", true));

  AddDocuments({kMatchingDocA, kMatchingDocB});
  PersistQueryMapping({kMatchingDocA.key(), kMatchingDocB.key()});

  DocumentSet docs = ExpectIndexFreeQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocA, kMatchingDocB}));

  AddDocuments({kUpdatedMatchingDocB});

  docs = ExpectIndexFreeQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs,
            DocSet(query.Comparator(), {kMatchingDocA, kUpdatedMatchingDocB}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsWithoutLimboFreeSnapshotVersion) {
  core::Query query = Query("coll").AddingFilter(Filter("matches", "==", true));

  DocumentSet docs = ExpectFullCollectionQuery(
      [&] { return RunQuery(query, kMissingLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsForUnfilteredCollectionQuery) {
  core::Query query = Query("coll");

  DocumentSet docs = ExpectFullCollectionQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWithDocumentRemoval) {
  core::Query query =
      Query("coll").AddingFilter(Filter("matches", "==", true)).WithLimit(1);

  // While the backend would never add DocA to the set of remote keys, this
  // allows us to easily simulate what would happen when a document no longer
  // matches due to an out-of-band update.
  AddDocuments({kNonMatchingDocA});
  PersistQueryMapping({kMatchingDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWhenLastDocumentHasPendingWrite) {
  core::Query query = Query("coll")
                          .AddingFilter(Filter("matches", "==", true))
                          .AddingOrderBy(OrderBy("order", "desc"))
                          .WithLimit(1);

  // Add a query mapping for a document that matches, but that sorts below
  // another document due to a pending write.
  AddDocuments({pPendingMatchingDocA});
  PersistQueryMapping({pPendingMatchingDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWhenLastDocumentUpdatedOutOfBand) {
  core::Query query = Query("coll")
                          .AddingFilter(Filter("matches", "==", true))
                          .AddingOrderBy(OrderBy("order", "desc"))
                          .WithLimit(1);

  // Add a query mapping for a document that matches, but that sorts below
  // another document based due to an update that the SDK received after the
  // query's snapshot was persisted.
  AddDocuments({kUpdatedDocA});
  PersistQueryMapping({kUpdatedDocA.key()});

  AddDocuments({kMatchingDocB});

  DocumentSet docs = ExpectFullCollectionQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {kMatchingDocB}));
}

TEST_F(IndexFreeQueryEngineTest,
       LimitQueriesUseInitialResultsIfLastDocumentInLimitIsUnchanged) {
  core::Query query =
      Query("coll").AddingOrderBy(OrderBy("order")).WithLimit(2);

  AddDocuments(
      {Doc("coll/a", 1, Map("order", 1)), Doc("coll/b", 1, Map("order", 3))});
  PersistQueryMapping({Key("coll/a"), Key("coll/b")});

  // Update "coll/a" but make sure it still sorts before "coll/b"
  AddDocuments(
      {Doc("coll/a", 1, Map("order", 2), DocumentState::kLocalMutations)});

  // Since the last document in the limit didn't change (and hence we know that
  // all documents written prior to query execution still sort after "coll/b"),
  // we should use an Index-Free query.
  DocumentSet docs = ExpectIndexFreeQuery(
      [&] { return RunQuery(query, kLastLimboFreeSnapshot); });
  EXPECT_EQ(docs,
            DocSet(query.Comparator(), {Doc("coll/a", 1, Map("order", 2),
                                            DocumentState::kLocalMutations),
                                        Doc("coll/b", 1, Map("order", 3))}));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
