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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_STORE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_STORE_H_

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <memory>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/remote/online_state_tracker.h"
#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_change.h"
#include "Firestore/core/src/firebase/firestore/remote/watch_stream.h"
#include "Firestore/core/src/firebase/firestore/remote/write_stream.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

@class FSTLocalStore;
@class FSTMutationBatch;
@class FSTMutationBatchResult;
@class FSTQueryData;

NS_ASSUME_NONNULL_BEGIN

/**
 * A protocol that describes the actions the FSTRemoteStore needs to perform on
 * a cooperating synchronization engine.
 */
@protocol FSTRemoteSyncer

/**
 * Applies one remote event to the sync engine, notifying any views of the
 * changes, and releasing any pending mutation batches that would become visible
 * because of the snapshot version the remote event contains.
 */
- (void)applyRemoteEvent:
    (const firebase::firestore::remote::RemoteEvent&)remoteEvent;

/**
 * Rejects the listen for the given targetID. This can be triggered by the
 * backend for any active target.
 *
 * @param targetID The targetID corresponding to a listen initiated via
 *     -listenToTargetWithQueryData: on FSTRemoteStore.
 * @param error A description of the condition that has forced the rejection.
 * Nearly always this will be an indication that the user is no longer
 * authorized to see the data matching the target.
 */
- (void)rejectListenWithTargetID:
            (const firebase::firestore::model::TargetId)targetID
                           error:
                               (NSError*)error;  // NOLINT(readability/casting)

/**
 * Applies the result of a successful write of a mutation batch to the sync
 * engine, emitting snapshots in any views that the mutation applies to, and
 * removing the batch from the mutation queue.
 */
- (void)applySuccessfulWriteWithResult:
    (FSTMutationBatchResult*)batchResult;  // NOLINT(readability/casting)

/**
 * Rejects the batch, removing the batch from the mutation queue, recomputing
 * the local view of any documents affected by the batch and then, emitting
 * snapshots with the reverted value.
 */
- (void)
    rejectFailedWriteWithBatchID:(firebase::firestore::model::BatchId)batchID
                           error:
                               (NSError*)error;  // NOLINT(readability/casting)

/**
 * Returns the set of remote document keys for the given target ID. This list
 * includes the documents that were assigned to the target when we received the
 * last snapshot.
 */
- (firebase::firestore::model::DocumentKeySet)remoteKeysForTarget:
    (firebase::firestore::model::TargetId)targetId;

@end

