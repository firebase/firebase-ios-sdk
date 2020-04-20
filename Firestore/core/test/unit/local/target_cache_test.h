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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_TARGET_CACHE_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_TARGET_CACHE_TEST_H_

#include <memory>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/model/types.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

namespace model {
class DocumentKey;
}  // namespace model

namespace local {

class Persistence;
class TargetCache;
class TargetData;

using FactoryFunc = std::unique_ptr<Persistence> (*)();

/**
 * A test fixture for implementing tests of TargetCache interface.
 *
 * This is separate from TargetCacheTest below in order to make additional
 * implementation-specific tests.
 */
class TargetCacheTestBase : public testing::Test {
 protected:
  explicit TargetCacheTestBase(std::unique_ptr<Persistence> persistence);

  ~TargetCacheTestBase();

  TargetData MakeTargetData(core::Query query);

  TargetData MakeTargetData(core::Query query,
                            model::TargetId target_id,
                            model::ListenSequenceNumber sequence_number,
                            int64_t version);

  void AddMatchingKey(const model::DocumentKey& key, model::TargetId target_id);

  void RemoveMatchingKey(const model::DocumentKey& key,
                         model::TargetId target_id);

  std::unique_ptr<Persistence> persistence_;
  TargetCache* cache_ = nullptr;

  core::Query query_rooms_;
  model::ListenSequenceNumber previous_sequence_number_ = 0;
  model::TargetId previous_target_id_ = 0;
  int64_t previous_snapshot_version_ = 0;
};

/**
 * These are tests for any implementation of the TargetCache interface.
 *
 * To test a specific implementation of TargetCache:
 *
 * + Write a persistence factory function
 * + Call INSTANTIATE_TEST_SUITE_P(MyNewTargetCacheTest,
 *                                 TargetCacheTest,
 *                                 testing::Values(PersistenceFactory));
 */
class TargetCacheTest : public TargetCacheTestBase,
                        public testing::WithParamInterface<FactoryFunc> {
 public:
  TargetCacheTest();
  ~TargetCacheTest();
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_TARGET_CACHE_TEST_H_
