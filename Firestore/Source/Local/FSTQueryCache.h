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

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Local/FSTGarbageCollector.h"
#import "Firestore/Source/Model/FSTDocumentKeySet.h"

@class FSTDocumentSet;
@class FSTMaybeDocument;
@class FSTQuery;
@class FSTQueryData;
@class FSTSnapshotVersion;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents cached queries received from the remote backend. This contains both a mapping between
 * queries and the documents that matched them according to the server, but also metadata about the
 * queries.
 *
 * The cache is keyed by FSTQuery and entries in the cache are FSTQueryData instances.
 */
@protocol FSTQueryCache <NSObject, FSTGarbageSource>

/** Starts the query cache up. */
- (void)start;

/**
 * Returns the highest target ID of any query in the cache. Typically called during startup to
 * seed a target ID generator and avoid collisions with existing queries. If there are no queries
 * in the cache, returns zero.
 */
- (FSTTargetID)highestTargetID;

/**
 * Returns the highest listen sequence number of any query seen by the cache.
 */
- (FSTListenSequenceNumber)highestListenSequenceNumber;

/**
 * A global snapshot version representing the last consistent snapshot we received from the
 * backend. This is monotonically increasing and any snapshots received from the backend prior to
 * this version (e.g. for targets resumed with a resume_token) should be suppressed (buffered)
 * until the backend has caught up to this snapshot version again. This prevents our cache from
 * ever going backwards in time.
 *
 * This is updated whenever our we get a TargetChange with a read_time and empty target_ids.
 */
- (FSTSnapshotVersion *)lastRemoteSnapshotVersion;

/**
 * Set the snapshot version representing the last consistent snapshot received from the backend.
 * (see -lastRemoteSnapshotVersion for more details).
 *
 * @param snapshotVersion The new snapshot version.
 */
- (void)setLastRemoteSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion;

/**
 * Adds an entry in the cache.
 *
 * The cache key is extracted from `queryData.query`. The key must not already exist in the cache.
 *
 * @param queryData A new FSTQueryData instance to put in the cache.
 */
- (void)addQueryData:(FSTQueryData *)queryData;

/**
 * Updates an entry in the cache.
 *
 * The cache key is extracted from `queryData.query`. The entry must already exist in the cache,
 * and it will be replaced.
 * @param queryData An FSTQueryData instance to replace an existing entry in the cache
 */
- (void)updateQueryData:(FSTQueryData *)queryData;

/** Removes the cached entry for the given query data (no-op if no entry exists). */
- (void)removeQueryData:(FSTQueryData *)queryData;

/** Returns the number of targets cached. */
- (int32_t)count;

/**
 * Looks up an FSTQueryData entry in the cache.
 *
 * @param query The query corresponding to the entry to look up.
 * @return The cached FSTQueryData entry, or nil if the cache has no entry for the query.
 */
- (nullable FSTQueryData *)queryDataForQuery:(FSTQuery *)query;

/** Adds the given document keys to cached query results of the given target ID. */
- (void)addMatchingKeys:(FSTDocumentKeySet *)keys forTargetID:(FSTTargetID)targetID;

/** Removes the given document keys from the cached query results of the given target ID. */
- (void)removeMatchingKeys:(FSTDocumentKeySet *)keys forTargetID:(FSTTargetID)targetID;

/** Removes all the keys in the query results of the given target ID. */
- (void)removeMatchingKeysForTargetID:(FSTTargetID)targetID;

- (FSTDocumentKeySet *)matchingKeysForTargetID:(FSTTargetID)targetID;

@end

NS_ASSUME_NONNULL_END
