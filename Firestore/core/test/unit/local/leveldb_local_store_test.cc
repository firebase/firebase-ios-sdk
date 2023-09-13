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

#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/model/delete_mutation.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/model/set_mutation.h"
#include "Firestore/core/src/remote/remote_event.h"
#include "Firestore/core/test/unit/local/local_store_test.h"
#include "Firestore/core/test/unit/local/persistence_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using model::DocumentKey;
using model::FieldIndex;
using model::IndexState;

using testutil::AddedRemoteEvent;
using testutil::Array;
using testutil::DeletedDoc;
using testutil::DeleteMutation;
using testutil::Doc;
using testutil::Field;
using testutil::Filter;
using testutil::Key;
using testutil::MakeFieldIndex;
using testutil::Map;
using testutil::OrderBy;
using testutil::OrFilters;
using testutil::OverlayTypeMap;
using testutil::SetMutation;
using testutil::UpdateRemoteEvent;
using testutil::Vector;
using testutil::Version;

class TestHelper : public LocalStoreTestHelper {
 public:
  std::unique_ptr<Persistence> MakePersistence() override {
    return LevelDbPersistenceForTesting();
  }

  /** Returns true if the garbage collector is eager, false if LRU. */
  bool IsGcEager() const override {
    return false;
  }
};

std::unique_ptr<LocalStoreTestHelper> Factory() {
  return absl::make_unique<TestHelper>();
}

// This lambda function takes a rvalue vector as parameter,
// then coverts it to a sorted set based on the compare function.
auto convertToSet = [](std::vector<FieldIndex>&& vec) {
  std::set<FieldIndex, FieldIndex::SemanticLess> result;
  for (auto& index : vec) {
    result.insert(std::move(index));
  }
  return result;
};

}  // namespace

INSTANTIATE_TEST_SUITE_P(LevelDbLocalStoreTest,
                         LocalStoreTest,
                         ::testing::Values(Factory));

class LevelDbLocalStoreTest : public LocalStoreTestBase {
 public:
  LevelDbLocalStoreTest()
      : LocalStoreTestBase(Factory()),
        max_operation_per_transaction_(
            LevelDbPersistence::kMaxOperationPerTransaction) {
  }

  const size_t max_operation_per_transaction_;
};

TEST_F(LevelDbLocalStoreTest, AddsIndexes) {
  FieldIndex index_a = MakeFieldIndex("coll", 0, FieldIndex::InitialState(),
                                      "a", model::Segment::Kind::kAscending);
  FieldIndex index_b = MakeFieldIndex("coll", 1, FieldIndex::InitialState(),
                                      "b", model::Segment::Kind::kDescending);
  FieldIndex index_c =
      FieldIndex{2,
                 "coll",
                 {model::Segment{Field("c1"), model::Segment::Kind::kAscending},
                  model::Segment{Field("c2"), model::Segment::Kind::kContains}},
                 model::FieldIndex::InitialState()};

  ConfigureFieldIndexes({index_a, index_b});
  ASSERT_EQ(convertToSet(GetFieldIndexes()),
            convertToSet({FieldIndex(index_a), FieldIndex(index_b)}));

  ConfigureFieldIndexes({index_a, index_c});
  ASSERT_EQ(convertToSet(GetFieldIndexes()),
            convertToSet({FieldIndex(index_a), FieldIndex(index_c)}));
}

TEST_F(LevelDbLocalStoreTest, RemovesIndexes) {
  FieldIndex index_a = MakeFieldIndex("coll", 0, FieldIndex::InitialState(),
                                      "a", model::Segment::Kind::kAscending);
  FieldIndex index_b = MakeFieldIndex("coll", 1, FieldIndex::InitialState(),
                                      "b", model::Segment::Kind::kDescending);

  ConfigureFieldIndexes({index_a, index_b});
  ASSERT_EQ(convertToSet(GetFieldIndexes()),
            convertToSet({FieldIndex(index_b), FieldIndex(index_a)}));

  ConfigureFieldIndexes({index_a});
  ASSERT_EQ(convertToSet(GetFieldIndexes()),
            convertToSet({FieldIndex(index_a)}));
}

