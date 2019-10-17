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

using firebase::firestore::auth::User;
using firebase::firestore::core::View;
using firebase::firestore::core::ViewDocumentChanges;
using firebase::firestore::local::IndexFreeQueryEngine;
using firebase::firestore::local::LocalDocumentsView;
using firebase::firestore::local::MemoryIndexManager;
using firebase::firestore::local::Persistence;
using firebase::firestore::local::QueryCache;
using firebase::firestore::local::QueryEngine;
using firebase::firestore::local::RemoteDocumentCache;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentMap;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::DocumentState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

namespace firebase {
namespace firestore {
namespace local {

using core::Query;

using testutil::Doc;
using testutil::DocSet;
using testutil::Filter;
using testutil::Key;
using testutil::Map;
using testutil::OrderBy;
using testutil::Resource;
using testutil::Version;

namespace {

int TEST_TARGET_ID = 1;

Document MATCHING_DOC_A = Doc("coll/a", 1, Map("matches", true, "order", 1));
Document NON_MATCHING_DOC_A =
    Doc("coll/a", 1, Map("matches", false, "order", 1));
Document PENDING_MATCHING_DOC_A = Doc("coll/a",
                                      1,
                                      Map("matches", true, "order", 1),
                                      DocumentState::kLocalMutations);
Document PENDING_NON_MATCHING_DOC_A = Doc("coll/a",
                                          1,
                                          Map("matches", false, "order", 1),
                                          DocumentState::kLocalMutations);
Document UPDATED_DOC_A = Doc("coll/a", 11, Map("matches", true, "order", 1));
Document MATCHING_DOC_B = Doc("coll/b", 1, Map("matches", true, "order", 2));
Document UPDATED_MATCHING_DOC_B =
    Doc("coll/b", 11, Map("matches", true, "order", 2));

SnapshotVersion LAST_LIMBO_FREE_SNAPSHOT = Version(10);
SnapshotVersion MISSING_LAST_LIMBO_FREE_SNAPSHOT = SnapshotVersion::None();

}  // namespace

class TestLocalDocumentsView : public LocalDocumentsView {
 public:
  TestLocalDocumentsView(RemoteDocumentCache* remote_document_cache,
                         MutationQueue* mutation_queue,
                         IndexManager* index_manager)
      : LocalDocumentsView(
            remote_document_cache, mutation_queue, index_manager) {
  }

  model::DocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::SnapshotVersion& since_read_time) override {
    EXPECT_TRUE(expect_index_free_execution.has_value());
    EXPECT_EQ(*expect_index_free_execution,
              since_read_time != SnapshotVersion::None());
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
        index_manager_(new MemoryIndexManager()),
        local_documents_view_(
            remote_document_cache_,
            persistence_->GetMutationQueueForUser(User::Unauthenticated()),
            index_manager_.get()) {
    query_engine_.SetLocalDocumentsView(&local_documents_view_);
  }

  /** Adds the provided documents to the query target mapping. */
  void PersistQueryMapping(const std::vector<DocumentKey>& keys) {
    persistence_->Run("PersistQueryMapping", [this, &keys]() {
      DocumentKeySet remote_keys;
      for (const DocumentKey& key : keys) {
        remote_keys = remote_keys.insert(key);
      }
      query_cache_->AddMatchingKeys(remote_keys, TEST_TARGET_ID);
    });
  }

  /** Adds the provided documents to the remote document cache. */
  void AddDocuments(const std::vector<Document>& docs) {
    persistence_->Run("AddDocuments", [this, &docs]() {
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
      const Query& query,
      const SnapshotVersion& last_limbo_free_snapshot_version) {
    const DocumentKeySet& remote_keys =
        query_cache_->GetMatchingKeys(TEST_TARGET_ID);
    DocumentMap docs = query_engine_.GetDocumentsMatchingQuery(
        query, last_limbo_free_snapshot_version, remote_keys);
    View view(query, DocumentKeySet());
    ViewDocumentChanges viewDocChanges =
        view.ComputeDocumentChanges(docs.underlying_map(), {});
    return view.ApplyChanges(viewDocChanges).snapshot()->documents();
  }

 private:
  std::unique_ptr<Persistence> persistence_;
  RemoteDocumentCache* remote_document_cache_;
  QueryCache* query_cache_;
  std::unique_ptr<MemoryIndexManager> index_manager_;
  IndexFreeQueryEngine query_engine_;
  TestLocalDocumentsView local_documents_view_;
};

TEST_F(IndexFreeQueryEngineTest, UsesTargetMappingForInitialView) {
  Query query =
      Query(Resource("coll")).AddingFilter(Filter("matches", "==", true));

  AddDocuments({MATCHING_DOC_A, MATCHING_DOC_B});
  PersistQueryMapping({MATCHING_DOC_A.key(), MATCHING_DOC_B.key()});

  const DocumentSet& docs = ExpectIndexFreeQuery(
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {MATCHING_DOC_A, MATCHING_DOC_B}));
}

TEST_F(IndexFreeQueryEngineTest, FiltersNonMatchingInitialResults) {
  Query query =
      Query(Resource("coll")).AddingFilter(Filter("matches", "==", true));

  AddDocuments({MATCHING_DOC_A, MATCHING_DOC_B});
  PersistQueryMapping({MATCHING_DOC_A.key(), MATCHING_DOC_B.key()});

  // Add a mutated document that is not yet part of query's set of remote keys.
  AddDocuments({PENDING_NON_MATCHING_DOC_A});

  const DocumentSet& docs = ExpectIndexFreeQuery(
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {MATCHING_DOC_B}));
}

TEST_F(IndexFreeQueryEngineTest, IncludesChangesSinceInitialResults) {
  Query query =
      Query(Resource("coll")).AddingFilter(Filter("matches", "==", true));

  AddDocuments({MATCHING_DOC_A, MATCHING_DOC_B});
  PersistQueryMapping({MATCHING_DOC_A.key(), MATCHING_DOC_B.key()});

  DocumentSet docs = ExpectIndexFreeQuery(
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {MATCHING_DOC_A, MATCHING_DOC_B}));

