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
    ExistenceFilterWatchChange change{std::move(filter), 5};
    EXPECT_EQ(change.target_id(), 5);
    EXPECT_EQ(change.filter().count(), 7);
    EXPECT_EQ(change.filter().bloom_filter(), absl::nullopt);
  }
  {
    nanopb::Message<google_firestore_v1_BloomFilter> bloom_filter;
    bloom_filter->hash_count = 33;
    bloom_filter->has_bits = true;
    bloom_filter->bits.padding = 7;
    bloom_filter->bits.bitmap =
        nanopb::MakeBytesArray(std::vector<uint8_t>{0x42, 0xFE});
    ExistenceFilter filter{7, std::move(bloom_filter)};
    ExistenceFilterWatchChange change{std::move(filter), 5};

    EXPECT_EQ(change.target_id(), 5);
    EXPECT_EQ(change.filter().count(), 7);

    nanopb::Message<google_firestore_v1_BloomFilter> bloom_filter_copy;
    bloom_filter_copy->hash_count = 33;
    bloom_filter_copy->has_bits = true;
    bloom_filter_copy->bits.padding = 7;
    bloom_filter_copy->bits.bitmap =
        nanopb::MakeBytesArray(std::vector<uint8_t>{0x42, 0xFE});
    EXPECT_TRUE(change.filter().bloom_filter().value() == bloom_filter_copy);
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
