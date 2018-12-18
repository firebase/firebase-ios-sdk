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

#import "Firestore/Source/Local/FSTMemoryQueryCache.h"

#import <Protobuf/GPBProtocolBuffers.h>

#include <memory>
#include <utility>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"

#include "Firestore/core/src/firebase/firestore/local/memory_query_cache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "absl/memory/memory.h"

using firebase::firestore::local::MemoryQueryCache;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

@implementation FSTMemoryQueryCache {
  std::unique_ptr<MemoryQueryCache> _cache;
}

- (instancetype)initWithPersistence:(FSTMemoryPersistence *)persistence {
  if (self = [super init]) {
    _cache = absl::make_unique<MemoryQueryCache>(persistence);
  }
  return self;
}

#pragma mark - FSTQueryCache implementation
#pragma mark Query tracking

- (TargetId)highestTargetID {
  return _cache->highest_target_id();
}

- (ListenSequenceNumber)highestListenSequenceNumber {
  return _cache->highest_listen_sequence_number();
}

- (const SnapshotVersion &)lastRemoteSnapshotVersion {
  return _cache->last_remote_snapshot_version();
}

- (void)setLastRemoteSnapshotVersion:(SnapshotVersion)snapshotVersion {
  _cache->set_last_remote_snapshot_version(snapshotVersion);
}

- (void)addQueryData:(FSTQueryData *)queryData {
  _cache->AddTarget(queryData);
}

- (void)updateQueryData:(FSTQueryData *)queryData {
  _cache->UpdateTarget(queryData);
}

- (int32_t)count {
  return _cache->count();
}

- (void)removeQueryData:(FSTQueryData *)queryData {
  _cache->RemoveTarget(queryData);
}

- (nullable FSTQueryData *)queryDataForQuery:(FSTQuery *)query {
  return _cache->GetTarget(query);
}

- (void)enumerateTargetsUsingBlock:(void (^)(FSTQueryData *queryData, BOOL *stop))block {
  _cache->EnumerateTargets(block);
}

- (int)removeQueriesThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber
                              liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  return _cache->RemoveTargets(sequenceNumber, liveQueries);
}

#pragma mark Reference tracking

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

- (BOOL)containsKey:(const firebase::firestore::model::DocumentKey &)key {
  return _cache->Contains(key);
}

- (size_t)byteSizeWithSerializer:(FSTLocalSerializer *)serializer {
  return _cache->CalculateByteSize(serializer);
}

@end

NS_ASSUME_NONNULL_END
