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
#include "Firestore/core/src/model/mutable_document.h"
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

using model::DocumentSet;
using model::SnapshotVersion;
using testutil::AndFilters;
using testutil::Array;
using testutil::Doc;
using testutil::DocSet;
using testutil::Filter;
using testutil::MakeFieldIndex;
using testutil::Map;
using testutil::OrderBy;
using testutil::OrFilters;
using testutil::PatchMutation;
using testutil::Query;
using testutil::SetMutation;
using testutil::Version;

std::unique_ptr<Persistence> PersistenceFactory() {
  return LevelDbPersistenceForTesting();
}

model::DocumentMap DocumentMap(
    const std::vector<model::MutableDocument>& docs) {
  model::DocumentMap doc_map;
  for (const auto& doc : docs) {
    doc_map = doc_map.insert(doc.key(), doc);
  }
  return doc_map;
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
    index_manager_->UpdateIndexEntries(DocumentMap({doc1, doc2}));
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
    index_manager_->UpdateIndexEntries(DocumentMap({doc1, doc2}));
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
    index_manager_->UpdateIndexEntries(DocumentMap({doc1, doc2, doc3, doc4}));
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

TEST_F(LevelDbQueryEngineTest, CanPerformOrQueriesUsingIndexes1) {
  persistence_->Run("CanPerformOrQueriesUsingIndexes", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", 0));
    auto doc2 = Doc("coll/2", 1, Map("a", 2, "b", 1));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", 2));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", 3));
    auto doc5 = Doc("coll/5", 1, Map("a", 1, "b", 1));
    AddDocuments({doc1, doc2, doc3, doc4, doc5});

    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kDescending));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc5));

    // Two equalities: a==1 || b==1.
    core::Query query1 = Query("coll").AddingFilter(
        OrFilters({Filter("a", "==", 1), Filter("b", "==", 1)}));
    DocumentSet result1 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query1, SnapshotVersion::None()); });
    EXPECT_EQ(result1, DocSet(query1.Comparator(), {doc1, doc2, doc4, doc5}));

    // With one inequality: a>2 || b==1.
    core::Query query2 = Query("coll").AddingFilter(
        OrFilters({Filter("a", ">", 2), Filter("b", "==", 1)}));
    DocumentSet result2 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query2, SnapshotVersion::None()); });
    EXPECT_EQ(result2, DocSet(query2.Comparator(), {doc2, doc3, doc5}));

    // (a==1 && b==0) || (a==3 && b==2)
    core::Query query3 = Query("coll").AddingFilter(
        OrFilters({AndFilters({Filter("a", "==", 1), Filter("b", "==", 0)}),
                   AndFilters({Filter("a", "==", 3), Filter("b", "==", 2)})}));
    DocumentSet result3 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query3, SnapshotVersion::None()); });
    EXPECT_EQ(result3, DocSet(query3.Comparator(), {doc1, doc3}));

    // a==1 && (b==0 || b==3).
    core::Query query4 = Query("coll").AddingFilter(
        AndFilters({Filter("a", "==", 1),
                    OrFilters({Filter("b", "==", 0), Filter("b", "==", 3)})}));
    DocumentSet result4 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query4, SnapshotVersion::None()); });
    EXPECT_EQ(result4, DocSet(query4.Comparator(), {doc1, doc4}));

    // (a==2 || b==2) && (a==3 || b==3)
    core::Query query5 = Query("coll").AddingFilter(
        AndFilters({OrFilters({Filter("a", "==", 2), Filter("b", "==", 2)}),
                    OrFilters({Filter("a", "==", 3), Filter("b", "==", 3)})}));
    DocumentSet result5 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query5, SnapshotVersion::None()); });
    EXPECT_EQ(result5, DocSet(query5.Comparator(), {doc3}));
  });
}

