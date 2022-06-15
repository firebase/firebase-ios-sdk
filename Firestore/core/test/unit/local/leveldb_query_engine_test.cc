/*
 * Copyright 2022 Google LLC
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

#include <vector>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/query_engine.h"
#include "Firestore/core/src/model/document_set.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/local/query_engine_test.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using model::DocumentMap;
using model::DocumentSet;
using model::SnapshotVersion;
using testutil::Doc;
using testutil::DocSet;
using testutil::Filter;
using testutil::MakeFieldIndex;
using testutil::Map;
using testutil::OrderBy;
using testutil::PatchMutation;
using testutil::Query;
using testutil::SetMutation;
using testutil::Version;

std::unique_ptr<Persistence> PersistenceFactory() {
  return LevelDbPersistenceForTesting();
}

}  // namespace

INSTANTIATE_TEST_SUITE_P(LevelDbQueryEngineTest,
                         QueryEngineTest,
                         testing::Values(PersistenceFactory));

class LevelDbQueryEngineTest : public QueryEngineTestBase {
 public:
  LevelDbQueryEngineTest() : QueryEngineTestBase(PersistenceFactory()) {
  }
};

TEST_F(LevelDbQueryEngineTest, CombinesIndexedWithNonIndexedResults) {
  persistence_->Run("CombinesIndexedWithNonIndexedResults", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/a", 1, Map("foo", true));
    auto doc2 = Doc("coll/b", 2, Map("foo", true));
    auto doc3 = Doc("coll/c", 3, Map("foo", true));
    auto doc4 = Doc("coll/d", 3, Map("foo", true)).SetHasLocalMutations();

    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "foo", model::Segment::kAscending));

    AddDocuments({doc1, doc2});

    DocumentMap doc_map;
    doc_map = doc_map.insert(doc1.key(), doc1);
    doc_map = doc_map.insert(doc2.key(), doc2);
    index_manager_->UpdateIndexEntries(doc_map);
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc2));

    AddDocuments({doc3});
    AddMutation(SetMutation("coll/d", Map("foo", true)));

    core::Query query = Query("coll").AddingFilter(Filter("foo", "==", true));

    DocumentSet docs = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query, SnapshotVersion::None()); });
    EXPECT_EQ(docs, DocSet(query.Comparator(), {doc1, doc2, doc3, doc4}));
  });
}

TEST_F(LevelDbQueryEngineTest, UsesPartialIndexForLimitQueries) {
  persistence_->Run("UsesPartialIndexForLimitQueries", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", 0));
    auto doc2 = Doc("coll/2", 1, Map("a", 1, "b", 1));
    auto doc3 = Doc("coll/3", 1, Map("a", 1, "b", 2));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", 3));
    auto doc5 = Doc("coll/5", 1, Map("a", 2, "b", 3));
    AddDocuments({doc1, doc2, doc3, doc4, doc5});

    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));

    DocumentMap doc_map;
    doc_map = doc_map.insert(doc1.key(), doc1);
    doc_map = doc_map.insert(doc2.key(), doc2);
    index_manager_->UpdateIndexEntries(doc_map);
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc5));

    core::Query query = Query("coll")
                            .AddingFilter(Filter("a", "==", 1))
                            .AddingFilter(Filter("b", "==", 1))
                            .WithLimitToFirst(3);
    DocumentSet docs = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query, SnapshotVersion::None()); });
    EXPECT_EQ(docs, DocSet(query.Comparator(), {doc2}));
  });
}

TEST_F(LevelDbQueryEngineTest, RefillsIndexedLimitQueries) {
  persistence_->Run("RefillsIndexedLimitQueries", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1));
    auto doc2 = Doc("coll/2", 1, Map("a", 2));
    auto doc3 = Doc("coll/3", 1, Map("a", 3));
    auto doc4 = Doc("coll/4", 1, Map("a", 4));
    AddDocuments({doc1, doc2, doc3, doc4});

    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));

    DocumentMap doc_map;
    doc_map = doc_map.insert(doc1.key(), doc1);
    doc_map = doc_map.insert(doc2.key(), doc2);
    doc_map = doc_map.insert(doc3.key(), doc3);
    doc_map = doc_map.insert(doc4.key(), doc4);
    index_manager_->UpdateIndexEntries(doc_map);
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc4));

    AddMutation(PatchMutation("coll/3", Map("a", 5)));

    core::Query query =
        Query("coll").AddingOrderBy(OrderBy("a")).WithLimitToFirst(3);
    DocumentSet docs = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query, SnapshotVersion::None()); });
    EXPECT_EQ(docs, DocSet(query.Comparator(), {doc1, doc2, doc4}));
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
