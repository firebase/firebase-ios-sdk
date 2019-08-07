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

#include <algorithm>
#include <utility>
#include <vector>

#import "Firestore/Source/Model/FSTDocument.h"

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/util/delayed_constructor.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace util = firebase::firestore::util;
using firebase::firestore::core::DocumentViewChange;
using firebase::firestore::core::DocumentViewChangeSet;
using firebase::firestore::core::Query;
using firebase::firestore::core::SyncState;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::MaybeDocumentMap;
using firebase::firestore::model::OnlineState;
using firebase::firestore::remote::TargetChange;
using firebase::firestore::util::ComparisonResult;
using firebase::firestore::util::DelayedConstructor;

NS_ASSUME_NONNULL_BEGIN

namespace {

int GetDocumentViewChangeTypePosition(DocumentViewChange::Type changeType) {
  switch (changeType) {
    case DocumentViewChange::Type::kRemoved:
      return 0;
    case DocumentViewChange::Type::kAdded:
      return 1;
    case DocumentViewChange::Type::kModified:
      return 2;
    case DocumentViewChange::Type::kMetadata:
      // A metadata change is converted to a modified change at the public API layer. Since we sort
      // by document key and then change type, metadata and modified changes must be sorted
      // equivalently.
      return 2;
  }
  HARD_FAIL("Unknown DocumentViewChange::Type %s", changeType);
}

}  // namespace

#pragma mark - FSTViewDocumentChanges

/** The result of applying a set of doc changes to a view. */
@interface FSTViewDocumentChanges ()

- (instancetype)initWithDocumentSet:(DocumentSet)documentSet
                          changeSet:(DocumentViewChangeSet &&)changeSet
                        needsRefill:(BOOL)needsRefill
                        mutatedKeys:(DocumentKeySet)mutatedKeys NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTViewDocumentChanges {
  DelayedConstructor<DocumentSet> _documentSet;
  DocumentKeySet _mutatedKeys;
  DocumentViewChangeSet _changeSet;
}

- (instancetype)initWithDocumentSet:(DocumentSet)documentSet
                          changeSet:(DocumentViewChangeSet &&)changeSet
                        needsRefill:(BOOL)needsRefill
                        mutatedKeys:(DocumentKeySet)mutatedKeys {
  self = [super init];
  if (self) {
    _documentSet.Init(std::move(documentSet));
    _changeSet = std::move(changeSet);
    _needsRefill = needsRefill;
    _mutatedKeys = std::move(mutatedKeys);
  }
  return self;
}

- (const DocumentKeySet &)mutatedKeys {
  return _mutatedKeys;
}

- (const firebase::firestore::model::DocumentSet &)documentSet {
  return *_documentSet;
}

- (const firebase::firestore::core::DocumentViewChangeSet &)changeSet {
  return _changeSet;
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
  hash = hash * 31u + self.key.Hash();
  return hash;
}

@end

#pragma mark - FSTViewChange

@interface FSTViewChange ()

+ (FSTViewChange *)changeWithSnapshot:(absl::optional<ViewSnapshot> &&)snapshot
                         limboChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges;

- (instancetype)initWithSnapshot:(absl::optional<ViewSnapshot> &&)snapshot
                    limboChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges
    NS_DESIGNATED_INITIALIZER;

@end

@implementation FSTViewChange {
  absl::optional<ViewSnapshot> _snapshot;
}

+ (FSTViewChange *)changeWithSnapshot:(absl::optional<ViewSnapshot> &&)snapshot
                         limboChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges {
  return [[self alloc] initWithSnapshot:std::move(snapshot) limboChanges:limboChanges];
}

- (instancetype)initWithSnapshot:(absl::optional<ViewSnapshot> &&)snapshot
                    limboChanges:(NSArray<FSTLimboDocumentChange *> *)limboChanges {
  self = [super init];
  if (self) {
    _snapshot = std::move(snapshot);
    _limboChanges = limboChanges;
  }
  return self;
}

- (absl::optional<ViewSnapshot> &)snapshot {
  return _snapshot;
}

@end

#pragma mark - FSTView

@interface FSTView ()

@property(nonatomic, assign) firebase::firestore::core::SyncState syncState;

/**
 * A flag whether the view is current with the backend. A view is considered current after it
 * has seen the current flag from the backend and did not lose consistency within the watch stream
 * (e.g. because of an existence filter mismatch).
 */
@property(nonatomic, assign, getter=isCurrent) BOOL current;

@end

