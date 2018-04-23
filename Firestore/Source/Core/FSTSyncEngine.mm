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

#import "Firestore/Source/Core/FSTSyncEngine.h"

#import <GRPCClient/GRPCCall.h>

#include <map>
#include <set>
#include <unordered_map>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTSnapshotVersion.h"
#import "Firestore/Source/Core/FSTTransaction.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Local/FSTEagerGarbageCollector.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Local/FSTLocalViewChanges.h"
#import "Firestore/Source/Local/FSTLocalWriteResult.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Util/FSTAssert.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"
#import "Firestore/Source/Util/FSTLogger.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;
using firebase::firestore::core::TargetIdGenerator;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

// Limbo documents don't use persistence, and are eagerly GC'd. So, listens for them don't need
// real sequence numbers.
static const FSTListenSequenceNumber kIrrelevantSequenceNumber = -1;

#pragma mark - FSTQueryView

/**
 * FSTQueryView contains all of the info that FSTSyncEngine needs to track for a particular
 * query and view.
 */
@interface FSTQueryView : NSObject

- (instancetype)initWithQuery:(FSTQuery *)query
                     targetID:(FSTTargetID)targetID
                  resumeToken:(NSData *)resumeToken
                         view:(FSTView *)view NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** The query itself. */
@property(nonatomic, strong, readonly) FSTQuery *query;

/** The targetID created by the client that is used in the watch stream to identify this query. */
@property(nonatomic, assign, readonly) FSTTargetID targetID;

/**
 * An identifier from the datastore backend that indicates the last state of the results that
 * was received. This can be used to indicate where to continue receiving new doc changes for the
 * query.
 */
@property(nonatomic, copy, readonly) NSData *resumeToken;

/**
 * The view is responsible for computing the final merged truth of what docs are in the query.
 * It gets notified of local and remote changes, and applies the query filters and limits to
 * determine the most correct possible results.
 */
@property(nonatomic, strong, readonly) FSTView *view;

@end

@implementation FSTQueryView

- (instancetype)initWithQuery:(FSTQuery *)query
                     targetID:(FSTTargetID)targetID
                  resumeToken:(NSData *)resumeToken
                         view:(FSTView *)view {
  if (self = [super init]) {
    _query = query;
    _targetID = targetID;
    _resumeToken = resumeToken;
    _view = view;
  }
  return self;
}

@end

#pragma mark - FSTSyncEngine

@interface FSTSyncEngine ()

/** The local store, used to persist mutations and cached documents. */
@property(nonatomic, strong, readonly) FSTLocalStore *localStore;

/** The remote store for sending writes, watches, etc. to the backend. */
@property(nonatomic, strong, readonly) FSTRemoteStore *remoteStore;

/** FSTQueryViews for all active queries, indexed by query. */
@property(nonatomic, strong, readonly)
    NSMutableDictionary<FSTQuery *, FSTQueryView *> *queryViewsByQuery;

/** FSTQueryViews for all active queries, indexed by target ID. */
@property(nonatomic, strong, readonly)
    NSMutableDictionary<NSNumber *, FSTQueryView *> *queryViewsByTarget;

/** Used to track any documents that are currently in limbo. */
@property(nonatomic, strong, readonly) FSTReferenceSet *limboDocumentRefs;

/** The garbage collector used to collect documents that are no longer in limbo. */
@property(nonatomic, strong, readonly) FSTEagerGarbageCollector *limboCollector;

@end

@implementation FSTSyncEngine {
  /** Used for creating the FSTTargetIDs for the listens used to resolve limbo documents. */
  TargetIdGenerator _targetIdGenerator;

  /** Stores user completion blocks, indexed by user and FSTBatchID. */
  std::unordered_map<User, NSMutableDictionary<NSNumber *, FSTVoidErrorBlock> *, HashUser>
      _mutationCompletionBlocks;

  /**
   * When a document is in limbo, we create a special listen to resolve it. This maps the
   * DocumentKey of each limbo document to the TargetId of the listen resolving it.
   */
  std::map<DocumentKey, TargetId> _limboTargetsByKey;

  /** The inverse of _limboTargetsByKey, a map of TargetId to the key of the limbo doc. */
  std::map<TargetId, DocumentKey> _limboKeysByTarget;

  User _currentUser;
}

