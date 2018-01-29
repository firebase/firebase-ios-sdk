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
#import "Firestore/Source/Local/FSTLevelDBMigrations.h"
#import "Firestore/Source/Local/FSTLevelDBUtil.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

NS_ASSUME_NONNULL_BEGIN

using leveldb::DB;
using leveldb::Options;
using leveldb::Status;

@interface FSTLevelDBMigrationsTests : XCTestCase
@end

@implementation FSTLevelDBMigrationsTests {
  std::unique_ptr<DB> _db;
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
  FSTPBTargetGlobal *metadata = [FSTLevelDBUtil readTargetMetadataFromDB:_db.get()];
  XCTAssertNil(metadata, @"Not expecting metadata yet, we should have an empty db");
  [FSTLevelDBMigrations runMigrationsToVersion:0 onDB:_db.get()];
  metadata = [FSTLevelDBUtil readTargetMetadataFromDB:_db.get()];
  XCTAssertNotNil(metadata, @"Migrations should have added the metadata");
}

- (void)testSetsVersionNumber {
  FSTLevelDBSchemaVersion initial = [FSTLevelDBMigrations schemaVersionForDB:_db.get()];
  XCTAssertEqual(0, initial, "No version should be equivalent to 0");

  // Pick an arbitrary high migration number and migrate to it.
  FSTLevelDBSchemaVersion target = 1000;
  [FSTLevelDBMigrations runMigrationsToVersion:target onDB:_db.get()];
  FSTLevelDBSchemaVersion actual = [FSTLevelDBMigrations schemaVersionForDB:_db.get()];
  XCTAssertEqual(target, actual, @"Expected to save the target version that we migrated to");
}

@end

NS_ASSUME_NONNULL_END
