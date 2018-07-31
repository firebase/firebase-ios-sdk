/*
 * Copyright 2017 Google
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

#import "Firestore/Source/Local/FSTQueryCache.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "leveldb/db.h"

@class FSTLevelDB;
@class FSTLocalSerializer;
@class FSTPBTargetGlobal;

NS_ASSUME_NONNULL_BEGIN

/** Cached Queries backed by LevelDB. */
@interface FSTLevelDBQueryCache : NSObject <FSTQueryCache>

/**
 * Retrieves the global singleton metadata row from the given database, if it exists.
 * TODO(gsoltis): remove this method once fully ported to transactions.
 */
+ (nullable FSTPBTargetGlobal *)readTargetMetadataFromDB:(leveldb::DB *)db;

/**
 * Retrieves the global singleton metadata row using the given transaction, if it exists.
 */
+ (nullable FSTPBTargetGlobal *)readTargetMetadataWithTransaction:
    (firebase::firestore::local::LevelDbTransaction *)transaction;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a new query cache in the given LevelDB.
 *
 * @param db The LevelDB in which to create the cache.
 */
- (instancetype)initWithDB:(FSTLevelDB *)db
                serializer:(FSTLocalSerializer *)serializer NS_DESIGNATED_INITIALIZER;

/** Starts the query cache up. */
- (void)start;

- (void)enumerateOrphanedDocumentsUsingBlock:
    (void (^)(const firebase::firestore::model::DocumentKey &docKey,
              FSTListenSequenceNumber sequenceNumber,
              BOOL *stop))block;

@end

NS_ASSUME_NONNULL_END
