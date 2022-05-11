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

#ifndef FIRESTORE_CORE_SRC_LOCAL_LEVELDB_MIGRATIONS_H_
#define FIRESTORE_CORE_SRC_LOCAL_LEVELDB_MIGRATIONS_H_

#include <cstdint>

#include "Firestore/core/src/local/leveldb_transaction.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "leveldb/db.h"

namespace firebase {
namespace firestore {
namespace local {

class LevelDbMigrations {
 public:
  using SchemaVersion = int32_t;

  /**
   * Returns the current version of the schema for the given database
   */
  static SchemaVersion ReadSchemaVersion(leveldb::DB* db);

  /**
   * Runs any migrations needed to bring the given database up to the current
   * schema version
   */
  static void RunMigrations(leveldb::DB* db, const LocalSerializer& serializer);

  /**
   * Runs any migrations needed to bring the given database up to the given
   * schema version
   */
  static void RunMigrations(leveldb::DB* db,
                            SchemaVersion version,
                            const LocalSerializer& serializer);
};

/**
 * Schema version for the iOS client.
 *
 * Note that tables aren't a concept in LevelDB. They exist in our schema as
 * just prefixes on keys. This means tables don't need to be created but they
 * also can't easily be dropped and re-created.
 *
 * Migrations:
 *   * Migration 1 used to ensure the target_global row existed, without
 *     clearing it. No longer required because migration 3 unconditionally
 *     clears it.
 *   * Migration 2 used to ensure that the target_global row had a correct count
 *     of targets. No longer required because migration 3 deletes them all.
 *   * Migration 3 deletes the entire query cache to deal with cache corruption
 *     related to limbo resolution. Addresses
 *     https://github.com/firebase/firebase-ios-sdk/issues/1548.
 *   * Migration 4 ensures that every document in the remote document cache
 *     has a sentinel row with a sequence number.
 *   * Migration 5 drops held write acks.
 *   * Migration 6 populates the collection_parents index.
 *   * Migration 7 rewrites query_targets canonical ids in new format.
 *   * Migration 8 kicks off overlay data migration.
 */
const LevelDbMigrations::SchemaVersion kSchemaVersion = 8;

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_LEVELDB_MIGRATIONS_H_
