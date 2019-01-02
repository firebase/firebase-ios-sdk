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

#import "Firestore/Source/Core/FSTView.h"

#include <utility>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Core/FSTViewSnapshot.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentSet.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::OnlineState;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTViewDocumentChanges

/** The result of applying a set of doc changes to a view. */
@interface FSTViewDocumentChanges ()

- (instancetype)initWithDocumentSet:(FSTDocumentSet *)documentSet
                          changeSet:(FSTDocumentViewChangeSet *)changeSet
                        needsRefill:(BOOL)needsRefill
                        mutatedKeys:(DocumentKeySet)mutatedKeys NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTViewDocumentChanges {
  DocumentKeySet _mutatedKeys;
}

- (instancetype)initWithDocumentSet:(FSTDocumentSet *)documentSet
                          changeSet:(FSTDocumentViewChangeSet *)changeSet
                        needsRefill:(BOOL)needsRefill
                        mutatedKeys:(DocumentKeySet)mutatedKeys {
  self = [super init];
  if (self) {
    _documentSet = documentSet;
    _changeSet = changeSet;
    _needsRefill = needsRefill;
    _mutatedKeys = std::move(mutatedKeys);
  }
  return self;
}

- (const DocumentKeySet &)mutatedKeys {
  return _mutatedKeys;
}

@end

#pragma mark - FSTLimboDocumentChange

@interface FSTLimboDocumentChange ()

+ (instancetype)changeWithType:(FSTLimboDocumentChangeType)type key:(DocumentKey)key;

- (instancetype)initWithType:(FSTLimboDocumentChangeType)type
                         key:(DocumentKey)key NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTLimboDocumentChange {
  DocumentKey _key;
}

+ (instancetype)changeWithType:(FSTLimboDocumentChangeType)type key:(DocumentKey)key {
  return [[FSTLimboDocumentChange alloc] initWithType:type key:std::move(key)];
}

- (instancetype)initWithType:(FSTLimboDocumentChangeType)type key:(DocumentKey)key {
  self = [super init];
  if (self) {
    _type = type;
    _key = std::move(key);
  }
  return self;
}

- (const DocumentKey &)key {
  return _key;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  }
  if (![other isKindOfClass:[FSTLimboDocumentChange class]]) {
    return NO;
  }
  FSTLimboDocumentChange *otherChange = (FSTLimboDocumentChange *)other;
  return self.type == otherChange.type && self.key == otherChange.key;
}

- (NSUInteger)hash {
  NSUInteger hash = self.type;
  hash = hash * 31u + [self.key hash];
  return hash;
}

@end

#pragma mark - FSTViewChange

@interface FSTViewChange ()

+ (FSTViewChange *)changeWithSnapshot:(nullable FSTViewSnapshot *)snapshot
                         limboChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges;

- (instancetype)initWithSnapshot:(nullable FSTViewSnapshot *)snapshot
                    limboChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTViewChange

+ (FSTViewChange *)changeWithSnapshot:(nullable FSTViewSnapshot *)snapshot
                         limboChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges {
  return [[self alloc] initWithSnapshot:snapshot limboChanges:limboChanges];
}

- (instancetype)initWithSnapshot:(nullable FSTViewSnapshot *)snapshot
                    limboChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges {
  self = [super init];
  if (self) {
    _snapshot = snapshot;
    _limboChanges = limboChanges;
  }
  return self;
}

@end

#pragma mark - FSTView

static NSComparisonResult FSTCompareDocumentViewChangeTypes(FSTDocumentViewChangeType c1,
                                                            FSTDocumentViewChangeType c2);

@interface FSTView ()

@property(nonatomic, strong, readonly) FSTQuery *query;

@property(nonatomic, assign) FSTSyncState syncState;

/**
 * A flag whether the view is current with the backend. A view is considered current after it
 * has seen the current flag from the backend and did not lose consistency within the watch stream
 * (e.g. because of an existence filter mismatch).
 */
@property(nonatomic, assign, getter=isCurrent) BOOL current;

@property(nonatomic, strong) FSTDocumentSet *documentSet;

@end

@implementation FSTView {
  /** Documents included in the remote target. */
  DocumentKeySet _syncedDocuments;

  /** Documents in the view but not in the remote target */
  DocumentKeySet _limboDocuments;

  /** Document Keys that have local changes. */
  DocumentKeySet _mutatedKeys;
}

- (instancetype)initWithQuery:(FSTQuery *)query remoteDocuments:(DocumentKeySet)remoteDocuments {
  self = [super init];
  if (self) {
    _query = query;
    _documentSet = [FSTDocumentSet documentSetWithComparator:query.comparator];
    _syncedDocuments = std::move(remoteDocuments);
  }
  return self;
}

