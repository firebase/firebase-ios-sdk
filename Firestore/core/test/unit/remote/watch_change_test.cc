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

#include "Firestore/core/src/remote/watch_change.h"

#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/remote/existence_filter.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using model::MutableDocument;

using testutil::Doc;
using testutil::Map;

TEST(WatchChangeTest, CanCreateDocumentWatchChange) {
  MutableDocument doc = Doc("a/b", 1, Map());
  DocumentWatchChange change{{1, 2, 3}, {4, 5}, doc.key(), doc};

  EXPECT_EQ(change.updated_target_ids().size(), 3);
  EXPECT_EQ(change.removed_target_ids().size(), 2);
  // Testing object identity here is fine.
  EXPECT_EQ(change.new_document(), doc);
}

TEST(WatchChangeTest, CanCreateExistenceFilterWatchChange) {
  {
    ExistenceFilter filter{7, /*bloom_filter=*/absl::nullopt};
    ExistenceFilterWatchChange change{filter, 5};
    EXPECT_EQ(change.filter().count(), 7);
    EXPECT_EQ(change.filter().bloom_filter_parameters(), absl::nullopt);
    EXPECT_EQ(change.target_id(), 5);
  }
  {
    BloomFilterParameters bloom_filter_parameters{{0x42, 0xFE}, 7, 33};
    ExistenceFilter filter{7, bloom_filter_parameters};
    ExistenceFilterWatchChange change{std::move(filter), 5};
    EXPECT_EQ(change.filter().count(), 7);
    EXPECT_EQ(change.filter().bloom_filter_parameters(),
              bloom_filter_parameters);
    EXPECT_EQ(change.target_id(), 5);
  }
}

TEST(WatchChangeTest, CanCreateWatchTargetChange) {
  WatchTargetChange change{WatchTargetChangeState::Reset,
                           {
                               1,
                               2,
                           }};
  EXPECT_EQ(change.state(), WatchTargetChangeState::Reset);
  EXPECT_EQ(change.target_ids().size(), 2);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
