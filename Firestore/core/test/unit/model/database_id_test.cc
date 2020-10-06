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

#include "Firestore/core/src/model/database_id.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(DatabaseIdTest, Constructor) {
  DatabaseId id("p", "d");
  EXPECT_EQ("p", id.project_id());
  EXPECT_EQ("d", id.database_id());
  EXPECT_FALSE(id.IsDefaultDatabase());
}

TEST(DatabaseIdTest, DefaultDb) {
  DatabaseId id("p", DatabaseId::kDefault);
  EXPECT_EQ("p", id.project_id());
  EXPECT_EQ("(default)", id.database_id());
  EXPECT_TRUE(id.IsDefaultDatabase());
}

TEST(DatabaseIdTest, Comparison) {
  EXPECT_LT(DatabaseId("a", "b"), DatabaseId("b", "a"));
  EXPECT_LT(DatabaseId("a", "b"), DatabaseId("a", "c"));
  EXPECT_EQ(DatabaseId("a", "b"), DatabaseId("a", "b"));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
