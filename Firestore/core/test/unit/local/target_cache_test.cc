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

#include "Firestore/core/test/unit/local/target_cache_test.h"

#include <set>
#include <string>
#include <unordered_set>
#include <utility>

#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/immutable/sorted_set.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/target_cache.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gmock/gmock.h"
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

using testing::Contains;
using testutil::Filter;
using testutil::Key;
using testutil::ResumeToken;
using testutil::Version;

TargetCacheTestBase::TargetCacheTestBase(
    std::unique_ptr<Persistence> persistence)
    : persistence_(std::move(persistence)),
      cache_(persistence_->target_cache()),
      query_rooms_(testutil::Query("rooms")),
      previous_sequence_number_(1000),
      previous_target_id_(500),
      previous_snapshot_version_(100) {
}

TargetCacheTestBase::~TargetCacheTestBase() = default;

/**
 * Creates a new TargetData object from the given parameters, synthesizing a
 * resume token from the snapshot version.
 */
TargetData TargetCacheTestBase::MakeTargetData(Query query) {
  return MakeTargetData(std::move(query), ++previous_target_id_,
                        ++previous_sequence_number_,
                        ++previous_snapshot_version_);
}

TargetData TargetCacheTestBase::MakeTargetData(
    Query query,
    TargetId target_id,
    ListenSequenceNumber sequence_number,
    int64_t version) {
  ByteString resume_token = ResumeToken(version);
  return TargetData(query.ToTarget(), target_id, sequence_number,
                    QueryPurpose::Listen, Version(version), Version(version),
                    resume_token, /*expected_count=*/absl::nullopt);
}

void TargetCacheTestBase::AddMatchingKey(const DocumentKey& key,
                                         TargetId target_id) {
  DocumentKeySet keys{key};
  cache_->AddMatchingKeys(keys, target_id);
}

void TargetCacheTestBase::RemoveMatchingKey(const DocumentKey& key,
                                            TargetId target_id) {
  DocumentKeySet keys{key};
  cache_->RemoveMatchingKeys(keys, target_id);
}

TargetCacheTest::TargetCacheTest() : TargetCacheTestBase(GetParam()()) {
}

// Out of line definition supports unique_ptr to forward declaration.
TargetCacheTest::~TargetCacheTest() = default;

TEST_P(TargetCacheTest, ReadQueryNotInCache) {
  persistence_->Run("test_read_query_not_in_cache", [&] {
    ASSERT_EQ(cache_->GetTarget(query_rooms_.ToTarget()), absl::nullopt);
  });
}

TEST_P(TargetCacheTest, SetAndReadAQuery) {
  persistence_->Run("test_set_and_read_a_query", [&] {
    TargetData target_data = MakeTargetData(query_rooms_);
    cache_->AddTarget(target_data);

    auto result = cache_->GetTarget(query_rooms_.ToTarget());
    ASSERT_NE(result, absl::nullopt);
    ASSERT_EQ(result->target(), target_data.target());
    ASSERT_EQ(result->target_id(), target_data.target_id());
    ASSERT_EQ(result->resume_token(), target_data.resume_token());
  });
}

TEST_P(TargetCacheTest, CanonicalIDCollision) {
  persistence_->Run("test_canonical_id_collision", [&] {
    // Type information is currently lost in our canonical_id implementations so
    // this currently an easy way to force colliding canonical_i_ds
    Query q1 = testutil::Query("a").AddingFilter(Filter("foo", "==", 1));
    Query q2 = testutil::Query("a").AddingFilter(Filter("foo", "==", "1"));
    ASSERT_EQ(q1.CanonicalId(), q2.CanonicalId());

    TargetData data1 = MakeTargetData(q1);
    cache_->AddTarget(data1);

    // Using the other query should not return the target cache entry despite
    // equal canonical_i_ds.
    ASSERT_EQ(cache_->GetTarget(q2.ToTarget()), absl::nullopt);
    ASSERT_EQ(cache_->GetTarget(q1.ToTarget()), data1);

    TargetData data2 = MakeTargetData(q2);
    cache_->AddTarget(data2);
    ASSERT_EQ(cache_->size(), 2);

    ASSERT_EQ(cache_->GetTarget(q1.ToTarget()), data1);
    ASSERT_EQ(cache_->GetTarget(q2.ToTarget()), data2);

    cache_->RemoveTarget(data1);
    ASSERT_EQ(cache_->GetTarget(q1.ToTarget()), absl::nullopt);
    ASSERT_EQ(cache_->GetTarget(q2.ToTarget()), data2);
    ASSERT_EQ(cache_->size(), 1);

    cache_->RemoveTarget(data2);
    ASSERT_EQ(cache_->GetTarget(q1.ToTarget()), absl::nullopt);
    ASSERT_EQ(cache_->GetTarget(q2.ToTarget()), absl::nullopt);
    ASSERT_EQ(cache_->size(), 0);
  });
}

