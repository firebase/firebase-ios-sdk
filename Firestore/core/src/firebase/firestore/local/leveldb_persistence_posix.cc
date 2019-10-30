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

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

#if !defined(__APPLE__) && !defined(_WIN32)

#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>
#include <cstdlib>

namespace firebase {
namespace firestore {
namespace local {
namespace {

using util::Path;
using util::Status;
using util::StatusOr;

StatusOr<Path> GetHomeDirectory() {
  if (getenv("HOME") == nullptr) {
    struct passwd pwd;
    struct passwd* result;
    std::string buffer(sysconf(_SC_GETPW_R_SIZE_MAX), '\0');
    getpwuid_r(getuid(), &pwd, &buffer[0], buffer.size(), &result);

    if (result == nullptr) {
      return Status(Error::NotFound,
                    "Failed to find a directory to write LevelDB data files.");
    }
    return Path::FromUtf8(pwd.pw_dir);
  }

  return Path::FromUtf8(getenv("HOME"));
}

StatusOr<Path> GetDataHomeDirectory() {
  if (getenv("XDG_DATA_HOME") == nullptr) {
    const Path& home_dir = GetHomeDirectory().ValueOrDie();
    return home_dir.AppendUtf8(".local/share");
  }

  return Path::FromUtf8(getenv("XDG_DATA_HOME"));
}

}  // namespace

Path LevelDbPersistence::AppDataDirectory() {
  std::string dot_prefixed = absl::StrCat(".", kReservedPathComponent);

#if defined(__linux__) && !defined(__ANDROID__)
  const Path& dir = GetDataHomeDirectory().ValueOrDie();
  return dir.AppendUtf8(dot_prefixed);

#else

  const Path& dir = GetHomeDirectory().ValueOrDie();
  return dir.AppendUtf8(dot_prefixed);

#endif  // defined(__linux__) && !defined(__ANDROID__)
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__) && !defined(_WIN32)
