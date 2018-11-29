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

#include <utility>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTMemoryPersistence.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryQueryCache ()

/** Maps a query to the data about that query. */
@property(nonatomic, strong, readonly) NSMutableDictionary<FSTQuery *, FSTQueryData *> *queries;

/** A ordered bidirectional mapping between documents and the remote target IDs. */
@property(nonatomic, strong, readonly) FSTReferenceSet *references;

/** The highest numbered target ID encountered. */
@property(nonatomic, assign) TargetId highestTargetID;

@property(nonatomic, assign) ListenSequenceNumber highestListenSequenceNumber;

@end

@implementation FSTMemoryQueryCache {
  FSTMemoryPersistence *_persistence;
  /** The last received snapshot version. */
  SnapshotVersion _lastRemoteSnapshotVersion;
}

- (instancetype)initWithPersistence:(FSTMemoryPersistence *)persistence {
  if (self = [super init]) {
    _persistence = persistence;
    _queries = [NSMutableDictionary dictionary];
    _references = [[FSTReferenceSet alloc] init];
    _lastRemoteSnapshotVersion = SnapshotVersion::None();
  }
  return self;
}

#pragma mark - FSTQueryCache implementation
#pragma mark Query tracking

- (TargetId)highestTargetID {
  return _highestTargetID;
}

- (ListenSequenceNumber)highestListenSequenceNumber {
  return _highestListenSequenceNumber;
}

- (const SnapshotVersion &)lastRemoteSnapshotVersion {
  return _lastRemoteSnapshotVersion;
}

- (void)setLastRemoteSnapshotVersion:(SnapshotVersion)snapshotVersion {
  _lastRemoteSnapshotVersion = std::move(snapshotVersion);
}

- (void)addQueryData:(FSTQueryData *)queryData {
  self.queries[queryData.query] = queryData;
  if (queryData.targetID > self.highestTargetID) {
    self.highestTargetID = queryData.targetID;
  }
  if (queryData.sequenceNumber > self.highestListenSequenceNumber) {
    self.highestListenSequenceNumber = queryData.sequenceNumber;
  }
}

- (void)updateQueryData:(FSTQueryData *)queryData {
  self.queries[queryData.query] = queryData;
  if (queryData.targetID > self.highestTargetID) {
    self.highestTargetID = queryData.targetID;
  }
  if (queryData.sequenceNumber > self.highestListenSequenceNumber) {
    self.highestListenSequenceNumber = queryData.sequenceNumber;
  }
}

- (int32_t)count {
  return (int32_t)[self.queries count];
}

- (void)removeQueryData:(FSTQueryData *)queryData {
  [self.queries removeObjectForKey:queryData.query];
  [self.references removeReferencesForID:queryData.targetID];
}

- (nullable FSTQueryData *)queryDataForQuery:(FSTQuery *)query {
  return self.queries[query];
}

- (void)enumerateTargetsUsingBlock:(void (^)(FSTQueryData *queryData, BOOL *stop))block {
  [self.queries
      enumerateKeysAndObjectsUsingBlock:^(FSTQuery *key, FSTQueryData *queryData, BOOL *stop) {
        block(queryData, stop);
      }];
}

- (int)removeQueriesThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber
                              liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  NSMutableArray<FSTQuery *> *toRemove = [NSMutableArray array];
  [self.queries
      enumerateKeysAndObjectsUsingBlock:^(FSTQuery *query, FSTQueryData *queryData, BOOL *stop) {
        if (queryData.sequenceNumber <= sequenceNumber) {
          if (liveQueries[@(queryData.targetID)] == nil) {
            [toRemove addObject:query];
            [self.references removeReferencesForID:queryData.targetID];
          }
        }
      }];
  [self.queries removeObjectsForKeys:toRemove];
  return (int)[toRemove count];
}

#pragma mark Reference tracking

- (void)addMatchingKeys:(const DocumentKeySet &)keys forTargetID:(TargetId)targetID {
  [self.references addReferencesToKeys:keys forID:targetID];
  for (const DocumentKey &key : keys) {
    [_persistence.referenceDelegate addReference:key];
  }
}

- (void)removeMatchingKeys:(const DocumentKeySet &)keys forTargetID:(TargetId)targetID {
  [self.references removeReferencesToKeys:keys forID:targetID];
  for (const DocumentKey &key : keys) {
    [_persistence.referenceDelegate removeReference:key];
  }
}

- (void)removeMatchingKeysForTargetID:(TargetId)targetID {
  [self.references removeReferencesForID:targetID];
}

- (DocumentKeySet)matchingKeysForTargetID:(TargetId)targetID {
  return [self.references referencedKeysForID:targetID];
}

- (BOOL)containsKey:(const firebase::firestore::model::DocumentKey &)key {
  return [self.references containsKey:key];
}

- (size_t)byteSizeWithSerializer:(FSTLocalSerializer *)serializer {
  __block size_t count = 0;
  [self.queries
      enumerateKeysAndObjectsUsingBlock:^(FSTQuery *key, FSTQueryData *queryData, BOOL *stop) {
        count += [[serializer encodedQueryData:queryData] serializedSize];
      }];
  return count;
}

@end

NS_ASSUME_NONNULL_END
