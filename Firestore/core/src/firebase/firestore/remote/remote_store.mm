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

#include "Firestore/core/src/firebase/firestore/remote/remote_store.h"

namespace firebase {
namespace firestore {
namespace remote {

void RemoteStore::StartWatchStream() {
  HARD_ASSERT([self shouldStartWatchStream],
              "startWatchStream: called when shouldStartWatchStream: is false.");
  _watchChangeAggregator = absl::make_unique<WatchChangeAggregator>(self);
  _watchStream->Start();

  _onlineStateTracker.HandleWatchStreamStart();
}

void RemoteStore::ListenToTarget(FSTQueryData* query_data) {
  TargetId targetKey = queryData.targetID;
  HARD_ASSERT(_listenTargets.find(targetKey) == _listenTargets.end(),
              "listenToQuery called with duplicate target id: %s", targetKey);

  _listenTargets[targetKey] = queryData;

  if ([self shouldStartWatchStream]) {
    [self startWatchStream];
  } else if (_watchStream->IsOpen()) {
    [self sendWatchRequestWithQueryData:queryData];
  }
}

void RemoteStore::SendWatchRequest(FSTQueryData* query_data) {
  _watchChangeAggregator->RecordPendingTargetRequest(queryData.targetID);
  _watchStream->WatchQuery(queryData);
}

void RemoteStore::StopListening(TargetId target_id) {
  size_t num_erased = _listenTargets.erase(targetID);
  HARD_ASSERT(num_erased == 1, "stopListeningToTargetID: target not currently watched: %s",
              targetID);

  if (_watchStream->IsOpen()) {
    [self sendUnwatchRequestForTargetID:targetID];
  }
  if (_listenTargets.empty()) {
    if (_watchStream->IsOpen()) {
      _watchStream->MarkIdle();
    } else if ([self canUseNetwork]) {
      // Revert to OnlineState::Unknown if the watch stream is not open and we have no listeners,
      // since without any listens to send we cannot confirm if the stream is healthy and upgrade
      // to OnlineState::Online.
      _onlineStateTracker.UpdateState(OnlineState::Unknown);
    }
  }
}

void RemoteStore::SendUnwatchRequest(TargetId target_id) {
  _watchChangeAggregator->RecordPendingTargetRequest(targetID);
  _watchStream->UnwatchTargetId(targetID);
}

bool RemoteStore::ShouldStartWatchStream() const {
  return [self canUseNetwork] && !_watchStream->IsStarted() && !_listenTargets.empty();
}

void RemoteStore::CleanUpWatchStreamState() {
  _watchChangeAggregator.reset();
}

void RemoteStore::OnWatchStreamOpen() {
  // Restore any existing watches.
  for (const auto &kv : _listenTargets) {
    [self sendWatchRequestWithQueryData:kv.second];
  }
}

void RemoteStore::OnWatchStreamChange(const WatchChange& change, const SnapshotVersion& snapshot_version) {
  // Mark the connection as Online because we got a message from the server.
  _onlineStateTracker.UpdateState(OnlineState::Online);

  if (change.type() == WatchChange::Type::TargetChange) {
    const WatchTargetChange &watchTargetChange = static_cast<const WatchTargetChange &>(change);
    if (watchTargetChange.state() == WatchTargetChangeState::Removed &&
        !watchTargetChange.cause().ok()) {
      // There was an error on a target, don't wait for a consistent snapshot to raise events
      return [self processTargetErrorForWatchChange:watchTargetChange];
    } else {
      _watchChangeAggregator->HandleTargetChange(watchTargetChange);
    }
  } else if (change.type() == WatchChange::Type::Document) {
    _watchChangeAggregator->HandleDocumentChange(static_cast<const DocumentWatchChange &>(change));
  } else {
    HARD_ASSERT(change.type() == WatchChange::Type::ExistenceFilter,
                "Expected watchChange to be an instance of ExistenceFilterWatchChange");
    _watchChangeAggregator->HandleExistenceFilter(
        static_cast<const ExistenceFilterWatchChange &>(change));
  }

  if (snapshotVersion != SnapshotVersion::None() &&
      snapshotVersion >= [self.localStore lastRemoteSnapshotVersion]) {
    // We have received a target change with a global snapshot if the snapshot version is not
    // equal to SnapshotVersion.None().
    [self raiseWatchSnapshotWithSnapshotVersion:snapshotVersion];
  }
}

void RemoteStore::OnWatchStreamError(const Status& error) {
  if (error.ok()) {
    // Graceful stop (due to Stop() or idle timeout). Make sure that's desirable.
    HARD_ASSERT(![self shouldStartWatchStream],
                "Watch stream was stopped gracefully while still needed.");
  }

  [self cleanUpWatchStreamState];

  // If we still need the watch stream, retry the connection.
  if ([self shouldStartWatchStream]) {
    _onlineStateTracker.HandleWatchStreamFailure(error);

    [self startWatchStream];
  } else {
    // We don't need to restart the watch stream because there are no active targets. The online
    // state is set to unknown because there is no active attempt at establishing a connection.
    _onlineStateTracker.UpdateState(OnlineState::Unknown);
  }
}

/**
 * Takes a batch of changes from the Datastore, repackages them as a `RemoteEvent`, and passes that
 * on to the SyncEngine.
 */
void RemoteStore::RaiseWatchSnapshot(const SnapshotVersion& snapshot_version) {
  HARD_ASSERT(snapshotVersion != SnapshotVersion::None(),
              "Can't raise event for unknown SnapshotVersion");

  RemoteEvent remoteEvent = _watchChangeAggregator->CreateRemoteEvent(snapshotVersion);

  // Update in-memory resume tokens. `FSTLocalStore` will update the persistent view of these when
  // applying the completed `RemoteEvent`.
  for (const auto &entry : remoteEvent.target_changes()) {
    const TargetChange &target_change = entry.second;
    NSData *resumeToken = target_change.resume_token();
    if (resumeToken.length > 0) {
      TargetId targetID = entry.first;
      auto found = _listenTargets.find(targetID);
      FSTQueryData *queryData = found != _listenTargets.end() ? found->second : nil;
      // A watched target might have been removed already.
      if (queryData) {
        _listenTargets[targetID] =
            [queryData queryDataByReplacingSnapshotVersion:snapshotVersion
                                               resumeToken:resumeToken
                                            sequenceNumber:queryData.sequenceNumber];
      }
    }
  }

  // Re-establish listens for the targets that have been invalidated by existence filter
  // mismatches.
  for (TargetId targetID : remoteEvent.target_mismatches()) {
    auto found = _listenTargets.find(targetID);
    if (found == _listenTargets.end()) {
      // A watched target might have been removed already.
      continue;
    }
    FSTQueryData *queryData = found->second;

    // Clear the resume token for the query, since we're in a known mismatch state.
    queryData = [[FSTQueryData alloc] initWithQuery:queryData.query
                                           targetID:targetID
                               listenSequenceNumber:queryData.sequenceNumber
                                            purpose:queryData.purpose];
    _listenTargets[targetID] = queryData;

    // Cause a hard reset by unwatching and rewatching immediately, but deliberately don't send a
    // resume token so that we get a full update.
    [self sendUnwatchRequestForTargetID:targetID];

    // Mark the query we send as being on behalf of an existence filter mismatch, but don't
    // actually retain that in _listenTargets. This ensures that we flag the first re-listen this
    // way without impacting future listens of this target (that might happen e.g. on reconnect).
    FSTQueryData *requestQueryData =
        [[FSTQueryData alloc] initWithQuery:queryData.query
                                   targetID:targetID
                       listenSequenceNumber:queryData.sequenceNumber
                                    purpose:FSTQueryPurposeExistenceFilterMismatch];
    [self sendWatchRequestWithQueryData:requestQueryData];
  }

  // Finally handle remote event
  [self.syncEngine applyRemoteEvent:remoteEvent];
}

/** Process a target error and passes the error along to SyncEngine. */
void RemoteStore::ProcessTargetError(const WatchTargetChange& change) {
  HARD_ASSERT(!change.cause().ok(), "Handling target error without a cause");
  // Ignore targets that have been removed already.
  for (TargetId targetID : change.target_ids()) {
    auto found = _listenTargets.find(targetID);
    if (found != _listenTargets.end()) {
      _listenTargets.erase(found);
      _watchChangeAggregator->RemoveTarget(targetID);
      [self.syncEngine rejectListenWithTargetID:targetID error:util::MakeNSError(change.cause())];
    }
  }
}

/*
_watchChangeAggregator
_watchStream
_onlineStateTracker
_listenTargets
_syncEngine

[canUseNetwork]

 */
}  // namespace remote
}  // namespace firestore
}  // namespace firebase
