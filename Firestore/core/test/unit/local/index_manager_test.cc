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

#include "Firestore/core/test/unit/local/index_manager_test.h"

#include <algorithm>
#include <memory>
#include <string>
#include <vector>

#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/index_manager.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/model/resource_path.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {

using credentials::User;
using model::ResourcePath;

void IndexManagerTest::AssertParents(const std::string& collection_id,
                                     std::vector<std::string> expected) {
  IndexManager* index_manager =
      persistence->GetIndexManager(User::Unauthenticated());
  std::vector<ResourcePath> actual_paths =
      index_manager->GetCollectionParents(collection_id);
  std::vector<std::string> actual;
  for (const ResourcePath& actual_path : actual_paths) {
    actual.push_back(actual_path.CanonicalString());
  }
  std::sort(expected.begin(), expected.end());
  std::sort(actual.begin(), actual.end());

  SCOPED_TRACE("AssertParents(\"" + collection_id + "\", ...)");
  EXPECT_EQ(actual, expected);
}

IndexManagerTest::~IndexManagerTest() {
  persistence->Shutdown();
}

TEST_P(IndexManagerTest, AddAndReadCollectionParentIndexEntries) {
  IndexManager* index_manager =
      persistence->GetIndexManager(User::Unauthenticated());
  persistence->Run("AddAndReadCollectionParentIndexEntries", [&]() {
    index_manager->AddToCollectionParentIndex(ResourcePath{"messages"});
    index_manager->AddToCollectionParentIndex(ResourcePath{"messages"});
    index_manager->AddToCollectionParentIndex(
        ResourcePath{"rooms", "foo", "messages"});
    index_manager->AddToCollectionParentIndex(
        ResourcePath{"rooms", "bar", "messages"});
    index_manager->AddToCollectionParentIndex(
        ResourcePath{"rooms", "foo", "messages2"});

    AssertParents("messages",
                  std::vector<std::string>{"", "rooms/bar", "rooms/foo"});
    AssertParents("messages2", std::vector<std::string>{"rooms/foo"});
    AssertParents("messages3", std::vector<std::string>{});
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