- (instancetype)initWithLocalStore:(FSTLocalStore *)localStore
                       remoteStore:(FSTRemoteStore *)remoteStore
                       initialUser:(const User &)initialUser {
  if (self = [super init]) {
    _localStore = localStore;
    _remoteStore = remoteStore;

    _queryViewsByQuery = [NSMutableDictionary dictionary];
    _queryViewsByTarget = [NSMutableDictionary dictionary];

    _limboCollector = [[FSTEagerGarbageCollector alloc] init];
    _limboDocumentRefs = [[FSTReferenceSet alloc] init];
    [_limboCollector addGarbageSource:_limboDocumentRefs];

    _targetIdGenerator = TargetIdGenerator::SyncEngineTargetIdGenerator(0);
    _currentUser = initialUser;
  }
  return self;
}

- (FSTTargetID)listenToQuery:(FSTQuery *)query {
  [self assertDelegateExistsForSelector:_cmd];
  FSTAssert(self.queryViewsByQuery[query] == nil, @"We already listen to query: %@", query);

  FSTQueryData *queryData = [self.localStore allocateQuery:query];
  FSTDocumentDictionary *docs = [self.localStore executeQuery:query];
  FSTDocumentKeySet *remoteKeys = [self.localStore remoteDocumentKeysForTarget:queryData.targetID];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:remoteKeys];
  FSTViewDocumentChanges *viewDocChanges = [view computeChangesWithDocuments:docs];
  FSTViewChange *viewChange = [view applyChangesToDocuments:viewDocChanges];
  FSTAssert(viewChange.limboChanges.count == 0,
            @"View returned limbo docs before target ack from the server.");

  FSTQueryView *queryView = [[FSTQueryView alloc] initWithQuery:query
                                                       targetID:queryData.targetID
                                                    resumeToken:queryData.resumeToken
                                                           view:view];
  self.queryViewsByQuery[query] = queryView;
  self.queryViewsByTarget[@(queryData.targetID)] = queryView;
  [self.delegate handleViewSnapshots:@[ viewChange.snapshot ]];

  [self.remoteStore listenToTargetWithQueryData:queryData];
  return queryData.targetID;
}

- (void)stopListeningToQuery:(FSTQuery *)query {
  [self assertDelegateExistsForSelector:_cmd];

  FSTQueryView *queryView = self.queryViewsByQuery[query];
  FSTAssert(queryView, @"Trying to stop listening to a query not found");

  [self.localStore releaseQuery:query];
  [self.remoteStore stopListeningToTargetID:queryView.targetID];
  [self removeAndCleanupQuery:queryView];
  [self.localStore collectGarbage];
}

- (void)writeMutations:(NSArray<FSTMutation *> *)mutations
            completion:(FSTVoidErrorBlock)completion {
  [self assertDelegateExistsForSelector:_cmd];

  FSTLocalWriteResult *result = [self.localStore locallyWriteMutations:mutations];
  [self addMutationCompletionBlock:completion batchID:result.batchID];

  [self emitNewSnapshotsWithChanges:result.changes remoteEvent:nil];
  [self.remoteStore fillWritePipeline];
}

- (void)addMutationCompletionBlock:(FSTVoidErrorBlock)completion batchID:(FSTBatchID)batchID {
  NSMutableDictionary<NSNumber *, FSTVoidErrorBlock> *completionBlocks =
      _mutationCompletionBlocks[_currentUser];
  if (!completionBlocks) {
    completionBlocks = [NSMutableDictionary dictionary];
    _mutationCompletionBlocks[_currentUser] = completionBlocks;
  }
  [completionBlocks setObject:completion forKey:@(batchID)];
}

/**
 * Takes an updateBlock in which a set of reads and writes can be performed atomically. In the
 * updateBlock, user code can read and write values using a transaction object. After the
 * updateBlock, all changes will be committed. If someone else has changed any of the data
 * referenced, then the updateBlock will be called again. If the updateBlock still fails after the
 * given number of retries, then the transaction will be rejected.
 *
 * The transaction object passed to the updateBlock contains methods for accessing documents
 * and collections. Unlike other firestore access, data accessed with the transaction will not
 * reflect local changes that have not been committed. For this reason, it is required that all
 * reads are performed before any writes. Transactions must be performed while online.
 */
