
#import "Firestore/Source/Local/FSTDataCache.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"
#import "Firestore/Source/Local/FSTDataAccess.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Target.pbobjc.h"
#import "FSTQuery.h"
#import "FSTRemoteEvent.h"
#import "FSTListenSequence.h"
#import "FSTAssert.h"
#import "FSTRemoteDocumentChangeBuffer.h"
#import "target_id_generator.h"

using firebase::firestore::core::TargetIdGenerator;

NS_ASSUME_NONNULL_BEGIN

@protocol FSTPersistenceCleanupDelegate

- (void)handlePotentiallyOrphanedDocument:(FSTDocumentKey *)key
                           sequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                             exemptTarget:(FSTTargetID)targetID
                                    group:(FSTWriteGroup *)group;

- (void)targetWasRemoved:(FSTTargetID)targetID group:(FSTWriteGroup *)group;

@end

@interface FSTAbstractDataAccess : NSObject<FSTDataCache>

@property (strong, nonatomic) id<FSTQueryCache> queryCache;

- (FSTQueryData *)updateQuery:(FSTTargetID)targetID forChange:(FSTTargetChange *)change group:(FSTWriteGroup *)group;

- (void)addNewSnapshotVersion:(FSTSnapshotVersion *)remoteVersion group:(FSTWriteGroup *)group;

- (void)addPotentiallyOrphanedDocuments:(FSTDocumentKeySet *)affected
                                  group:(FSTWriteGroup *)group;

- (FSTRemoteDocumentChangeBuffer *)changeBuffer;

- (FSTQueryData *)getOrCreateQueryData:(FSTQuery *)query;

- (void)resetQuery:(FSTQueryData *)queryData documents:(FSTDocumentKeySet *)documents group:(FSTWriteGroup *)group;

- (void)updateQuery:(FSTQueryData *)queryData
     documentsAdded:(FSTDocumentKeySet *)added
   documentsRemoved:(FSTDocumentKeySet *)removed
              group:(FSTWriteGroup *)group;

- (void)start;

- (void)shutdown;

- (FSTQueryData *)removeQuery:(FSTQuery *)query group:(FSTWriteGroup *)group;

@end

@implementation FSTAbstractDataAccess {
  id<FSTRemoteDocumentCache> _documentCache;
  FSTListenSequence *_listenSequence;
  id<FSTPersistenceCleanupDelegate> _delegate;
  TargetIdGenerator _targetIDGenerator;
}

- (void)start {}

- (void)shutdown {}

- (FSTTargetID)highestTargetID {
  return [_queryCache highestTargetId];
}

- (FSTSnapshotVersion *)lastRemoteSnapshotVersion {
  return [_queryCache lastRemoteSnapshotVersion];
}

- (FSTQueryData *)queryDataForQuery:(FSTQuery *)query {
  return [_queryCache queryDataForQuery:query];
}

- (FSTDocumentKeySet *)documentsForTarget:(FSTTargetID)targetID {
  return [_queryCache matchingKeysForTargetID:targetID];
}

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query {
  return [_documentCache documentsMatchingQuery:query];
}

- (nullable FSTMaybeDocument *)documentForKey:(FSTDocumentKey *)documentKey {
  return [_documentCache entryForKey:documentKey];
}

- (FSTQueryData *)updateQuery:(FSTTargetID)targetID forChange:(FSTTargetChange *)change group:(FSTWriteGroup *)group {
  FSTQueryData *queryData = [self.queryCache queryDataForTargetID:targetID];
  NSData *resumeToken = change.resumeToken.length > 0 ? change.resumeToken : queryData.resumeToken;
  FSTListenSequenceNumber sequenceNumber = [_listenSequence next];
  FSTQueryData *updated = [queryData queryDataByReplacingSnapshotVersion:queryData.snapshotVersion
                                                             resumeToken:resumeToken
                                                          sequenceNumber:sequenceNumber];
  [_queryCache updateQueryData:updated group:group];
  return updated;
}

- (void)updateQuery:(FSTQueryData *)queryData
     documentsAdded:(FSTDocumentKeySet *)added
   documentsRemoved:(FSTDocumentKeySet *)removed
              group:(FSTWriteGroup *)group {

  FSTListenSequenceNumber sequenceNumber = [_listenSequence next];
  [_queryCache removeMatchingKeys:removed
                      forTargetID:queryData.targetID
                 atSequenceNumber:sequenceNumber
                            group:group];
  [_queryCache addMatchingKeys:added
                   forTargetID:queryData.targetID
              atSequenceNumber:sequenceNumber
                         group:group];

  // TODO(gsoltis): iterate removed, send them to delegate
}