TEST_F(LevelDbLocalStoreTest, DoesNotResetIndexWhenSameIndexIsAdded) {
  FieldIndex index_a = MakeFieldIndex("coll", 0, FieldIndex::InitialState(),
                                      "a", model::Segment::Kind::kAscending);

  ConfigureFieldIndexes({index_a});
  ASSERT_EQ(convertToSet(GetFieldIndexes()),
            convertToSet({FieldIndex(index_a)}));

  core::Query query = testutil::Query("foo").AddingFilter(Filter("a", "==", 1));
  int target_id = AllocateQuery(query);
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("a", 1)), {target_id}));

  BackfillIndexes();
  FieldIndex updated_index_a =
      MakeFieldIndex("coll", 0, IndexState(1, Version(10), Key("coll/a"), -1),
                     "a", model::Segment::Kind::kAscending);

  ASSERT_EQ(convertToSet(GetFieldIndexes()),
            convertToSet({FieldIndex(updated_index_a)}));

  // Re-add the same index. We do not reset the index to its initial state.
  ConfigureFieldIndexes({index_a});
  ASSERT_EQ(convertToSet(GetFieldIndexes()),
            convertToSet({FieldIndex(updated_index_a)}));
}

TEST_F(LevelDbLocalStoreTest, DeletedDocumentRemovesIndex) {
  FieldIndex index =
      MakeFieldIndex("coll", 0, FieldIndex::InitialState(), "matches",
                     model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("matches", "==", true));
  int target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("matches", true)), {target_id}));

  // Add the document to the index
  BackfillIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 1, /* byCollection= */ 0);
  FSTAssertQueryReturned("coll/a");

  ApplyRemoteEvent(UpdateRemoteEvent(DeletedDoc("coll/a", 0), {target_id}, {}));

  // No backfill needed for deleted document.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 0);
  FSTAssertQueryReturned();
}

TEST_F(LevelDbLocalStoreTest, UsesIndexes) {
  FieldIndex index =
      MakeFieldIndex("coll", 0, FieldIndex::InitialState(), "matches",
                     model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("matches", "==", true));
  int target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("matches", true)), {target_id}));

  BackfillIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 1, /* byCollection= */ 0);
  FSTAssertQueryReturned("coll/a");
}

TEST_F(LevelDbLocalStoreTest,
       UsesPartiallyIndexedRemoteDocumentsWhenAvailable) {
  FieldIndex index =
      MakeFieldIndex("coll", 0, FieldIndex::InitialState(), "matches",
                     model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("matches", "==", true));
  int target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("matches", true)), {target_id}));

  BackfillIndexes();

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/b", 20, Map("matches", true)), {target_id}));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 1, /* byCollection= */ 1);
  FSTAssertQueryReturned("coll/a", "coll/b");
}

TEST_F(LevelDbLocalStoreTest, UsesPartiallyIndexedOverlaysWhenAvailable) {
  FieldIndex index =
      MakeFieldIndex("coll", 0, FieldIndex::InitialState(), "matches",
                     model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  WriteMutation(SetMutation("coll/a", Map("matches", true)));
  BackfillIndexes();

  WriteMutation(SetMutation("coll/b", Map("matches", true)));

  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("matches", "==", true));
  ExecuteQuery(query);
  FSTAssertOverlaysRead(/* byKey= */ 1, /* byCollection= */ 1);
  FSTAssertOverlayTypes(
      OverlayTypeMap({{Key("coll/a"), model::Mutation::Type::Set},
                      {Key("coll/b"), model::Mutation::Type::Set}}));

  FSTAssertQueryReturned("coll/a", "coll/b");
}

