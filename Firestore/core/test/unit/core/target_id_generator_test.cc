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

#include "Firestore/core/src/core/target_id_generator.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

TEST(TargetIdGenerator, Constructor) {
  TargetIdGenerator query_cache_generator =
      TargetIdGenerator::TargetCacheTargetIdGenerator(0);
  TargetIdGenerator sync_engine_generator =
      TargetIdGenerator::SyncEngineTargetIdGenerator();
  EXPECT_EQ(TargetIdGeneratorId::TargetCache,
            query_cache_generator.generator_id());
  EXPECT_EQ(2, query_cache_generator.NextId());
  EXPECT_EQ(TargetIdGeneratorId::SyncEngine,
            sync_engine_generator.generator_id());
  EXPECT_EQ(1, sync_engine_generator.NextId());
}

TEST(TargetIdGenerator, Increment) {
  TargetIdGenerator a = TargetIdGenerator::TargetCacheTargetIdGenerator(0);
  EXPECT_EQ(2, a.NextId());
  EXPECT_EQ(4, a.NextId());
  EXPECT_EQ(6, a.NextId());

  TargetIdGenerator b = TargetIdGenerator::TargetCacheTargetIdGenerator(46);
  EXPECT_EQ(48, b.NextId());
  EXPECT_EQ(50, b.NextId());
  EXPECT_EQ(52, b.NextId());
  EXPECT_EQ(54, b.NextId());

  TargetIdGenerator c = TargetIdGenerator::SyncEngineTargetIdGenerator();
  EXPECT_EQ(1, c.NextId());
  EXPECT_EQ(3, c.NextId());
  EXPECT_EQ(5, c.NextId());
}

}  //  namespace core
}  //  namespace firestore
}  //  namespace firebase
