/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_EVENT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_EVENT_H_

#if !defined(__OBJC__)
// TODO(varconst): the only dependencies are `FSTMaybeDocument` and `NSData`
// (the latter is used to represent the resume token).
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <set>
#include <unordered_map>
#include <unordered_set>

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"

@class FSTMaybeDocument;
@class FSTQueryData;
@class FSTRemoteEvent;
@class FSTTargetChange;

NS_ASSUME_NONNULL_BEGIN

/**
 * Interface implemented by RemoteStore to expose target metadata to the
 * `WatchChangeAggregator`.
 */
@protocol FSTTargetMetadataProvider

/**
 * Returns the set of remote document keys for the given target ID as of the
 * last raised snapshot.
 */
- (firebase::firestore::model::DocumentKeySet)remoteKeysForTarget:
    (firebase::firestore::model::TargetId)targetID;

/**
 * Returns the FSTQueryData for an active target ID or 'null' if this query has
 * become inactive
 */
- (nullable FSTQueryData*)queryDataForTarget:
    (firebase::firestore::model::TargetId)targetID;

@end

namespace firebase {
namespace firestore {
namespace remote {

/** Tracks the internal state of a Watch target. */
class TargetState {
 public:
  TargetState();

  /**
   * Whether this target has been marked 'current'.
   *
   * 'Current' has special meaning in the RPC protocol: It implies that the
   * Watch backend has sent us all changes up to the point at which the target
   * was added and that the target is consistent with the rest of the watch
   * stream.
   */
  bool IsCurrent() const {
    return is_current_;
  }

  /** The last resume token sent to us for this target. */
  NSData* resume_token() const {
    return resume_token_;
  }

  /** Whether we have modified any state that should trigger a snapshot. */
  bool HasPendingChanges() const {
    return has_pending_changes_;
  }

  /** Whether this target has pending target adds or target removes. */
  bool IsPending() const {
    return outstanding_responses_ != 0;
  }

  /**
   * Applies the resume token to the `TargetChange`, but only when it has a new
   * value. Empty resume tokens are discarded.
   */
  void UpdateResumeToken(NSData* resume_token);

  /** Resets the document changes and sets `HasPendingChanges` to false. */
  void ClearPendingChanges();

  /**
   * Creates a target change from the current set of changes.
   *
   * To reset the document changes after raising this snapshot, call
   * `ClearPendingChanges()`.
   */
  FSTTargetChange* ToTargetChange() const;

  void RecordTargetRequest();
  void RecordTargetResponse();
  void MarkCurrent();
  void AddDocumentChange(const model::DocumentKey& document_key,
                         core::DocumentViewChangeType type);
  void RemoveDocumentChange(const model::DocumentKey& document_key);

 private:
  // We initialize to 'true' so that newly-added targets are included in the
  // next RemoteEvent.
  bool has_pending_changes_ = true;

  bool is_current_ = false;

  /**
   * The number of outstanding responses (adds or removes) that we are waiting
   * on. We only consider targets active that have no outstanding responses.
   */
  int outstanding_responses_ = 0;

  /**
   * Keeps track of the document changes since the last raised snapshot.
   *
   * These changes are continuously updated as we receive document updates and
   * always reflect the current set of changes against the last issued snapshot.
   */
  std::unordered_map<model::DocumentKey,
                     core::DocumentViewChangeType,
                     model::DocumentKeyHash>
      document_changes_;

  NSData* resume_token_;
};

class WatchChangeAggregator {
 public:
  WatchChangeAggregator() {
  }

  /**
   * Processes and adds the DocumentWatchChange to the current set of changes.
   */
  void HandleDocumentChange(const DocumentWatchChange& document_change);

  /** Processes and adds the WatchTargetChange to the current set of changes. */
  void HandleTargetChange(const WatchTargetChange& target_change);

  /**
   * Handles existence filters and synthesizes deletes for filter mismatches.
   * Targets that are invalidated by filter mismatches are added to
   * `targetMismatches`.
   */
  void HandleExistenceFilter(
      const ExistenceFilterWatchChange& existence_filter);

  /**
   * Converts the current state into a remote event with the snapshot version
   * taken from the initializer.
   */
  FSTRemoteEvent* CreateRemoteEvent(
      const model::SnapshotVersion& snapshot_version);

  std::vector<model::TargetId> GetTargetIds(
      const WatchTargetChange& target_change) const;

  /** Removes the in-memory state for the provided target. */
  void RemoveTarget(model::TargetId target_id);

  /**
   * Increment the number of acks needed from watch before we can consider the
   * server to be 'in-sync' with the client's active targets.
   */
  void RecordTargetRequest(model::TargetId target_id);

 private:
  void AddDocumentToTarget(model::TargetId target_id,
                           FSTMaybeDocument* document);
  void RemoveDocumentFromTarget(model::TargetId target_id,
                                const model::DocumentKey& key,
                                FSTMaybeDocument* _Nullable updated_document);
  bool TargetContainsDocument(model::TargetId target_id,
                              const model::DocumentKey& key);

  /**
   * Returns true if the given target_id is active. Active targets are those for
   * which there are no pending requests to add a listen and are in the current
   * list of targets the client cares about.
   *
   * Clients can repeatedly listen and stop listening to targets, so this check
   * is useful in preventing in preventing race conditions for a target where
   * events arrive but the server hasn't yet acknowledged the intended change in
   * state.
   */
  bool IsActiveTarget(model::TargetId target_id) const;
  FSTQueryData* QueryDataForActiveTarget(model::TargetId target_id) const;

  int GetCurrentDocumentCountForTarget(model::TargetId target_id);

  /**
   * Resets the state of a Watch target to its initial state (e.g. sets
   * 'current' to false, clears the resume token and removes its target mapping
   * from all documents).
   */
  void ResetTarget(model::TargetId target_id);

  TargetState& EnsureTargetState(model::TargetId target_id);

  /** The internal state of all tracked targets. */
  std::unordered_map<model::TargetId, TargetState> target_states_;

  /** Keeps track of document to update */
  std::unordered_map<model::DocumentKey,
                     FSTMaybeDocument*,
                     model::DocumentKeyHash>
      pending_document_updates_;

  /** A mapping of document keys to their set of target IDs. */
  std::unordered_map<model::DocumentKey,
                     std::set<model::TargetId>,
                     model::DocumentKeyHash>
      pending_document_target_mappings_;

  /**
   * A list of targets with existence filter mismatches. These targets are known
   * to be inconsistent and their listens needs to be re-established by
   * `RemoteStore`.
   */
  std::unordered_set<model::TargetId> pending_target_resets_;

  id<FSTTargetMetadataProvider> target_metadata_provider_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_EVENT_H_

NS_ASSUME_NONNULL_END