- (void)transactionWithRetries:(int)retries
           workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                   updateBlock:(FSTTransactionBlock)updateBlock
                    completion:(FSTVoidIDErrorBlock)completion {
  [workerDispatchQueue verifyIsCurrentQueue];
  FSTAssert(retries >= 0, @"Got negative number of retries for transaction");
  FSTTransaction *transaction = [self.remoteStore transaction];
  updateBlock(transaction, ^(id _Nullable result, NSError *_Nullable error) {
    [workerDispatchQueue dispatchAsync:^{
      if (error) {
        completion(nil, error);
        return;
      }
      [transaction commitWithCompletion:^(NSError *_Nullable transactionError) {
        if (!transactionError) {
          completion(result, nil);
          return;
        }
        // TODO(b/35201829): Only retry on real transaction failures.
        if (retries == 0) {
          NSError *wrappedError =
              [NSError errorWithDomain:FIRFirestoreErrorDomain
                                  code:FIRFirestoreErrorCodeFailedPrecondition
                              userInfo:@{
                                NSLocalizedDescriptionKey : @"Transaction failed all retries.",
                                NSUnderlyingErrorKey : transactionError
                              }];
          completion(nil, wrappedError);
          return;
        }
        [workerDispatchQueue verifyIsCurrentQueue];
        return [self transactionWithRetries:(retries - 1)
                        workerDispatchQueue:workerDispatchQueue
                                updateBlock:updateBlock
                                 completion:completion];
      }];
    }];
  });
}

- (void)applyRemoteEvent:(FSTRemoteEvent *)remoteEvent {
  [self assertDelegateExistsForSelector:_cmd];

  // Make sure limbo documents are deleted if there were no results.
  // Filter out document additions to targets that they already belong to.
  [remoteEvent.targetChanges enumerateKeysAndObjectsUsingBlock:^(
                                 FSTBoxedTargetID *_Nonnull targetID,
                                 FSTTargetChange *_Nonnull targetChange, BOOL *_Nonnull stop) {
    const auto iter = self->_limboKeysByTarget.find([targetID intValue]);
    if (iter == self->_limboKeysByTarget.end()) {
      FSTQueryView *qv = self.queryViewsByTarget[targetID];
      FSTAssert(qv, @"Missing queryview for non-limbo query: %i", [targetID intValue]);
      [remoteEvent filterUpdatesFromTargetChange:targetChange
                               existingDocuments:qv.view.syncedDocuments];
    } else {
      [remoteEvent synthesizeDeleteForLimboTargetChange:targetChange key:iter->second];
    }
  }];

  FSTMaybeDocumentDictionary *changes = [self.localStore applyRemoteEvent:remoteEvent];
  [self emitNewSnapshotsWithChanges:changes remoteEvent:remoteEvent];
}

- (void)applyChangedOnlineState:(FSTOnlineState)onlineState {
  NSMutableArray<FSTViewSnapshot *> *newViewSnapshots = [NSMutableArray array];
  [self.queryViewsByQuery
      enumerateKeysAndObjectsUsingBlock:^(FSTQuery *query, FSTQueryView *queryView, BOOL *stop) {
        FSTViewChange *viewChange = [queryView.view applyChangedOnlineState:onlineState];
        FSTAssert(viewChange.limboChanges.count == 0,
                  @"OnlineState should not affect limbo documents.");
        if (viewChange.snapshot) {
          [newViewSnapshots addObject:viewChange.snapshot];
        }
      }];

  [self.delegate handleViewSnapshots:newViewSnapshots];
}

