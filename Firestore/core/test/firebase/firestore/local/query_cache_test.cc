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

#include "Firestore/core/test/firebase/firestore/local/query_cache_test.h"

#include <set>
#include <utility>

#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/local/query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::DocumentKey;
using model::DocumentKeySet;
using model::ListenSequenceNumber;
using model::SnapshotVersion;
using model::TargetId;
using nanopb::ByteString;

using testutil::Filter;
using testutil::Key;
using testutil::ResumeToken;
using testutil::Version;

QueryCacheTestBase::QueryCacheTestBase(std::unique_ptr<Persistence> persistence)
    : persistence_(std::move(persistence)),
      cache_(persistence_->query_cache()),
      query_rooms_(testutil::Query("rooms")),
      previous_sequence_number_(1000),
      previous_target_id_(500),
      previous_snapshot_version_(100) {
}

QueryCacheTestBase::~QueryCacheTestBase() = default;

/**
 * Creates a new QueryData object from the given parameters, synthesizing a
 * resume token from the snapshot version.
 */
QueryData QueryCacheTestBase::MakeQueryData(Query query) {
  return MakeQueryData(std::move(query), ++previous_target_id_,
                       ++previous_sequence_number_,
                       ++previous_snapshot_version_);
}

QueryData QueryCacheTestBase::MakeQueryData(
    Query query,
    TargetId target_id,
    ListenSequenceNumber sequence_number,
    int64_t version) {
  ByteString resume_token = ResumeToken(version);
  return QueryData(*query.ToTarget(), target_id, sequence_number,
                   QueryPurpose::Listen, Version(version), resume_token);
}

void QueryCacheTestBase::AddMatchingKey(const DocumentKey& key,
                                        TargetId target_id) {
  DocumentKeySet keys{key};
  cache_->AddMatchingKeys(keys, target_id);
}

void QueryCacheTestBase::RemoveMatchingKey(const DocumentKey& key,
                                           TargetId target_id) {
  DocumentKeySet keys{key};
  cache_->RemoveMatchingKeys(keys, target_id);
}

QueryCacheTest::QueryCacheTest() : QueryCacheTestBase(GetParam()()) {
}

// Out of line definition supports unique_ptr to forward declaration.
QueryCacheTest::~QueryCacheTest() = default;

TEST_P(QueryCacheTest, ReadQueryNotInCache) {
  persistence_->Run("test_read_query_not_in_cache", [&]() {
    ASSERT_EQ(cache_->GetTarget(*query_rooms_.ToTarget()), absl::nullopt);
  });
}

TEST_P(QueryCacheTest, SetAndReadAQuery) {
  persistence_->Run("test_set_and_read_a_query", [&]() {
    QueryData query_data = MakeQueryData(query_rooms_);
    cache_->AddTarget(query_data);

    auto result = cache_->GetTarget(*query_rooms_.ToTarget());
    ASSERT_NE(result, absl::nullopt);
    ASSERT_EQ(result->target(), query_data.target());
    ASSERT_EQ(result->target_id(), query_data.target_id());
    ASSERT_EQ(result->resume_token(), query_data.resume_token());
  });
}

