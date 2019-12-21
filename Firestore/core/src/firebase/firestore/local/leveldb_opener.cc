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

#include <string>

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/util/filesystem.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using core::DatabaseInfo;
using util::Path;
using util::StatusOr;

constexpr const char* kReservedPathComponent = "firestore";

}  // namespace

StatusOr<Path> LevelDbOpener::AppDataDir() {
  return util::AppDataDir(kReservedPathComponent);
}

Path LevelDbOpener::StorageDir(const Path& base_path,
                               const DatabaseInfo& database_info) {
  // Use two different path formats:
  //
  //   * persistence_key / project_id . database_id / name
  //   * persistence_key / project_id / name
  //
  // project_ids are DNS-compatible names and cannot contain dots so there's
  // no danger of collisions.
  std::string project_key = database_info.database_id().project_id();
  if (!database_info.database_id().IsDefaultDatabase()) {
    absl::StrAppend(&project_key, ".",
                    database_info.database_id().database_id());
  }

  // Reserve one additional path component to allow multiple physical databases
  return Path::JoinUtf8(base_path, database_info.persistence_key(), project_key,
                        "main");
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
