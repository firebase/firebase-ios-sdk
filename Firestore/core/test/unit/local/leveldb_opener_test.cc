/*
 * Copyright 2020 Google LLC
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

#include "Firestore/core/src/local/leveldb_opener.h"

#include "Firestore/core/src/core/database_info.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/autoid.h"
#include "Firestore/core/src/util/filesystem.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/test/unit/testutil/filesystem_testing.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "Firestore/core/test/unit/testutil/testutil.h"
#include "absl/strings/str_cat.h"
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
using testutil::IsPermissionDenied;
using testutil::IsUnimplemented;
using testutil::TestTempDir;
using util::CreateAutoId;
using util::Filesystem;
using util::Path;
using util::Status;
using util::StatusOr;

using testing::_;
using testing::NiceMock;
using testing::Return;

DatabaseInfo FakeDatabaseInfo() {
  return DatabaseInfo(testutil::DbId(), "key", "example.com", true);
}

DatabaseInfo FakeDatabaseInfoOtherProject() {
  return DatabaseInfo(testutil::DbId("other-project"), "key", "example.com",
                      true);
}

void RunPersistence(LevelDbOpener* opener) {
  auto created = opener->Create(LruParams::Disabled());

  ASSERT_OK(created.status());
  auto persistence = std::move(created).ValueOrDie();
  persistence->Shutdown();
}

}  // namespace

TEST(LevelDbOpenerTest, CanFindAppDataDir) {
  LevelDbOpener opener(FakeDatabaseInfo());
  StatusOr<Path> maybe_dir = opener.FirestoreAppDataDir();
  ASSERT_OK(maybe_dir.status());

  Path dir = maybe_dir.ValueOrDie();
  EXPECT_THAT(dir.Basename().ToUtf8String(), testing::EndsWith("firestore"));
}

TEST(LevelDbOpenerTest, CanFindLegacyAppDataDir) {
  LevelDbOpener opener(FakeDatabaseInfo());
  StatusOr<Path> maybe_dir = opener.FirestoreLegacyAppDataDir();
#if TARGET_OS_IOS || TARGET_OS_OSX
  EXPECT_OK(maybe_dir.status());

  Path dir = maybe_dir.ValueOrDie();
  EXPECT_THAT(dir.Basename().ToUtf8String(), testing::EndsWith("firestore"));
#else

  ASSERT_THAT(maybe_dir.status(), IsUnimplemented());
#endif
}

/**
 * A Filesystem that implements modern behavior for macOS and iOS, where data
 * might be migrated.
 */
class MigratingFilesystem : public Filesystem {
 public:
  explicit MigratingFilesystem(Path root_dir) : root_dir_(std::move(root_dir)) {
  }

  StatusOr<Path> AppDataDir(absl::string_view app_name) override {
    return Path::JoinUtf8(root_dir_, "Library/Application Support", app_name);
  }

  StatusOr<Path> LegacyDocumentsDir(absl::string_view app_name) override {
    return Path::JoinUtf8(root_dir_, "Documents", app_name);
  }

 private:
  Path root_dir_;
};

TEST(LevelDbOpenerTest, CanMigrateLegacyData) {
  TestTempDir root_dir;
  MigratingFilesystem fs(root_dir.path());

  Path modern_dir = fs.AppDataDir("firestore").ValueOrDie();
  Path legacy_dir = fs.LegacyDocumentsDir("firestore").ValueOrDie();

  DatabaseInfo db_info = FakeDatabaseInfo();
  {
    // Open as if the old way
    LevelDbOpener opener(db_info, legacy_dir);
    RunPersistence(&opener);
    ASSERT_THAT(fs.IsDirectory(modern_dir), IsNotFound());
    ASSERT_THAT(fs.IsDirectory(legacy_dir), IsOk());
  }

  {
    // Using the new filesystem, verify the migration actually happened.
    LevelDbOpener opener(db_info, &fs);
    RunPersistence(&opener);
    ASSERT_THAT(fs.IsDirectory(modern_dir), IsOk());
    ASSERT_THAT(fs.IsDirectory(legacy_dir), IsNotFound());
  }
}

TEST(LevelDbOpenerTest, MigrationPreservesUnrelatedData) {
  TestTempDir root_dir;
  MigratingFilesystem fs(root_dir.path());

  DatabaseInfo db_info = FakeDatabaseInfo();
  DatabaseInfo other_info = FakeDatabaseInfoOtherProject();

  Path modern_dir = fs.AppDataDir("firestore").ValueOrDie();
  Path legacy_dir = fs.LegacyDocumentsDir("firestore").ValueOrDie();

  Path db_path = Path::JoinUtf8(legacy_dir, "key/project/main");
  Path other_path = Path::JoinUtf8(legacy_dir, "key/other-project/main");

  {
    // Run both projects as if the old way.
    LevelDbOpener db_opener(db_info, legacy_dir);
    RunPersistence(&db_opener);
    ASSERT_THAT(fs.IsDirectory(db_path), IsOk());

    LevelDbOpener other_opener(other_info, legacy_dir);
    RunPersistence(&other_opener);
    ASSERT_THAT(fs.IsDirectory(other_path), IsOk());
  }

  {
    // Migrate one of them; the other data should be preserved.
    LevelDbOpener db_opener(db_info, &fs);
    RunPersistence(&db_opener);

    Path migrated = Path::JoinUtf8(modern_dir, "key/project/main");
    ASSERT_THAT(fs.IsDirectory(migrated), IsOk());
    ASSERT_THAT(fs.IsDirectory(db_path), IsNotFound());
    ASSERT_THAT(fs.IsDirectory(other_path), IsOk());
  }
}

/**
 * A Filesystem that implements modern behavior for other platforms, where
 * there's no legacy documents directory.
 */
class OtherFilesystem : public Filesystem {
 public:
  explicit OtherFilesystem(Path root_dir) : root_dir_(std::move(root_dir)) {
  }

  StatusOr<Path> AppDataDir(absl::string_view app_name) override {
    return Path::JoinUtf8(root_dir_, absl::StrCat(".", app_name));
  }

  StatusOr<Path> LegacyDocumentsDir(absl::string_view) override {
    return Status(Error::kErrorUnimplemented, "unimplemented");
  }

 private:
  Path root_dir_;
};

TEST(LevelDbOpenerTest, WorksWithoutLegacyData) {
  TestTempDir root_dir;
  OtherFilesystem other_fs(root_dir.path());

  Path data_dir = other_fs.AppDataDir("firestore").ValueOrDie();
  ASSERT_THAT(other_fs.IsDirectory(data_dir), IsNotFound());

  DatabaseInfo db_info = FakeDatabaseInfo();

  LevelDbOpener opener(db_info, &other_fs);
  RunPersistence(&opener);
  ASSERT_THAT(other_fs.IsDirectory(data_dir), IsOk());
}

class MockFilesystem : public Filesystem {
 public:
  MOCK_METHOD1(AppDataDir, StatusOr<Path>(absl::string_view));
};

TEST(LevelDbOpenerTest, HandlesAppDataDirFailure) {
  NiceMock<MockFilesystem> fs;

  EXPECT_CALL(fs, AppDataDir)
      .WillRepeatedly(Return(Status(Error::kErrorPermissionDenied, "EPERM")));

  DatabaseInfo db_info = FakeDatabaseInfo();
  LevelDbOpener opener(db_info, &fs);
  auto created = opener.Create(LruParams::Disabled());
  ASSERT_THAT(created.status(), IsPermissionDenied());
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