TEST_P(TargetCacheTest, SetQueryToNewValue) {
  persistence_->Run("test_set_query_to_new_value", [&] {
    TargetData target_data1 = MakeTargetData(query_rooms_, 1, 10, 1);
    cache_->AddTarget(target_data1);

    TargetData target_data2 = MakeTargetData(query_rooms_, 1, 10, 2);
    cache_->AddTarget(target_data2);

    auto result = cache_->GetTarget(query_rooms_.ToTarget());
    ASSERT_NE(target_data2.resume_token(), target_data1.resume_token());
    ASSERT_NE(target_data2.snapshot_version(), target_data1.snapshot_version());
    ASSERT_EQ(result->resume_token(), target_data2.resume_token());
    ASSERT_EQ(result->snapshot_version(), target_data2.snapshot_version());
  });
}

TEST_P(TargetCacheTest, EnumerateSequenceNumbers) {
  std::unordered_set<ListenSequenceNumber> sequence_numbers;
  persistence_->Run("test_enumerate_sequence_numbers", [&] {
    for (int i = 0; i < 10; i++) {
      TargetData target_data =
          MakeTargetData(testutil::Query(std::to_string(i)));
      cache_->AddTarget(target_data);
      sequence_numbers.insert(target_data.sequence_number());
    }

    int result_count = 0;
    cache_->EnumerateSequenceNumbers([&](ListenSequenceNumber sequence_number) {
      EXPECT_THAT(sequence_numbers, Contains(sequence_number));
      ++result_count;
    });

    ASSERT_EQ(result_count, 10);
  });
}

TEST_P(TargetCacheTest, RemoveTarget) {
  persistence_->Run("test_remove_target", [&] {
    TargetData target_data1 = MakeTargetData(query_rooms_);
    cache_->AddTarget(target_data1);

    cache_->RemoveTarget(target_data1);

    auto result = cache_->GetTarget(query_rooms_.ToTarget());
    ASSERT_EQ(result, absl::nullopt);
  });
}

TEST_P(TargetCacheTest, RemoveNonExistentTarget) {
  persistence_->Run("test_remove_non_existent_target", [&] {
    TargetData target_data = MakeTargetData(query_rooms_);

    // no-op, but make sure it doesn't throw.
    EXPECT_NO_THROW(cache_->RemoveTarget(target_data));
  });
}

