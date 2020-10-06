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

#include "Firestore/core/src/core/database_info.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {

using firebase::firestore::model::DatabaseId;

TEST(DatabaseInfo, Getter) {
  DatabaseInfo info(DatabaseId("project id", "database id"), "key",
                    "http://host", true);
  EXPECT_EQ(DatabaseId("project id", "database id"), info.database_id());
  EXPECT_EQ("key", info.persistence_key());
  EXPECT_EQ("http://host", info.host());
  EXPECT_TRUE(info.ssl_enabled());
}

TEST(DatabaseInfo, DefaultDatabase) {
  DatabaseInfo info(DatabaseId("project id"), "key", "http://host", false);
  EXPECT_EQ("project id", info.database_id().project_id());
  EXPECT_EQ("(default)", info.database_id().database_id());
  EXPECT_EQ("key", info.persistence_key());
  EXPECT_EQ("http://host", info.host());
  EXPECT_FALSE(info.ssl_enabled());
}

}  //  namespace core
}  //  namespace firestore
}  //  namespace firebase
