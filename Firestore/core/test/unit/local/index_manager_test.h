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

#ifndef FIRESTORE_CORE_TEST_UNIT_LOCAL_INDEX_MANAGER_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_LOCAL_INDEX_MANAGER_TEST_H_

#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/local/index_manager.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

class Persistence;

using FactoryFunc = std::unique_ptr<Persistence> (*)();

class IndexManagerTest : public ::testing::TestWithParam<FactoryFunc> {
 public:
  // `GetParam()` must return a factory function.
  IndexManagerTest() : persistence{GetParam()()} {
  }

  std::unique_ptr<Persistence> persistence;

  virtual ~IndexManagerTest();

 protected:
  void AssertParents(const std::string& collection_id,
                     std::vector<std::string> expected);
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_LOCAL_INDEX_MANAGER_TEST_H_
