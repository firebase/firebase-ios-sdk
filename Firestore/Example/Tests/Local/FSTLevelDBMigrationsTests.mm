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

#import <XCTest/XCTest.h>
#include <leveldb/db.h>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Local/FSTLevelDBMigrations.h"
#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"

#include "Firestore/core/src/firebase/firestore/util/ordered_code.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::util::OrderedCode;
using leveldb::DB;
using leveldb::Options;
using leveldb::Status;

@interface FSTLevelDBMigrationsTests : XCTestCase
@end

@implementation FSTLevelDBMigrationsTests {
  std::shared_ptr<DB> _db;
}

- (void)setUp {
  Options options;
  options.error_if_exists = true;
  options.create_if_missing = true;

  NSString *dir = [FSTPersistenceTestHelpers levelDBDir];
  DB *db;
  Status status = DB::Open(options, [dir UTF8String], &db);
  XCTAssert(status.ok(), @"Failed to create db: %s", status.ToString().c_str());
  _db.reset(db);
}

- (void)tearDown {
  _db.reset();
}

- (void)testAddsTargetGlobal {
  FSTPBTargetGlobal *metadata = [FSTLevelDBQueryCache readTargetMetadataFromDB:_db];
  XCTAssertNil(metadata, @"Not expecting metadata yet, we should have an empty db");
  LevelDbTransaction transaction(_db.get());
  [FSTLevelDBMigrations runMigrationsWithTransaction:&transaction];
  transaction.Commit();
  metadata = [FSTLevelDBQueryCache readTargetMetadataFromDB:_db];
  XCTAssertNotNil(metadata, @"Migrations should have added the metadata");
}

- (void)testSetsVersionNumber {
  LevelDbTransaction transaction(_db.get());
  FSTLevelDBSchemaVersion initial =
      [FSTLevelDBMigrations schemaVersionWithTransaction:&transaction];
  XCTAssertEqual(0, initial, "No version should be equivalent to 0");

  // Pick an arbitrary high migration number and migrate to it.
  [FSTLevelDBMigrations runMigrationsWithTransaction:&transaction];
  FSTLevelDBSchemaVersion actual = [FSTLevelDBMigrations schemaVersionWithTransaction:&transaction];
  XCTAssertGreaterThan(actual, 0, @"Expected to migrate to a schema version > 0");
}

- (void)testCountsQueries {
  NSUInteger expected = 50;
  {
    // Setup some targets to be counted in the migration.
    LevelDbTransaction transaction(_db.get());
    for (int i = 0; i < expected; i++) {
      std::string key = [FSTLevelDBTargetKey keyWithTargetID:i];
      transaction.Put(key, "dummy");
    }
    // Add a dummy entry after the targets to make sure the iteration is correctly bounded.
    // Use a table that would sort logically right after that table 'target'.
    std::string dummyKey;
    // Magic number that indicates a table name follows. Needed to mimic the prefix to the target
    // table.
    OrderedCode::WriteSignedNumIncreasing(&dummyKey, 5);
    OrderedCode::WriteString(&dummyKey, "targetA");
    transaction.Put(dummyKey, "dummy");
    transaction.Commit();
  }

  {
    LevelDbTransaction transaction(_db.get());
    [FSTLevelDBMigrations runMigrationsWithTransaction:&transaction];
    transaction.Commit();
    FSTPBTargetGlobal *metadata = [FSTLevelDBQueryCache readTargetMetadataFromDB:_db];
    XCTAssertEqual(expected, metadata.targetCount, @"Failed to count all of the targets we added");
  }
}

@end

NS_ASSUME_NONNULL_END