TEST_F(LevelDbLocalStoreTest, DoesNotUseLimitWhenIndexIsOutdated) {
  FieldIndex index = MakeFieldIndex("coll", 0, FieldIndex::InitialState(),
                                    "count", model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  core::Query query = testutil::Query("coll")
                          .AddingOrderBy(OrderBy("count"))
                          .WithLimitToFirst(2);
  int target_id = AllocateQuery(query);

  ApplyRemoteEvent(AddedRemoteEvent(
      {Doc("coll/a", 10, Map("count", 1)), Doc("coll/b", 10, Map("count", 2)),
       Doc("coll/c", 10, Map("count", 3))},
      {target_id}));
  BackfillIndexes();

  WriteMutation(DeleteMutation("coll/b"));

  ExecuteQuery(query);

  // The query engine first reads the documents by key and then re-runs the
  // query without limit.
  FSTAssertRemoteDocumentsRead(/* byKey= */ 5, /* byCollection= */ 0);
  FSTAssertOverlaysRead(/* byKey= */ 5, /* byCollection= */ 1);
  FSTAssertOverlayTypes(
      OverlayTypeMap({{Key("coll/b"), model::Mutation::Type::Delete}}));

  FSTAssertQueryReturned("coll/a", "coll/c");
}

TEST_F(LevelDbLocalStoreTest, UsesIndexForLimitQueryWhenIndexIsUpdated) {
  FieldIndex index = MakeFieldIndex("coll", 0, FieldIndex::InitialState(),
                                    "count", model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  core::Query query = testutil::Query("coll")
                          .AddingOrderBy(OrderBy("count"))
                          .WithLimitToFirst(2);
  int target_id = AllocateQuery(query);

  ApplyRemoteEvent(AddedRemoteEvent(
      {Doc("coll/a", 10, Map("count", 1)), Doc("coll/b", 10, Map("count", 2)),
       Doc("coll/c", 10, Map("count", 3))},
      {target_id}));

  WriteMutation(DeleteMutation("coll/b"));
  BackfillIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 2, /* byCollection= */ 0);
  FSTAssertOverlaysRead(/* byKey= */ 2, /* byCollection= */ 0);
  FSTAssertOverlayTypes(OverlayTypeMap({}));

  FSTAssertQueryReturned("coll/a", "coll/c");
}

TEST_F(LevelDbLocalStoreTest, IndexesServerTimestamps) {
  FieldIndex index = MakeFieldIndex("coll", 0, FieldIndex::InitialState(),
                                    "time", model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  WriteMutation(
      SetMutation("coll/a", Map(), {testutil::ServerTimestamp("time")}));
  BackfillIndexes();

  core::Query query =
      testutil::Query("coll").AddingOrderBy(OrderBy("time", "asc"));

  ExecuteQuery(query);
  FSTAssertOverlaysRead(/* byKey= */ 1, /* byCollection= */ 0);
  FSTAssertOverlayTypes(
      OverlayTypeMap({{Key("coll/a"), model::Mutation::Type::Set}}));

  FSTAssertQueryReturned("coll/a");
}

TEST_F(LevelDbLocalStoreTest, CanAutoCreateIndexes) {
  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("matches", "==", true));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("matches", true)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/b", 10, Map("matches", false)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/c", 10, Map("matches", false)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/d", 10, Map("matches", false)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/e", 10, Map("matches", true)), {target_id}));

  // First time query runs without indexes.
  // Based on current heuristic, collection document counts (5) > 2 * resultSize
  // (2). Full matched index should be created.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  BackfillIndexes();

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/f", 20, Map("matches", true)), {target_id}));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 2, /* byCollection= */ 1);
  FSTAssertQueryReturned("coll/a", "coll/e", "coll/f");
}

TEST_F(LevelDbLocalStoreTest, CanAutoCreateIndexesWorksWithOrQuery) {
  core::Query query = testutil::Query("coll").AddingFilter(
      OrFilters({Filter("a", "==", 3), Filter("b", "==", true)}));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("b", true)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/b", 10, Map("b", false)), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(Doc("coll/c", 10, Map("a", 5, "b", false)),
                                    {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/d", 10, Map("a", true)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/e", 10, Map("a", 3, "b", true)), {target_id}));

  // First time query runs without indexes.
  // Based on current heuristic, collection document counts (5) > 2 * resultSize
  // (2). Full matched index should be created.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  BackfillIndexes();

  ApplyRemoteEvent(AddedRemoteEvent(Doc("coll/f", 20, Map("a", 3, "b", false)),
                                    {target_id}));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 2, /* byCollection= */ 1);
  FSTAssertQueryReturned("coll/a", "coll/e", "coll/f");
}

TEST_F(LevelDbLocalStoreTest, DoesNotAutoCreateIndexesForSmallCollections) {
  core::Query query = testutil::Query("coll")
                          .AddingFilter(Filter("foo", "==", 9))
                          .AddingFilter(Filter("count", ">=", 3));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/a", 10, Map("foo", 9, "count", 5)), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/b", 10, Map("foo", 8, "count", 1)), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/c", 10, Map("foo", 9, "count", 0)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/d", 10, Map("count", 4)), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/e", 10, Map("foo", 9, "count", 3)), {target_id}));

  // SDK will not create indexes since collection size is too small.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  BackfillIndexes();

  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/f", 20, Map("foo", 9, "count", 15)), {target_id}));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 3);
  FSTAssertQueryReturned("coll/a", "coll/e", "coll/f");
}

