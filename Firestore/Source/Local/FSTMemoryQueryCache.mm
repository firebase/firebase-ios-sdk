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

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTMemoryQueryCache ()

/** Maps a query to the data about that query. */
@property(nonatomic, strong, readonly) NSMutableDictionary<FSTQuery *, FSTQueryData *> *queries;

/** A ordered bidirectional mapping between documents and the remote target IDs. */
@property(nonatomic, strong, readonly) FSTReferenceSet *references;

/** The highest numbered target ID encountered. */
@property(nonatomic, assign) FSTTargetID highestTargetID;

@property(nonatomic, assign) FSTListenSequenceNumber highestListenSequenceNumber;

/** The last received snapshot version. */
@property(nonatomic, strong) FSTSnapshotVersion *lastRemoteSnapshotVersion;

@end

@implementation FSTMemoryQueryCache

- (instancetype)init {
  if (self = [super init]) {
    _queries = [NSMutableDictionary dictionary];
    _references = [[FSTReferenceSet alloc] init];
    _lastRemoteSnapshotVersion = [FSTSnapshotVersion noVersion];
  }
  return self;
}

#pragma mark - FSTQueryCache implementation
#pragma mark Query tracking

- (void)start {
  // Nothing to do.
}

- (FSTTargetID)highestTargetID {
  return _highestTargetID;
}

- (FSTListenSequenceNumber)highestListenSequenceNumber {
  return _highestListenSequenceNumber;
}

/*- (FSTSnapshotVersion *)lastRemoteSnapshotVersion {
  return _lastRemoteSnapshotVersion;
}

- (void)setLastRemoteSnapshotVersion:(FSTSnapshotVersion *)snapshotVersion
                               group:(FSTWriteGroup *)group {
  _lastRemoteSnapshotVersion = snapshotVersion;
}*/

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

#pragma mark Reference tracking

- (void)addMatchingKeys:(FSTDocumentKeySet *)keys forTargetID:(FSTTargetID)targetID {
  [self.references addReferencesToKeys:keys forID:targetID];
}

- (void)removeMatchingKeys:(FSTDocumentKeySet *)keys forTargetID:(FSTTargetID)targetID {
  [self.references removeReferencesToKeys:keys forID:targetID];
}

- (void)removeMatchingKeysForTargetID:(FSTTargetID)targetID {
  [self.references removeReferencesForID:targetID];
}

- (FSTDocumentKeySet *)matchingKeysForTargetID:(FSTTargetID)targetID {
  return [self.references referencedKeysForID:targetID];
}

#pragma mark - FSTGarbageSource implementation

- (nullable id<FSTGarbageCollector>)garbageCollector {
  return self.references.garbageCollector;
}

- (void)setGarbageCollector:(nullable id<FSTGarbageCollector>)garbageCollector {
  self.references.garbageCollector = garbageCollector;
}

- (BOOL)containsKey:(const firebase::firestore::model::DocumentKey &)key {
  return [self.references containsKey:key];
}

@end

NS_ASSUME_NONNULL_END