- (void)rejectListenWithTargetID:(const TargetId)targetID error:(NSError *)error {
  [self assertDelegateExistsForSelector:_cmd];

  const auto iter = _limboKeysByTarget.find(targetID);
  if (iter != _limboKeysByTarget.end()) {
    const DocumentKey limboKey = iter->second;
    // Since this query failed, we won't want to manually unlisten to it.
    // So go ahead and remove it from bookkeeping.
    _limboTargetsByKey.erase(limboKey);
    _limboKeysByTarget.erase(targetID);

    // TODO(dimond): Retry on transient errors?

    // It's a limbo doc. Create a synthetic event saying it was deleted. This is kind of a hack.
    // Ideally, we would have a method in the local store to purge a document. However, it would
    // be tricky to keep all of the local store's invariants with another method.
    NSMutableDictionary<NSNumber *, FSTTargetChange *> *targetChanges =
        [NSMutableDictionary dictionary];
    FSTDeletedDocument *doc =
        [FSTDeletedDocument documentWithKey:limboKey version:[FSTSnapshotVersion noVersion]];
    FSTRemoteEvent *event = [FSTRemoteEvent eventWithSnapshotVersion:[FSTSnapshotVersion noVersion]
                                                       targetChanges:targetChanges
                                                     documentUpdates:{{limboKey, doc}}];
    [self applyRemoteEvent:event];
  } else {
    FSTQueryView *queryView = self.queryViewsByTarget[@(targetID)];
    FSTAssert(queryView, @"Unknown targetId: %d", targetID);
    [self.localStore releaseQuery:queryView.query];
    [self removeAndCleanupQuery:queryView];
    [self.delegate handleError:error forQuery:queryView.query];
  }
}

- (void)applySuccessfulWriteWithResult:(FSTMutationBatchResult *)batchResult {
  [self assertDelegateExistsForSelector:_cmd];

  // The local store may or may not be able to apply the write result and raise events immediately
  // (depending on whether the watcher is caught up), so we raise user callbacks first so that they
  // consistently happen before listen events.
  [self processUserCallbacksForBatchID:batchResult.batch.batchID error:nil];

  FSTMaybeDocumentDictionary *changes = [self.localStore acknowledgeBatchWithResult:batchResult];
  [self emitNewSnapshotsWithChanges:changes remoteEvent:nil];
}

- (void)rejectFailedWriteWithBatchID:(FSTBatchID)batchID error:(NSError *)error {
  [self assertDelegateExistsForSelector:_cmd];

  // The local store may or may not be able to apply the write result and raise events immediately
  // (depending on whether the watcher is caught up), so we raise user callbacks first so that they
  // consistently happen before listen events.
  [self processUserCallbacksForBatchID:batchID error:error];

  FSTMaybeDocumentDictionary *changes = [self.localStore rejectBatchID:batchID];
  [self emitNewSnapshotsWithChanges:changes remoteEvent:nil];
}

- (void)processUserCallbacksForBatchID:(FSTBatchID)batchID error:(NSError *_Nullable)error {
  NSMutableDictionary<NSNumber *, FSTVoidErrorBlock> *completionBlocks =
      _mutationCompletionBlocks[_currentUser];

  // NOTE: Mutations restored from persistence won't have completion blocks, so it's okay for
  // this (or the completion below) to be nil.
  if (completionBlocks) {
    NSNumber *boxedBatchID = @(batchID);
    FSTVoidErrorBlock completion = completionBlocks[boxedBatchID];
    if (completion) {
      completion(error);
      [completionBlocks removeObjectForKey:boxedBatchID];
    }
  }
}

- (void)assertDelegateExistsForSelector:(SEL)methodSelector {
  FSTAssert(self.delegate, @"Tried to call '%@' before delegate was registered.",
            NSStringFromSelector(methodSelector));
}

- (void)removeAndCleanupQuery:(FSTQueryView *)queryView {
  [self.queryViewsByQuery removeObjectForKey:queryView.query];
  [self.queryViewsByTarget removeObjectForKey:@(queryView.targetID)];

  [self.limboDocumentRefs removeReferencesForID:queryView.targetID];
  [self garbageCollectLimboDocuments];
}

/**
 * Computes a new snapshot from the changes and calls the registered callback with the new snapshot.
 */
