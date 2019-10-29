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

#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include <iostream>

#include "Firestore/core/src/firebase/firestore/util/filesystem.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

using util::RecursivelyCreateDir;
using util::RecursivelyDelete;

TEST(LevelDbPersistenceTest, CanFindAppDataDirectory) {
  const auto& path = LevelDbPersistence::AppDataDirectory();
  EXPECT_TRUE(RecursivelyCreateDir(path).ok());
  EXPECT_TRUE(RecursivelyDelete(path).ok());
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase
