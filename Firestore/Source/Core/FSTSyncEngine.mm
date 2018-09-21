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
#include <utility>

#import "FIRFirestoreErrors.h"
#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTTransaction.h"
#import "Firestore/Source/Core/FSTView.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Local/FSTLocalStore.h"
#import "Firestore/Source/Local/FSTLocalViewChanges.h"
#import "Firestore/Source/Local/FSTLocalWriteResult.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTReferenceSet.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTMutationBatch.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

using firebase::firestore::auth::HashUser;
using firebase::firestore::auth::User;
using firebase::firestore::core::TargetIdGenerator;
using firebase::firestore::model::BatchId;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::OnlineState;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

NS_ASSUME_NONNULL_BEGIN

// Limbo documents don't use persistence, and are eagerly GC'd. So, listens for them don't need
// real sequence numbers.
static const ListenSequenceNumber kIrrelevantSequenceNumber = -1;

#pragma mark - FSTQueryView

/**
 * FSTQueryView contains all of the info that FSTSyncEngine needs to track for a particular
 * query and view.
 */
@interface FSTQueryView : NSObject

- (instancetype)initWithQuery:(FSTQuery *)query
                     targetID:(TargetId)targetID
                  resumeToken:(NSData *)resumeToken
                         view:(FSTView *)view NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** The query itself. */
@property(nonatomic, strong, readonly) FSTQuery *query;

/** The targetID created by the client that is used in the watch stream to identify this query. */
@property(nonatomic, assign, readonly) TargetId targetID;

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
                     targetID:(TargetId)targetID
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

#pragma mark - LimboResolution

/** Tracks a limbo resolution. */
class LimboResolution {
 public:
  LimboResolution() {
  }

  explicit LimboResolution(const DocumentKey &key) : key{key} {
  }

  DocumentKey key;

  /**
   * Set to true once we've received a document. This is used in remoteKeysForTarget and
   * ultimately used by FSTWatchChangeAggregator to decide whether it needs to manufacture a delete
   * event for the target once the target is CURRENT.
   */
  bool document_received = false;
};

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

@end

@implementation FSTSyncEngine {
  /** Used for creating the TargetId for the listens used to resolve limbo documents. */
  TargetIdGenerator _targetIdGenerator;

  /** Stores user completion blocks, indexed by user and BatchId. */
  std::unordered_map<User, NSMutableDictionary<NSNumber *, FSTVoidErrorBlock> *, HashUser>
      _mutationCompletionBlocks;

  /**
   * When a document is in limbo, we create a special listen to resolve it. This maps the
   * DocumentKey of each limbo document to the TargetId of the listen resolving it.
   */
  std::map<DocumentKey, TargetId> _limboTargetsByKey;

  /**
   * Basically the inverse of limboTargetsByKey, a map of target ID to a LimboResolution (which
   * includes the DocumentKey as well as whether we've received a document for the target).
   */
  std::map<TargetId, LimboResolution> _limboResolutionsByTarget;

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

    _limboDocumentRefs = [[FSTReferenceSet alloc] init];
    _targetIdGenerator = TargetIdGenerator::SyncEngineTargetIdGenerator(0);
    _currentUser = initialUser;
  }
  return self;
}

- (TargetId)listenToQuery:(FSTQuery *)query {
  [self assertDelegateExistsForSelector:_cmd];
  HARD_ASSERT(self.queryViewsByQuery[query] == nil, "We already listen to query: %s", query);

  FSTQueryData *queryData = [self.localStore allocateQuery:query];
  FSTDocumentDictionary *docs = [self.localStore executeQuery:query];
  DocumentKeySet remoteKeys = [self.localStore remoteDocumentKeysForTarget:queryData.targetID];

  FSTView *view = [[FSTView alloc] initWithQuery:query remoteDocuments:std::move(remoteKeys)];
  FSTViewDocumentChanges *viewDocChanges = [view computeChangesWithDocuments:docs];
  FSTViewChange *viewChange = [view applyChangesToDocuments:viewDocChanges];
  HARD_ASSERT(viewChange.limboChanges.count == 0,
              "View returned limbo docs before target ack from the server.");

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
  HARD_ASSERT(queryView, "Trying to stop listening to a query not found");

  [self.localStore releaseQuery:query];
  [self.remoteStore stopListeningToTargetID:queryView.targetID];
  [self removeAndCleanupQuery:queryView];
}

- (void)writeMutations:(NSArray<FSTMutation *> *)mutations
            completion:(FSTVoidErrorBlock)completion {
  [self assertDelegateExistsForSelector:_cmd];

  FSTLocalWriteResult *result = [self.localStore locallyWriteMutations:mutations];
  [self addMutationCompletionBlock:completion batchID:result.batchID];

  [self emitNewSnapshotsWithChanges:result.changes remoteEvent:nil];
  [self.remoteStore fillWritePipeline];
}

- (void)addMutationCompletionBlock:(FSTVoidErrorBlock)completion batchID:(BatchId)batchID {
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
  HARD_ASSERT(retries >= 0, "Got negative number of retries for transaction");
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

  // Update `receivedDocument` as appropriate for any limbo targets.
  for (const auto &entry : remoteEvent.targetChanges) {
    TargetId targetID = entry.first;
    FSTTargetChange *change = entry.second;
    const auto iter = _limboResolutionsByTarget.find(targetID);
    if (iter != _limboResolutionsByTarget.end()) {
      LimboResolution &limboResolution = iter->second;
      // Since this is a limbo resolution lookup, it's for a single document and it could be
      // added, modified, or removed, but not a combination.
      HARD_ASSERT(change.addedDocuments.size() + change.modifiedDocuments.size() +
                          change.removedDocuments.size() <=
                      1,
                  "Limbo resolution for single document contains multiple changes.");

      if (change.addedDocuments.size() > 0) {
        limboResolution.document_received = true;
      } else if (change.modifiedDocuments.size() > 0) {
        HARD_ASSERT(limboResolution.document_received,
                    "Received change for limbo target document without add.");
      } else if (change.removedDocuments.size() > 0) {
        HARD_ASSERT(limboResolution.document_received,
                    "Received remove for limbo target document without add.");
        limboResolution.document_received = false;
      } else {
        // This was probably just a CURRENT targetChange or similar.
      }
    }
  }

  FSTMaybeDocumentDictionary *changes = [self.localStore applyRemoteEvent:remoteEvent];
  [self emitNewSnapshotsWithChanges:changes remoteEvent:remoteEvent];
}

- (void)applyChangedOnlineState:(OnlineState)onlineState {
  NSMutableArray<FSTViewSnapshot *> *newViewSnapshots = [NSMutableArray array];
  [self.queryViewsByQuery
      enumerateKeysAndObjectsUsingBlock:^(FSTQuery *query, FSTQueryView *queryView, BOOL *stop) {
        FSTViewChange *viewChange = [queryView.view applyChangedOnlineState:onlineState];
        HARD_ASSERT(viewChange.limboChanges.count == 0,
                    "OnlineState should not affect limbo documents.");
        if (viewChange.snapshot) {
          [newViewSnapshots addObject:viewChange.snapshot];
        }
      }];

  [self.delegate handleViewSnapshots:newViewSnapshots];
}

- (void)rejectListenWithTargetID:(const TargetId)targetID error:(NSError *)error {
  [self assertDelegateExistsForSelector:_cmd];

  const auto iter = _limboResolutionsByTarget.find(targetID);
  if (iter != _limboResolutionsByTarget.end()) {
    const DocumentKey limboKey = iter->second.key;
    // Since this query failed, we won't want to manually unlisten to it.
    // So go ahead and remove it from bookkeeping.
    _limboTargetsByKey.erase(limboKey);
    _limboResolutionsByTarget.erase(targetID);

    // TODO(dimond): Retry on transient errors?

    // It's a limbo doc. Create a synthetic event saying it was deleted. This is kind of a hack.
    // Ideally, we would have a method in the local store to purge a document. However, it would
    // be tricky to keep all of the local store's invariants with another method.
    FSTDeletedDocument *doc =
        [FSTDeletedDocument documentWithKey:limboKey version:SnapshotVersion::None()];
    DocumentKeySet limboDocuments = DocumentKeySet{doc.key};
    FSTRemoteEvent *event = [[FSTRemoteEvent alloc] initWithSnapshotVersion:SnapshotVersion::None()
        targetChanges:{}
        targetMismatches:{}
        documentUpdates:{
          { limboKey, doc }
        }
        limboDocuments:std::move(limboDocuments)];
    [self applyRemoteEvent:event];
  } else {
    FSTQueryView *queryView = self.queryViewsByTarget[@(targetID)];
    HARD_ASSERT(queryView, "Unknown targetId: %s", targetID);
    FSTQuery *query = queryView.query;
    [self.localStore releaseQuery:query];
    [self removeAndCleanupQuery:queryView];
    if ([self errorIsInteresting:error]) {
      LOG_WARN("Listen for query at %s failed: %s", query.path.CanonicalString(),
               error.localizedDescription);
    }
    [self.delegate handleError:error forQuery:query];
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

- (void)rejectFailedWriteWithBatchID:(BatchId)batchID error:(NSError *)error {
  [self assertDelegateExistsForSelector:_cmd];
  FSTMaybeDocumentDictionary *changes = [self.localStore rejectBatchID:batchID];

  if (!changes.isEmpty && [self errorIsInteresting:error]) {
    LOG_WARN("Write at %s failed: %s", changes.minKey.path.CanonicalString(),
             error.localizedDescription);
  }

  // The local store may or may not be able to apply the write result and raise events immediately
  // (depending on whether the watcher is caught up), so we raise user callbacks first so that they
  // consistently happen before listen events.
  [self processUserCallbacksForBatchID:batchID error:error];

  [self emitNewSnapshotsWithChanges:changes remoteEvent:nil];
}

- (void)processUserCallbacksForBatchID:(BatchId)batchID error:(NSError *_Nullable)error {
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
  HARD_ASSERT(self.delegate, "Tried to call '%s' before delegate was registered.",
              NSStringFromSelector(methodSelector));
}

- (void)removeAndCleanupQuery:(FSTQueryView *)queryView {
  [self.queryViewsByQuery removeObjectForKey:queryView.query];
  [self.queryViewsByTarget removeObjectForKey:@(queryView.targetID)];

  DocumentKeySet limboKeys = [self.limboDocumentRefs referencedKeysForID:queryView.targetID];
  [self.limboDocumentRefs removeReferencesForID:queryView.targetID];
  for (const DocumentKey &key : limboKeys) {
    if (![self.limboDocumentRefs containsKey:key]) {
      // We removed the last reference for this key.
      [self removeLimboTargetForKey:key];
    }
  }
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

        FSTTargetChange *_Nullable targetChange = nil;
        if (remoteEvent) {
          auto it = remoteEvent.targetChanges.find(queryView.targetID);
          if (it != remoteEvent.targetChanges.end()) {
            targetChange = it->second;
          }
        }
        FSTViewChange *viewChange =
            [queryView.view applyChangesToDocuments:viewDocChanges targetChange:targetChange];

        [self updateTrackedLimboDocumentsWithChanges:viewChange.limboChanges
                                            targetID:queryView.targetID];

        if (viewChange.snapshot) {
          [newSnapshots addObject:viewChange.snapshot];
          FSTLocalViewChanges *docChanges =
              [FSTLocalViewChanges changesForViewSnapshot:viewChange.snapshot
                                             withTargetID:queryView.targetID];
          [documentChangesInAllViews addObject:docChanges];
        }
      }];

  [self.delegate handleViewSnapshots:newSnapshots];
  [self.localStore notifyLocalViewChanges:documentChangesInAllViews];
}