namespace firebase {
namespace firestore {
namespace remote {

class RemoteStore : public TargetMetadataProvider,
                    public WatchStreamCallback,
                    public WriteStreamCallback {
 public:
  RemoteStore(FSTLocalStore* local_store,
              Datastore* datastore,
              util::AsyncQueue* worker_queue,
              std::function<void(model::OnlineState)> online_state_handler);

  // TODO(varconst): remove the getters and setters

  id<FSTRemoteSyncer> sync_engine() {
    return sync_engine_;
  }
  void set_sync_engine(id<FSTRemoteSyncer> sync_engine) {
    sync_engine_ = sync_engine;
  }

  FSTLocalStore* local_store() {
    return local_store_;
  }

  OnlineStateTracker& online_state_tracker() {
    return online_state_tracker_;
  }

  void set_is_network_enabled(bool value) {
    is_network_enabled_ = value;
  }

  WatchStream& watch_stream() {
    return *watch_stream_;
  }
  WriteStream& write_stream() {
    return *write_stream_;
  }

  std::vector<FSTMutationBatch*>& write_pipeline() {
    return write_pipeline_;
  }

  /** Listens to the target identified by the given `FSTQueryData`. */
  void Listen(FSTQueryData* query_data);

  /** Stops listening to the target with the given target ID. */
  void StopListening(model::TargetId target_id);

  model::DocumentKeySet GetRemoteKeysForTarget(
      model::TargetId target_id) const override;
  FSTQueryData* GetQueryDataForTarget(model::TargetId target_id) const override;

  void OnWatchStreamOpen() override;
  void OnWatchStreamChange(
      const WatchChange& change,
      const model::SnapshotVersion& snapshot_version) override;
  void OnWatchStreamClose(const util::Status& status) override;

  void OnWriteStreamOpen() override;

  /**
   * Handles the closing of the StreamingWrite RPC, either because of an error
   * or because the RPC has been terminated by the client or the server.
   */
  void OnWriteStreamClose(const util::Status& status) override;

  /**
   * Handles a successful handshake response from the server, which is our cue
   * to send any pending writes.
   */
  void OnWriteStreamHandshakeComplete() override;

  /**
   * Handles a successful StreamingWriteResponse from the server that contains a
   * mutation result.
   */
  void OnWriteStreamResponse(
      model::SnapshotVersion commit_version,
      std::vector<FSTMutationResult*> mutation_results) override;

  // TODO(varconst): make the following methods private.

  bool CanUseNetwork() const;

  void StartWatchStream();

  /**
   * Returns true if the network is enabled, the watch stream has not yet been
   * started and there are active watch targets.
   */
  bool ShouldStartWatchStream() const;

  void CleanUpWatchStreamState();

  /**
   * Attempts to fill our write pipeline with writes from the `FSTLocalStore`.
   *
   * Called internally to bootstrap or refill the write pipeline and by
   * `FSTSyncEngine` whenever there are new mutations to process.
   *
   * Starts the write stream if necessary.
   */
  void FillWritePipeline();

  /**
   * Queues additional writes to be sent to the write stream, sending them
   * immediately if the write stream is established.
   */
  void AddToWritePipeline(FSTMutationBatch* batch);

 private:
  void SendWatchRequest(FSTQueryData* query_data);
  void SendUnwatchRequest(model::TargetId target_id);

  /**
   * Takes a batch of changes from the `Datastore`, repackages them as a
   * `RemoteEvent`, and passes that on to the `SyncEngine`.
   */
  void RaiseWatchSnapshot(const model::SnapshotVersion& snapshot_version);

  /** Process a target error and passes the error along to `SyncEngine`. */
  void ProcessTargetError(const WatchTargetChange& change);

  void StartWriteStream();

  /**
   * Returns true if the network is enabled, the write stream has not yet been
   * started and there are pending writes.
   */
  bool ShouldStartWriteStream() const;

  /**
   * Returns true if we can add to the write pipeline (i.e. it is not full and
   * the network is enabled).
   */
  bool CanAddToWritePipeline() const;

  void HandleHandshakeError(const util::Status& status);
  void HandleWriteError(const util::Status& status);

  id<FSTRemoteSyncer> sync_engine_ = nil;

  /**
   * The local store, used to fill the write pipeline with outbound mutations
   * and resolve existence filter mismatches. Immutable after initialization.
   */
  FSTLocalStore* local_store_ = nil;

  /**
   * A mapping of watched targets that the client cares about tracking and the
   * user has explicitly called a 'listen' for this target.
   *
   * These targets may or may not have been sent to or acknowledged by the
   * server. On re-establishing the listen stream, these targets should be sent
   * to the server. The targets removed with unlistens are removed eagerly
   * without waiting for confirmation from the listen stream.
   */
  std::unordered_map<model::TargetId, FSTQueryData*> listen_targets_;

  OnlineStateTracker online_state_tracker_;

  /**
   * Set to true by `EnableNetwork` and false by `DisableNetworkInternal` and
   * indicates the user-preferred network state.
   */
  bool is_network_enabled_ = false;

  std::shared_ptr<WatchStream> watch_stream_;
  std::shared_ptr<WriteStream> write_stream_;
  std::unique_ptr<WatchChangeAggregator> watch_change_aggregator_;

  /**
   * A list of up to `kMaxPendingWrites` writes that we have fetched from the
   * `LocalStore` via `FillWritePipeline` and have or will send to the write
   * stream.
   *
   * Whenever `write_pipeline_` is not empty, the `RemoteStore` will attempt to
   * start or restart the write stream. When the stream is established, the
   * writes in the pipeline will be sent in order.
   *
   * Writes remain in `write_pipeline_` until they are acknowledged by the
   * backend and thus will automatically be re-sent if the stream is interrupted
   * / restarted before they're acknowledged.
   *
   * Write responses from the backend are linked to their originating request
   * purely based on order, and so we can just remove writes from the front of
   * the `write_pipeline_` as we receive responses.
   */
  std::vector<FSTMutationBatch*> write_pipeline_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_REMOTE_STORE_H_