TEST_P(QueryCacheTest, CanonicalIDCollision) {
  persistence_->Run("test_canonical_id_collision", [&]() {
    // Type information is currently lost in our canonical_id implementations so
    // this currently an easy way to force colliding canonical_i_ds
    Query q1 = testutil::Query("a").AddingFilter(Filter("foo", "==", 1));
    Query q2 = testutil::Query("a").AddingFilter(Filter("foo", "==", "1"));
    ASSERT_EQ(q1.CanonicalId(), q2.CanonicalId());

    QueryData data1 = MakeQueryData(q1);
    cache_->AddTarget(data1);

    // Using the other query should not return the query cache entry despite
    // equal canonical_i_ds.
    ASSERT_EQ(cache_->GetTarget(*q2.ToTarget()), absl::nullopt);
    ASSERT_EQ(cache_->GetTarget(*q1.ToTarget()), data1);

    QueryData data2 = MakeQueryData(q2);
    cache_->AddTarget(data2);
    ASSERT_EQ(cache_->size(), 2);

    ASSERT_EQ(cache_->GetTarget(*q1.ToTarget()), data1);
    ASSERT_EQ(cache_->GetTarget(*q2.ToTarget()), data2);

    cache_->RemoveTarget(data1);
    ASSERT_EQ(cache_->GetTarget(*q1.ToTarget()), absl::nullopt);
    ASSERT_EQ(cache_->GetTarget(*q2.ToTarget()), data2);
    ASSERT_EQ(cache_->size(), 1);

    cache_->RemoveTarget(data2);
    ASSERT_EQ(cache_->GetTarget(*q1.ToTarget()), absl::nullopt);
    ASSERT_EQ(cache_->GetTarget(*q2.ToTarget()), absl::nullopt);
    ASSERT_EQ(cache_->size(), 0);
  });
}

TEST_P(QueryCacheTest, SetQueryToNewValue) {
  persistence_->Run("test_set_query_to_new_value", [&]() {
    QueryData query_data1 = MakeQueryData(query_rooms_, 1, 10, 1);
    cache_->AddTarget(query_data1);

    QueryData query_data2 = MakeQueryData(query_rooms_, 1, 10, 2);
    cache_->AddTarget(query_data2);

    auto result = cache_->GetTarget(*query_rooms_.ToTarget());
    ASSERT_NE(query_data2.resume_token(), query_data1.resume_token());
    ASSERT_NE(query_data2.snapshot_version(), query_data1.snapshot_version());
    ASSERT_EQ(result->resume_token(), query_data2.resume_token());
    ASSERT_EQ(result->snapshot_version(), query_data2.snapshot_version());
  });
}

TEST_P(QueryCacheTest, RemoveQuery) {
  persistence_->Run("test_remove_query", [&]() {
    QueryData query_data1 = MakeQueryData(query_rooms_);
    cache_->AddTarget(query_data1);

    cache_->RemoveTarget(query_data1);

    auto result = cache_->GetTarget(*query_rooms_.ToTarget());
    ASSERT_EQ(result, absl::nullopt);
  });
}

TEST_P(QueryCacheTest, RemoveNonExistentQuery) {
  persistence_->Run("test_remove_non_existent_query", [&]() {
    QueryData query_data = MakeQueryData(query_rooms_);

    // no-op, but make sure it doesn't throw.
    EXPECT_NO_THROW(cache_->RemoveTarget(query_data));
  });
}

TEST_P(QueryCacheTest, RemoveQueryRemovesMatchingKeysToo) {
  persistence_->Run("test_remove_query_removes_matching_keys_too", [&]() {
    QueryData rooms = MakeQueryData(query_rooms_);
    cache_->AddTarget(rooms);

    DocumentKey key1 = Key("rooms/foo");
    DocumentKey key2 = Key("rooms/bar");
    AddMatchingKey(key1, rooms.target_id());
    AddMatchingKey(key2, rooms.target_id());

    ASSERT_TRUE(cache_->Contains(key1));
    ASSERT_TRUE(cache_->Contains(key2));

    cache_->RemoveTarget(rooms);
    ASSERT_FALSE(cache_->Contains(key1));
    ASSERT_FALSE(cache_->Contains(key2));
  });
}

TEST_P(QueryCacheTest, AddOrRemoveMatchingKeys) {
  persistence_->Run("test_add_or_remove_matching_keys", [&]() {
    DocumentKey key = Key("foo/bar");

    ASSERT_FALSE(cache_->Contains(key));

    AddMatchingKey(key, 1);
    ASSERT_TRUE(cache_->Contains(key));

    AddMatchingKey(key, 2);
    ASSERT_TRUE(cache_->Contains(key));

    RemoveMatchingKey(key, 1);
    ASSERT_TRUE(cache_->Contains(key));

    RemoveMatchingKey(key, 2);
    ASSERT_FALSE(cache_->Contains(key));
  });
}

