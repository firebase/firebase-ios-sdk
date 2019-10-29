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

#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

#if !defined(__APPLE__) && !defined(_WIN32)

#include <pwd.h>
#include <sys/types.h>
#include <unistd.h>

namespace firebase {
namespace firestore {
namespace local {

using util::Path;

Path LevelDbPersistence::AppDataDirectory() {
  const char* home_dir;

  if ((home_dir = getenv("HOME")) == NULL) {
    home_dir = getpwuid(getuid())->pw_dir;
  }

  std::string dot_prefixed = absl::StrCat(".", kReservedPathComponent);
  return Path::FromUtf8(std::string(home_dir)).AppendUtf8(dot_prefixed);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // !defined(__APPLE__) && !defined(_WIN32)