- (const DocumentKeySet &)syncedDocuments {
  return _syncedDocuments;
}

- (FSTViewDocumentChanges *)computeChangesWithDocuments:(const MaybeDocumentMap &)docChanges {
  return [self computeChangesWithDocuments:docChanges previousChanges:nil];
}

- (FSTViewDocumentChanges *)computeChangesWithDocuments:(const MaybeDocumentMap &)docChanges
                                        previousChanges:
                                            (nullable FSTViewDocumentChanges *)previousChanges {
  FSTDocumentViewChangeSet *changeSet =
      previousChanges ? previousChanges.changeSet : [FSTDocumentViewChangeSet changeSet];
  FSTDocumentSet *oldDocumentSet = previousChanges ? previousChanges.documentSet : self.documentSet;

  DocumentKeySet newMutatedKeys = previousChanges ? previousChanges.mutatedKeys : _mutatedKeys;
  DocumentKeySet oldMutatedKeys = _mutatedKeys;
  FSTDocumentSet *newDocumentSet = oldDocumentSet;
  BOOL needsRefill = NO;

  // Track the last doc in a (full) limit. This is necessary, because some update (a delete, or an
  // update moving a doc past the old limit) might mean there is some other document in the local
  // cache that either should come (1) between the old last limit doc and the new last document,
  // in the case of updates, or (2) after the new last document, in the case of deletes. So we
  // keep this doc at the old limit to compare the updates to.
  //
  // Note that this should never get used in a refill (when previousChanges is set), because there
  // will only be adds -- no deletes or updates.
  FSTDocument *_Nullable lastDocInLimit =
      (self.query.limit && oldDocumentSet.count == self.query.limit) ? oldDocumentSet.lastDocument
                                                                     : nil;

  for (const auto &kv : docChanges) {
    const DocumentKey &key = kv.first;
    FSTMaybeDocument *maybeNewDoc = kv.second;

    FSTDocument *_Nullable oldDoc = [oldDocumentSet documentForKey:key];
    FSTDocument *_Nullable newDoc = nil;
    if ([maybeNewDoc isKindOfClass:[FSTDocument class]]) {
      newDoc = (FSTDocument *)maybeNewDoc;
    }
    if (newDoc) {
      HARD_ASSERT(key == newDoc.key, "Mismatching key in document changes: %s != %s", key,
                  newDoc.key.ToString());
      if (![self.query matchesDocument:newDoc]) {
        newDoc = nil;
      }
    }

    BOOL oldDocHadPendingMutations = oldDoc && oldMutatedKeys.contains(oldDoc.key);

    // We only consider committed mutations for documents that were mutated during the lifetime of
    // the view.
    BOOL newDocHasPendingMutations =
        newDoc && (newDoc.hasLocalMutations ||
                   (oldMutatedKeys.contains(newDoc.key) && newDoc.hasCommittedMutations));

    BOOL changeApplied = NO;
    // Calculate change
    if (oldDoc && newDoc) {
      BOOL docsEqual = [oldDoc.data isEqual:newDoc.data];
      if (!docsEqual) {
        if (![self shouldWaitForSyncedDocument:newDoc oldDocument:oldDoc]) {
          [changeSet addChange:[FSTDocumentViewChange
                                   changeWithDocument:newDoc
                                                 type:FSTDocumentViewChangeTypeModified]];
          changeApplied = YES;

          if (lastDocInLimit && self.query.comparator(newDoc, lastDocInLimit) > 0) {
            // This doc moved from inside the limit to after the limit. That means there may be
            // some doc in the local cache that's actually less than this one.
            needsRefill = YES;
          }
        }
      } else if (oldDocHadPendingMutations != newDocHasPendingMutations) {
        [changeSet
            addChange:[FSTDocumentViewChange changeWithDocument:newDoc
                                                           type:FSTDocumentViewChangeTypeMetadata]];
        changeApplied = YES;
      }

    } else if (!oldDoc && newDoc) {
      [changeSet
          addChange:[FSTDocumentViewChange changeWithDocument:newDoc
                                                         type:FSTDocumentViewChangeTypeAdded]];
      changeApplied = YES;
    } else if (oldDoc && !newDoc) {
      [changeSet
          addChange:[FSTDocumentViewChange changeWithDocument:oldDoc
                                                         type:FSTDocumentViewChangeTypeRemoved]];
      changeApplied = YES;

      if (lastDocInLimit) {
        // A doc was removed from a full limit query. We'll need to re-query from the local cache
        // to see if we know about some other doc that should be in the results.
        needsRefill = YES;
      }
    }

    if (changeApplied) {
      if (newDoc) {
        newDocumentSet = [newDocumentSet documentSetByAddingDocument:newDoc];
        if (newDoc.hasLocalMutations) {
          newMutatedKeys = newMutatedKeys.insert(key);
        } else {
          newMutatedKeys = newMutatedKeys.erase(key);
        }
      } else {
        newDocumentSet = [newDocumentSet documentSetByRemovingKey:key];
        newMutatedKeys = newMutatedKeys.erase(key);
      }
    }
  }

  if (self.query.limit) {
    for (long i = newDocumentSet.count - self.query.limit; i > 0; --i) {
      FSTDocument *oldDoc = [newDocumentSet lastDocument];
      newDocumentSet = [newDocumentSet documentSetByRemovingKey:oldDoc.key];
      newMutatedKeys = newMutatedKeys.erase(oldDoc.key);
      [changeSet
          addChange:[FSTDocumentViewChange changeWithDocument:oldDoc
                                                         type:FSTDocumentViewChangeTypeRemoved]];
    }
  }

  HARD_ASSERT(!needsRefill || !previousChanges,
              "View was refilled using docs that themselves needed refilling.");

  return [[FSTViewDocumentChanges alloc] initWithDocumentSet:newDocumentSet
                                                   changeSet:changeSet
                                                 needsRefill:needsRefill
                                                 mutatedKeys:newMutatedKeys];
}