/** Updates the limbo document state for the given targetID. */
- (void)updateTrackedLimboDocumentsWithChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges
                                      targetID:(TargetId)targetID {
  for (FSTLimboDocumentChange *limboChange in limboChanges) {
    switch (limboChange.type) {
      case FSTLimboDocumentChangeTypeAdded:
        [self.limboDocumentRefs addReferenceToKey:limboChange.key forID:targetID];
        [self trackLimboChange:limboChange];
        break;

      case FSTLimboDocumentChangeTypeRemoved:
        LOG_DEBUG("Document no longer in limbo: %s", limboChange.key.ToString());
        [self.limboDocumentRefs removeReferenceToKey:limboChange.key forID:targetID];
        if (![self.limboDocumentRefs containsKey:limboChange.key]) {
          // We removed the last reference for this key
          [self removeLimboTargetForKey:limboChange.key];
        }
        break;

      default:
        HARD_FAIL("Unknown limbo change type: %s", limboChange.type);
    }
  }
}

- (void)trackLimboChange:(FSTLimboDocumentChange *)limboChange {
  DocumentKey key{limboChange.key};

  if (_limboTargetsByKey.find(key) == _limboTargetsByKey.end()) {
    LOG_DEBUG("New document in limbo: %s", key.ToString());
    TargetId limboTargetID = _targetIdGenerator.NextId();
    FSTQuery *query = [FSTQuery queryWithPath:key.path()];
    FSTQueryData *queryData = [[FSTQueryData alloc] initWithQuery:query
                                                         targetID:limboTargetID
                                             listenSequenceNumber:kIrrelevantSequenceNumber
                                                          purpose:FSTQueryPurposeLimboResolution];
    _limboResolutionsByTarget.emplace(limboTargetID, LimboResolution{key});
    [self.remoteStore listenToTargetWithQueryData:queryData];
    _limboTargetsByKey[key] = limboTargetID;
  }
}

- (void)removeLimboTargetForKey:(const DocumentKey &)key {
  const auto iter = _limboTargetsByKey.find(key);
  if (iter == _limboTargetsByKey.end()) {
    // This target already got removed, because the query failed.
    return;
  }
  TargetId limboTargetID = iter->second;
  [self.remoteStore stopListeningToTargetID:limboTargetID];
  _limboTargetsByKey.erase(key);
  _limboResolutionsByTarget.erase(limboTargetID);
}

// Used for testing
- (std::map<DocumentKey, TargetId>)currentLimboDocuments {
  // Return defensive copy
  return _limboTargetsByKey;
}

- (void)credentialDidChangeWithUser:(const firebase::firestore::auth::User &)user {
  BOOL userChanged = (_currentUser != user);
  _currentUser = user;

  if (userChanged) {
    // Notify local store and emit any resulting events from swapping out the mutation queue.
    FSTMaybeDocumentDictionary *changes = [self.localStore userDidChange:user];
    [self emitNewSnapshotsWithChanges:changes remoteEvent:nil];
  }

  // Notify remote store so it can restart its streams.
  [self.remoteStore credentialDidChange];
}

- (firebase::firestore::model::DocumentKeySet)remoteKeysForTarget:(FSTBoxedTargetID *)targetId {
  const auto iter = _limboResolutionsByTarget.find([targetId intValue]);
  if (iter != _limboResolutionsByTarget.end() && iter->second.document_received) {
    return DocumentKeySet{iter->second.key};
  } else {
    FSTQueryView *queryView = self.queryViewsByTarget[targetId];
    return queryView ? queryView.view.syncedDocuments : DocumentKeySet{};
  }
}

/**
 * Decides if the error likely represents a developer mistake such as forgetting to create an index
 * or permission denied. Used to decide whether an error is worth automatically logging as a
 * warning.
 */
- (BOOL)errorIsInteresting:(NSError *)error {
  if (error.domain == FIRFirestoreErrorDomain) {
    if (error.code == FIRFirestoreErrorCodeFailedPrecondition &&
        [error.localizedDescription containsString:@"requires an index"]) {
      return YES;
    } else if (error.code == FIRFirestoreErrorCodePermissionDenied) {
      return YES;
    }
  }

  return NO;
}

@end

NS_ASSUME_NONNULL_END
