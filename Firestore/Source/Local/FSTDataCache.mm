
#include <memory>

#import "Firestore/Source/Local/FSTDataCache.h"
#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "FSTListenSequence.h"
#import "FSTAssert.h"
#import "FSTRemoteDocumentChangeBuffer.h"
#import "target_id_generator.h"
#import "FSTPersistence.h"
#import "FSTMutationQueue.h"

using firebase::firestore::core::TargetIdGenerator;

NS_ASSUME_NONNULL_BEGIN

typedef struct {
    id<FSTMutationQueue> mutationQueue;
    id<FSTQueryCache> queryCache;
    id<FSTRemoteDocumentCache> documentCache;
} table_drivers;

@protocol FSTPersistenceCleanupDelegate

- (void)handlePotentiallyOrphanedDocument:(FSTDocumentKey *)key
                           sequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                             exemptTarget:(FSTTargetID)targetID
                                  drivers:(table_drivers *)drivers
                                    group:(FSTWriteGroup *)group;

- (void)targetWasRemoved:(FSTTargetID)targetID
                 drivers:(table_drivers *)drivers
                   group:(FSTWriteGroup *)group;

@end

@implementation FSTDataCache {
  std::unique_ptr<table_drivers> _table_drivers;
  FSTListenSequence *_listenSequence;
  id<FSTPersistenceCleanupDelegate> _delegate;
  TargetIdGenerator _targetIDGenerator;
}

- (id<FSTMutationQueue>)mutationQueue {
  return _table_drivers->mutationQueue;
}

- (void)start {}

- (void)shutdown {
  // TODO: shut down persistence
}

- (FSTTargetID)highestTargetID {
  return [_table_drivers->queryCache highestTargetID];
}

- (FSTSnapshotVersion *)lastRemoteSnapshotVersion {
  return [_table_drivers->queryCache lastRemoteSnapshotVersion];
}

- (FSTQueryData *)queryDataForQuery:(FSTQuery *)query {
  return [_table_drivers->queryCache queryDataForQuery:query];
}

- (FSTDocumentKeySet *)documentsForTarget:(FSTTargetID)targetID {
  return [_table_drivers->queryCache matchingKeysForTargetID:targetID];
}

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query {
  return [_table_drivers->documentCache documentsMatchingQuery:query];
}

- (nullable FSTMaybeDocument *)documentForKey:(FSTDocumentKey *)documentKey {
  return [_table_drivers->documentCache entryForKey:documentKey];
}

- (FSTQueryData *)updateQuery:(FSTTargetID)targetID forChange:(FSTTargetChange *)change group:(FSTWriteGroup *)group {
  FSTQueryData *queryData = [_table_drivers->queryCache queryDataForTargetID:targetID];
  NSData *resumeToken = change.resumeToken.length > 0 ? change.resumeToken : queryData.resumeToken;
  FSTListenSequenceNumber sequenceNumber = [_listenSequence next];
  FSTQueryData *updated = [queryData queryDataByReplacingSnapshotVersion:queryData.snapshotVersion
                                                             resumeToken:resumeToken
                                                          sequenceNumber:sequenceNumber];
  [_table_drivers->queryCache updateQueryData:updated group:group];
  return updated;
}

- (void)updateQuery:(FSTQueryData *)queryData
     documentsAdded:(FSTDocumentKeySet *)added
   documentsRemoved:(FSTDocumentKeySet *)removed
              group:(FSTWriteGroup *)group {

  FSTListenSequenceNumber sequenceNumber = [_listenSequence next];
  [_table_drivers->queryCache removeMatchingKeys:removed
                      forTargetID:queryData.targetID
                 atSequenceNumber:sequenceNumber
                            group:group];
  [_table_drivers->queryCache addMatchingKeys:added
                   forTargetID:queryData.targetID
              atSequenceNumber:sequenceNumber
                         group:group];

  // TODO(gsoltis): iterate removed, send them to delegate
}

- (void)resetQuery:(FSTQueryData *)queryData documents:(FSTDocumentKeySet *)documents group:(FSTWriteGroup *)group {
  FSTListenSequenceNumber sequenceNumber = [_listenSequence next];
  [_table_drivers->queryCache removeKeysForTargetID:queryData.targetID
                           withBlock:^BOOL(FSTDocumentKey *docKey) {
                             if ([documents containsObject:docKey]) {
                               return NO;
                             } else {
                               [_delegate handlePotentiallyOrphanedDocument:docKey
                                                             sequenceNumber:sequenceNumber
                                                               exemptTarget:queryData.targetID
                                                                    drivers:_table_drivers.get()
                                                                      group:group];
                               return YES;
                             }
                           } group:group];
  [_table_drivers->queryCache addMatchingKeys:documents
                   forTargetID:queryData.targetID
              atSequenceNumber:sequenceNumber
                         group:group];
}

