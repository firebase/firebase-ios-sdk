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

#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

TEST(TargetIdGenerator, Constructor) {
  TargetIdGenerator local_store_generator =
      TargetIdGenerator::LocalStoreTargetIdGenerator(0);
  TargetIdGenerator sync_engine_generator =
      TargetIdGenerator::SyncEngineTargetIdGenerator(0);
  EXPECT_EQ(TargetIdGeneratorId::LocalStore,
            local_store_generator.generator_id());
  EXPECT_EQ(2, local_store_generator.NextId());
  EXPECT_EQ(TargetIdGeneratorId::SyncEngine,
            sync_engine_generator.generator_id());
  EXPECT_EQ(1, sync_engine_generator.NextId());
}

TEST(TargetIdGenerator, SkipPast) {
  EXPECT_EQ(1, TargetIdGenerator::SyncEngineTargetIdGenerator(-1).NextId());
  EXPECT_EQ(3, TargetIdGenerator::SyncEngineTargetIdGenerator(2).NextId());
  EXPECT_EQ(5, TargetIdGenerator::SyncEngineTargetIdGenerator(4).NextId());

  for (int i = 4; i < 12; ++i) {
    TargetIdGenerator a = TargetIdGenerator::LocalStoreTargetIdGenerator(i);
    TargetIdGenerator b = TargetIdGenerator::SyncEngineTargetIdGenerator(i);
    EXPECT_EQ((i + 2) & ~1, a.NextId());
    EXPECT_EQ((i + 1) | 1, b.NextId());
  }

  EXPECT_EQ(13, TargetIdGenerator::SyncEngineTargetIdGenerator(12).NextId());
  EXPECT_EQ(24, TargetIdGenerator::LocalStoreTargetIdGenerator(22).NextId());
}

TEST(TargetIdGenerator, Increment) {
  TargetIdGenerator a = TargetIdGenerator::LocalStoreTargetIdGenerator(0);
  EXPECT_EQ(2, a.NextId());
  EXPECT_EQ(4, a.NextId());
  EXPECT_EQ(6, a.NextId());

  TargetIdGenerator b = TargetIdGenerator::LocalStoreTargetIdGenerator(46);
  EXPECT_EQ(48, b.NextId());
  EXPECT_EQ(50, b.NextId());
  EXPECT_EQ(52, b.NextId());
  EXPECT_EQ(54, b.NextId());

  TargetIdGenerator c = TargetIdGenerator::SyncEngineTargetIdGenerator(0);
  EXPECT_EQ(1, c.NextId());
  EXPECT_EQ(3, c.NextId());
  EXPECT_EQ(5, c.NextId());

  TargetIdGenerator d = TargetIdGenerator::SyncEngineTargetIdGenerator(46);
  EXPECT_EQ(47, d.NextId());
  EXPECT_EQ(49, d.NextId());
  EXPECT_EQ(51, d.NextId());
  EXPECT_EQ(53, d.NextId());
}

}  //  namespace core
}  //  namespace firestore
}  //  namespace firebase
