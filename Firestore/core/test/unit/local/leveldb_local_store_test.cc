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
using testutil::DeletedDoc;
using testutil::DeleteMutation;
using testutil::Doc;
using testutil::Field;
using testutil::Filter;
using testutil::Key;
using testutil::MakeFieldIndex;
using testutil::Map;
using testutil::OrderBy;
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
  auto cmp = [](const FieldIndex& left, const FieldIndex& right) {
    return FieldIndex::SemanticCompare(left, right) ==
           util::ComparisonResult::Ascending;
  };

  std::set<FieldIndex, decltype(cmp)> result(cmp);
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
  LevelDbLocalStoreTest() : LocalStoreTestBase(Factory()) {
  }
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
  FSTAssertQueryReturned("coll/a");
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
