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

#include "Firestore/core/src/firebase/firestore/local/leveldb_opener.h"

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/autoid.h"
#include "Firestore/core/src/firebase/firestore/util/filesystem.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/test/firebase/firestore/testutil/filesystem_testing.h"
#include "Firestore/core/test/firebase/firestore/testutil/status_testing.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using core::DatabaseInfo;
using model::DatabaseId;
using remote::Serializer;
using testutil::IsNotFound;
using testutil::IsOk;
using testutil::TestTempDir;
using util::CreateAutoId;
using util::IsDirectory;
using util::Path;
using util::Status;
using util::TempDir;

DatabaseInfo FakeDatabaseInfo() {
  return DatabaseInfo(testutil::DbId(), "key", "example.com", true);
}

DatabaseInfo FakeDatabaseInfoOtherProject() {
  return DatabaseInfo(testutil::DbId("other-project"), "key", "example.com",
                      true);
}

void RunPersistence(LevelDbOpener* opener) {
  auto created = opener->Create(LruParams::Disabled());

  EXPECT_OK(created.status());
  auto persistence = std::move(created).ValueOrDie();
  persistence->Shutdown();
}

}  // namespace

TEST(LevelDbOpenerTest, CanFindAppDataDir) {
  LevelDbOpener opener(FakeDatabaseInfo());
  Path path = opener.AppDataDir();
  ASSERT_OK(opener.status());
  EXPECT_THAT(path.Basename().ToUtf8String(), testing::EndsWith("firestore"));
}

TEST(LevelDbOpenerTest, CanFindLegacyDocumentsDir) {
  LevelDbOpener opener(FakeDatabaseInfo());
  Path path = opener.LegacyDocumentsDir();
  EXPECT_OK(opener.status());
  EXPECT_THAT(path.Basename().ToUtf8String(), testing::EndsWith("firestore"));
}

TEST(LevelDbOpenerTest, CanMigrateLegacyData) {
  TestTempDir root_dir;

  // These names don't actually matter, and work on any platform
  Path legacy_dir = root_dir.Child("Documents/firestore");
  Path new_dir = root_dir.Child("Library/Application Support/firestore");

  ASSERT_THAT(IsDirectory(legacy_dir), IsNotFound());
  ASSERT_THAT(IsDirectory(new_dir), IsNotFound());

  DatabaseInfo db_info = FakeDatabaseInfo();
  {
    // Open as if the old way
    LevelDbOpener opener(db_info);
    ASSERT_FALSE(opener.PreferredExists(legacy_dir));

    RunPersistence(&opener);
    ASSERT_THAT(IsDirectory(legacy_dir), IsOk());
    ASSERT_THAT(IsDirectory(new_dir), IsNotFound());
  }

  {
    LevelDbOpener opener(db_info);
    ASSERT_FALSE(opener.PreferredExists(new_dir));
    opener.MaybeMigrate(legacy_dir);

    RunPersistence(&opener);
    ASSERT_THAT(IsDirectory(legacy_dir), IsNotFound());
    ASSERT_THAT(IsDirectory(new_dir), IsOk());
  }
}

TEST(LevelDbOpenerTest, MigrationPreservesUnrelatedData) {
  TestTempDir root_dir;

  Path legacy_dir = root_dir.Child("Documents/firestore");
  Path new_dir = root_dir.Child("Library/Application Support/firestore");

  DatabaseInfo db_info = FakeDatabaseInfo();
  DatabaseInfo other_info = FakeDatabaseInfoOtherProject();

  Path db_path = Path::JoinUtf8(legacy_dir, "key/project/main");
  Path other_path = Path::JoinUtf8(legacy_dir, "key/other-project/main");

  {
    // Run both projects as if the old way.
    LevelDbOpener db_opener(db_info);
    ASSERT_FALSE(db_opener.PreferredExists(legacy_dir));
    RunPersistence(&db_opener);
    ASSERT_THAT(IsDirectory(db_path), IsOk());

    LevelDbOpener other_opener(other_info);
    ASSERT_FALSE(other_opener.PreferredExists(legacy_dir));
    RunPersistence(&other_opener);
    ASSERT_THAT(IsDirectory(other_path), IsOk());
  }

  {
    LevelDbOpener db_opener(db_info);
    ASSERT_FALSE(db_opener.PreferredExists(new_dir));
    db_opener.MaybeMigrate(legacy_dir);
    RunPersistence(&db_opener);

    ASSERT_THAT(IsDirectory(db_path), IsNotFound());
    ASSERT_THAT(IsDirectory(other_path), IsOk());
  }
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