- (BOOL)shouldWaitForSyncedDocument:(FSTDocument *)newDoc oldDocument:(FSTDocument *)oldDoc {
  // We suppress the initial change event for documents that were modified as part of a write
  // acknowledgment (e.g. when the value of a server transform is applied) as Watch will send us
  // the same document again. By suppressing the event, we only raise two user visible events (one
  // with `hasPendingWrites` and the final state of the document) instead of three (one with
  // `hasPendingWrites`, the modified document with `hasPendingWrites` and the final state of the
  // document).
  return (oldDoc.hasLocalMutations && newDoc.hasCommittedMutations && !newDoc.hasLocalMutations);
}

- (FSTViewChange *)applyChangesToDocuments:(FSTViewDocumentChanges *)docChanges {
  return [self applyChangesToDocuments:docChanges targetChange:nil];
}

- (FSTViewChange *)applyChangesToDocuments:(FSTViewDocumentChanges *)docChanges
                              targetChange:(nullable FSTTargetChange *)targetChange {
  HARD_ASSERT(!docChanges.needsRefill, "Cannot apply changes that need a refill");

  FSTDocumentSet *oldDocuments = self.documentSet;
  self.documentSet = docChanges.documentSet;
  _mutatedKeys = docChanges.mutatedKeys;

  // Sort changes based on type and query comparator.
  NSArray<FSTDocumentViewChange *> *changes = [docChanges.changeSet changes];
  changes = [changes sortedArrayUsingComparator:^NSComparisonResult(FSTDocumentViewChange *c1,
                                                                    FSTDocumentViewChange *c2) {
    NSComparisonResult typeComparison = FSTCompareDocumentViewChangeTypes(c1.type, c2.type);
    if (typeComparison != NSOrderedSame) {
      return typeComparison;
    }
    return self.query.comparator(c1.document, c2.document);
  }];
  [self applyTargetChange:targetChange];
  NSArray<FSTLimboDocumentChange *> *limboChanges = [self updateLimboDocuments];
  BOOL synced = _limboDocuments.empty() && self.isCurrent;
  FSTSyncState newSyncState = synced ? FSTSyncStateSynced : FSTSyncStateLocal;
  BOOL syncStateChanged = newSyncState != self.syncState;
  self.syncState = newSyncState;

  if (changes.count == 0 && !syncStateChanged) {
    // No changes.
    return [FSTViewChange changeWithSnapshot:nil limboChanges:limboChanges];
  } else {
    FSTViewSnapshot *snapshot =
        [[FSTViewSnapshot alloc] initWithQuery:self.query
                                     documents:docChanges.documentSet
                                  oldDocuments:oldDocuments
                               documentChanges:changes
                                     fromCache:newSyncState == FSTSyncStateLocal
                                   mutatedKeys:docChanges.mutatedKeys
                              syncStateChanged:syncStateChanged
                       excludesMetadataChanges:NO];

    return [FSTViewChange changeWithSnapshot:snapshot limboChanges:limboChanges];
  }
}

