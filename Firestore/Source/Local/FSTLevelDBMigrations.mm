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

#include "Firestore/Source/Local/FSTLevelDBMigrations.h"

#include <leveldb/db.h>
#include <leveldb/write_batch.h>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"
#import "Firestore/Source/Local/FSTWriteGroup.h"

NS_ASSUME_NONNULL_BEGIN

// Current version of the schema defined in this file.
static FSTLevelDBSchemaVersion kSchemaVersion = 1;

using leveldb::DB;
using leveldb::Iterator;
using leveldb::Status;
using leveldb::Slice;
using leveldb::WriteOptions;

/**
 * Ensures that the global singleton target metadata row exists in LevelDB.
 * @param db The db in which to require the row.
 */
static void EnsureTargetGlobal(std::shared_ptr<DB> db, FSTWriteGroup *group) {
  FSTPBTargetGlobal *targetGlobal = [FSTLevelDBQueryCache readTargetMetadataFromDB:db];
  if (!targetGlobal) {
    [group setMessage:[FSTPBTargetGlobal message] forKey:[FSTLevelDBTargetGlobalKey key]];
  }
}

/**
 * Save the given version number as the current version of the schema of the database.
 * @param version The version to save
 * @param group The transaction in which to save the new version number
 */
static void SaveVersion(FSTLevelDBSchemaVersion version, FSTWriteGroup *group) {
  std::string key = [FSTLevelDBVersionKey key];
  std::string version_string = std::to_string(version);
  [group setData:version_string forKey:key];
}

static void AddTargetCount(std::shared_ptr<DB> db) {
  std::unique_ptr<Iterator> it(db->NewIterator([FSTLevelDBUtil standardReadOptions]));
  Slice start_key = [FSTLevelDBTargetKey keyPrefix];
  it->Seek(start_key);

  NSUInteger count = 0;
  while (it->Valid() && it->key().starts_with(start_key)) {
    count++;
    it->Next();
  }

  FSTPBTargetGlobal *targetGlobal = [FSTLevelDBUtil readTargetMetadataFromDB:db];
  FSTCAssert(targetGlobal != nil, @"We should have a metadata row as it was added in an earlier migration");
  targetGlobal.targetCount = count;
  SaveTargetGlobal(targetGlobal, db);
}

@implementation FSTLevelDBMigrations

+ (FSTLevelDBSchemaVersion)schemaVersionForDB:(std::shared_ptr<DB>)db {
  std::string key = [FSTLevelDBVersionKey key];
  std::string version_string;
  Status status = db->Get([FSTLevelDB standardReadOptions], key, &version_string);
  if (status.IsNotFound()) {
    return 0;
  } else {
    return stoi(version_string);
  }
}

+ (void)runMigrationsOnDB:(std::shared_ptr<DB>)db {
  FSTWriteGroup *group = [FSTWriteGroup groupWithAction:@"Migrations"];
  FSTLevelDBSchemaVersion currentVersion = [self schemaVersionForDB:db];
  // Each case in this switch statement intentionally falls through. This lets us
  // start at the current schema version and apply any migrations that have not yet
  // been applied, to bring us up to current, as defined by the kSchemaVersion constant.
  switch (currentVersion) {
    case 0:
      EnsureTargetGlobal(db, group);
      // Fallthrough
    case 1:
      AddTargetCount(db);
      // Fallthrough
    default:
      if (currentVersion < kSchemaVersion) {
        SaveVersion(kSchemaVersion, group);
      }
  }
  if (!group.isEmpty) {
    [group writeToDB:db];
  }
}

@end

NS_ASSUME_NONNULL_END
