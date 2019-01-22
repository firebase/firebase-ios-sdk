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

#import "Firestore/Source/Remote/FSTRemoteEvent.h"

#include <set>
#include <unordered_map>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"

@class FSTMaybeDocument;
@class FSTTargetState;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace remote {

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

  /** Removes the in-memory state for the provided target. */
  void RemoveTarget(model::TargetId target_id);

  /**
   * Handles existence filters and synthesizes deletes for filter mismatches.
   * Targets that are invalidated by filter mismatches are added to
   * `targetMismatches`.
   */
  void HandleExistenceFilter(
      const ExistenceFilterWatchChange& existence_filter);

  /**
   * Increment the number of acks needed from watch before we can consider the
   * server to be 'in-sync' with the client's active targets.
   */
  void RecordTargetRequest(model::TargetId target_id);

  /**
   * Converts the current state into a remote event with the snapshot version
   * taken from the initializer.
   */
  FSTRemoteEvent* CreateRemoteEvent(const SnapshotVersion& snapshot_version);

 private:
  /** The internal state of all tracked targets. */
  std::unordered_map<model::TargetId, FSTTargetState *> target_states_;

  /** Keeps track of document to update */
  std::unordered_map<model::DocumentKey, FSTMaybeDocument *, model::DocumentKeyHash> pending_document_updates_;

  /** A mapping of document keys to their set of target IDs. */
  std::unordered_map<model::DocumentKey, std::set<model::TargetId>, model::DocumentKeyHash>
      pending_document_target_mappings_;

  /**
   * A list of targets with existence filter mismatches. These targets are known to be inconsistent
   * and their listens needs to be re-established by `RemoteStore`.
   */
  std::unordered_set<model::TargetId> pending_target_resets_;

  id<FSTTargetMetadataProvider> target_metadata_provider_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_EVENT_H_

NS_ASSUME_NONNULL_END