TEST_F(LevelDbQueryEngineTest, CanPerformOrQueriesUsingIndexes2) {
  persistence_->Run("CanPerformOrQueriesUsingIndexes", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", 0));
    auto doc2 = Doc("coll/2", 1, Map("a", 2, "b", 1));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", 2));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", 3));
    auto doc5 = Doc("coll/5", 1, Map("a", 1, "b", 1));
    AddDocuments({doc1, doc2, doc3, doc4, doc5});

    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kDescending));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc5));

    // Test with limits (implicit order by ASC): (a==1) || (b > 0) LIMIT 2
    core::Query query6 = Query("coll")
                             .AddingFilter(OrFilters(
                                 {Filter("a", "==", 1), Filter("b", ">", 0)}))
                             .WithLimitToFirst(2);
    DocumentSet result6 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query6, SnapshotVersion::None()); });
    EXPECT_EQ(result6, DocSet(query6.Comparator(), {doc1, doc2}));

    // Test with limits (implicit order by DESC): (a==1) || (b > 0)
    // LIMIT_TO_LAST 2
    core::Query query7 = Query("coll")
                             .AddingFilter(OrFilters(
                                 {Filter("a", "==", 1), Filter("b", ">", 0)}))
                             .WithLimitToLast(2);
    DocumentSet result7 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query7, SnapshotVersion::None()); });
    EXPECT_EQ(result7, DocSet(query7.Comparator(), {doc3, doc4}));

    // Test with limits (explicit order by ASC): (a==2) || (b == 1) ORDER BY a
    // LIMIT 1
    core::Query query8 = Query("coll")
                             .AddingFilter(OrFilters(
                                 {Filter("a", "==", 2), Filter("b", "==", 1)}))
                             .WithLimitToFirst(1)
                             .AddingOrderBy(OrderBy("a", "asc"));
    DocumentSet result8 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query8, SnapshotVersion::None()); });
    EXPECT_EQ(result8, DocSet(query8.Comparator(), {doc5}));

    // Test with limits (explicit order by DESC): (a==2) || (b == 1) ORDER BY a
    // LIMIT_TO_LAST 1
    core::Query query9 = Query("coll")
                             .AddingFilter(OrFilters(
                                 {Filter("a", "==", 2), Filter("b", "==", 1)}))
                             .WithLimitToLast(1)
                             .AddingOrderBy(OrderBy("a", "asc"));
    DocumentSet result9 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query9, SnapshotVersion::None()); });
    EXPECT_EQ(result9, DocSet(query9.Comparator(), {doc2}));

    // Test with limits without orderBy (the __name__ ordering is the tie
    // breaker).
    core::Query query10 = Query("coll")
                              .AddingFilter(OrFilters(
                                  {Filter("a", "==", 2), Filter("b", "==", 1)}))
                              .WithLimitToFirst(1);
    DocumentSet result10 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query10, SnapshotVersion::None()); });
    EXPECT_EQ(result10, DocSet(query10.Comparator(), {doc2}));
  });
}

TEST_F(LevelDbQueryEngineTest, OrQueryWithInAndNotInUsingIndexes) {
  persistence_->Run("OrQueryWithInAndNotInUsingIndexes", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", 0));
    auto doc2 = Doc("coll/2", 1, Map("b", 1));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", 2));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", 3));
    auto doc5 = Doc("coll/5", 1, Map("a", 1));
    auto doc6 = Doc("coll/6", 1, Map("a", 2));
    AddDocuments({doc1, doc2, doc3, doc4, doc5, doc6});
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kDescending));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5, doc6}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc6));

    // Two equalities: a==1 || b==1.
    auto query1 = testutil::Query("coll").AddingFilter(
        OrFilters({Filter("a", "==", 2), Filter("b", "in", Array(2, 3))}));
    DocumentSet result1 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query1, SnapshotVersion::None()); });
    EXPECT_EQ(result1, DocSet(query1.Comparator(), {doc3, doc4, doc6}));

    // a==2 || (b != 2 && b != 3)
    // Has implicit "orderBy b"
    auto query2 = testutil::Query("coll").AddingFilter(
        OrFilters({Filter("a", "==", 2), Filter("b", "not-in", Array(2, 3))}));
    DocumentSet result2 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query2, SnapshotVersion::None()); });
    EXPECT_EQ(result2, DocSet(query2.Comparator(), {doc1, doc2}));
  });
}

