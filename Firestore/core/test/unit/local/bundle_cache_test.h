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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_BUNDLE_CACHE_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_BUNDLE_CACHE_TEST_H_

#include <memory>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

namespace model {
class DocumentKey;
}  // namespace model

namespace local {

class Persistence;
class BundleCache;

using FactoryFunc = std::unique_ptr<Persistence> (*)();

/**
 * These are tests for any implementation of the BundleCache interface.
 *
 * To test a specific implementation of BundleCache:
 *
 * - Write a persistence factory function
 * - Call INSTANTIATE_TEST_SUITE_P(MyNewBundleCacheTest,
 *                                 BundleCacheTest,
 *                                 testing::Values(PersistenceFactory));
 */
class BundleCacheTest : public testing::Test,
                        public testing::WithParamInterface<FactoryFunc> {
 public:
  BundleCacheTest();
  explicit BundleCacheTest(std::unique_ptr<Persistence> persistence);
  ~BundleCacheTest() = default;

 protected:
  std::unique_ptr<Persistence> persistence_;
  BundleCache* cache_ = nullptr;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_BUNDLE_CACHE_TEST_H_
