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

#include "Firestore/core/src/firebase/firestore/util/filesystem.h"

#if defined(_WIN32)
#include <cwchar>
#endif
#include <fstream>

#include "Firestore/core/src/firebase/firestore/util/autoid.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/string_win.h"
#include "Firestore/core/test/firebase/firestore/util/status_test_util.h"
#include "absl/strings/match.h"
#include "absl/types/optional.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

/** Creates an empty file at the given path. */
static void Touch(const Path& path) {
  std::ofstream out{path.native_value()};
  ASSERT_TRUE(out.good());
  out.close();
}

/** Creates a random filename that doesn't exist. */
static Path TestFilename() {
  return Path::FromUtf8("firestore-testing-" + CreateAutoId());
}

TEST(FilesystemTest, Exists) {
  EXPECT_TRUE(Exists(Path::FromUtf8("/")));

  Path file = Path::JoinUtf8("/", TestFilename());
  EXPECT_FALSE(Exists(file));
}

#if defined(_WIN32)
#define ASSERT_USEFUL_TEMP_DIR(dir)                          \
  do {                                                       \
    ASSERT_TRUE(absl::StartsWith(tmp.ToUtf8String(), "C:")); \
  } while (0)

#else
#define ASSERT_USEFUL_TEMP_DIR(dir)                         \
  do {                                                      \
    ASSERT_TRUE(absl::StartsWith(tmp.ToUtf8String(), "/")); \
  } while (0)
#endif  // defined(_WIN32)

TEST(FilesystemTest, GetTempDir) {
  Path tmp = TempDir();
  ASSERT_USEFUL_TEMP_DIR(tmp);
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
#endif
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

TEST(FilesystemTest, GetTempDirNoTmpdir) {
  // Save aside old value of TMPDIR (if set) and force TMPDIR to unset.
  absl::optional<std::string> old_tmpdir = GetEnv("TMPDIR");
  if (old_tmpdir) {
    UnsetEnv("TMPDIR");
    ASSERT_EQ(absl::nullopt, GetEnv("TMPDIR"));
  }

  Path tmp = TempDir();
  ASSERT_USEFUL_TEMP_DIR(tmp);

  // Return old value of TMPDIR, if set
  if (old_tmpdir) {
    int result = SetEnv("TMPDIR", old_tmpdir->c_str());
    ASSERT_EQ(0, result);
  }
}

TEST(FilesystemTest, RecursivelyCreateDir) {
  Path parent = Path::JoinUtf8(TempDir(), TestFilename());
  Path dir = Path::JoinUtf8(parent, "middle", "leaf");

  Status status = RecursivelyCreateDir(dir);
  ASSERT_OK(status);
  ASSERT_TRUE(Exists(dir));

  status = RecursivelyDelete(parent);
  ASSERT_OK(status);
  ASSERT_FALSE(Exists(dir));
}

TEST(FilesystemTest, RecursivelyCreateDirFailure) {
  Path dir = Path::JoinUtf8(TempDir(), TestFilename());
  Path subdir = Path::JoinUtf8(dir, "middle", "leaf");

  // Create a file that interferes with creating the directory.
  Touch(dir);

  Status status = RecursivelyCreateDir(subdir);
  EXPECT_EQ(FirestoreErrorCode::FailedPrecondition, status.code());

  status = RecursivelyDelete(dir);
  EXPECT_OK(status);
}

TEST(FilesystemTest, RecursivelyDelete) {
  Path tmp_dir = TempDir();
  ASSERT_TRUE(Exists(tmp_dir));

  Path file = Path::JoinUtf8(tmp_dir, TestFilename());
  Status status = RecursivelyDelete(file);
  EXPECT_OK(status);
  EXPECT_FALSE(Exists(file));

  Touch(file);
  EXPECT_TRUE(Exists(file));

  status = RecursivelyDelete(file);
  EXPECT_OK(status);
  EXPECT_FALSE(Exists(file));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
