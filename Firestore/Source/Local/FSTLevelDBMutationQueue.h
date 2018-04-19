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

#import "Firestore/Source/Local/FSTMutationQueue.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "leveldb/db.h"

@class FSTLevelDB;
@class FSTLocalSerializer;
@protocol FSTGarbageCollector;

NS_ASSUME_NONNULL_BEGIN

/** A mutation queue for a specific user, backed by LevelDB. */
@interface FSTLevelDBMutationQueue : NSObject <FSTMutationQueue>

- (instancetype)init __attribute__((unavailable("Use a static constructor")));

/** The garbage collector to notify about potential garbage keys. */
@property(nonatomic, weak, readwrite, nullable) id<FSTGarbageCollector> garbageCollector;

/**
 * Creates a new mutation queue for the given user, in the given LevelDB.
 *
 * @param user The user for which to create a mutation queue.
 * @param db The LevelDB in which to create the queue.
 */
+ (instancetype)mutationQueueWithUser:(const firebase::firestore::auth::User &)user
                                   db:(FSTLevelDB *)db
                           serializer:(FSTLocalSerializer *)serializer;

/**
 * Returns one larger than the largest batch ID that has been stored. If there are no mutations
 * returns 0. Note that batch IDs are global.
 */
+ (FSTBatchID)loadNextBatchIDFromDB:(std::shared_ptr<leveldb::DB>)db;

@end

NS_ASSUME_NONNULL_END