TEST_F(LevelDbLocalStoreTest,
       DoesNotAutoCreateIndexesWhenIndexLookUpIsExpensive) {
  core::Query query = testutil::Query("coll").AddingFilter(
      Filter("array", "array-contains-any", Array(0, 7)));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(5);

  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/a", 10, Map("array", Array(2, 7))), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/b", 10, Map("array", Array())), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/c", 10, Map("array", Array(3))), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/d", 10, Map("array", Array(2, 10, 20))), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/e", 10, Map("array", Array(2, 0, 8))), {target_id}));

  // First time query runs without indexes.
  // Based on current heuristic, collection document counts (5) > 2 * resultSize
  // (2). Full matched index should be created.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  BackfillIndexes();

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/f", 20, Map("array", Array(0))), {target_id}));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 3);
  FSTAssertQueryReturned("coll/a", "coll/e", "coll/f");
}

TEST_F(LevelDbLocalStoreTest, IndexAutoCreationWorksWhenBackfillerRunsHalfway) {
  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("matches", "==", "foo"));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("matches", "foo")), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/b", 10, Map("matches", "")), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/c", 10, Map("matches", "bar")), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/d", 10, Map("matches", 7)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/e", 10, Map("matches", "foo")), {target_id}));

  // First time query is running without indexes.
  // Based on current heuristic, collection document counts (5) > 2 * resultSize
  // (2). Full matched index should be created.
  ExecuteQuery(query);
  // Only document a matches the result
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  SetBackfillerMaxDocumentsToProcess(2);
  BackfillIndexes();

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/f", 20, Map("matches", "foo")), {target_id}));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 1, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e", "coll/f");
}

TEST_F(LevelDbLocalStoreTest,
       IndexCreatedByIndexAutoCreationExistsAfterTurnOffAutoCreation) {
  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("value", "not-in", Array(3)));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("value", 5)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/b", 10, Map("value", 3)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/c", 10, Map("value", 3)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/d", 10, Map("value", 3)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/e", 10, Map("value", 2)), {target_id}));

  // First time query runs without indexes.
  // Based on current heuristic, collection document counts (5) > 2 * resultSize
  // (2). Full matched index should be created.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  SetIndexAutoCreationEnabled(false);

  BackfillIndexes();

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/f", 20, Map("value", 7)), {target_id}));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 2, /* byCollection= */ 1);
  FSTAssertQueryReturned("coll/a", "coll/e", "coll/f");
}

TEST_F(LevelDbLocalStoreTest, DisableIndexAutoCreationWorks) {
  core::Query query1 =
      testutil::Query("coll").AddingFilter(Filter("value", "in", Array(0, 1)));
  int target_id1 = AllocateQuery(query1);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("value", 1)), {target_id1}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/b", 10, Map("value", 8)), {target_id1}));
  ApplyRemoteEvent(AddedRemoteEvent(Doc("coll/c", 10, Map("value", "string")),
                                    {target_id1}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/d", 10, Map("value", false)), {target_id1}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/e", 10, Map("value", 0)), {target_id1}));

  // First time query is running without indexes.
  // Based on current heuristic, collection document counts (5) > 2 * resultSize
  // (2). Full matched index should be created.
  ExecuteQuery(query1);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  SetIndexAutoCreationEnabled(false);

  BackfillIndexes();

  ExecuteQuery(query1);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 2, /* byCollection= */ 0);
  FSTAssertQueryReturned("coll/a", "coll/e");

  core::Query query2 = testutil::Query("foo").AddingFilter(
      Filter("value", "!=", std::numeric_limits<double>::quiet_NaN()));
  int target_id2 = AllocateQuery(query2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/a", 10, Map("value", 5)), {target_id2}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("foo/b", 10, Map("value", std::numeric_limits<double>::quiet_NaN())),
      {target_id2}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("foo/c", 10, Map("value", std::numeric_limits<double>::quiet_NaN())),
      {target_id2}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("foo/d", 10, Map("value", std::numeric_limits<double>::quiet_NaN())),
      {target_id2}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("foo/e", 10, Map("value", "string")), {target_id2}));

  ExecuteQuery(query2);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("foo/a", "foo/e");

  BackfillIndexes();

  // Run the query in second time, test index won't be created
  ExecuteQuery(query2);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("foo/a", "foo/e");
}

