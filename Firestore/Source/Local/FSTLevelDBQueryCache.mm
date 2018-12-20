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

#import "Firestore/Source/Local/FSTLevelDBQueryCache.h"

#include <memory>
#include <string>
#include <utility>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTLevelDB.h"
#import "Firestore/Source/Local/FSTLocalSerializer.h"
#import "Firestore/Source/Local/FSTQueryData.h"

#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_query_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"
#include "absl/strings/match.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::local::DescribeKey;
using firebase::firestore::local::LevelDbDocumentTargetKey;
using firebase::firestore::local::LevelDbQueryTargetKey;
using firebase::firestore::local::LevelDbQueryCache;
using firebase::firestore::local::LevelDbTargetDocumentKey;
using firebase::firestore::local::LevelDbTargetGlobalKey;
using firebase::firestore::local::LevelDbTargetKey;
using firebase::firestore::local::LevelDbTransaction;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using leveldb::DB;
using leveldb::Slice;
using leveldb::Status;

@implementation FSTLevelDBQueryCache {
  std::unique_ptr<LevelDbQueryCache> _cache;
}

+ (nullable FSTPBTargetGlobal *)readTargetMetadataFromDB:(DB *)db {
  return LevelDbQueryCache::ReadMetadata(db);
}

- (instancetype)initWithDB:(FSTLevelDB *)db serializer:(FSTLocalSerializer *)serializer {
  if (self = [super init]) {
    HARD_ASSERT(db, "db must not be NULL");
    _cache = absl::make_unique<LevelDbQueryCache>(db, serializer);
  }
  return self;
}

- (void)start {
  _cache->Start();
}

#pragma mark - FSTQueryCache implementation

- (TargetId)highestTargetID {
  return _cache->highest_target_id();
}

- (ListenSequenceNumber)highestListenSequenceNumber {
  return _cache->highest_listen_sequence_number();
}

- (const SnapshotVersion &)lastRemoteSnapshotVersion {
  return _cache->GetLastRemoteSnapshotVersion();
}

- (void)setLastRemoteSnapshotVersion:(SnapshotVersion)snapshotVersion {
  _cache->SetLastRemoteSnapshotVersion(std::move(snapshotVersion));
}

- (void)enumerateTargetsUsingBlock:(void (^)(FSTQueryData *queryData, BOOL *stop))block {
  _cache->EnumerateTargets(block);
}

- (void)enumerateOrphanedDocumentsUsingBlock:
    (void (^)(const DocumentKey &docKey, ListenSequenceNumber sequenceNumber, BOOL *stop))block {
  _cache->EnumerateOrphanedDocuments(block);
}

- (void)addQueryData:(FSTQueryData *)queryData {
  _cache->AddTarget(queryData);
}

- (void)updateQueryData:(FSTQueryData *)queryData {
  _cache->UpdateTarget(queryData);
}

- (void)removeQueryData:(FSTQueryData *)queryData {
  _cache->RemoveTarget(queryData);
}

- (int)removeQueriesThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber
                              liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  return _cache->RemoveTargets(sequenceNumber, liveQueries);
}

- (int32_t)count {
  return _cache->size();
}

- (nullable FSTQueryData *)queryDataForQuery:(FSTQuery *)query {
  return _cache->GetTarget(query);
}

#pragma mark Matching Key tracking

- (void)addMatchingKeys:(const DocumentKeySet &)keys forTargetID:(TargetId)targetID {
  _cache->AddMatchingKeys(keys, targetID);
}

- (void)removeMatchingKeys:(const DocumentKeySet &)keys forTargetID:(TargetId)targetID {
  _cache->RemoveMatchingKeys(keys, targetID);
}

- (void)removeMatchingKeysForTargetID:(TargetId)targetID {
  _cache->RemoveAllKeysForTarget(targetID);
}

- (DocumentKeySet)matchingKeysForTargetID:(TargetId)targetID {
  return _cache->GetMatchingKeys(targetID);
}

- (BOOL)containsKey:(const DocumentKey &)key {
  return _cache->Contains(key);
}

@end

NS_ASSUME_NONNULL_END
