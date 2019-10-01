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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_LOCAL_INDEX_MANAGER_TEST_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_LOCAL_INDEX_MANAGER_TEST_H_

#if !defined(__OBJC__)
#error "For now, this file must only be included by ObjC source files."
#endif  // !defined(__OBJC__)

#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/firebase/firestore/local/index_manager.h"
#include "gtest/gtest.h"

#import "Firestore/Source/Local/FSTPersistence.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace local {

using FactoryFunc = id<FSTPersistence> _Nonnull (*)();

class IndexManagerTest : public ::testing::TestWithParam<FactoryFunc> {
 public:
  // `GetParam()` must return a factory function.
  IndexManagerTest() : persistence{GetParam()()} {
  }

  id<FSTPersistence> persistence;

  virtual ~IndexManagerTest();

 protected:
  void AssertParents(const std::string& collection_id,
                     std::vector<std::string> expected);
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_LOCAL_INDEX_MANAGER_TEST_H_
