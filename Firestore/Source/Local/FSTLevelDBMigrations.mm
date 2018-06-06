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
#include "absl/strings/match.h"
#include "leveldb/write_batch.h"

NS_ASSUME_NONNULL_BEGIN

// Current version of the schema defined in this file.
static FSTLevelDBSchemaVersion kSchemaVersion = 2;

using firebase::firestore::local::LevelDbTransaction;
using leveldb::DB;
using leveldb::Iterator;
using leveldb::Status;
using leveldb::Slice;
using leveldb::WriteOptions;

/**
 * Ensures that the global singleton target metadata row exists in LevelDB.
 */
static void EnsureTargetGlobal(LevelDbTransaction *transaction) {
  FSTPBTargetGlobal *targetGlobal =
      [FSTLevelDBQueryCache readTargetMetadataWithTransaction:transaction];
  if (!targetGlobal) {
    transaction->Put([FSTLevelDBTargetGlobalKey key], [FSTPBTargetGlobal message]);
  }
}

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

/**
 * This function counts the number of targets that currently exist in the given db. It
 * then reads the target global row, adds the count to the metadata from that row, and writes
 * the metadata back.
 *
 * It assumes the metadata has already been written and is able to be read in this transaction.
 */
static void AddTargetCount(LevelDbTransaction *transaction) {
  auto it = transaction->NewIterator();
  std::string start_key = [FSTLevelDBTargetKey keyPrefix];
  it->Seek(start_key);

  int32_t count = 0;
  while (it->Valid() && absl::StartsWith(it->key(), start_key)) {
    count++;
    it->Next();
  }

  FSTPBTargetGlobal *targetGlobal =
      [FSTLevelDBQueryCache readTargetMetadataWithTransaction:transaction];
  HARD_ASSERT(targetGlobal != nil,
              "We should have a metadata row as it was added in an earlier migration");
  targetGlobal.targetCount = count;
  transaction->Put([FSTLevelDBTargetGlobalKey key], targetGlobal);
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

+ (void)runMigrationsWithTransaction:(firebase::firestore::local::LevelDbTransaction *)transaction {
  FSTLevelDBSchemaVersion currentVersion = [self schemaVersionWithTransaction:transaction];
  // Each case in this switch statement intentionally falls through. This lets us
  // start at the current schema version and apply any migrations that have not yet
  // been applied, to bring us up to current, as defined by the kSchemaVersion constant.
  switch (currentVersion) {
    case 0:
      EnsureTargetGlobal(transaction);
      // Fallthrough
    case 1:
      // We're now guaranteed that the target global exists. We can safely add a count to it.
      AddTargetCount(transaction);
      // Fallthrough
    default:
      if (currentVersion < kSchemaVersion) {
        SaveVersion(kSchemaVersion, transaction);
      }
  }
}

@end

NS_ASSUME_NONNULL_END
