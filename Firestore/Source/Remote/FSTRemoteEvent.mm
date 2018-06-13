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

#import "Firestore/Source/Remote/FSTRemoteEvent.h"

#include <map>
#include <set>
#include <unordered_map>
#include <utility>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Remote/FSTExistenceFilter.h"
#import "Firestore/Source/Remote/FSTRemoteStore.h"
#import "Firestore/Source/Remote/FSTWatchChange.h"
#import "Firestore/Source/Util/FSTClasses.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeyHash;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::util::Hash;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTTargetChange

@implementation FSTTargetChange {
  DocumentKeySet _addedDocuments;
  DocumentKeySet _modifiedDocuments;
  DocumentKeySet _removedDocuments;
}

- (instancetype)initWithResumeToken:(NSData *)resumeToken
                            current:(BOOL)current
                     addedDocuments:(DocumentKeySet)addedDocuments
                  modifiedDocuments:(DocumentKeySet)modifiedDocuments
                   removedDocuments:(DocumentKeySet)removedDocuments {
  if (self = [super init]) {
    _resumeToken = [resumeToken copy];
    _current = current;
    _addedDocuments = std::move(addedDocuments);
    _modifiedDocuments = std::move(modifiedDocuments);
    _removedDocuments = std::move(removedDocuments);
  }
  return self;
}

- (const DocumentKeySet &)addedDocuments {
  return _addedDocuments;
}

- (const DocumentKeySet &)modifiedDocuments {
  return _modifiedDocuments;
}

- (const DocumentKeySet &)removedDocuments {
  return _removedDocuments;
}

- (BOOL)isEqual:(id)other {
  if (other == self) {
    return YES;
  }
  if (![other isMemberOfClass:[FSTTargetChange class]]) {
    return NO;
  }

  return [self current] == [other current] &&
         [[self resumeToken] isEqualToData:[other resumeToken]] &&
         [self addedDocuments] == [other addedDocuments] &&
         [self modifiedDocuments] == [other modifiedDocuments] &&
         [self removedDocuments] == [other removedDocuments];
}

@end

#pragma mark - FSTTargetState

/** Tracks the internal state of a Watch target. */
@interface FSTTargetState : NSObject

/**
 * Whether this target has been marked 'current'.
 *
 * 'Current' has special meaning in the RPC protocol: It implies that the Watch backend has sent us
 * all changes up to the point at which the target was added and that the target is consistent with
 * the rest of the watch stream.
 */
@property(nonatomic) BOOL current;

/** The last resume token sent to us for this target. */
@property(nonatomic, readonly, strong) NSData *resumeToken;

/** Whether we have modified any state that should trigger a snapshot. */
@property(nonatomic, readonly) BOOL hasPendingChanges;

/** Whether this target has pending target adds or target removes. */
- (BOOL)isPending;

/**
 * Applies the resume token to the TargetChange, but only when it has a new value. Empty
 * resumeTokens are discarded.
 */
- (void)updateResumeToken:(NSData *)resumeToken;

/** Resets the document changes and sets `hasPendingChanges` to false. */
- (void)clearPendingChanges;
/**
 * Creates a target change from the current set of changes.
 *
 * To reset the document changes after raising this snapshot, call `clearPendingChanges()`.
 */
- (FSTTargetChange *)toTargetChange;

- (void)recordTargetRequest;
- (void)recordTargetResponse;
- (void)markCurrent;
- (void)addDocumentChangeWithType:(FSTDocumentViewChangeType)type
                           forKey:(const DocumentKey &)documentKey;
- (void)removeDocumentChangeForKey:(const DocumentKey &)documentKey;

@end

@implementation FSTTargetState {
  /**
   * The number of outstanding responses (adds or removes) that we are waiting on. We only consider
   * targets active that have no outstanding responses.
   */
  int _outstandingResponses;

  /**
   * Keeps track of the document changes since the last raised snapshot.
   *
   * These changes are continuously updated as we receive document updates and always reflect the
   * current set of changes against the last issued snapshot.
   */
  std::unordered_map<DocumentKey, FSTDocumentViewChangeType, DocumentKeyHash> _documentChanges;
}

- (instancetype)init {
  if (self = [super init]) {
    _resumeToken = [NSData data];
    _outstandingResponses = 0;

    // We initialize to 'true' so that newly-added targets are included in the next RemoteEvent.
    _hasPendingChanges = YES;
  }
  return self;
}

- (BOOL)isPending {
  return _outstandingResponses != 0;
}

- (void)updateResumeToken:(NSData *)resumeToken {
  if (resumeToken.length > 0) {
    _hasPendingChanges = YES;
    _resumeToken = [resumeToken copy];
  }
}

- (void)clearPendingChanges {
  _hasPendingChanges = NO;
  _documentChanges.clear();
}

- (void)recordTargetRequest {
  _outstandingResponses += 1;
}

- (void)recordTargetResponse {
  _outstandingResponses -= 1;
}

- (void)markCurrent {
  _hasPendingChanges = YES;
  _current = true;
}

- (void)addDocumentChangeWithType:(FSTDocumentViewChangeType)type
                           forKey:(const DocumentKey &)documentKey {
  _hasPendingChanges = YES;
  _documentChanges[documentKey] = type;
}

- (void)removeDocumentChangeForKey:(const DocumentKey &)documentKey {
  _hasPendingChanges = YES;
  _documentChanges.erase(documentKey);
}

- (FSTTargetChange *)toTargetChange {
  DocumentKeySet addedDocuments;
  DocumentKeySet modifiedDocuments;
  DocumentKeySet removedDocuments;

  for (const auto &entry : _documentChanges) {
    switch (entry.second) {
      case FSTDocumentViewChangeTypeAdded:
        addedDocuments = addedDocuments.insert(entry.first);
        break;
      case FSTDocumentViewChangeTypeModified:
        modifiedDocuments = modifiedDocuments.insert(entry.first);
        break;
      case FSTDocumentViewChangeTypeRemoved:
        removedDocuments = removedDocuments.insert(entry.first);
        break;
      default:
        HARD_FAIL("Encountered invalid change type: %s", entry.second);
    }
  }

  return [[FSTTargetChange alloc] initWithResumeToken:_resumeToken
                                              current:_current
                                       addedDocuments:std::move(addedDocuments)
                                    modifiedDocuments:std::move(modifiedDocuments)
                                     removedDocuments:std::move(removedDocuments)];
}
@end

#pragma mark - FSTRemoteEvent

@implementation FSTRemoteEvent {
  SnapshotVersion _snapshotVersion;
  std::unordered_map<FSTTargetID, FSTTargetChange *> _targetChanges;
  std::unordered_set<FSTTargetID> _targetMismatches;
  std::unordered_map<DocumentKey, FSTMaybeDocument *, DocumentKeyHash> _documentUpdates;
  DocumentKeySet _limboDocumentChanges;
}

- (instancetype)
initWithSnapshotVersion:(SnapshotVersion)snapshotVersion
          targetChanges:(std::unordered_map<FSTTargetID, FSTTargetChange *>)targetChanges
       targetMismatches:(std::unordered_set<FSTTargetID>)targetMismatches
        documentUpdates:
            (std::unordered_map<DocumentKey, FSTMaybeDocument *, DocumentKeyHash>)documentUpdates
         limboDocuments:(DocumentKeySet)limboDocuments {
  self = [super init];
  if (self) {
    _snapshotVersion = std::move(snapshotVersion);
    _targetChanges = std::move(targetChanges);
    _targetMismatches = std::move(targetMismatches);
    _documentUpdates = std::move(documentUpdates);
    _limboDocumentChanges = std::move(limboDocuments);
  }
  return self;
}

- (const SnapshotVersion &)snapshotVersion {
  return _snapshotVersion;
}

- (const DocumentKeySet &)limboDocumentChanges {
  return _limboDocumentChanges;
}

- (const std::unordered_map<FSTTargetID, FSTTargetChange *> &)targetChanges {
  return _targetChanges;
}

- (const std::unordered_map<DocumentKey, FSTMaybeDocument *, DocumentKeyHash> &)documentUpdates {
  return _documentUpdates;
}

- (const std::unordered_set<FSTTargetID> &)targetMismatches {
  return _targetMismatches;
}

@end

#pragma mark - FSTWatchChangeAggregator

@implementation FSTWatchChangeAggregator {
  /** The internal state of all tracked targets. */
  std::unordered_map<FSTTargetID, FSTTargetState *> _targetStates;

  /** Keeps track of document to update */
  std::unordered_map<DocumentKey, FSTMaybeDocument *, DocumentKeyHash> _pendingDocumentUpdates;

  /** A mapping of document keys to their set of target IDs. */
  std::unordered_map<DocumentKey, std::set<FSTTargetID>, DocumentKeyHash>
      _pendingDocumentTargetMappings;

  /**
   * A list of targets with existence filter mismatches. These targets are known to be inconsistent
   * and their listens needs to be re-established by RemoteStore.
   */
  std::unordered_set<FSTTargetID> _pendingTargetResets;

  id<FSTTargetMetadataProvider> _targetMetadataProvider;
}

- (instancetype)initWithTargetMetadataProvider:
    (id<FSTTargetMetadataProvider>)targetMetadataProvider {
  self = [super init];
  if (self) {
    _targetMetadataProvider = targetMetadataProvider;
  }
  return self;
}

- (void)handleDocumentChange:(FSTDocumentWatchChange *)documentChange {
  for (FSTBoxedTargetID *targetID in documentChange.updatedTargetIDs) {
    if ([documentChange.document isKindOfClass:[FSTDocument class]]) {
      [self addDocument:documentChange.document toTarget:targetID.intValue];
    } else if ([documentChange.document isKindOfClass:[FSTDeletedDocument class]]) {
      [self removeDocument:documentChange.document
                   withKey:documentChange.documentKey
                fromTarget:targetID.intValue];
    }
  }

  for (FSTBoxedTargetID *targetID in documentChange.removedTargetIDs) {
    [self removeDocument:documentChange.document
                 withKey:documentChange.documentKey
              fromTarget:targetID.intValue];
  }
}

- (void)handleTargetChange:(FSTWatchTargetChange *)targetChange {
  for (FSTBoxedTargetID *boxedTargetID in targetChange.targetIDs) {
    int targetID = boxedTargetID.intValue;
    FSTTargetState *targetState = [self ensureTargetStateForTarget:targetID];
    switch (targetChange.state) {
      case FSTWatchTargetChangeStateNoChange:
        if ([self isActiveTarget:targetID]) {
          [targetState updateResumeToken:targetChange.resumeToken];
        }
        break;
      case FSTWatchTargetChangeStateAdded:
        // We need to decrement the number of pending acks needed from watch for this targetId.
        [targetState recordTargetResponse];
        if (!targetState.isPending) {
          // We have a freshly added target, so we need to reset any state that we had previously.
          // This can happen e.g. when remove and add back a target for existence filter mismatches.
          [targetState clearPendingChanges];
        }
        [targetState updateResumeToken:targetChange.resumeToken];
        break;
      case FSTWatchTargetChangeStateRemoved:
        // We need to keep track of removed targets to we can post-filter and remove any target
        // changes.
        [targetState recordTargetResponse];
        if (!targetState.isPending) {
          [self removeTarget:targetID];
        }
        HARD_ASSERT(!targetChange.cause, "WatchChangeAggregator does not handle errored targets");
        break;
      case FSTWatchTargetChangeStateCurrent:
        if ([self isActiveTarget:targetID]) {
          [targetState markCurrent];
          [targetState updateResumeToken:targetChange.resumeToken];
        }
        break;
      case FSTWatchTargetChangeStateReset:
        if ([self isActiveTarget:targetID]) {
          // Reset the target and synthesizes removes for all existing documents. The backend will
          // re-add any documents that still match the target before it sends the next global
          // snapshot.
          [self resetTarget:targetID];
          [targetState updateResumeToken:targetChange.resumeToken];
        }
        break;
      default:
        HARD_FAIL("Unknown target watch change state: %s", targetChange.state);
    }
  }
}

- (void)removeTarget:(FSTTargetID)targetID {
  _targetStates.erase(targetID);
}

- (void)handleExistenceFilter:(FSTExistenceFilterWatchChange *)existenceFilter {
  FSTTargetID targetID = existenceFilter.targetID;
  int expectedCount = existenceFilter.filter.count;

  FSTQueryData *queryData = [self queryDataForActiveTarget:targetID];
  if (queryData) {
    FSTQuery *query = queryData.query;
    if ([query isDocumentQuery]) {
      if (expectedCount == 0) {
        // The existence filter told us the document does not exist. We deduce that this document
        // does not exist and apply a deleted document to our updates. Without applying this deleted
        // document there might be another query that will raise this document as part of a snapshot
        // until it is resolved, essentially exposing inconsistency between queries.
        FSTDocumentKey *key = [FSTDocumentKey keyWithPath:query.path];
        [self
            removeDocument:[FSTDeletedDocument documentWithKey:key version:SnapshotVersion::None()]
                   withKey:key
                fromTarget:targetID];
      } else {
        HARD_ASSERT(expectedCount == 1, "Single document existence filter with count: %s",
                    expectedCount);
      }
    } else {
      int currentSize = [self currentDocumentCountForTarget:targetID];
      if (currentSize != expectedCount) {
        // Existence filter mismatch: We reset the mapping and raise a new snapshot with
        // `isFromCache:true`.
        [self resetTarget:targetID];
        _pendingTargetResets.insert(targetID);
      }
    }
  }
}

- (int)currentDocumentCountForTarget:(FSTTargetID)targetID {
  FSTTargetState *targetState = [self ensureTargetStateForTarget:targetID];
  FSTTargetChange *targetChange = [targetState toTargetChange];
  return ([_targetMetadataProvider remoteKeysForTarget:@(targetID)].size() +
          targetChange.addedDocuments.size() - targetChange.removedDocuments.size());
}

/**
 * Resets the state of a Watch target to its initial state (e.g. sets 'current' to false, clears the
 * resume token and removes its target mapping from all documents).
 */
- (void)resetTarget:(FSTTargetID)targetID {
  auto currentTargetState = _targetStates.find(targetID);
  HARD_ASSERT(currentTargetState != _targetStates.end() && !(currentTargetState->second.isPending),
              "Should only reset active targets");

  _targetStates[targetID] = [FSTTargetState new];

  // Trigger removal for any documents currently mapped to this target. These removals will be part
  // of the initial snapshot if Watch does not resend these documents.
  DocumentKeySet existingKeys = [_targetMetadataProvider remoteKeysForTarget:@(targetID)];

  for (FSTDocumentKey *key : existingKeys) {
    [self removeDocument:nil withKey:key fromTarget:targetID];
  }
}

/**
 * Adds the provided document to the internal list of document updates and its document key to the
 * given target's mapping.
 */
- (void)addDocument:(FSTMaybeDocument *)document toTarget:(FSTTargetID)targetID {
  if (![self isActiveTarget:targetID]) {
    return;
  }

  FSTDocumentViewChangeType changeType = [self containsDocument:document.key inTarget:targetID]
                                             ? FSTDocumentViewChangeTypeModified
                                             : FSTDocumentViewChangeTypeAdded;

  FSTTargetState *targetState = [self ensureTargetStateForTarget:targetID];
  [targetState addDocumentChangeWithType:changeType forKey:document.key];

  _pendingDocumentUpdates[document.key] = document;
  _pendingDocumentTargetMappings[document.key].insert(targetID);
}

/**
 * Removes the provided document from the target mapping. If the document no longer matches the
 * target, but the document's state is still known (e.g. we know that the document was deleted or we
 * received the change that caused the filter mismatch), the new document can be provided to update
 * the remote document cache.
 */
- (void)removeDocument:(FSTMaybeDocument *_Nullable)document
               withKey:(const DocumentKey &)key
            fromTarget:(FSTTargetID)targetID {
  if (![self isActiveTarget:targetID]) {
    return;
  }

  FSTTargetState *targetState = [self ensureTargetStateForTarget:targetID];

  if ([self containsDocument:key inTarget:targetID]) {
    [targetState addDocumentChangeWithType:FSTDocumentViewChangeTypeRemoved forKey:key];
  } else {
    // The document may have entered and left the target before we raised a snapshot, so we can just
    // ignore the change.
    [targetState removeDocumentChangeForKey:key];
  }
  _pendingDocumentTargetMappings[key].insert(targetID);

  if (document) {
    _pendingDocumentUpdates[key] = document;
  }
}

/**
 * Returns whether the LocalStore considers the document to be part of the specified target.
 */
- (BOOL)containsDocument:(FSTDocumentKey *)key inTarget:(FSTTargetID)targetID {
  const DocumentKeySet &existingKeys = [_targetMetadataProvider remoteKeysForTarget:@(targetID)];
  return existingKeys.contains(key);
}

- (FSTTargetState *)ensureTargetStateForTarget:(FSTTargetID)targetID {
  if (!_targetStates[targetID]) {
    _targetStates[targetID] = [FSTTargetState new];
  }

  return _targetStates[targetID];
}

/**
 * Returns YES if the given targetId is active. Active targets are those for which there are no
 * pending requests to add a listen and are in the current list of targets the client cares about.
 *
 * Clients can repeatedly listen and stop listening to targets, so this check is useful in
 * preventing in preventing race conditions for a target where events arrive but the server hasn't
 * yet acknowledged the intended change in state.
 */
- (BOOL)isActiveTarget:(FSTTargetID)targetID {
  return [self queryDataForActiveTarget:targetID] != nil;
}

- (nullable FSTQueryData *)queryDataForActiveTarget:(FSTTargetID)targetID {
  auto targetState = _targetStates.find(targetID);
  return targetState != _targetStates.end() && targetState->second.isPending
             ? nil
             : [_targetMetadataProvider queryDataForTarget:@(targetID)];
}

- (FSTRemoteEvent *)remoteEventAtSnapshotVersion:(const SnapshotVersion &)snapshotVersion {
  std::unordered_map<FSTTargetID, FSTTargetChange *> targetChanges;

  for (const auto &entry : _targetStates) {
    FSTTargetID targetID = entry.first;
    FSTTargetState *targetState = entry.second;

    FSTQueryData *queryData = [self queryDataForActiveTarget:targetID];
    if (queryData) {
      if (targetState.current && [queryData.query isDocumentQuery]) {
        // Document queries for document that don't exist can produce an empty result set. To update
        // our local cache, we synthesize a document delete if we have not previously received the
        // document. This resolves the limbo state of the document, removing it from
        // limboDocumentRefs.
        FSTDocumentKey *key = [FSTDocumentKey keyWithPath:queryData.query.path];
        if (_pendingDocumentUpdates.find(key) == _pendingDocumentUpdates.end() &&
            ![self containsDocument:key inTarget:targetID]) {
          [self removeDocument:[FSTDeletedDocument documentWithKey:key version:snapshotVersion]
                       withKey:key
                    fromTarget:targetID];
        }
      }

      if (targetState.hasPendingChanges) {
        targetChanges[targetID] = [targetState toTargetChange];
        [targetState clearPendingChanges];
      }
    }
  }

  DocumentKeySet resolvedLimboDocuments;

  // We extract the set of limbo-only document updates as the GC logic  special-cases documents that
  // do not appear in the query cache.
  //
  // TODO(gsoltis): Expand on this comment.
  for (const auto &entry : _pendingDocumentTargetMappings) {
    BOOL isOnlyLimboTarget = YES;

    for (FSTTargetID targetID : entry.second) {
      FSTQueryData *queryData = [self queryDataForActiveTarget:targetID];
      if (queryData && queryData.purpose != FSTQueryPurposeLimboResolution) {
        isOnlyLimboTarget = NO;
        break;
      }
    }

    if (isOnlyLimboTarget) {
      resolvedLimboDocuments = resolvedLimboDocuments.insert(entry.first);
    }
  }

  FSTRemoteEvent *remoteEvent =
      [[FSTRemoteEvent alloc] initWithSnapshotVersion:snapshotVersion
                                        targetChanges:targetChanges
                                     targetMismatches:_pendingTargetResets
                                      documentUpdates:_pendingDocumentUpdates
                                       limboDocuments:resolvedLimboDocuments];

  _pendingDocumentUpdates.clear();
  _pendingDocumentTargetMappings.clear();
  _pendingTargetResets.clear();

  return remoteEvent;
}

- (void)recordTargetRequest:(FSTBoxedTargetID *)targetID {
  // For each request we get we need to record we need a response for it.
  FSTTargetState *targetState = [self ensureTargetStateForTarget:targetID.intValue];
  [targetState recordTargetRequest];
}
@end

NS_ASSUME_NONNULL_END