- (void)emitNewSnapshotsWithChanges:(FSTMaybeDocumentDictionary *)changes
                        remoteEvent:(FSTRemoteEvent *_Nullable)remoteEvent {
  NSMutableArray<FSTViewSnapshot *> *newSnapshots = [NSMutableArray array];
  NSMutableArray<FSTLocalViewChanges *> *documentChangesInAllViews = [NSMutableArray array];

  [self.queryViewsByQuery
      enumerateKeysAndObjectsUsingBlock:^(FSTQuery *query, FSTQueryView *queryView, BOOL *stop) {
        FSTView *view = queryView.view;
        FSTViewDocumentChanges *viewDocChanges = [view computeChangesWithDocuments:changes];
        if (viewDocChanges.needsRefill) {
          // The query has a limit and some docs were removed/updated, so we need to re-run the
          // query against the local store to make sure we didn't lose any good docs that had been
          // past the limit.
          FSTDocumentDictionary *docs = [self.localStore executeQuery:queryView.query];
          viewDocChanges = [view computeChangesWithDocuments:docs previousChanges:viewDocChanges];
        }
        FSTTargetChange *_Nullable targetChange = remoteEvent.targetChanges[@(queryView.targetID)];
        FSTViewChange *viewChange =
            [queryView.view applyChangesToDocuments:viewDocChanges targetChange:targetChange];

        [self updateTrackedLimboDocumentsWithChanges:viewChange.limboChanges
                                            targetID:queryView.targetID];

        if (viewChange.snapshot) {
          [newSnapshots addObject:viewChange.snapshot];
          FSTLocalViewChanges *docChanges =
              [FSTLocalViewChanges changesForViewSnapshot:viewChange.snapshot];
          [documentChangesInAllViews addObject:docChanges];
        }
      }];

  [self.delegate handleViewSnapshots:newSnapshots];
  [self.localStore notifyLocalViewChanges:documentChangesInAllViews];
  [self.localStore collectGarbage];
}

/** Updates the limbo document state for the given targetID. */
- (void)updateTrackedLimboDocumentsWithChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges
                                      targetID:(FSTTargetID)targetID {
  for (FSTLimboDocumentChange *limboChange in limboChanges) {
    switch (limboChange.type) {
      case FSTLimboDocumentChangeTypeAdded:
        [self.limboDocumentRefs addReferenceToKey:limboChange.key forID:targetID];
        [self trackLimboChange:limboChange];
        break;

      case FSTLimboDocumentChangeTypeRemoved:
        FSTLog(@"Document no longer in limbo: %s", limboChange.key.ToString().c_str());
        [self.limboDocumentRefs removeReferenceToKey:limboChange.key forID:targetID];
        break;

      default:
        FSTFail(@"Unknown limbo change type: %ld", (long)limboChange.type);
    }
  }
  [self garbageCollectLimboDocuments];
}

- (void)trackLimboChange:(FSTLimboDocumentChange *)limboChange {
  DocumentKey key{limboChange.key};

  if (_limboTargetsByKey.find(key) == _limboTargetsByKey.end()) {
    FSTLog(@"New document in limbo: %s", key.ToString().c_str());
    TargetId limboTargetID = _targetIdGenerator.NextId();
    FSTQuery *query = [FSTQuery queryWithPath:key.path()];
    FSTQueryData *queryData = [[FSTQueryData alloc] initWithQuery:query
                                                         targetID:limboTargetID
                                             listenSequenceNumber:kIrrelevantSequenceNumber
                                                          purpose:FSTQueryPurposeLimboResolution];
    _limboKeysByTarget[limboTargetID] = key;
    [self.remoteStore listenToTargetWithQueryData:queryData];
    _limboTargetsByKey[key] = limboTargetID;
  }
}

/** Garbage collect the limbo documents that we no longer need to track. */
- (void)garbageCollectLimboDocuments {
  const std::set<DocumentKey> garbage = [self.limboCollector collectGarbage];
  for (const DocumentKey &key : garbage) {
    const auto iter = _limboTargetsByKey.find(key);
    if (iter == _limboTargetsByKey.end()) {
      // This target already got removed, because the query failed.
      return;
    }
    TargetId limboTargetID = iter->second;
    [self.remoteStore stopListeningToTargetID:limboTargetID];
    _limboTargetsByKey.erase(key);
    _limboKeysByTarget.erase(limboTargetID);
  }
}

// Used for testing
- (std::map<DocumentKey, TargetId>)currentLimboDocuments {
  // Return defensive copy
  return _limboTargetsByKey;
}

- (void)userDidChange:(const User &)user {
  _currentUser = user;

  // Notify local store and emit any resulting events from swapping out the mutation queue.
  FSTMaybeDocumentDictionary *changes = [self.localStore userDidChange:user];
  [self emitNewSnapshotsWithChanges:changes remoteEvent:nil];

  // Notify remote store so it can restart its streams.
  [self.remoteStore userDidChange:user];
}

@end

NS_ASSUME_NONNULL_END