- (FSTViewChange *)applyChangedOnlineState:(OnlineState)onlineState {
  if (self.isCurrent && onlineState == OnlineState::Offline) {
    // If we're offline, set `current` to NO and then call applyChanges to refresh our syncState
    // and generate an FSTViewChange as appropriate. We are guaranteed to get a new FSTTargetChange
    // that sets `current` back to YES once the client is back online.
    self.current = NO;
    return
        [self applyChangesToDocuments:[[FSTViewDocumentChanges alloc]
                                          initWithDocumentSet:self.documentSet
                                                    changeSet:[FSTDocumentViewChangeSet changeSet]
                                                  needsRefill:NO
                                                  mutatedKeys:_mutatedKeys]];
  } else {
    // No effect, just return a no-op FSTViewChange.
    return [[FSTViewChange alloc] initWithSnapshot:nil limboChanges:@[]];
  }
}

#pragma mark - Private methods

/** Returns whether the doc for the given key should be in limbo. */
- (BOOL)shouldBeLimboDocumentKey:(const DocumentKey &)key {
  // If the remote end says it's part of this query, it's not in limbo.
  if (_syncedDocuments.contains(key)) {
    return NO;
  }
  // The local store doesn't think it's a result, so it shouldn't be in limbo.
  if (![self.documentSet containsKey:key]) {
    return NO;
  }
  // If there are local changes to the doc, they might explain why the server doesn't know that it's
  // part of the query. So don't put it in limbo.
  // TODO(klimt): Ideally, we would only consider changes that might actually affect this specific
  // query.
  if ([self.documentSet documentForKey:key].hasLocalMutations) {
    return NO;
  }
  // Everything else is in limbo.
  return YES;
}

/**
 * Updates syncedDocuments and current based on the given change.
 */
- (void)applyTargetChange:(nullable FSTTargetChange *)targetChange {
  if (targetChange) {
    for (const DocumentKey &key : targetChange.addedDocuments) {
      _syncedDocuments = _syncedDocuments.insert(key);
    }
    for (const DocumentKey &key : targetChange.modifiedDocuments) {
      HARD_ASSERT(_syncedDocuments.find(key) != _syncedDocuments.end(),
                  "Modified document %s not found in view.", key.ToString());
    }
    for (const DocumentKey &key : targetChange.removedDocuments) {
      _syncedDocuments = _syncedDocuments.erase(key);
    }

    self.current = targetChange.current;
  }
}

/** Updates limboDocuments and returns any changes as FSTLimboDocumentChanges. */
- (NSArray<FSTLimboDocumentChange *> *)updateLimboDocuments {
  // We can only determine limbo documents when we're in-sync with the server.
  if (!self.isCurrent) {
    return @[];
  }

  // TODO(klimt): Do this incrementally so that it's not quadratic when updating many documents.
  DocumentKeySet oldLimboDocuments = std::move(_limboDocuments);
  _limboDocuments = DocumentKeySet{};
  for (FSTDocument *doc in self.documentSet.documentEnumerator) {
    if ([self shouldBeLimboDocumentKey:doc.key]) {
      _limboDocuments = _limboDocuments.insert(doc.key);
    }
  }

  // Diff the new limbo docs with the old limbo docs.
  NSMutableArray<FSTLimboDocumentChange *> *changes =
      [NSMutableArray arrayWithCapacity:(oldLimboDocuments.size() + _limboDocuments.size())];
  for (const DocumentKey &key : oldLimboDocuments) {
    if (!_limboDocuments.contains(key)) {
      [changes addObject:[FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeRemoved
                                                            key:key]];
    }
  }
  for (const DocumentKey &key : _limboDocuments) {
    if (!oldLimboDocuments.contains(key)) {
      [changes addObject:[FSTLimboDocumentChange changeWithType:FSTLimboDocumentChangeTypeAdded
                                                            key:key]];
    }
  }
  return changes;
}

@end

static inline int DocumentViewChangeTypePosition(FSTDocumentViewChangeType changeType) {
  switch (changeType) {
    case FSTDocumentViewChangeTypeRemoved:
      return 0;
    case FSTDocumentViewChangeTypeAdded:
      return 1;
    case FSTDocumentViewChangeTypeModified:
      return 2;
    case FSTDocumentViewChangeTypeMetadata:
      // A metadata change is converted to a modified change at the public API layer. Since we sort
      // by document key and then change type, metadata and modified changes must be sorted
      // equivalently.
      return 2;
    default:
      HARD_FAIL("Unknown FSTDocumentViewChangeType %s", changeType);
  }
}

static NSComparisonResult FSTCompareDocumentViewChangeTypes(FSTDocumentViewChangeType c1,
                                                            FSTDocumentViewChangeType c2) {
  int pos1 = DocumentViewChangeTypePosition(c1);
  int pos2 = DocumentViewChangeTypePosition(c2);
  if (pos1 == pos2) {
    return NSOrderedSame;
  } else if (pos1 < pos2) {
    return NSOrderedAscending;
  } else {
    return NSOrderedDescending;
  }
}

NS_ASSUME_NONNULL_END
