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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_REMOTE_DOCUMENT_CACHE_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_REMOTE_DOCUMENT_CACHE_TEST_H_

#include <memory>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/core/src/nanopb/message.h"
#include "absl/strings/string_view.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

class MutableDocument;

}  // namespace model

namespace local {

class IndexManager;
class Persistence;
class RemoteDocumentCache;

using FactoryFunc = std::unique_ptr<Persistence> (*)();

/**
 * These are tests for any implementation of the RemoteDocumentCache interface.
 *
 * To test a specific implementation of RemoteDocumentCache:
 *
 * + Write a persistence factory function
 * + Call INSTANTIATE_TEST_SUITE_P(MyNewRemoteDocumentCacheTest,
 *                                 RemoteDocumentCacheTest,
 *                                 testing::Values(PersistenceFactory));
 */
class RemoteDocumentCacheTest : public ::testing::TestWithParam<FactoryFunc> {
 public:
  // `GetParam()` must return a factory function.
  RemoteDocumentCacheTest();

 protected:
  model::MutableDocument SetTestDocument(absl::string_view path);
  model::MutableDocument SetTestDocument(
      absl::string_view path, nanopb::Message<google_firestore_v1_Value> data);
  model::MutableDocument SetTestDocument(absl::string_view path,
                                         int update_time,
                                         int read_time);
  model::MutableDocument SetTestDocument(
      absl::string_view path,
      nanopb::Message<google_firestore_v1_Value> data,
      int update_time,
      int read_time);
  void SetAndReadTestDocument(absl::string_view path);

  std::unique_ptr<Persistence> persistence_;
  RemoteDocumentCache* cache_;
  IndexManager* index_manager_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_REMOTE_DOCUMENT_CACHE_TEST_H_
