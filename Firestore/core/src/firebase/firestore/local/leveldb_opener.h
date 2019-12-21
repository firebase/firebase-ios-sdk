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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_OPENER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_OPENER_H_

#include <memory>

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {

namespace util {
template <typename T>
class StatusOr;
}  // namespace util

namespace local {

class LevelDbPersistence;
struct LruParams;

class LevelDbOpener {
 public:
  explicit LevelDbOpener(core::DatabaseInfo database_info);

  /**
   * Finds a suitable directory to serve as the root of all Firestore local
   * storage.
   */
  util::Path AppDataDir();

  /**
   * Finds the location where Firestore used to keep local storage.
   */
  util::Path LegacyDocumentsDir();

  /**
   * Computes a unique storage directory for the given identifying components of
   * local storage.
   *
   * @param base_path The root application data directory relative to which
   *     the instance-specific storage directory will be created. Usually just
   *     `AppDataDir()`.
   * @return A storage directory unique to the instance identified by
   *     `database_info`.
   */
  util::Path StorageDir(const util::Path& base_path);

  bool PreferredExists(const util::Path& app_data_dir);

  void MaybeMigrate(const util::Path& legacy_docs_dir);

  util::StatusOr<std::unique_ptr<LevelDbPersistence>> Create(
      const LruParams& lru_params);

  bool ok() const {
    return status_.ok();
  }

  const util::Status& status() const {
    return status_;
  }

 private:
  bool IsDirectory(const util::Path& path);

  static void RecursivelyCleanupLegacyDirs(util::Path legacy_dir,
                                           const util::Path& container_dir);

  core::DatabaseInfo database_info_;
  util::Path preferred_dir_;
  bool preferred_exists_ = false;
  util::Status status_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_OPENER_H_
