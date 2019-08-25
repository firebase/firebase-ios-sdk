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

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/core/view.h"
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
using firebase::firestore::core::LimboDocumentChange;
using firebase::firestore::core::Query;
using firebase::firestore::core::SyncState;
using firebase::firestore::core::ViewChange;
using firebase::firestore::core::ViewDocumentChanges;
using firebase::firestore::core::ViewSnapshot;
using firebase::firestore::model::Document;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::DocumentSet;
using firebase::firestore::model::MaybeDocument;
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

- (ComparisonResult)compare:(const Document &)document with:(const Document &)otherDocument {
  return _documentSet->comparator().Compare(document, otherDocument);
}

- (const DocumentKeySet &)syncedDocuments {
  return _syncedDocuments;
}

- (ViewDocumentChanges)computeChangesWithDocuments:(const MaybeDocumentMap &)docChanges {
  return [self computeChangesWithDocuments:docChanges previousChanges:absl::nullopt];
}

- (ViewDocumentChanges)computeChangesWithDocuments:(const MaybeDocumentMap &)docChanges
                                   previousChanges:(const absl::optional<ViewDocumentChanges> &)
                                                       previousChanges {
  DocumentViewChangeSet changeSet;
  if (previousChanges) {
    changeSet = previousChanges->change_set();
  }
  DocumentSet oldDocumentSet = previousChanges ? previousChanges->document_set() : *_documentSet;

  DocumentKeySet newMutatedKeys = previousChanges ? previousChanges->mutated_keys() : _mutatedKeys;
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
  absl::optional<Document> lastDocInLimit;
  if (_query.limit() != Query::kNoLimit && oldDocumentSet.size() == _query.limit()) {
    lastDocInLimit = oldDocumentSet.GetLastDocument();
  }

  for (const auto &kv : docChanges) {
    const DocumentKey &key = kv.first;
    const MaybeDocument &maybeNewDoc = kv.second;

    absl::optional<Document> oldDoc = oldDocumentSet.GetDocument(key);
    absl::optional<Document> newDoc;
    if (maybeNewDoc.is_document()) {
      newDoc = Document(maybeNewDoc);
    }
    if (newDoc) {
      HARD_ASSERT(key == newDoc->key(), "Mismatching key in document changes: %s != %s",
                  key.ToString(), newDoc->key().ToString());
      if (!_query.Matches(*newDoc)) {
        newDoc = absl::nullopt;
      }
    }

    bool oldDocHadPendingMutations = oldDoc && oldMutatedKeys.contains(key);

    // We only consider committed mutations for documents that were mutated during the lifetime of
    // the view.
    bool newDocHasPendingMutations =
        newDoc && (newDoc->has_local_mutations() ||
                   (oldMutatedKeys.contains(key) && newDoc->has_committed_mutations()));

    bool changeApplied = false;
    // Calculate change
    if (oldDoc && newDoc) {
      bool docsEqual = oldDoc->data() == newDoc->data();
      if (!docsEqual) {
        if (![self shouldWaitForSyncedDocument:*newDoc oldDocument:*oldDoc]) {
          changeSet.AddChange(DocumentViewChange{*newDoc, DocumentViewChange::Type::kModified});
          changeApplied = true;

          if (lastDocInLimit && util::Descending([self compare:*newDoc with:*lastDocInLimit])) {
            // This doc moved from inside the limit to after the limit. That means there may be
            // some doc in the local cache that's actually less than this one.
            needsRefill = true;
          }
        }
      } else if (oldDocHadPendingMutations != newDocHasPendingMutations) {
        changeSet.AddChange(DocumentViewChange{*newDoc, DocumentViewChange::Type::kMetadata});
        changeApplied = true;
      }

    } else if (!oldDoc && newDoc) {
      changeSet.AddChange(DocumentViewChange{*newDoc, DocumentViewChange::Type::kAdded});
      changeApplied = true;
    } else if (oldDoc && !newDoc) {
      changeSet.AddChange(DocumentViewChange{*oldDoc, DocumentViewChange::Type::kRemoved});
      changeApplied = true;

      if (lastDocInLimit) {
        // A doc was removed from a full limit query. We'll need to re-query from the local cache
        // to see if we know about some other doc that should be in the results.
        needsRefill = true;
      }
    }

    if (changeApplied) {
      if (newDoc) {
        newDocumentSet = newDocumentSet.insert(newDoc);
        if (newDoc->has_local_mutations()) {
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
      const Document &oldDoc = *newDocumentSet.GetLastDocument();
      newDocumentSet = newDocumentSet.erase(oldDoc.key());
      newMutatedKeys = newMutatedKeys.erase(oldDoc.key());
      changeSet.AddChange(DocumentViewChange{oldDoc, DocumentViewChange::Type::kRemoved});
    }
  }

  HARD_ASSERT(!needsRefill || !previousChanges,
              "View was refilled using docs that themselves needed refilling.");

  return ViewDocumentChanges(std::move(newDocumentSet), std::move(changeSet), newMutatedKeys,
                             needsRefill);
}

- (BOOL)shouldWaitForSyncedDocument:(const Document &)newDoc oldDocument:(const Document &)oldDoc {
  // We suppress the initial change event for documents that were modified as part of a write
  // acknowledgment (e.g. when the value of a server transform is applied) as Watch will send us
  // the same document again. By suppressing the event, we only raise two user visible events (one
  // with `hasPendingWrites` and the final state of the document) instead of three (one with
  // `hasPendingWrites`, the modified document with `hasPendingWrites` and the final state of the
  // document).
  return (oldDoc.has_local_mutations() && newDoc.has_committed_mutations() &&
          !newDoc.has_local_mutations());
}

- (ViewChange)applyChangesToDocuments:(const core::ViewDocumentChanges &)docChanges {
  return [self applyChangesToDocuments:docChanges targetChange:{}];
}

- (ViewChange)applyChangesToDocuments:(const core::ViewDocumentChanges &)docChanges
                         targetChange:(const absl::optional<TargetChange> &)targetChange {
  HARD_ASSERT(!docChanges.needs_refill(), "Cannot apply changes that need a refill");

  DocumentSet oldDocuments = *_documentSet;
  *_documentSet = docChanges.document_set();
  _mutatedKeys = docChanges.mutated_keys();

  // Sort changes based on type and query comparator.
  std::vector<DocumentViewChange> changes = docChanges.change_set().GetChanges();
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
  std::vector<LimboDocumentChange> limboChanges = [self updateLimboDocuments];
  BOOL synced = _limboDocuments.empty() && self.isCurrent;
  SyncState newSyncState = synced ? SyncState::Synced : SyncState::Local;
  bool syncStateChanged = newSyncState != self.syncState;
  self.syncState = newSyncState;

  if (changes.empty() && !syncStateChanged) {
    // No changes.
    return ViewChange(absl::nullopt, std::move(limboChanges));
  } else {
    ViewSnapshot snapshot{_query,
                          docChanges.document_set(),
                          oldDocuments,
                          std::move(changes),
                          docChanges.mutated_keys(),
                          /*from_cache=*/newSyncState == SyncState::Local,
                          syncStateChanged,
                          /*excludes_metadata_changes=*/false};

    return ViewChange(std::move(snapshot), std::move(limboChanges));
  }
}

- (ViewChange)applyChangedOnlineState:(OnlineState)onlineState {
  if (self.isCurrent && onlineState == OnlineState::Offline) {
    // If we're offline, set `current` to NO and then call applyChanges to refresh our syncState
    // and generate a ViewChange as appropriate. We are guaranteed to get a new `TargetChange` that
    // sets `current` back to YES once the client is back online.
    self.current = NO;
    return [self applyChangesToDocuments:ViewDocumentChanges(*_documentSet, DocumentViewChangeSet{},
                                                             _mutatedKeys, false)];
  } else {
    // No effect, just return a no-op ViewChange.
    return ViewChange(absl::nullopt, {});
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
  if (_documentSet->GetDocument(key)->has_local_mutations()) {
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

/** Updates limboDocuments and returns any changes as LimboDocumentChanges. */
- (std::vector<LimboDocumentChange>)updateLimboDocuments {
  // We can only determine limbo documents when we're in-sync with the server.
  if (!self.isCurrent) {
    return {};
  }

  // TODO(klimt): Do this incrementally so that it's not quadratic when updating many documents.
  DocumentKeySet oldLimboDocuments = std::move(_limboDocuments);
  _limboDocuments = DocumentKeySet{};
  for (const Document &doc : *_documentSet) {
    if ([self shouldBeLimboDocumentKey:doc.key()]) {
      _limboDocuments = _limboDocuments.insert(doc.key());
    }
  }

  // Diff the new limbo docs with the old limbo docs.
  std::vector<LimboDocumentChange> changes;
  changes.reserve(oldLimboDocuments.size() + _limboDocuments.size());

  for (const DocumentKey &key : oldLimboDocuments) {
    if (!_limboDocuments.contains(key)) {
      changes.push_back(LimboDocumentChange::Removed(key));
    }
  }
  for (const DocumentKey &key : _limboDocuments) {
    if (!oldLimboDocuments.contains(key)) {
      changes.push_back(LimboDocumentChange::Added(key));
    }
  }
  return changes;
}

@end

NS_ASSUME_NONNULL_END