- (FSTQueryData *)removeQuery:(FSTQuery *)query group:(FSTWriteGroup *)group {
  FSTQueryData *queryData = [_table_drivers->queryCache queryDataForQuery:query];
  if (!queryData) {
    FSTFail(@"Attempted to remove non-existent query: %@", query.canonicalID);
  }
  [_delegate targetWasRemoved:queryData.targetID drivers:_table_drivers.get() group:group];
  return queryData;
}

- (void)addNewSnapshotVersion:(FSTSnapshotVersion *)remoteVersion group:(FSTWriteGroup *)group {
  FSTSnapshotVersion *lastRemoteVersion = _table_drivers->queryCache.lastRemoteSnapshotVersion;
  if (![remoteVersion isEqual:[FSTSnapshotVersion noVersion]]) {
    FSTAssert([remoteVersion compare:lastRemoteVersion] != NSOrderedAscending,
            @"Watch stream reverted to previous snapshot?? (%@ < %@)", remoteVersion,
            lastRemoteVersion);
    [_table_drivers->queryCache setLastRemoteSnapshotVersion:remoteVersion group:group];
  }
}

- (void)addPotentiallyOrphanedDocuments:(FSTDocumentKeySet *)affected
                                  group:(FSTWriteGroup *)group {
  FSTListenSequenceNumber sequenceNumber = [_listenSequence next];
  [affected enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
    [_delegate handlePotentiallyOrphanedDocument:key
                                  sequenceNumber:sequenceNumber
                                    exemptTarget:0
                                         drivers:_table_drivers.get()
                                           group:group];
  }];
}

- (FSTRemoteDocumentChangeBuffer *)changeBuffer {
  return [FSTRemoteDocumentChangeBuffer changeBufferWithCache:_table_drivers->documentCache];
}

- (FSTQueryData *)getOrCreateQueryData:(FSTQuery *)query {
  FSTQueryData *queryData = [_table_drivers->queryCache queryDataForQuery:query];
  if (!queryData) {
    queryData = [[FSTQueryData alloc] initWithQuery:query
                                           targetID:_targetIDGenerator.NextId()
                               listenSequenceNumber:[_listenSequence next]
                                            purpose:FSTQueryPurposeListen];
  }
  return queryData;
}

@end

@interface FSTNoOpDataAccess : NSObject<FSTPersistenceCleanupDelegate>
@end

@implementation FSTNoOpDataAccess
- (void)handlePotentiallyOrphanedDocument:(FSTDocumentKey *)key
                           sequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                             exemptTarget:(FSTTargetID)targetID
                                    group:(FSTWriteGroup *)group {
  // Noop
}

- (void)targetWasRemoved:(FSTTargetID)targetID group:(FSTWriteGroup *)group {
  // Noop
}


@end

@implementation FSTLRUDataAccess

+ (FSTLRUDataAccess *)delegate {
  return [[FSTLRUDataAccess alloc] init];
}

- (void)handlePotentiallyOrphanedDocument:(FSTDocumentKey *)key
                           sequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                             exemptTarget:(FSTTargetID)targetID
                                  drivers:(table_drivers *)drivers
                                    group:(FSTWriteGroup *)group {
  // TODO: set the sentinel key to sequenceNumber
}

- (void)targetWasRemoved:(FSTTargetID)targetID drivers:(table_drivers *)drivers group:(FSTWriteGroup *)group {
  // Noop, we don't bump anything on listen removal.
}


@end

@implementation FSTEagerDataAccess

+ (FSTEagerDataAccess *)delegate {
  return [[FSTEagerDataAccess alloc] init];
}

- (void)handlePotentiallyOrphanedDocument:(FSTDocumentKey *)key
                           sequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                             exemptTarget:(FSTTargetID)targetID
                                  drivers:(table_drivers *)drivers
                                    group:(FSTWriteGroup *)group {
  if (![drivers->queryCache containsKey:key] && ![drivers->mutationQueue containsKey:key]) {
    [drivers->documentCache removeEntryForKey:key group:group];
  }
}

- (void)targetWasRemoved:(FSTTargetID)targetID drivers:(table_drivers *)drivers group:(FSTWriteGroup *)group {
  // TODO(ggsoltis): as documents are removed, check if they are orphaned
  // this is tricky w/o transactions.
  [drivers->queryCache removeTarget:targetID
                          group:group block:^(FSTDocumentKey *removed) {
    if (![drivers->mutationQueue containsKey:removed]) {
      __block BOOL found = NO;
      [drivers->queryCache enumerateTargetsForDocument:removed block:^(FSTTargetID toCheck, BOOL *stop) {
        if (targetID != toCheck) {
          *stop = YES;
          found = YES;
        }
      }];
      if (found) {
        [drivers->documentCache removeEntryForKey:removed group:group];
        // TODO: remove sentinel
        [drivers->queryCache removeSentinelKey:removed];
      }
    }
   }];
}

@end

NS_ASSUME_NONNULL_END