TEST_F(LevelDbQueryEngineTest, OrQueryWithArrayMembershipUsingIndexes) {
  persistence_->Run("OrQueryWithArrayMembershipUsingIndexes", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", Array(0)));
    auto doc2 = Doc("coll/2", 1, Map("b", Array(1)));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", Array(2, 7)));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", Array(3, 7)));
    auto doc5 = Doc("coll/5", 1, Map("a", 1));
    auto doc6 = Doc("coll/6", 1, Map("a", 2));
    AddDocuments({doc1, doc2, doc3, doc4, doc5, doc6});
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kContains));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5, doc6}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc6));

    auto query1 = testutil::Query("coll").AddingFilter(
        OrFilters({Filter("a", "==", 2), Filter("b", "array-contains", 7)}));
    DocumentSet result1 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query1, SnapshotVersion::None()); });
    EXPECT_EQ(result1, DocSet(query1.Comparator(), {doc3, doc4, doc6}));

    auto query2 = testutil::Query("coll").AddingFilter(
        OrFilters({Filter("a", "==", 2),
                   Filter("b", "array-contains-any", Array(0, 3))}));
    DocumentSet result2 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query2, SnapshotVersion::None()); });
    EXPECT_EQ(result2, DocSet(query2.Comparator(), {doc1, doc4, doc6}));
  });
}

TEST_F(LevelDbQueryEngineTest, QueryWithMultipleInsOnTheSameField) {
  persistence_->Run("QueryWithMultipleInsOnTheSameField", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", 0));
    auto doc2 = Doc("coll/2", 1, Map("b", 1));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", 2));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", 3));
    auto doc5 = Doc("coll/5", 1, Map("a", 1));
    auto doc6 = Doc("coll/6", 1, Map("a", 2));
    AddDocuments({doc1, doc2, doc3, doc4, doc5, doc6});
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kDescending));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5, doc6}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc6));

    // a IN [1,2,3] && a IN [0,1,4] should result in "a==1".
    auto query1 = testutil::Query("coll").AddingFilter(
        AndFilters({Filter("a", "in", Array(1, 2, 3)),
                    Filter("a", "in", Array(0, 1, 4))}));
    DocumentSet result1 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query1, SnapshotVersion::None()); });
    EXPECT_EQ(result1, DocSet(query1.Comparator(), {doc1, doc4, doc5}));

    // a IN [2,3] && a IN [0,1,4] is never true and so the result should be an
    // empty set.
    auto query2 = testutil::Query("coll").AddingFilter(AndFilters(
        {Filter("a", "in", Array(2, 3)), Filter("a", "in", Array(0, 1, 4))}));
    DocumentSet result2 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query2, SnapshotVersion::None()); });
    EXPECT_EQ(result2, DocSet(query2.Comparator(), {}));

    // a IN [0,3] || a IN [0,2] should union them (similar to: a IN [0,2,3]).
    auto query3 = testutil::Query("coll").AddingFilter(OrFilters(
        {Filter("a", "in", Array(0, 3)), Filter("a", "in", Array(0, 2))}));
    DocumentSet result3 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query3, SnapshotVersion::None()); });
    EXPECT_EQ(result3, DocSet(query3.Comparator(), {doc3, doc6}));

    // Nested composite filter: (a IN [0,1,2,3] && (a IN [0,2] || (b>1 && a IN
    // [1,3]))
    auto query4 = testutil::Query("coll").AddingFilter(AndFilters(
        {Filter("a", "in", Array(0, 1, 2, 3)),
         OrFilters({Filter("a", "in", Array(0, 2)),
                    AndFilters({Filter("b", ">=", 1),
                                Filter("a", "in", Array(1, 3))})})}));
    DocumentSet result4 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query4, SnapshotVersion::None()); });
    EXPECT_EQ(result4, DocSet(query4.Comparator(), {doc3, doc4}));
  });
}