TEST_P(QueryCacheTest, MatchingKeysForTargetID) {
  persistence_->Run("test_matching_keys_for_target_id", [&]() {
    DocumentKey key1 = Key("foo/bar");
    DocumentKey key2 = Key("foo/baz");
    DocumentKey key3 = Key("foo/blah");

    AddMatchingKey(key1, 1);
    AddMatchingKey(key2, 1);
    AddMatchingKey(key3, 2);

    ASSERT_EQ(cache_->GetMatchingKeys(1), (DocumentKeySet{key1, key2}));
    ASSERT_EQ(cache_->GetMatchingKeys(2), (DocumentKeySet{key3}));

    AddMatchingKey(key1, 2);
    ASSERT_EQ(cache_->GetMatchingKeys(1), (DocumentKeySet{key1, key2}));
    ASSERT_EQ(cache_->GetMatchingKeys(2), (DocumentKeySet{key1, key3}));
  });
}

TEST_P(QueryCacheTest, HighestListenSequenceNumber) {
  persistence_->Run("test_highest_listen_sequence_number", [&]() {
    QueryData query1(*testutil::Query("rooms").ToTarget(), 1, 10,
                     QueryPurpose::Listen);
    cache_->AddTarget(query1);
    QueryData query2(*testutil::Query("halls").ToTarget(), 2, 20,
                     QueryPurpose::Listen);
    cache_->AddTarget(query2);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 20);

    // Sequence numbers never come down.
    cache_->RemoveTarget(query2);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 20);

    QueryData query3(*testutil::Query("garages").ToTarget(), 42, 100,
                     QueryPurpose::Listen);
    cache_->AddTarget(query3);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 100);

    cache_->AddTarget(query1);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 100);

    cache_->RemoveTarget(query3);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 100);
  });
}

TEST_P(QueryCacheTest, HighestTargetID) {
  persistence_->Run("test_highest_target_id", [&]() {
    ASSERT_EQ(cache_->highest_target_id(), 0);

    QueryData query1(*testutil::Query("rooms").ToTarget(), 1, 10,
                     QueryPurpose::Listen);
    DocumentKey key1 = Key("rooms/bar");
    DocumentKey key2 = Key("rooms/foo");
    cache_->AddTarget(query1);
    AddMatchingKey(key1, 1);
    AddMatchingKey(key2, 1);

    QueryData query2(*testutil::Query("halls").ToTarget(), 2, 20,
                     QueryPurpose::Listen);
    DocumentKey key3 = Key("halls/foo");
    cache_->AddTarget(query2);
    AddMatchingKey(key3, 2);
    ASSERT_EQ(cache_->highest_target_id(), 2);

    // TargetIDs never come down.
    cache_->RemoveTarget(query2);
    ASSERT_EQ(cache_->highest_target_id(), 2);

    // A query with an empty result set still counts.
    QueryData query3(*testutil::Query("garages").ToTarget(), 42, 100,
                     QueryPurpose::Listen);
    cache_->AddTarget(query3);
    ASSERT_EQ(cache_->highest_target_id(), 42);

    cache_->RemoveTarget(query1);
    ASSERT_EQ(cache_->highest_target_id(), 42);

    cache_->RemoveTarget(query3);
    ASSERT_EQ(cache_->highest_target_id(), 42);
  });
}

TEST_P(QueryCacheTest, LastRemoteSnapshotVersion) {
  persistence_->Run("test_last_remote_snapshot_version", [&]() {
    ASSERT_EQ(cache_->GetLastRemoteSnapshotVersion(), SnapshotVersion::None());

    // Can set the snapshot version.
    cache_->SetLastRemoteSnapshotVersion(Version(42));
    ASSERT_EQ(cache_->GetLastRemoteSnapshotVersion(), Version(42));
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
