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

#import "Firestore/Source/Model/FSTDocument.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/src/firebase/firestore/remote/existence_filter.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "gtest/gtest.h"

using firebase::firestore::model::DocumentState;
using firebase::firestore::remote::DocumentWatchChange;
using firebase::firestore::remote::ExistenceFilter;
using firebase::firestore::remote::ExistenceFilterWatchChange;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WatchTargetChangeState;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace remote {

TEST(WatchChangeTest, CanCreateDocumentWatchChange) {
  FSTMaybeDocument* doc = FSTTestDoc("a/b", 1, @{}, DocumentState::kSynced);
  DocumentWatchChange change{{1, 2, 3}, {4, 5}, doc.key, doc};

  EXPECT_EQ(change.updated_target_ids().size(), 3);
  EXPECT_EQ(change.removed_target_ids().size(), 2);
  // Testing object identity here is fine.
  EXPECT_EQ(change.new_document(), doc);
}

TEST(WatchChangeTest, CanCreateExistenceFilterWatchChange) {
  ExistenceFilter filter{7};
  ExistenceFilterWatchChange change{filter, 5};
  EXPECT_EQ(change.filter().count(), 7);
  EXPECT_EQ(change.target_id(), 5);
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

NS_ASSUME_NONNULL_END