TEST_F(LevelDbQueryEngineTest, QueryWithMultipleInsOnDifferentFields) {
  persistence_->Run("QueryWithMultipleInsOnDifferentFields", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", 0));
    auto doc2 = Doc("coll/2", 1, Map("b", 1));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", 2));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", 3));
    auto doc5 = Doc("coll/5", 1, Map("a", 1));
    auto doc6 = Doc("coll/6", 1, Map("a", 2));
    AddDocuments({doc1, doc2, doc3, doc4, doc5, doc6});
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kDescending));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5, doc6}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc6));

    auto query1 = testutil::Query("coll").AddingFilter(OrFilters(
        {Filter("a", "in", Array(2, 3)), Filter("b", "in", Array(0, 2))}));
    DocumentSet result1 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query1, SnapshotVersion::None()); });
    EXPECT_EQ(result1, DocSet(query1.Comparator(), {doc1, doc3, doc6}));

    auto query2 = testutil::Query("coll").AddingFilter(AndFilters(
        {Filter("a", "in", Array(2, 3)), Filter("b", "in", Array(0, 2))}));
    DocumentSet result2 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query2, SnapshotVersion::None()); });
    EXPECT_EQ(result2, DocSet(query2.Comparator(), {doc3}));

    // Nested composite filter: (b in [0,3] && (b IN [1] || (b in [2,3] && a IN
    // [1,3]))
    auto query3 = testutil::Query("coll").AddingFilter(AndFilters(
        {Filter("b", "in", Array(0, 3)),
         OrFilters({Filter("b", "in", Array(1)),
                    AndFilters({Filter("b", "in", Array(2, 3)),
                                Filter("a", "in", Array(1, 3))})})}));
    DocumentSet result3 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query3, SnapshotVersion::None()); });
    EXPECT_EQ(result3, DocSet(query3.Comparator(), {doc4}));
  });
}

TEST_F(LevelDbQueryEngineTest, QueryInWithArrayContainsAny) {
  persistence_->Run("QueryInWithArrayContainsAny", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", Array(0)));
    auto doc2 = Doc("coll/2", 1, Map("b", Array(1)));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", Array(2, 7), "c", 10));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", Array(3, 7)));
    auto doc5 = Doc("coll/5", 1, Map("a", 1));
    auto doc6 = Doc("coll/6", 1, Map("a", 2, "c", 20));
    AddDocuments({doc1, doc2, doc3, doc4, doc5, doc6});
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kContains));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5, doc6}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc6));

    auto query1 = testutil::Query("coll").AddingFilter(
        OrFilters({Filter("a", "in", Array(2, 3)),
                   Filter("b", "array-contains-any", Array(0, 7))}));
    DocumentSet result1 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query1, SnapshotVersion::None()); });
    EXPECT_EQ(result1, DocSet(query1.Comparator(), {doc1, doc3, doc4, doc6}));

    auto query2 = testutil::Query("coll").AddingFilter(
        AndFilters({Filter("a", "in", Array(2, 3)),
                    Filter("b", "array-contains-any", Array(0, 7))}));
    DocumentSet result2 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query2, SnapshotVersion::None()); });
    EXPECT_EQ(result2, DocSet(query2.Comparator(), {doc3}));

    auto query3 = testutil::Query("coll").AddingFilter(OrFilters(
        {AndFilters({Filter("a", "in", Array(2, 3)), Filter("c", "==", 10)}),
         Filter("b", "array-contains-any", Array(0, 7))}));
    DocumentSet result3 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query3, SnapshotVersion::None()); });
    EXPECT_EQ(result3, DocSet(query3.Comparator(), {doc1, doc3, doc4}));

    auto query4 = testutil::Query("coll").AddingFilter(
        AndFilters({Filter("a", "in", Array(2, 3)),
                    OrFilters({Filter("b", "array-contains-any", Array(0, 7)),
                               Filter("c", "==", 20)})}));
    DocumentSet result4 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query4, SnapshotVersion::None()); });
    EXPECT_EQ(result4, DocSet(query4.Comparator(), {doc3, doc6}));
  });
}