TEST_F(LevelDbLocalStoreTest, DeleteAllIndexesWorksWithIndexAutoCreation) {
  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("value", "==", "match"));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("value", "match")), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/b", 10, Map("value", std::numeric_limits<double>::quiet_NaN())),
      {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/c", 10, Map("value", nullptr)), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(Doc("coll/d", 10, Map("value", "mismatch")),
                                    {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/e", 10, Map("value", "match")), {target_id}));

  // First time query is running without indexes.
  // Based on current heuristic, collection document counts (5) > 2 * resultSize
  // (2). Full matched index should be created.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  BackfillIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 2, /* byCollection= */ 0);
  FSTAssertQueryReturned("coll/a", "coll/e");

  DeleteAllIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  // Field index is created again.
  BackfillIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 2, /* byCollection= */ 0);
  FSTAssertQueryReturned("coll/a", "coll/e");
}

TEST_F(LevelDbLocalStoreTest, DeleteAllIndexesWorksWithManualAddedIndexes) {
  FieldIndex index =
      MakeFieldIndex("coll", 0, FieldIndex::InitialState(), "matches",
                     model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("matches", "==", true));
  int target_id = AllocateQuery(query);

  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/a", 10, Map("matches", true)), {target_id}));

  BackfillIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 1, /* byCollection= */ 0);
  FSTAssertQueryReturned("coll/a");

  DeleteAllIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 1);
  FSTAssertQueryReturned("coll/a");
}

TEST_F(LevelDbLocalStoreTest,
       DeleteAllIndexesWorksWhenMoreThanOneTransactionRequiredToCompleteTask) {
  FieldIndex index =
      MakeFieldIndex("coll", 0, FieldIndex::InitialState(), "matches",
                     model::Segment::Kind::kAscending);
  ConfigureFieldIndexes({index});

  core::Query query =
      testutil::Query("coll").AddingFilter(Filter("matches", "==", true));
  int target_id = AllocateQuery(query);

  // requires at least 2 transactions
  const size_t num_of_documents = max_operation_per_transaction_ * 1.5;

  for (size_t count = 1; count <= num_of_documents; count++) {
    ApplyRemoteEvent(AddedRemoteEvent(
        Doc("coll/" + std::to_string(count), 10, Map("matches", true)),
        {target_id}));
  }

  SetBackfillerMaxDocumentsToProcess(num_of_documents);
  BackfillIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ num_of_documents,
                               /* byCollection= */ 0);

  DeleteAllIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0,
                               /* byCollection= */ num_of_documents);
}

TEST_F(LevelDbLocalStoreTest, IndexAutoCreationWorksWithMutation) {
  core::Query query = testutil::Query("coll").AddingFilter(
      Filter("value", "array-contains-any", Array(8, 1, "string")));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/a", 10, Map("value", Array(8, 1, "string"))), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/b", 10, Map("value", Array())), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/c", 10, Map("value", Array(3))), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/d", 10, Map("value", Array(0, 5))), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/e", 10, Map("value", Array("string"))), {target_id}));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  WriteMutation(DeleteMutation("coll/e"));

  BackfillIndexes();

  WriteMutation(SetMutation("coll/f", Map("value", Array(1))));

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 1, /* byCollection= */ 0);
  FSTAssertOverlaysRead(/* byKey= */ 1, /* byCollection= */ 1);
  FSTAssertQueryReturned("coll/a", "coll/f");
}

TEST_F(LevelDbLocalStoreTest,
       IndexAutoCreationDoesnotWorkWithMultipleInequality) {
  core::Query query = testutil::Query("coll")
                          .AddingFilter(Filter("field1", "<", 5))
                          .AddingFilter(Filter("field2", "<", 5));
  int target_id = AllocateQuery(query);

  SetIndexAutoCreationEnabled(true);
  SetMinCollectionSizeToAutoCreateIndex(0);
  SetRelativeIndexReadCostPerDocument(2);

  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/a", 10, Map("field1", 1, "field2", 2)), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/b", 10, Map("field1", 8, "field2", 2)), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/c", 10, Map("field1", "string", "field2", 2)), {target_id}));
  ApplyRemoteEvent(
      AddedRemoteEvent(Doc("coll/d", 10, Map("field1", 2)), {target_id}));
  ApplyRemoteEvent(AddedRemoteEvent(
      Doc("coll/e", 10, Map("field1", 4, "field2", 4)), {target_id}));

  // First time query is running without indexes.
  // Based on current heuristic, collection document counts (5) > 2 * resultSize
  // (2). Full matched index will not be created since FieldIndex does not
  // support multiple inequality.
  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");

  BackfillIndexes();

  ExecuteQuery(query);
  FSTAssertRemoteDocumentsRead(/* byKey= */ 0, /* byCollection= */ 2);
  FSTAssertQueryReturned("coll/a", "coll/e");
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
