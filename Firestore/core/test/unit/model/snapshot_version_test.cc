/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/model/snapshot_version.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(SnapshotVersion, Getter) {
  SnapshotVersion version(Timestamp(123, 456));
  EXPECT_EQ(Timestamp(123, 456), version.timestamp());

  const SnapshotVersion& no_version = SnapshotVersion::None();
  EXPECT_EQ(Timestamp(), no_version.timestamp());
}

TEST(SnapshotVersion, Comparison) {
  EXPECT_LT(SnapshotVersion::None(), SnapshotVersion(Timestamp(123, 456)));

  EXPECT_LT(SnapshotVersion(Timestamp(123, 456)),
            SnapshotVersion(Timestamp(456, 123)));
  EXPECT_GT(SnapshotVersion(Timestamp(456, 123)),
            SnapshotVersion(Timestamp(123, 456)));
  EXPECT_LE(SnapshotVersion(Timestamp(123, 456)),
            SnapshotVersion(Timestamp(456, 123)));
  EXPECT_LE(SnapshotVersion(Timestamp(123, 456)),
            SnapshotVersion(Timestamp(123, 456)));
  EXPECT_GE(SnapshotVersion(Timestamp(456, 123)),
            SnapshotVersion(Timestamp(123, 456)));
  EXPECT_GE(SnapshotVersion(Timestamp(123, 456)),
            SnapshotVersion(Timestamp(123, 456)));
  EXPECT_EQ(SnapshotVersion(Timestamp(123, 456)),
            SnapshotVersion(Timestamp(123, 456)));
  EXPECT_NE(SnapshotVersion(Timestamp(123, 456)),
            SnapshotVersion(Timestamp(456, 123)));
}

}  //  namespace model
}  //  namespace firestore
}  //  namespace firebase