TEST_F(LevelDbQueryEngineTest, QueryInWithArrayContains) {
  persistence_->Run("QueryInWithArrayContains", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", Array(0)));
    auto doc2 = Doc("coll/2", 1, Map("b", Array(1)));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", Array(2, 7), "c", 10));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", Array(3, 7)));
    auto doc5 = Doc("coll/5", 1, Map("a", 1));
    auto doc6 = Doc("coll/6", 1, Map("a", 2, "c", 20));
    AddDocuments({doc1, doc2, doc3, doc4, doc5, doc6});
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kContains));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5, doc6}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc6));

    auto query1 = testutil::Query("coll").AddingFilter(OrFilters(
        {Filter("a", "in", Array(2, 3)), Filter("b", "array-contains", 3)}));
    DocumentSet result1 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query1, SnapshotVersion::None()); });
    EXPECT_EQ(result1, DocSet(query1.Comparator(), {doc3, doc4, doc6}));

    auto query2 = testutil::Query("coll").AddingFilter(AndFilters(
        {Filter("a", "in", Array(2, 3)), Filter("b", "array-contains", 7)}));
    DocumentSet result2 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query2, SnapshotVersion::None()); });
    EXPECT_EQ(result2, DocSet(query2.Comparator(), {doc3}));

    auto query3 = testutil::Query("coll").AddingFilter(
        OrFilters({Filter("a", "in", Array(2, 3)),
                   AndFilters({Filter("b", "array-contains", 3),
                               Filter("a", "==", 1)})}));
    DocumentSet result3 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query3, SnapshotVersion::None()); });
    EXPECT_EQ(result3, DocSet(query3.Comparator(), {doc3, doc4, doc6}));

    auto query4 = testutil::Query("coll").AddingFilter(AndFilters(
        {Filter("a", "in", Array(2, 3)),
         OrFilters({Filter("b", "array-contains", 7), Filter("a", "==", 1)})}));
    DocumentSet result4 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query4, SnapshotVersion::None()); });
    EXPECT_EQ(result4, DocSet(query4.Comparator(), {doc3}));
  });
}

TEST_F(LevelDbQueryEngineTest, OrderByEquality) {
  persistence_->Run("OrderByEquality", [&] {
    mutation_queue_->Start();
    index_manager_->Start();

    auto doc1 = Doc("coll/1", 1, Map("a", 1, "b", Array(0)));
    auto doc2 = Doc("coll/2", 1, Map("b", Array(1)));
    auto doc3 = Doc("coll/3", 1, Map("a", 3, "b", Array(2, 7), "c", 10));
    auto doc4 = Doc("coll/4", 1, Map("a", 1, "b", Array(3, 7)));
    auto doc5 = Doc("coll/5", 1, Map("a", 1));
    auto doc6 = Doc("coll/6", 1, Map("a", 2, "c", 20));
    AddDocuments({doc1, doc2, doc3, doc4, doc5, doc6});
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kAscending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "a", model::Segment::kDescending));
    index_manager_->AddFieldIndex(
        MakeFieldIndex("coll", "b", model::Segment::kContains));
    index_manager_->UpdateIndexEntries(
        DocumentMap({doc1, doc2, doc3, doc4, doc5, doc6}));
    index_manager_->UpdateCollectionGroup(
        "coll", model::IndexOffset::FromDocument(doc6));

    auto query1 = testutil::Query("coll")
                      .AddingFilter(Filter("a", "==", 1))
                      .AddingOrderBy(OrderBy("a"));
    DocumentSet result1 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query1, SnapshotVersion::None()); });
    EXPECT_EQ(result1, DocSet(query1.Comparator(), {doc1, doc4, doc5}));

    auto query2 = testutil::Query("coll")
                      .AddingFilter(Filter("a", "in", Array(2, 3)))
                      .AddingOrderBy(OrderBy("a"));
    DocumentSet result2 = ExpectOptimizedCollectionScan(
        [&] { return RunQuery(query2, SnapshotVersion::None()); });
    EXPECT_EQ(result2, DocSet(query2.Comparator(), {doc6, doc3}));
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
