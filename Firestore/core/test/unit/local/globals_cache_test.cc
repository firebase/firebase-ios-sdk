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

#include "Firestore/core/test/unit/local/globals_cache_test.h"

#include "Firestore/core/src/local/globals_cache.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

using util::ComparisonResult;

namespace local {

GlobalsCacheTest::GlobalsCacheTest(std::unique_ptr<Persistence> persistence)
    : persistence_(std::move(NOT_NULL(persistence))),
      cache_(persistence_->globals_cache()) {
}

GlobalsCacheTest::GlobalsCacheTest() : GlobalsCacheTest(GetParam()()) {
}

namespace {

TEST_P(GlobalsCacheTest, ReturnsEmptyBytestringWhenSessionTokenNotFound) {
  persistence_->Run(
      "test_returns_empty_bytestring_when_session_token_not_found", [&] {
        auto expected = ByteString();
        EXPECT_EQ(cache_->GetSessionToken().CompareTo(expected),
                  ComparisonResult::Same);
      });
}

TEST_P(GlobalsCacheTest, ReturnsSavedSessionToken) {
  persistence_->Run("test_returns_saved_session_token", [&] {
    auto expected = ByteString("magic");
    cache_->SetSessionToken(expected);

    EXPECT_EQ(cache_->GetSessionToken().CompareTo(expected),
              ComparisonResult::Same);

    // Overwrite
    expected = ByteString("science");
    cache_->SetSessionToken(expected);

    EXPECT_EQ(cache_->GetSessionToken().CompareTo(expected),
              ComparisonResult::Same);
  });
}

}  // namespace

}  // namespace local
}  // namespace firestore
}  // namespace firebase
