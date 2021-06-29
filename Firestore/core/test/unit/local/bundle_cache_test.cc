/*
 * Copyright 2021 Google LLC
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

#include "Firestore/core/test/unit/local/bundle_cache_test.h"

#include <set>
#include <utility>

#include "Firestore/core/src/bundle/bundle_metadata.h"
#include "Firestore/core/src/bundle/bundled_query.h"
#include "Firestore/core/src/bundle/named_query.h"
#include "Firestore/core/src/core/field_filter.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/target.h"
#include "Firestore/core/src/local/bundle_cache.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

BundleCacheTest::BundleCacheTest(std::unique_ptr<Persistence> persistence)
    : persistence_(std::move(NOT_NULL(persistence))),
      cache_(persistence_->bundle_cache()) {
}

BundleCacheTest::BundleCacheTest() : BundleCacheTest(GetParam()()) {
}

namespace {

using bundle::BundledQuery;
using bundle::BundleMetadata;
using bundle::NamedQuery;
using core::Query;
using core::Target;
using model::SnapshotVersion;
using testutil::Filter;

TEST_P(BundleCacheTest, ReturnsNullOptWhenBundleIdNotFound) {
  persistence_->Run("test_returns_nullopt_when_bundle_id_not_found", [&] {
    EXPECT_EQ(cache_->GetBundleMetadata("bundle-1"), absl::nullopt);
  });
}

TEST_P(BundleCacheTest, ReturnsSavedBundle) {
  persistence_->Run("test_returns_saved_bundle", [&] {
    auto expected =
        BundleMetadata("bundle-1", 1, SnapshotVersion(Timestamp::Now()));
    cache_->SaveBundleMetadata(expected);

    auto actual = cache_->GetBundleMetadata("bundle-1");
    EXPECT_EQ(actual.value(), expected);

    // Overwrite
    expected = BundleMetadata("bundle-1", 2, SnapshotVersion(Timestamp::Now()));
    cache_->SaveBundleMetadata(expected);

    actual = cache_->GetBundleMetadata("bundle-1");
    EXPECT_EQ(actual.value(), expected);
  });
}

TEST_P(BundleCacheTest, ReturnsNullOptWhenNamedQueryNotFound) {
  persistence_->Run("test_returns_nullopt_when_named_query_not_found", [&] {
    EXPECT_EQ(cache_->GetNamedQuery("query-1"), absl::nullopt);
  });
}

TEST_P(BundleCacheTest, ReturnsSavedCollectionQueries) {
  persistence_->Run("test_returns_saved_collection_queries", [&] {
    Target t =
        testutil::Query("a").AddingFilter(Filter("foo", "==", 1)).ToTarget();
    BundledQuery bundle_query(t, core::LimitType::First);
    NamedQuery expected("query-1", bundle_query,
                        SnapshotVersion(Timestamp::Now()));

    cache_->SaveNamedQuery(expected);

    auto actual = cache_->GetNamedQuery("query-1");
    EXPECT_EQ(actual, expected);
  });
}

TEST_P(BundleCacheTest, ReturnsSavedLimitToFirstQueries) {
  persistence_->Run("test_returns_saved_limit_to_first_queries", [&] {
    Target t = testutil::Query("a")
                   .AddingFilter(Filter("foo", "==", 1))
                   .WithLimitToFirst(3)
                   .ToTarget();
    BundledQuery bundle_query(t, core::LimitType::First);
    NamedQuery expected("query-1", bundle_query,
                        SnapshotVersion(Timestamp::Now()));

    cache_->SaveNamedQuery(expected);

    auto actual = cache_->GetNamedQuery("query-1");
    EXPECT_EQ(actual, expected);
  });
}

TEST_P(BundleCacheTest, ReturnsSavedLimitToLastQueries) {
  persistence_->Run("test_returns_saved_limit_to_last_queries", [&] {
    Target t =
        testutil::Query("a")
            .AddingFilter(Filter("foo", "==", 1))
            // Use `LimitToFirst` here to avoid order flipping of `ToTarget()`.
            .WithLimitToFirst(3)
            .ToTarget();
    BundledQuery bundle_query(t, core::LimitType::Last);
    NamedQuery expected("query-1", bundle_query,
                        SnapshotVersion(Timestamp::Now()));

    cache_->SaveNamedQuery(expected);

    auto actual = cache_->GetNamedQuery("query-1");
    EXPECT_EQ(actual, expected);
    // TODO(wuandy): Add assertion to check the read named query translate to
    // actual limit-to-last core queries, once we have the translation
    // implemented.
  });
}

TEST_P(BundleCacheTest, ReturnsSavedCollectionGroupQueries) {
  persistence_->Run("test_returns_saved_collection_group_queries", [&] {
    Target t = testutil::CollectionGroupQuery("a")
                   .AddingFilter(Filter("foo", "==", 1))
                   .ToTarget();
    BundledQuery bundle_query(t, core::LimitType::First);
    NamedQuery expected("query-1", bundle_query,
                        SnapshotVersion(Timestamp::Now()));

    cache_->SaveNamedQuery(expected);

    auto actual = cache_->GetNamedQuery("query-1");
    EXPECT_EQ(actual, expected);
  });
}

}  // namespace
}  // namespace local
}  // namespace firestore
}  // namespace firebase
