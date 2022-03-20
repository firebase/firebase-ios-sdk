/*
 * Copyright 2022 Google LLC
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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_DOCUMENT_OVERLAY_CACHE_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_DOCUMENT_OVERLAY_CACHE_TEST_H_

#include <memory>
#include <string>
#include <vector>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

namespace model {

class Mutation;

}  // namespace model

namespace local {

class DocumentOverlayCache;
class Persistence;

using FactoryFunc = std::unique_ptr<Persistence> (*)();

/**
 * A test fixture for implementing tests of the DocumentOverlayCache interface.
 *
 * This is separate from DocumentOverlayCacheTest below in order to make
 * additional implementation-specific tests.
 */
class DocumentOverlayCacheTestBase : public testing::Test {
 public:
  explicit DocumentOverlayCacheTestBase(
      std::unique_ptr<Persistence> persistence);

 protected:
  void SaveOverlaysWithMutations(int largest_batch_id,
                                 const std::vector<model::Mutation>& mutations);

  void SaveOverlaysWithSetMutations(int largest_batch_id,
                                    const std::vector<std::string>& keys);

  void ExpectCacheContainsOverlaysFor(const std::vector<std::string>& keys);

  void ExpectCacheDoesNotContainOverlaysFor(
      const std::vector<std::string>& keys);

  int GetOverlayCount() const;

  std::unique_ptr<Persistence> persistence_;
  DocumentOverlayCache* cache_ = nullptr;
};

/**
 * These are tests for any implementation of the DocumentOverlayCache interface.
 *
 * To test a specific implementation of DocumentOverlayCache:
 *
 * + Write a persistence factory function
 * + Call INSTANTIATE_TEST_SUITE_P(MyNewDocumentOverlayCacheTest,
 *                                 DocumentOverlayCacheTest,
 *                                 testing::Values(PersistenceFactory));
 */
class DocumentOverlayCacheTest
    : public DocumentOverlayCacheTestBase,
      public testing::WithParamInterface<FactoryFunc> {
 public:
  // `GetParam()` must return a factory function.
  DocumentOverlayCacheTest();
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_DOCUMENT_OVERLAY_CACHE_TEST_H_