  AddDocuments({UPDATED_MATCHING_DOC_B});

  docs = ExpectIndexFreeQuery(
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs, DocSet(query.Comparator(),
                         {MATCHING_DOC_A, UPDATED_MATCHING_DOC_B}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsWithoutLimboFreeSnapshotVersion) {
  Query query =
      Query(Resource("coll")).AddingFilter(Filter("matches", "==", true));

  const DocumentSet& docs = ExpectFullCollectionQuery([&query, this]() {
    return RunQuery(query, MISSING_LAST_LIMBO_FREE_SNAPSHOT);
  });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsForUnfilteredCollectionQuery) {
  Query query = Query(Resource("coll"));

  const DocumentSet& docs = ExpectFullCollectionQuery(
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWithDocumentRemoval) {
  Query query = Query(Resource("coll"))
                    .AddingFilter(Filter("matches", "==", true))
                    .WithLimit(1);

  // While the backend would never add DocA to the set of remote keys, this
  // allows us to easily simulate what would happen when a document no longer
  // matches due to an out-of-band update.
  AddDocuments({NON_MATCHING_DOC_A});
  PersistQueryMapping({MATCHING_DOC_A.key()});

  AddDocuments({MATCHING_DOC_B});

  DocumentSet docs = ExpectFullCollectionQuery(
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {MATCHING_DOC_B}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWhenLastDocumentHasPendingWrite) {
  Query query = Query(Resource("coll"))
                    .AddingFilter(Filter("matches", "==", true))
                    .AddingOrderBy(OrderBy("order", "desc"))
                    .WithLimit(1);

  // Add a query mapping for a document that matches, but that sorts below
  // another document due to a pending write.
  AddDocuments({PENDING_MATCHING_DOC_A});
  PersistQueryMapping({PENDING_MATCHING_DOC_A.key()});

  AddDocuments({MATCHING_DOC_B});

  DocumentSet docs = ExpectFullCollectionQuery(
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {MATCHING_DOC_B}));
}

TEST_F(IndexFreeQueryEngineTest,
       DoesNotUseInitialResultsForLimitQueryWhenLastDocumentUpdatedOutOfBand) {
  Query query = Query(Resource("coll"))
                    .AddingFilter(Filter("matches", "==", true))
                    .AddingOrderBy(OrderBy("order", "desc"))
                    .WithLimit(1);

  // Add a query mapping for a document that matches, but that sorts below
  // another document based due to an update that the SDK received after the
  // query's snapshot was persisted.
  AddDocuments({UPDATED_DOC_A});
  PersistQueryMapping({UPDATED_DOC_A.key()});

  AddDocuments({MATCHING_DOC_B});

  DocumentSet docs = ExpectFullCollectionQuery(
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs, DocSet(query.Comparator(), {MATCHING_DOC_B}));
}

TEST_F(IndexFreeQueryEngineTest,
       LimitQueriesUseInitialResultsIfLastDocumentInLimitIsUnchanged) {
  Query query =
      Query(Resource("coll")).AddingOrderBy(OrderBy("order")).WithLimit(2);

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
      [&query, this]() { return RunQuery(query, LAST_LIMBO_FREE_SNAPSHOT); });
  EXPECT_EQ(docs,
            DocSet(query.Comparator(), {Doc("coll/a", 1, Map("order", 2),
                                            DocumentState::kLocalMutations),
                                        Doc("coll/b", 1, Map("order", 3))}));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