TEST_P(TargetCacheTest, RemoveTargetRemovesMatchingKeysToo) {
  persistence_->Run("test_remove_target_removes_matching_keys_too", [&] {
    TargetData rooms = MakeTargetData(query_rooms_);
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

TEST_P(TargetCacheTest, RemoveTargets) {
  persistence_->Run("test_remove_targets", [&] {
    TargetData target_data1 = MakeTargetData(testutil::Query("a"));
    cache_->AddTarget(target_data1);
    TargetData target_data2 = MakeTargetData(testutil::Query("b"));
    cache_->AddTarget(target_data2);

    cache_->RemoveTargets(target_data2.sequence_number(), {});

    auto result = cache_->GetTarget(target_data1.target());
    ASSERT_EQ(result, absl::nullopt);
    result = cache_->GetTarget(target_data2.target());
    ASSERT_EQ(result, absl::nullopt);
  });
}

TEST_P(TargetCacheTest, RemoveTargetsRemovesMatchingKeysToo) {
  persistence_->Run("test_remove_targets_removes_matching_keys_too", [&] {
    TargetData rooms = MakeTargetData(query_rooms_);
    cache_->AddTarget(rooms);

    DocumentKey key1 = Key("rooms/foo");
    DocumentKey key2 = Key("rooms/bar");
    AddMatchingKey(key1, rooms.target_id());
    AddMatchingKey(key2, rooms.target_id());

    ASSERT_TRUE(cache_->Contains(key1));
    ASSERT_TRUE(cache_->Contains(key2));

    cache_->RemoveTargets(rooms.sequence_number(), {});
    ASSERT_FALSE(cache_->Contains(key1));
    ASSERT_FALSE(cache_->Contains(key2));
  });
}

TEST_P(TargetCacheTest, AddOrRemoveMatchingKeys) {
  persistence_->Run("test_add_or_remove_matching_keys", [&] {
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

TEST_P(TargetCacheTest, MatchingKeysForTargetID) {
  persistence_->Run("test_matching_keys_for_target_id", [&] {
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

TEST_P(TargetCacheTest, HighestListenSequenceNumber) {
  persistence_->Run("test_highest_listen_sequence_number", [&] {
    TargetData query1(testutil::Query("rooms").ToTarget(), 1, 10,
                      QueryPurpose::Listen);
    cache_->AddTarget(query1);
    TargetData query2(testutil::Query("halls").ToTarget(), 2, 20,
                      QueryPurpose::Listen);
    cache_->AddTarget(query2);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 20);

    // Sequence numbers never come down.
    cache_->RemoveTarget(query2);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 20);

    TargetData query3(testutil::Query("garages").ToTarget(), 42, 100,
                      QueryPurpose::Listen);
    cache_->AddTarget(query3);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 100);

    cache_->AddTarget(query1);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 100);

    cache_->RemoveTarget(query3);
    ASSERT_EQ(cache_->highest_listen_sequence_number(), 100);
  });
}

TEST_P(TargetCacheTest, HighestTargetID) {
  persistence_->Run("test_highest_target_id", [&] {
    ASSERT_EQ(cache_->highest_target_id(), 0);

    TargetData query1(testutil::Query("rooms").ToTarget(), 1, 10,
                      QueryPurpose::Listen);
    DocumentKey key1 = Key("rooms/bar");
    DocumentKey key2 = Key("rooms/foo");
    cache_->AddTarget(query1);
    AddMatchingKey(key1, 1);
    AddMatchingKey(key2, 1);

    TargetData query2(testutil::Query("halls").ToTarget(), 2, 20,
                      QueryPurpose::Listen);
    DocumentKey key3 = Key("halls/foo");
    cache_->AddTarget(query2);
    AddMatchingKey(key3, 2);
    ASSERT_EQ(cache_->highest_target_id(), 2);

    // TargetIDs never come down.
    cache_->RemoveTarget(query2);
    ASSERT_EQ(cache_->highest_target_id(), 2);

    // A query with an empty result set still counts.
    TargetData query3(testutil::Query("garages").ToTarget(), 42, 100,
                      QueryPurpose::Listen);
    cache_->AddTarget(query3);
    ASSERT_EQ(cache_->highest_target_id(), 42);

    cache_->RemoveTarget(query1);
    ASSERT_EQ(cache_->highest_target_id(), 42);

    cache_->RemoveTarget(query3);
    ASSERT_EQ(cache_->highest_target_id(), 42);
  });
}

TEST_P(TargetCacheTest, LastRemoteSnapshotVersion) {
  persistence_->Run("test_last_remote_snapshot_version", [&] {
    ASSERT_EQ(cache_->GetLastRemoteSnapshotVersion(), SnapshotVersion::None());

    // Can set the snapshot version.
    cache_->SetLastRemoteSnapshotVersion(Version(42));
    ASSERT_EQ(cache_->GetLastRemoteSnapshotVersion(), Version(42));
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
