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

#import "Firestore/Source/Local/FSTLevelDBMigrations.h"

#include <string>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/base/macros.h"
#include "absl/memory/memory.h"
#include "absl/strings/match.h"
#include "leveldb/write_batch.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Schema version for the iOS client.
 *
 * Note that tables aren't a concept in LevelDB. They exist in our schema as just prefixes on keys.
 * This means tables don't need to be created but they also can't easily be dropped and re-created.
 *
 * Migrations:
 *   * Migration 1 used to ensure the target_global row existed, without clearing it. No longer
 *     required because migration 3 unconditionally clears it.
 *   * Migration 2 used to ensure that the target_global row had a correct count of targets. No
 *     longer required because migration 3 deletes them all.
 *   * Migration 3 deletes the entire query cache to deal with cache corruption related to
 *     limbo resolution. Addresses https://github.com/firebase/firebase-ios-sdk/issues/1548.
 */
static FSTLevelDBSchemaVersion kSchemaVersion = 3;

using firebase::firestore::local::LevelDbTransaction;
using leveldb::Iterator;
using leveldb::Status;
using leveldb::Slice;
using leveldb::WriteOptions;

/**
 * Save the given version number as the current version of the schema of the database.
 * @param version The version to save
 * @param transaction The transaction in which to save the new version number
 */
static void SaveVersion(FSTLevelDBSchemaVersion version, LevelDbTransaction *transaction) {
  std::string key = [FSTLevelDBVersionKey key];
  std::string version_string = std::to_string(version);
  transaction->Put(key, version_string);
}

static void DeleteEverythingWithPrefix(const std::string &prefix, leveldb::DB *db) {
  bool more_deletes = true;
  while (more_deletes) {
    LevelDbTransaction transaction(db, "Delete everything with prefix");
    auto it = transaction.NewIterator();

    more_deletes = false;
    for (it->Seek(prefix); it->Valid() && absl::StartsWith(it->key(), prefix); it->Next()) {
      if (transaction.changed_keys() >= 1000) {
        more_deletes = true;
        break;
      }
      transaction.Delete(it->key());
    }

    transaction.Commit();
  }
}

/** Migration 3. */
static void ClearQueryCache(leveldb::DB *db) {
  DeleteEverythingWithPrefix([FSTLevelDBTargetKey keyPrefix], db);
  DeleteEverythingWithPrefix([FSTLevelDBDocumentTargetKey keyPrefix], db);
  DeleteEverythingWithPrefix([FSTLevelDBTargetDocumentKey keyPrefix], db);
  DeleteEverythingWithPrefix([FSTLevelDBQueryTargetKey keyPrefix], db);

  LevelDbTransaction transaction(db, "Drop query cache");

  // Reset the target global entry too (to reset the target count).
  transaction.Put([FSTLevelDBTargetGlobalKey key], [FSTPBTargetGlobal message]);

  SaveVersion(3, &transaction);
  transaction.Commit();
}

@implementation FSTLevelDBMigrations

+ (FSTLevelDBSchemaVersion)schemaVersionWithTransaction:
    (firebase::firestore::local::LevelDbTransaction *)transaction {
  std::string key = [FSTLevelDBVersionKey key];
  std::string version_string;
  Status status = transaction->Get(key, &version_string);
  if (status.IsNotFound()) {
    return 0;
  } else {
    return stoi(version_string);
  }
}

+ (void)runMigrationsWithDatabase:(leveldb::DB *)database {
  [self runMigrationsWithDatabase:database upToVersion:kSchemaVersion];
}

+ (void)runMigrationsWithDatabase:(leveldb::DB *)database
                      upToVersion:(FSTLevelDBSchemaVersion)toVersion {
  LevelDbTransaction transaction{database, "Read schema version"};
  FSTLevelDBSchemaVersion fromVersion = [self schemaVersionWithTransaction:&transaction];

  // This must run unconditionally because schema migrations were added to iOS after the first
  // release. There may be clients that have never run any migrations that have existing targets.
  if (fromVersion < 3 && toVersion >= 3) {
    ClearQueryCache(database);
  }
}

@end

NS_ASSUME_NONNULL_END