- (void)resetQuery:(FSTQueryData *)queryData documents:(FSTDocumentKeySet *)documents group:(FSTWriteGroup *)group {
  FSTListenSequenceNumber sequenceNumber = [_listenSequence next];
  [_queryCache removeKeysForTargetID:queryData.targetID
                           withBlock:^BOOL(FSTDocumentKey *docKey) {
                             if ([documents containsObject:docKey]) {
                               return NO;
                             } else {
                               [_delegate handlePotentiallyOrphanedDocument:docKey
                                                             sequenceNumber:sequenceNumber
                                                               exemptTarget:queryData.targetID
                                                                      group:group];
                               return YES;
                             }
                           } group:group];
  [_queryCache addMatchingKeys:documents
                   forTargetID:queryData.targetID
              atSequenceNumber:sequenceNumber
                         group:group];
}

- (FSTQueryData *)removeQuery:(FSTQuery *)query group:(FSTWriteGroup *)group {
  FSTQueryData *queryData = [_queryCache queryDataForQuery:query];
  if (!queryData) {
    FSTFail(@"Attempted to remove non-existent query: %@", query.canonicalID);
  }
  [_delegate targetWasRemoved:queryData.targetID group:group];
  return queryData;
}

- (void)addNewSnapshotVersion:(FSTSnapshotVersion *)remoteVersion group:(FSTWriteGroup *)group {
  FSTSnapshotVersion *lastRemoteVersion = self.queryCache.lastRemoteSnapshotVersion;
  if (![remoteVersion isEqual:[FSTSnapshotVersion noVersion]]) {
    FSTAssert([remoteVersion compare:lastRemoteVersion] != NSOrderedAscending,
            @"Watch stream reverted to previous snapshot?? (%@ < %@)", remoteVersion,
            lastRemoteVersion);
    [_queryCache setLastRemoteSnapshotVersion:remoteVersion group:group];
  }
}

- (void)addPotentiallyOrphanedDocuments:(FSTDocumentKeySet *)affected
                                  group:(FSTWriteGroup *)group {
  FSTListenSequenceNumber sequenceNumber = [_listenSequence next];
  [affected enumerateObjectsUsingBlock:^(FSTDocumentKey *key, BOOL *stop) {
    [_delegate handlePotentiallyOrphanedDocument:key
                                  sequenceNumber:sequenceNumber
                                    exemptTarget:0
                                           group:group];
  }];
}

- (FSTRemoteDocumentChangeBuffer *)changeBuffer {
  return [FSTRemoteDocumentChangeBuffer changeBufferWithCache:_documentCache];
}

- (FSTQueryData *)getOrCreateQueryData:(FSTQuery *)query {
  FSTQueryData *queryData = [_queryCache queryDataForQuery:query];
  if (!queryData) {
    queryData = [[FSTQueryData alloc] initWithQuery:query
                                           targetID:_targetIDGenerator.NextId()
                               listenSequenceNumber:[_listenSequence next]
                                            purpose:FSTQueryPurposeListen];
  }
  return queryData;
}

@end

@interface FSTNoOpDataAccess : FSTAbstractDataAccess<FSTPersistenceCleanupDelegate>
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

@interface FSTLRUDataAccess : FSTAbstractDataAccess<FSTPersistenceCleanupDelegate>
@end

@implementation FSTLRUDataAccess
- (void)handlePotentiallyOrphanedDocument:(FSTDocumentKey *)key
                           sequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                             exemptTarget:(FSTTargetID)targetID
                                    group:(FSTWriteGroup *)group {
  // TODO: set the sentinel key to sequenceNumber
}

- (void)targetWasRemoved:(FSTTargetID)targetID group:(FSTWriteGroup *)group {
  // Noop, we don't bump anything on listen removal.
}


@end

@interface FSTEagerDataAccess : FSTAbstractDataAccess<FSTPersistenceCleanupDelegate>

@property (strong, nonatomic) id<FSTMutationQueue> mutationQueue;
@property (strong, nonatomic) id<FSTQueryCache> queryCache;
@property (strong, nonatomic) id<FSTRemoteDocumentCache> documentCache;

@end

@implementation FSTEagerDataAccess
- (void)handlePotentiallyOrphanedDocument:(FSTDocumentKey *)key
                           sequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                             exemptTarget:(FSTTargetID)targetID
                                    group:(FSTWriteGroup *)group {
  if (![self.queryCache containsKey:key] && ![self.mutationQueue containsKey:key]) {
    [self.documentCache removeEntryForKey:key group:group];
  }
}

- (void)targetWasRemoved:(FSTTargetID)targetID group:(FSTWriteGroup *)group {
  // TODO(ggsoltis): as documents are removed, check if they are orphaned
  // this is tricky w/o transactions.
  [self.queryCache removeTarget:targetID
                          group:group block:^(FSTDocumentKey *removed) {
    if (![self.mutationQueue containsKey:removed]) {
      __block BOOL found = NO;
      [self.queryCache enumerateTargetsForDocument:removed block:^(FSTTargetID toCheck, BOOL *stop) {
        if (targetID != toCheck) {
          *stop = YES;
          found = YES;
        }
      }];
      if (found) {
        [self.documentCache removeEntryForKey:removed group:group];
        // TODO: remove sentinel
        [self.queryCache removeSentinelKey:removed];
      }
    }
   }];
}

@end

NS_ASSUME_NONNULL_END