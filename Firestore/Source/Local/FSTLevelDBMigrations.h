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

#import <Foundation/Foundation.h>

#include <memory>

#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "leveldb/db.h"

NS_ASSUME_NONNULL_BEGIN

typedef int32_t FSTLevelDBSchemaVersion;

@interface FSTLevelDBMigrations : NSObject

/**
 * Returns the current version of the schema for the given database
 */
+ (FSTLevelDBSchemaVersion)schemaVersionWithTransaction:
    (firebase::firestore::local::LevelDbTransaction *)transaction;

/**
 * Runs any migrations needed to bring the given database up to the current schema version
 */
+ (void)runMigrationsWithTransaction:(firebase::firestore::local::LevelDbTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
