/*
 * Copyright 2018 Google LLC
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

#include "Firestore/core/src/util/filesystem.h"

#if defined(_WIN32)
#include <cwchar>
#endif
#include <fstream>

#include "Firestore/core/src/util/autoid.h"
#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/path.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_win.h"
#include "Firestore/core/test/unit/testutil/filesystem_testing.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "absl/strings/match.h"
#include "absl/types/optional.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

using testutil::RandomFilename;
using testutil::TestTempDir;
using testutil::Touch;

static void WriteStringToFile(const Path& path, const std::string& text) {
  std::ofstream out{path.native_value()};
  ASSERT_TRUE(out.good());
  Defer cleanup([&] {
    out.close();
    ASSERT_TRUE(out.good());
  });

  out << text;
}

static void WriteBytesToFile(const Path& path, int byte_count) {
  WriteStringToFile(path, std::string(byte_count, 'a'));
}

#define ASSERT_NOT_FOUND(expression)                       \
  do {                                                     \
    ASSERT_EQ(Error::kErrorNotFound, (expression).code()); \
  } while (0)

#define EXPECT_NOT_FOUND(expression)                       \
  do {                                                     \
    ASSERT_EQ(Error::kErrorNotFound, (expression).code()); \
  } while (0)

#define EXPECT_FAILED_PRECONDITION(expression)                       \
  do {                                                               \
    ASSERT_EQ(Error::kErrorFailedPrecondition, (expression).code()); \
  } while (0)

class FilesystemTest : public testing::Test {
 protected:
  Filesystem* fs_ = Filesystem::Default();
};

TEST_F(FilesystemTest, Exists) {
  EXPECT_OK(fs_->IsDirectory(Path::FromUtf8("/")));

  Path file = Path::JoinUtf8("/", RandomFilename());
  EXPECT_NOT_FOUND(fs_->IsDirectory(file));
}

TEST_F(FilesystemTest, GetTempDir) {
  Path tmp = fs_->TempDir();
  ASSERT_NE("", tmp.ToUtf8String());
  ASSERT_OK(fs_->IsDirectory(tmp));
}

absl::optional<std::string> GetEnv(const char* name) {
#if defined(_WIN32)
  // The required buffer size (not the length of the value)
  size_t value_size = 0;
  errno_t result = getenv_s(&value_size, nullptr, 0, name);
  if (result) {
    ADD_FAILURE() << "getenv_s failed with errno=" << result;
    return absl::nullopt;
  }
  if (value_size == 0) return absl::nullopt;

  std::string value(value_size, '\0');
  result = getenv_s(&value_size, &value[0], value_size, name);
  if (result) {
    ADD_FAILURE() << "getenv_s failed with errno=" << result;
    return absl::nullopt;
  }

  value.resize(value_size - 1);

  return value;

#else
  const char* value = getenv(name);
  if (!value) return absl::nullopt;

  return std::string{value};
#endif  // defined(_WIN32)
}

int SetEnv(const char* env_var, const char* value) {
#if defined(_WIN32)
  return _putenv_s(env_var, value);
#else
  return setenv(env_var, value, 1);
#endif
}

int UnsetEnv(const char* env_var) {
#if defined(_WIN32)
  std::string entry{env_var};
  entry.push_back('=');
  return _putenv(entry.c_str());
#else
  return unsetenv(env_var);
#endif
}

TEST_F(FilesystemTest, GetTempDirNoTmpdir) {
  // Save aside old value of TMPDIR (if set) and force TMPDIR to unset.
  absl::optional<std::string> old_tmpdir = GetEnv("TMPDIR");
  if (old_tmpdir) {
    UnsetEnv("TMPDIR");
    ASSERT_EQ(absl::nullopt, GetEnv("TMPDIR"));
  }

  Path tmp = fs_->TempDir();
  ASSERT_NE("", tmp.ToUtf8String());
  ASSERT_OK(fs_->IsDirectory(tmp));

  // Return old value of TMPDIR, if set
  if (old_tmpdir) {
    int result = SetEnv("TMPDIR", old_tmpdir->c_str());
    ASSERT_EQ(0, result);
  }
}

TEST_F(FilesystemTest, RecursivelyCreateDir) {
  Path parent = Path::JoinUtf8(fs_->TempDir(), RandomFilename());
  Path dir = Path::JoinUtf8(parent, "middle", "leaf");

  ASSERT_OK(fs_->RecursivelyCreateDir(dir));
  ASSERT_OK(fs_->IsDirectory(dir));

  // Creating a directory that exists should succeed.
  ASSERT_OK(fs_->RecursivelyCreateDir(dir));

  ASSERT_OK(fs_->RecursivelyRemove(parent));
  ASSERT_NOT_FOUND(fs_->IsDirectory(dir));
}

TEST_F(FilesystemTest, RecursivelyCreateDirFailure) {
  Path dir = Path::JoinUtf8(fs_->TempDir(), RandomFilename());
  Path subdir = Path::JoinUtf8(dir, "middle", "leaf");

  // Create a file that interferes with creating the directory.
  Touch(dir);

  Status status = fs_->RecursivelyCreateDir(subdir);
  EXPECT_EQ(Error::kErrorFailedPrecondition, status.code());

  EXPECT_OK(fs_->RecursivelyRemove(dir));
}

TEST_F(FilesystemTest, RecursivelyRemove) {
  Path tmp_dir = fs_->TempDir();
  ASSERT_OK(fs_->IsDirectory(tmp_dir));

  Path file = Path::JoinUtf8(tmp_dir, RandomFilename());
  EXPECT_NOT_FOUND(fs_->IsDirectory(file));

  // Deleting something that doesn't exist should succeed.
  EXPECT_OK(fs_->RecursivelyRemove(file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(file));

  Path nested_file = Path::JoinUtf8(file, RandomFilename());
  EXPECT_OK(fs_->RecursivelyRemove(nested_file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(nested_file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(file));

  Touch(file);
  EXPECT_FAILED_PRECONDITION(fs_->IsDirectory(file));

  EXPECT_NOT_FOUND(fs_->IsDirectory(nested_file));
  EXPECT_OK(fs_->RecursivelyRemove(nested_file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(nested_file));

  EXPECT_OK(fs_->RecursivelyRemove(file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(nested_file));

  // Deleting some highly nested path should work.
  EXPECT_OK(fs_->RecursivelyRemove(nested_file));
}

TEST_F(FilesystemTest, RecursivelyRemoveTree) {
  TestTempDir root_dir;
  Path middle_dir = root_dir.Child("middle");
  Path leaf1_dir = Path::JoinUtf8(middle_dir, "leaf1");
  Path leaf2_dir = Path::JoinUtf8(middle_dir, "leaf2");
  ASSERT_OK(fs_->RecursivelyCreateDir(leaf1_dir));
  ASSERT_OK(fs_->RecursivelyCreateDir(leaf2_dir));

  Touch(Path::JoinUtf8(middle_dir, "a"));
  Touch(Path::JoinUtf8(middle_dir, "b"));
  Touch(Path::JoinUtf8(leaf1_dir, "1"));
  Touch(Path::JoinUtf8(leaf2_dir, "A"));
  Touch(Path::JoinUtf8(leaf2_dir, "B"));

  EXPECT_OK(fs_->RecursivelyRemove(root_dir.path()));
  EXPECT_NOT_FOUND(fs_->IsDirectory(root_dir.path()));
  EXPECT_NOT_FOUND(fs_->IsDirectory(leaf1_dir));
  EXPECT_NOT_FOUND(fs_->IsDirectory(Path::JoinUtf8(leaf2_dir, "A")));
}

TEST_F(FilesystemTest, RecursivelyRemovePreservesPeers) {
  TestTempDir root_dir;

  // Ensure that when deleting a directory we don't delete any directory that
  // has a name that's a suffix of that directory. (This matters because on
  // Win32 directories are traversed with a glob which can easily over-match.)
  Path child = root_dir.Child("child");
  Path child_suffix = root_dir.Child("child_suffix");

  ASSERT_OK(fs_->RecursivelyCreateDir(child));
  ASSERT_OK(fs_->RecursivelyCreateDir(child_suffix));

  ASSERT_OK(fs_->RecursivelyRemove(child));
  ASSERT_OK(fs_->IsDirectory(child_suffix));
}

TEST_F(FilesystemTest, FileSize) {
  Path file = Path::JoinUtf8(fs_->TempDir(), RandomFilename());
  ASSERT_NOT_FOUND(fs_->FileSize(file).status());
  Touch(file);
  StatusOr<int64_t> result = fs_->FileSize(file);
  ASSERT_OK(result.status());
  ASSERT_EQ(0, result.ValueOrDie());

  WriteBytesToFile(file, 100);
  result = fs_->FileSize(file);
  ASSERT_OK(result.status());
  ASSERT_EQ(100, result.ValueOrDie());

  EXPECT_OK(fs_->RecursivelyRemove(file));
}

TEST_F(FilesystemTest, ReadFile) {
  TestTempDir root_dir;
  Path file = root_dir.RandomChild();
  StatusOr<std::string> result = fs_->ReadFile(file);
  ASSERT_FALSE(result.ok());

  Touch(file);
  result = fs_->ReadFile(file);
  ASSERT_OK(result.status());
  ASSERT_TRUE(result.ValueOrDie().empty());

  WriteStringToFile(file, "foobar");
  result = fs_->ReadFile(file);
  ASSERT_OK(result.status());
  ASSERT_EQ(result.ValueOrDie(), "foobar");
}

TEST_F(FilesystemTest, IsEmptyDir) {
  TestTempDir root_dir;

  Path dir = root_dir.Child("empty");
  ASSERT_FALSE(IsEmptyDir(dir));

  ASSERT_OK(fs_->RecursivelyCreateDir(dir));
  ASSERT_TRUE(IsEmptyDir(dir));

  Path file = Path::JoinUtf8(dir, RandomFilename());
  Touch(file);
  ASSERT_FALSE(IsEmptyDir(dir));
}

TEST_F(FilesystemTest, Rename) {
  TestTempDir root_dir;

  Path src_file = root_dir.Child("src");
  Path dest_file = root_dir.Child("dest");

  EXPECT_NOT_FOUND(fs_->IsDirectory(src_file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(dest_file));

  ASSERT_OK(fs_->RecursivelyCreateDir(src_file));
  EXPECT_OK(fs_->IsDirectory(src_file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(dest_file));

  ASSERT_OK(fs_->Rename(src_file, dest_file));
  EXPECT_NOT_FOUND(fs_->IsDirectory(src_file));
  EXPECT_OK(fs_->IsDirectory(dest_file));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
