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

#include "Firestore/core/src/firebase/firestore/core/sync_engine.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/core/transaction.h"
#include "Firestore/core/src/firebase/firestore/core/transaction_runner.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/document_set.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {
namespace core {

namespace {

using firestore::Error;
using auth::User;
using local::LocalStore;
using local::LocalViewChanges;
using local::LocalWriteResult;
using local::QueryData;
using local::QueryPurpose;
using model::BatchId;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::kBatchIdUnknown;
using model::ListenSequenceNumber;
using model::MaybeDocumentMap;
using model::NoDocument;
using model::SnapshotVersion;
using model::TargetId;
using remote::RemoteEvent;
using remote::TargetChange;
using util::AsyncQueue;
using util::Status;
using util::StatusCallback;

// Limbo documents don't use persistence, and are eagerly GC'd. So, listens for
// them don't need real sequence numbers.
const ListenSequenceNumber kIrrelevantSequenceNumber = -1;

bool ErrorIsInteresting(const Status& error) {
  bool missing_index =
      (error.code() == Error::FailedPrecondition &&
       error.error_message().find("requires an index") != std::string::npos);
  bool no_permission = (error.code() == Error::PermissionDenied);
  return missing_index || no_permission;
}

}  // namespace

SyncEngine::SyncEngine(LocalStore* local_store,
                       remote::RemoteStore* remote_store,
                       const auth::User& initial_user)
    : local_store_(local_store),
      remote_store_(remote_store),
      current_user_(initial_user),
      target_id_generator_(TargetIdGenerator::SyncEngineTargetIdGenerator()) {
}

void SyncEngine::AssertCallbackExists(absl::string_view source) {
  HARD_ASSERT(sync_engine_callback_,
              "Tried to call '%s' before callback was registered.", source);
}

TargetId SyncEngine::Listen(Query query) {
  AssertCallbackExists("Listen");

  HARD_ASSERT(query_views_by_query_.find(query) == query_views_by_query_.end(),
              "We already listen to query: %s", query.ToString());

  QueryData query_data = local_store_->AllocateQuery(query);
  ViewSnapshot view_snapshot = InitializeViewAndComputeSnapshot(query_data);
  std::vector<ViewSnapshot> snapshots;
  // Not using the `std::initializer_list` constructor to avoid extra copies.
  snapshots.push_back(std::move(view_snapshot));
  sync_engine_callback_->OnViewSnapshots(std::move(snapshots));

  // TODO(wuandy): move `query_data` into `Listen`.
  remote_store_->Listen(query_data);
  return query_data.target_id();
}

ViewSnapshot SyncEngine::InitializeViewAndComputeSnapshot(
    const local::QueryData& query_data) {
  DocumentMap docs = local_store_->ExecuteQuery(query_data.query());
  DocumentKeySet remote_keys =
      local_store_->GetRemoteDocumentKeys(query_data.target_id());

  View view(query_data.query(), std::move(remote_keys));
  ViewDocumentChanges view_doc_changes =
      view.ComputeDocumentChanges(docs.underlying_map());
  ViewChange view_change = view.ApplyChanges(view_doc_changes);
  HARD_ASSERT(view_change.limbo_changes().empty(),
              "View returned limbo docs before target ack from the server.");

  auto query_view =
      std::make_shared<QueryView>(query_data.query(), query_data.target_id(),
                                  query_data.resume_token(), std::move(view));
  query_views_by_query_[query_data.query()] = query_view;
  query_views_by_target_[query_data.target_id()] = query_view;

  HARD_ASSERT(
      view_change.snapshot().has_value(),
      "ApplyChanges to documents for new view should always return a snapshot");
  return view_change.snapshot().value();
}

void SyncEngine::StopListening(const Query& query) {
  AssertCallbackExists("StopListening");

  auto query_view = query_views_by_query_[query];
  HARD_ASSERT(query_view, "Trying to stop listening to a query not found");

  local_store_->ReleaseQuery(query);
  remote_store_->StopListening(query_view->target_id());
  RemoveAndCleanupQuery(query_view);
}

void SyncEngine::RemoveAndCleanupQuery(
    const std::shared_ptr<QueryView>& query_view) {
  query_views_by_query_.erase(query_view->query());
  query_views_by_target_.erase(query_view->target_id());

  DocumentKeySet limbo_keys =
      limbo_document_refs_.ReferencedKeys(query_view->target_id());
  limbo_document_refs_.RemoveReferences(query_view->target_id());
  for (const DocumentKey& key : limbo_keys) {
    if (!limbo_document_refs_.ContainsKey(key)) {
      // We removed the last reference for this key.
      RemoveLimboTarget(key);
    }
  }
}

void SyncEngine::WriteMutations(std::vector<model::Mutation>&& mutations,
                                StatusCallback callback) {
  AssertCallbackExists("WriteMutations");

  LocalWriteResult result = local_store_->WriteLocally(std::move(mutations));
  mutation_callbacks_[current_user_].insert(
      std::make_pair(result.batch_id(), std::move(callback)));

  EmitNewSnapshotsAndNotifyLocalStore(result.changes(), absl::nullopt);
  remote_store_->FillWritePipeline();
}

void SyncEngine::RegisterPendingWritesCallback(StatusCallback callback) {
  if (!remote_store_->CanUseNetwork()) {
    LOG_DEBUG("The network is disabled. The task returned by "
              "'waitForPendingWrites()' will not "
              "complete until the network is enabled.");
  }

  int largest_pending_batch_id =
      local_store_->GetHighestUnacknowledgedBatchId();

  if (largest_pending_batch_id == kBatchIdUnknown) {
    // Trigger the callback right away if there is no pending writes at the
    // moment.
    callback(Status::OK());
    return;
  }

  pending_writes_callbacks_[largest_pending_batch_id].push_back(
      std::move(callback));
}

void SyncEngine::Transaction(int retries,
                             const std::shared_ptr<AsyncQueue>& worker_queue,
                             TransactionUpdateCallback update_callback,
                             TransactionResultCallback result_callback) {
  worker_queue->VerifyIsCurrentQueue();
  HARD_ASSERT(retries >= 0, "Got negative number of retries for transaction");

  // Allocate a shared_ptr so that the TransactionRunner can outlive this frame.
  auto runner = std::make_shared<TransactionRunner>(worker_queue, remote_store_,
                                                    std::move(update_callback),
                                                    std::move(result_callback));
  runner->Run();
}

void SyncEngine::HandleCredentialChange(const auth::User& user) {
  bool user_changed = (current_user_ != user);
  current_user_ = user;

  if (user_changed) {
    // Fails callbacks waiting for pending writes requested by previous user.
    FailOutstandingPendingWriteCallbacks(
        "'waitForPendingWrites' callback is cancelled due to a user change.");
    // Notify local store and emit any resulting events from swapping out the
    // mutation queue.
    MaybeDocumentMap changes = local_store_->HandleUserChange(user);
    EmitNewSnapshotsAndNotifyLocalStore(changes, absl::nullopt);
  }

  // Notify remote store so it can restart its streams.
  remote_store_->HandleCredentialChange();
}

void SyncEngine::ApplyRemoteEvent(const RemoteEvent& remote_event) {
  AssertCallbackExists("HandleRemoteEvent");

  // Update received document as appropriate for any limbo targets.
  for (const auto& entry : remote_event.target_changes()) {
    TargetId target_id = entry.first;
    const TargetChange& change = entry.second;
    auto it = limbo_resolutions_by_target_.find(target_id);
    if (it == limbo_resolutions_by_target_.end()) {
      continue;
    }

    LimboResolution& limbo_resolution = it->second;
    // Since this is a limbo resolution lookup, it's for a single document and
    // it could be added, modified, or removed, but not a combination.
    auto changed_documents_count = change.added_documents().size() +
                                   change.modified_documents().size() +
                                   change.removed_documents().size();
    HARD_ASSERT(
        changed_documents_count <= 1,
        "Limbo resolution for single document contains multiple changes.");

    if (!change.added_documents().empty()) {
      limbo_resolution.document_received = true;
    } else if (!change.modified_documents().empty()) {
      HARD_ASSERT(limbo_resolution.document_received,
                  "Received change for limbo target document without add.");
    } else if (!change.removed_documents().empty()) {
      HARD_ASSERT(limbo_resolution.document_received,
                  "Received remove for limbo target document without add.");
      limbo_resolution.document_received = false;
    } else {
      // This was probably just a CURRENT target change or similar.
    }
  }

  MaybeDocumentMap changes = local_store_->ApplyRemoteEvent(remote_event);
  EmitNewSnapshotsAndNotifyLocalStore(changes, remote_event);
}

void SyncEngine::HandleRejectedListen(TargetId target_id, Status error) {
  AssertCallbackExists("HandleRejectedListen");

  auto it = limbo_resolutions_by_target_.find(target_id);
  if (it != limbo_resolutions_by_target_.end()) {
    DocumentKey limbo_key = it->second.key;
    // Since this query failed, we won't want to manually unlisten to it.
    // So go ahead and remove it from bookkeeping.
    limbo_targets_by_key_.erase(limbo_key);
    limbo_resolutions_by_target_.erase(target_id);

    // TODO(dimond): Retry on transient errors?

    // It's a limbo doc. Create a synthetic event saying it was deleted. This is
    // kind of a hack. Ideally, we would have a method in the local store to
    // purge a document. However, it would be tricky to keep all of the local
    // store's invariants with another method.
    NoDocument doc(limbo_key, SnapshotVersion::None(),
                   /* has_committed_mutations= */ false);
    DocumentKeySet limbo_documents = DocumentKeySet{limbo_key};
    RemoteEvent event{SnapshotVersion::None(), /*target_changes=*/{},
                      /*target_mismatches=*/{},
                      /*document_updates=*/{{limbo_key, doc}},
                      std::move(limbo_documents)};
    ApplyRemoteEvent(event);

  } else {
    auto found = query_views_by_target_.find(target_id);
    HARD_ASSERT(found != query_views_by_target_.end(), "Unknown target id: %s",
                target_id);
    auto query_view = found->second;
    const Query& query = query_view->query();
    local_store_->ReleaseQuery(query);
    RemoveAndCleanupQuery(query_view);
    if (ErrorIsInteresting(error)) {
      LOG_WARN("Listen for query at %s failed: %s",
               query.path().CanonicalString(), error.error_message());
    }
    sync_engine_callback_->OnError(query, std::move(error));
  }
}

void SyncEngine::HandleSuccessfulWrite(
    const model::MutationBatchResult& batch_result) {
  AssertCallbackExists("HandleSuccessfulWrite");

  // The local store may or may not be able to apply the write result and raise
  // events immediately (depending on whether the watcher is caught up), so we
  // raise user callbacks first so that they consistently happen before listen
  // events.
  NotifyUser(batch_result.batch().batch_id(), Status::OK());

  TriggerPendingWriteCallbacks(batch_result.batch().batch_id());

  MaybeDocumentMap changes = local_store_->AcknowledgeBatch(batch_result);
  EmitNewSnapshotsAndNotifyLocalStore(changes, absl::nullopt);
}

void SyncEngine::HandleRejectedWrite(
    firebase::firestore::model::BatchId batch_id, Status error) {
  AssertCallbackExists("HandleRejectedWrite");

  MaybeDocumentMap changes = local_store_->RejectBatch(batch_id);

  if (!changes.empty() && ErrorIsInteresting(error)) {
    const DocumentKey& min_key = changes.min()->first;
    LOG_WARN("Write at %s failed: %s", min_key.ToString(),
             error.error_message());
  }

  // The local store may or may not be able to apply the write result and raise
  // events immediately (depending on whether the watcher is caught up), so we
  // raise user callbacks first so that they consistently happen before listen
  // events.
  NotifyUser(batch_id, std::move(error));

  TriggerPendingWriteCallbacks(batch_id);

  EmitNewSnapshotsAndNotifyLocalStore(changes, absl::nullopt);
}

void SyncEngine::HandleOnlineStateChange(model::OnlineState online_state) {
  AssertCallbackExists("HandleOnlineStateChange");

  std::vector<ViewSnapshot> new_view_snapshot;
  for (const auto& entry : query_views_by_query_) {
    const auto& query_view = entry.second;
    ViewChange view_change =
        query_view->view().ApplyOnlineStateChange(online_state);
    HARD_ASSERT(view_change.limbo_changes().empty(),
                "OnlineState should not affect limbo documents.");
    if (view_change.snapshot().has_value()) {
      new_view_snapshot.push_back(*std::move(view_change).snapshot());
    }
  }

  sync_engine_callback_->OnViewSnapshots(std::move(new_view_snapshot));
  sync_engine_callback_->HandleOnlineStateChange(online_state);
}

DocumentKeySet SyncEngine::GetRemoteKeys(TargetId target_id) const {
  auto it = limbo_resolutions_by_target_.find(target_id);
  if (it != limbo_resolutions_by_target_.end() &&
      it->second.document_received) {
    return DocumentKeySet{it->second.key};
  } else {
    auto found = query_views_by_target_.find(target_id);
    if (found != query_views_by_target_.end()) {
      return found->second->view().synced_documents();
    }
    return DocumentKeySet{};
  }
}

void SyncEngine::NotifyUser(BatchId batch_id, Status status) {
  auto it = mutation_callbacks_.find(current_user_);

  // NOTE: Mutations restored from persistence won't have callbacks, so
  // it's okay for this (or the callback below) to not exist.
  if (it == mutation_callbacks_.end()) {
    return;
  }

  std::unordered_map<BatchId, StatusCallback>& callbacks = it->second;
  auto callback_it = callbacks.find(batch_id);
  if (callback_it != callbacks.end()) {
    callback_it->second(std::move(status));
    callbacks.erase(callback_it);
  }
}

void SyncEngine::TriggerPendingWriteCallbacks(BatchId batch_id) {
  auto it = pending_writes_callbacks_.find(batch_id);
  if (it != pending_writes_callbacks_.end()) {
    for (const auto& callback : it->second) {
      callback(Status::OK());
    }

    pending_writes_callbacks_.erase(it);
  }
}

void SyncEngine::FailOutstandingPendingWriteCallbacks(
    absl::string_view message) {
  for (const auto& entry : pending_writes_callbacks_) {
    for (const auto& callback : entry.second) {
      callback(Status(Error::Cancelled, message));
    }
  }

  pending_writes_callbacks_.clear();
}

void SyncEngine::EmitNewSnapshotsAndNotifyLocalStore(
    const MaybeDocumentMap& changes,
    const absl::optional<RemoteEvent>& maybe_remote_event) {
  std::vector<ViewSnapshot> new_snapshots;
  std::vector<LocalViewChanges> document_changes_in_all_views;

  for (const auto& entry : query_views_by_query_) {
    const auto& query_view = entry.second;
    View& view = query_view->view();
    ViewDocumentChanges view_doc_changes = view.ComputeDocumentChanges(changes);
    if (view_doc_changes.needs_refill()) {
      // The query has a limit and some docs were removed/updated, so we need to
      // re-run the query against the local store to make sure we didn't lose
      // any good docs that had been past the limit.
      DocumentMap docs = local_store_->ExecuteQuery(query_view->query());
      view_doc_changes =
          view.ComputeDocumentChanges(docs.underlying_map(), view_doc_changes);
    }

    absl::optional<TargetChange> target_changes;
    if (maybe_remote_event.has_value()) {
      const RemoteEvent& remote_event = maybe_remote_event.value();
      auto it = remote_event.target_changes().find(query_view->target_id());
      if (it != remote_event.target_changes().end()) {
        target_changes = it->second;
      }
    }
    ViewChange view_change =
        view.ApplyChanges(view_doc_changes, target_changes);

    UpdateTrackedLimboDocuments(view_change.limbo_changes(),
                                query_view->target_id());

    if (view_change.snapshot().has_value()) {
      new_snapshots.push_back(*view_change.snapshot());
      LocalViewChanges doc_changes = LocalViewChanges::FromViewSnapshot(
          *view_change.snapshot(), query_view->target_id());
      document_changes_in_all_views.push_back(std::move(doc_changes));
    }
  }

  sync_engine_callback_->OnViewSnapshots(std::move(new_snapshots));
  local_store_->NotifyLocalViewChanges(document_changes_in_all_views);
}

void SyncEngine::UpdateTrackedLimboDocuments(
    const std::vector<LimboDocumentChange>& limbo_changes, TargetId target_id) {
  for (const LimboDocumentChange& limbo_change : limbo_changes) {
    switch (limbo_change.type()) {
      case LimboDocumentChange::Type::Added:
        limbo_document_refs_.AddReference(limbo_change.key(), target_id);
        TrackLimboChange(limbo_change);
        break;

      case LimboDocumentChange::Type::Removed:
        LOG_DEBUG("Document no longer in limbo: %s",
                  limbo_change.key().ToString());
        limbo_document_refs_.RemoveReference(limbo_change.key(), target_id);
        if (!limbo_document_refs_.ContainsKey(limbo_change.key())) {
          // We removed the last reference for this key
          RemoveLimboTarget(limbo_change.key());
        }
        break;

      default:
        HARD_FAIL("Unknown limbo change type: %s", limbo_change.type());
    }
  }
}

void SyncEngine::TrackLimboChange(const LimboDocumentChange& limbo_change) {
  const DocumentKey& key = limbo_change.key();

  if (limbo_targets_by_key_.find(key) == limbo_targets_by_key_.end()) {
    LOG_DEBUG("New document in limbo: %s", key.ToString());

    TargetId limbo_target_id = target_id_generator_.NextId();
    Query query(key.path());
    QueryData query_data(std::move(query), limbo_target_id,
                         kIrrelevantSequenceNumber,
                         QueryPurpose::LimboResolution);
    limbo_resolutions_by_target_.emplace(limbo_target_id, LimboResolution{key});
    // TODO(wuandy): move `query_data` into `Listen`.
    remote_store_->Listen(query_data);
    limbo_targets_by_key_[key] = limbo_target_id;
  }
}

void SyncEngine::RemoveLimboTarget(const DocumentKey& key) {
  auto it = limbo_targets_by_key_.find(key);
  if (it == limbo_targets_by_key_.end()) {
    // This target already got removed, because the query failed.
    return;
  }

  TargetId limbo_target_id = it->second;
  remote_store_->StopListening(limbo_target_id);
  limbo_targets_by_key_.erase(key);
  limbo_resolutions_by_target_.erase(limbo_target_id);
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