@implementation FSTView {
  Query _query;

  DelayedConstructor<DocumentSet> _documentSet;

  /** Documents included in the remote target. */
  DocumentKeySet _syncedDocuments;

  /** Documents in the view but not in the remote target */
  DocumentKeySet _limboDocuments;

  /** Document Keys that have local changes. */
  DocumentKeySet _mutatedKeys;
}

- (instancetype)initWithQuery:(Query)query remoteDocuments:(DocumentKeySet)remoteDocuments {
  self = [super init];
  if (self) {
    _query = std::move(query);
    _documentSet.Init(_query.Comparator());
    _syncedDocuments = std::move(remoteDocuments);
  }
  return self;
}

- (ComparisonResult)compare:(FSTDocument *)document with:(FSTDocument *)otherDocument {
  return _documentSet->comparator().Compare(document, otherDocument);
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
  DocumentViewChangeSet changeSet;
  if (previousChanges) {
    changeSet = previousChanges.changeSet;
  }
  DocumentSet oldDocumentSet = previousChanges ? previousChanges.documentSet : *_documentSet;

  DocumentKeySet newMutatedKeys = previousChanges ? previousChanges.mutatedKeys : _mutatedKeys;
  DocumentKeySet oldMutatedKeys = _mutatedKeys;
  DocumentSet newDocumentSet = oldDocumentSet;
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
      (_query.limit() != Query::kNoLimit && oldDocumentSet.size() == _query.limit())
          ? oldDocumentSet.GetLastDocument()
          : nil;

  for (const auto &kv : docChanges) {
    const DocumentKey &key = kv.first;
    FSTMaybeDocument *maybeNewDoc = kv.second;

    FSTDocument *_Nullable oldDoc = oldDocumentSet.GetDocument(key);
    FSTDocument *_Nullable newDoc = nil;
    if ([maybeNewDoc isKindOfClass:[FSTDocument class]]) {
      newDoc = (FSTDocument *)maybeNewDoc;
    }
    if (newDoc) {
      HARD_ASSERT(key == newDoc.key, "Mismatching key in document changes: %s != %s",
                  key.ToString(), newDoc.key.ToString());
      if (!_query.Matches(newDoc)) {
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
      BOOL docsEqual = oldDoc.data == newDoc.data;
      if (!docsEqual) {
        if (![self shouldWaitForSyncedDocument:newDoc oldDocument:oldDoc]) {
          changeSet.AddChange(DocumentViewChange{newDoc, DocumentViewChange::Type::kModified});
          changeApplied = YES;

          if (lastDocInLimit && util::Descending([self compare:newDoc with:lastDocInLimit])) {
            // This doc moved from inside the limit to after the limit. That means there may be
            // some doc in the local cache that's actually less than this one.
            needsRefill = YES;
          }
        }
      } else if (oldDocHadPendingMutations != newDocHasPendingMutations) {
        changeSet.AddChange(DocumentViewChange{newDoc, DocumentViewChange::Type::kMetadata});
        changeApplied = YES;
      }

    } else if (!oldDoc && newDoc) {
      changeSet.AddChange(DocumentViewChange{newDoc, DocumentViewChange::Type::kAdded});
      changeApplied = YES;
    } else if (oldDoc && !newDoc) {
      changeSet.AddChange(DocumentViewChange{oldDoc, DocumentViewChange::Type::kRemoved});
      changeApplied = YES;

      if (lastDocInLimit) {
        // A doc was removed from a full limit query. We'll need to re-query from the local cache
        // to see if we know about some other doc that should be in the results.
        needsRefill = YES;
      }
    }

    if (changeApplied) {
      if (newDoc) {
        newDocumentSet = newDocumentSet.insert(newDoc);
        if (newDoc.hasLocalMutations) {
          newMutatedKeys = newMutatedKeys.insert(key);
        } else {
          newMutatedKeys = newMutatedKeys.erase(key);
        }
      } else {
        newDocumentSet = newDocumentSet.erase(key);
        newMutatedKeys = newMutatedKeys.erase(key);
      }
    }
  }

  int32_t limit = _query.limit();
  if (limit != Query::kNoLimit && newDocumentSet.size() > limit) {
    for (size_t i = newDocumentSet.size() - limit; i > 0; --i) {
      FSTDocument *oldDoc = newDocumentSet.GetLastDocument();
      newDocumentSet = newDocumentSet.erase(oldDoc.key);
      newMutatedKeys = newMutatedKeys.erase(oldDoc.key);
      changeSet.AddChange(DocumentViewChange{oldDoc, DocumentViewChange::Type::kRemoved});
    }
  }

  HARD_ASSERT(!needsRefill || !previousChanges,
              "View was refilled using docs that themselves needed refilling.");

  return [[FSTViewDocumentChanges alloc] initWithDocumentSet:std::move(newDocumentSet)
                                                   changeSet:std::move(changeSet)
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
  return [self applyChangesToDocuments:docChanges targetChange:{}];
}

- (FSTViewChange *)applyChangesToDocuments:(FSTViewDocumentChanges *)docChanges
                              targetChange:(const absl::optional<TargetChange> &)targetChange {
  HARD_ASSERT(!docChanges.needsRefill, "Cannot apply changes that need a refill");

  DocumentSet oldDocuments = *_documentSet;
  *_documentSet = docChanges.documentSet;
  _mutatedKeys = docChanges.mutatedKeys;

  // Sort changes based on type and query comparator.
  std::vector<DocumentViewChange> changes = docChanges.changeSet.GetChanges();
  std::sort(changes.begin(), changes.end(),
            [self](const DocumentViewChange &lhs, const DocumentViewChange &rhs) {
              int pos1 = GetDocumentViewChangeTypePosition(lhs.type());
              int pos2 = GetDocumentViewChangeTypePosition(rhs.type());
              if (pos1 != pos2) {
                return pos1 < pos2;
              }
              return util::Ascending([self compare:lhs.document() with:rhs.document()]);
            });

  [self applyTargetChange:targetChange];
  NSArray<FSTLimboDocumentChange *> *limboChanges = [self updateLimboDocuments];
  BOOL synced = _limboDocuments.empty() && self.isCurrent;
  SyncState newSyncState = synced ? SyncState::Synced : SyncState::Local;
  bool syncStateChanged = newSyncState != self.syncState;
  self.syncState = newSyncState;

  if (changes.empty() && !syncStateChanged) {
    // No changes.
    return [FSTViewChange changeWithSnapshot:absl::nullopt limboChanges:limboChanges];
  } else {
    ViewSnapshot snapshot{_query,
                          docChanges.documentSet,
                          oldDocuments,
                          std::move(changes),
                          docChanges.mutatedKeys,
                          /*from_cache=*/newSyncState == SyncState::Local,
                          syncStateChanged,
                          /*excludes_metadata_changes=*/false};

    return [FSTViewChange changeWithSnapshot:std::move(snapshot) limboChanges:limboChanges];
  }
}

- (FSTViewChange *)applyChangedOnlineState:(OnlineState)onlineState {
  if (self.isCurrent && onlineState == OnlineState::Offline) {
    // If we're offline, set `current` to NO and then call applyChanges to refresh our syncState
    // and generate an FSTViewChange as appropriate. We are guaranteed to get a new `TargetChange`
    // that sets `current` back to YES once the client is back online.
    self.current = NO;
    return [self applyChangesToDocuments:[[FSTViewDocumentChanges alloc]
                                             initWithDocumentSet:*_documentSet
                                                       changeSet:DocumentViewChangeSet {}
                                                     needsRefill:NO
                                                     mutatedKeys:_mutatedKeys]];
  } else {
    // No effect, just return a no-op FSTViewChange.
    return [[FSTViewChange alloc] initWithSnapshot:absl::nullopt limboChanges:@[]];
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
  if (!_documentSet->ContainsKey(key)) {
    return NO;
  }
  // If there are local changes to the doc, they might explain why the server doesn't know that it's
  // part of the query. So don't put it in limbo.
  // TODO(klimt): Ideally, we would only consider changes that might actually affect this specific
  // query.
  if (_documentSet->GetDocument(key).hasLocalMutations) {
    return NO;
  }
  // Everything else is in limbo.
  return YES;
}

/**
 * Updates syncedDocuments and current based on the given change.
 */
- (void)applyTargetChange:(const absl::optional<TargetChange> &)maybeTargetChange {
  if (maybeTargetChange.has_value()) {
    const TargetChange &target_change = maybeTargetChange.value();

    for (const DocumentKey &key : target_change.added_documents()) {
      _syncedDocuments = _syncedDocuments.insert(key);
    }
    for (const DocumentKey &key : target_change.modified_documents()) {
      HARD_ASSERT(_syncedDocuments.find(key) != _syncedDocuments.end(),
                  "Modified document %s not found in view.", key.ToString());
    }
    for (const DocumentKey &key : target_change.removed_documents()) {
      _syncedDocuments = _syncedDocuments.erase(key);
    }

    self.current = target_change.current();
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
  for (FSTDocument *doc : *_documentSet) {
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

NS_ASSUME_NONNULL_END
