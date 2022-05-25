/*
 * Copyright 2022 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_LOCAL_LEVELDB_OVERLAY_MIGRATION_MANAGER_H_
#define FIRESTORE_CORE_SRC_LOCAL_LEVELDB_OVERLAY_MIGRATION_MANAGER_H_

#include <string>

#include "Firestore/core/src/local/overlay_migration_manager.h"

namespace firebase {
namespace firestore {
namespace local {

class LevelDbPersistence;
class LocalStore;

class LevelDbOverlayMigrationManager : public OverlayMigrationManager {
 public:
  /**
   * Creates a new data migration manager.
   *
   * @param db The underlying LevelDb Persistence to use for data migrations.
   * @param uid The target uid the SDK is initialized with. Resources created
   * for other users during migration will be released at the end of migration.
   */
  LevelDbOverlayMigrationManager(LevelDbPersistence* db, const std::string& uid)
      : db_(db), uid_(uid) {
  }

  void Run() override;

 private:
  friend class LevelDbOverlayMigrationManagerTest;

  bool HasPendingOverlayMigration();

  // The LevelDbOverlayMigrationManager is owned by LevelDbPersistence.
  LevelDbPersistence* db_;

  std::string uid_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_LEVELDB_OVERLAY_MIGRATION_MANAGER_H_
