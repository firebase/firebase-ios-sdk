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

#if !__APPLE__ && !_WIN32

#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>

#include <cerrno>
#include <cstdlib>

namespace firebase {
namespace firestore {
namespace local {
namespace {

using util::Path;
using util::Status;
using util::StatusOr;

StatusOr<Path> GetHomeDirectory() {
  const char* home_dir = getenv("HOME");
  if (home_dir) return Path::FromUtf8(home_dir);

  passwd pwd;
  passwd* result;
  std::string buffer(sysconf(_SC_GETPW_R_SIZE_MAX), '\0');
  uid_t uid = getuid();
  int rc;
  do {
    rc = getpwuid_r(uid, &pwd, &buffer[0], buffer.size(), &result);
  } while (rc == EINTR);

  if (rc != 0) {
    return Status::FromErrno(
        rc, "Failed to find the home directory for the current user");
  }

  return Path::FromUtf8(pwd.pw_dir);
}

StatusOr<Path> GetDataHomeDirectory() {
  const char* data_home = getenv("XDG_DATA_HOME");
  if (data_home) return Path::FromUtf8(data_home);

  StatusOr<Path> maybe_home_dir = GetHomeDirectory();
  if (!maybe_home_dir.ok()) return maybe_home_dir;

  const Path& home_dir = maybe_home_dir.ValueOrDie();
  return home_dir.AppendUtf8(".local/share");
}

}  // namespace

StatusOr<Path> LevelDbPersistence::AppDataDirectory() {
#if __linux__ && !__ANDROID__
  StatusOr<Path> maybe_data_home = GetDataHomeDirectory();
  if (!maybe_data_home.ok()) return maybe_data_home;

  return maybe_data_home.ValueOrDie().AppendUtf8(kReservedPathComponent);

#else

  StatusOr<Path> maybe_home = GetHomeDirectory();
  if (!maybe_home.ok()) return maybe_home;

  std::string dot_prefixed = absl::StrCat(".", kReservedPathComponent);
  return maybe_home.ValueOrDie().AppendUtf8(dot_prefixed);

#endif  // __linux__ && !__ANDROID__
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // !__APPLE__ && !_WIN32
