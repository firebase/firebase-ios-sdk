/*
 * Copyright 2019 Google LLC
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

#include "Firestore/core/src/local/local_store.h"

#include <utility>

#include "Firestore/core/src/local/local_documents_view.h"
#include "Firestore/core/src/local/local_view_changes.h"
#include "Firestore/core/src/local/local_write_result.h"
#include "Firestore/core/src/local/lru_garbage_collector.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/local/query_engine.h"
#include "Firestore/core/src/local/query_result.h"
#include "Firestore/core/src/local/reference_delegate.h"
#include "Firestore/core/src/local/target_cache.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/src/model/mutation_batch_result.h"
#include "Firestore/core/src/model/patch_mutation.h"
#include "Firestore/core/src/remote/remote_event.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/to_string.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using auth::User;
using core::Query;
using core::Target;
using core::TargetIdGenerator;
using model::BatchId;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::DocumentVersionMap;
using model::ListenSequenceNumber;
using model::MaybeDocument;
using model::MaybeDocumentMap;
using model::Mutation;
using model::MutationBatch;
using model::MutationBatchResult;
using model::ObjectValue;
using model::OptionalMaybeDocumentMap;
using model::PatchMutation;
using model::Precondition;
using model::SnapshotVersion;
using model::TargetId;
using nanopb::ByteString;
using remote::TargetChange;

/**
 * The maximum time to leave a resume token buffered without writing it out.
 * This value is arbitrary: it's long enough to avoid several writes (possibly
 * indefinitely if updates come more frequently than this) but short enough that
 * restarting after crashing will still have a pretty recent resume token.
 */
const int64_t kResumeTokenMaxAgeSeconds = 5 * 60;  // 5 minutes

}  // namespace

LocalStore::LocalStore(Persistence* persistence,
                       QueryEngine* query_engine,
                       const User& initial_user)
    : persistence_(persistence),
      mutation_queue_(persistence->GetMutationQueueForUser(initial_user)),
      remote_document_cache_(persistence->remote_document_cache()),
      target_cache_(persistence->target_cache()),
      query_engine_(query_engine),
      local_documents_(
          absl::make_unique<LocalDocumentsView>(remote_document_cache_,
                                                mutation_queue_,
                                                persistence->index_manager())) {
  persistence->reference_delegate()->AddInMemoryPins(&local_view_references_);
  target_id_generator_ = TargetIdGenerator::TargetCacheTargetIdGenerator(0);
  query_engine_->SetLocalDocumentsView(local_documents_.get());
}

LocalStore::~LocalStore() = default;

void LocalStore::Start() {
  StartMutationQueue();
  TargetId target_id = target_cache_->highest_target_id();
  target_id_generator_ =
      TargetIdGenerator::TargetCacheTargetIdGenerator(target_id);
}

void LocalStore::StartMutationQueue() {
  persistence_->Run("Start MutationQueue", [&] { mutation_queue_->Start(); });
}

MaybeDocumentMap LocalStore::HandleUserChange(const User& user) {
  // Swap out the mutation queue, grabbing the pending mutation batches before
  // and after.
  std::vector<MutationBatch> old_batches = persistence_->Run(
      "OldBatches", [&] { return mutation_queue_->AllMutationBatches(); });

  // The old one has a reference to the mutation queue, so null it out first.
  local_documents_.reset();
  mutation_queue_ = persistence_->GetMutationQueueForUser(user);

  StartMutationQueue();

  return persistence_->Run("NewBatches", [&] {
    std::vector<MutationBatch> new_batches =
        mutation_queue_->AllMutationBatches();

    // Recreate our LocalDocumentsView using the new MutationQueue.
    local_documents_ = absl::make_unique<LocalDocumentsView>(
        remote_document_cache_, mutation_queue_, persistence_->index_manager());
    query_engine_->SetLocalDocumentsView(local_documents_.get());

    // Union the old/new changed keys.
    DocumentKeySet changed_keys;
    for (const std::vector<MutationBatch>* batches :
         {&old_batches, &new_batches}) {
      for (const MutationBatch& batch : *batches) {
        for (const Mutation& mutation : batch.mutations()) {
          changed_keys = changed_keys.insert(mutation.key());
        }
      }
    }

    // Return the set of all (potentially) changed documents as the result of
    // the user change.
    return local_documents_->GetDocuments(changed_keys);
  });
}

LocalWriteResult LocalStore::WriteLocally(std::vector<Mutation>&& mutations) {
  Timestamp local_write_time = Timestamp::Now();
  DocumentKeySet keys;
  for (const Mutation& mutation : mutations) {
    keys = keys.insert(mutation.key());
  }

  return persistence_->Run("Locally write mutations", [&] {
    // Load and apply all existing mutations. This lets us compute the current
    // base state for all non-idempotent transforms before applying any
    // additional user-provided writes.
    MaybeDocumentMap existing_documents = local_documents_->GetDocuments(keys);

    // For non-idempotent mutations (such as `FieldValue.increment()`), we
    // record the base state in a separate patch mutation. This is later used to
    // guarantee consistent values and prevents flicker even if the backend
    // sends us an update that already includes our transform.
    std::vector<Mutation> base_mutations;
    for (const Mutation& mutation : mutations) {
      absl::optional<MaybeDocument> base_document =
          existing_documents.get(mutation.key());

      absl::optional<ObjectValue> base_value =
          mutation.ExtractTransformBaseValue(base_document);
      if (base_value) {
        // NOTE: The base state should only be applied if there's some existing
        // document to override, so use a Precondition of exists=true
        base_mutations.push_back(PatchMutation(mutation.key(), *base_value,
                                               base_value->ToFieldMask(),
                                               Precondition::Exists(true)));
      }
    }

    MutationBatch batch = mutation_queue_->AddMutationBatch(
        local_write_time, std::move(base_mutations), std::move(mutations));
    MaybeDocumentMap changed_documents =
        batch.ApplyToLocalDocumentSet(existing_documents);
    return LocalWriteResult{batch.batch_id(), std::move(changed_documents)};
  });
}

MaybeDocumentMap LocalStore::AcknowledgeBatch(
    const MutationBatchResult& batch_result) {
  return persistence_->Run("Acknowledge batch", [&] {
    const MutationBatch& batch = batch_result.batch();
    mutation_queue_->AcknowledgeBatch(batch, batch_result.stream_token());
    ApplyBatchResult(batch_result);
    mutation_queue_->PerformConsistencyCheck();

    return local_documents_->GetDocuments(batch.keys());
  });
}

void LocalStore::ApplyBatchResult(const MutationBatchResult& batch_result) {
  const MutationBatch& batch = batch_result.batch();
  DocumentKeySet doc_keys = batch.keys();
  const DocumentVersionMap& versions = batch_result.doc_versions();

  for (const DocumentKey& doc_key : doc_keys) {
    absl::optional<MaybeDocument> remote_doc =
        remote_document_cache_->Get(doc_key);
    absl::optional<MaybeDocument> doc = remote_doc;

    auto ack_version_iter = versions.find(doc_key);
    HARD_ASSERT(ack_version_iter != versions.end(),
                "doc_versions should contain every doc in the write.");
    const SnapshotVersion& ack_version = ack_version_iter->second;

    if (!doc || doc->version() < ack_version) {
      doc = batch.ApplyToRemoteDocument(doc, doc_key, batch_result);
      if (!doc) {
        HARD_ASSERT(
            !remote_doc,
            "Mutation batch %s applied to document %s resulted in nullopt.",
            batch.ToString(), util::ToString(remote_doc));
      } else {
        remote_document_cache_->Add(*doc, batch_result.commit_version());
      }
    }
  }

  mutation_queue_->RemoveMutationBatch(batch);
}

MaybeDocumentMap LocalStore::RejectBatch(BatchId batch_id) {
  return persistence_->Run("Reject batch", [&] {
    absl::optional<MutationBatch> to_reject =
        mutation_queue_->LookupMutationBatch(batch_id);
    HARD_ASSERT(to_reject.has_value(), "Attempt to reject nonexistent batch!");

    mutation_queue_->RemoveMutationBatch(*to_reject);
    mutation_queue_->PerformConsistencyCheck();

    return local_documents_->GetDocuments(to_reject->keys());
  });
}

ByteString LocalStore::GetLastStreamToken() {
  return mutation_queue_->GetLastStreamToken();
}

void LocalStore::SetLastStreamToken(const ByteString& stream_token) {
  persistence_->Run("Set stream token",
                    [&] { mutation_queue_->SetLastStreamToken(stream_token); });
}

const SnapshotVersion& LocalStore::GetLastRemoteSnapshotVersion() const {
  return target_cache_->GetLastRemoteSnapshotVersion();
}

model::MaybeDocumentMap LocalStore::ApplyRemoteEvent(
    const remote::RemoteEvent& remote_event) {
  const SnapshotVersion& last_remote_version =
      target_cache_->GetLastRemoteSnapshotVersion();

  return persistence_->Run("Apply remote event", [&] {
    // TODO(gsoltis): move the sequence number into the reference delegate.
    ListenSequenceNumber sequence_number =
        persistence_->current_sequence_number();

    for (const auto& entry : remote_event.target_changes()) {
      TargetId target_id = entry.first;
      const TargetChange& change = entry.second;

      auto found = target_data_by_target_.find(target_id);
      if (found == target_data_by_target_.end()) {
        // We don't update the remote keys if the query is not active. This
        // ensures that we persist the updated target data along with the
        // updated assignment.
        continue;
      }

      TargetData old_target_data = found->second;

      target_cache_->RemoveMatchingKeys(change.removed_documents(), target_id);
      target_cache_->AddMatchingKeys(change.added_documents(), target_id);

      // Update the resume token if the change includes one. Don't clear any
      // preexisting value. Bump the sequence number as well, so that documents
      // being removed now are ordered later than documents that were reviously
      // _removed from this target.
      const ByteString& resume_token = change.resume_token();
      // Update the resume token if the change includes one.
      if (!resume_token.empty()) {
        TargetData new_target_data =
            old_target_data
                .WithResumeToken(resume_token, remote_event.snapshot_version())
                .WithSequenceNumber(sequence_number);
        target_data_by_target_[target_id] = new_target_data;

        // Update the target data if there are target changes (or if sufficient
        // time has passed since the last update).
        if (ShouldPersistTargetData(new_target_data, old_target_data, change)) {
          target_cache_->UpdateTarget(new_target_data);
        }
      }
    }

    OptionalMaybeDocumentMap changed_docs;
    const DocumentKeySet& limbo_documents =
        remote_event.limbo_document_changes();
    DocumentKeySet updated_keys;
    for (const auto& kv : remote_event.document_updates()) {
      updated_keys = updated_keys.insert(kv.first);
    }
    // Each loop iteration only affects its "own" doc, so it's safe to get all
    // the remote documents in advance in a single call.
    OptionalMaybeDocumentMap existing_docs =
        remote_document_cache_->GetAll(updated_keys);

    for (const auto& kv : remote_event.document_updates()) {
      const DocumentKey& key = kv.first;
      const MaybeDocument& doc = kv.second;
      absl::optional<MaybeDocument> existing_doc;
      auto found_existing = existing_docs.get(key);
      if (found_existing) {
        existing_doc = *found_existing;
      }

      // Note: The order of the steps below is important, since we want to
      // ensure that rejected limbo resolutions (which fabricate NoDocuments
      // with SnapshotVersion::None) never add documents to cache.
      if (doc.type() == MaybeDocument::Type::NoDocument &&
          doc.version() == SnapshotVersion::None()) {
        // NoDocuments with SnapshotVersion::None are used in manufactured
        // events. We remove these documents from cache since we lost access.
        remote_document_cache_->Remove(key);
        changed_docs = changed_docs.insert(key, doc);
      } else if (!existing_doc || doc.version() > existing_doc->version() ||
                 (doc.version() == existing_doc->version() &&
                  existing_doc->has_pending_writes())) {
        HARD_ASSERT(remote_event.snapshot_version() != SnapshotVersion::None(),
                    "Cannot add a document when the remote version is zero");
        remote_document_cache_->Add(doc, remote_event.snapshot_version());
        changed_docs = changed_docs.insert(key, doc);
      } else {
        LOG_DEBUG(
            "LocalStore Ignoring outdated watch update for %s. "
            "Current version: %s  Watch version: %s",
            key.ToString(), existing_doc->version().ToString(),
            doc.version().ToString());
      }

      // If this was a limbo resolution, make sure we mark when it was accessed.
      if (limbo_documents.contains(key)) {
        persistence_->reference_delegate()->UpdateLimboDocument(key);
      }
    }

    // HACK: The only reason we allow omitting snapshot version is so we can
    // synthesize remote events when we get permission denied errors while
    // trying to resolve the state of a locally cached document that is in
    // limbo.
    const SnapshotVersion& remote_version = remote_event.snapshot_version();
    if (remote_version != SnapshotVersion::None()) {
      HARD_ASSERT(remote_version >= last_remote_version,
                  "Watch stream reverted to previous snapshot?? (%s < %s)",
                  remote_version.ToString(), last_remote_version.ToString());
      target_cache_->SetLastRemoteSnapshotVersion(remote_version);
    }

    return local_documents_->GetLocalViewOfDocuments(changed_docs);
  });
}

bool LocalStore::ShouldPersistTargetData(const TargetData& new_target_data,
                                         const TargetData& old_target_data,
                                         const TargetChange& change) const {
  // Avoid clearing any existing value
  HARD_ASSERT(!new_target_data.resume_token().empty(),
              "Attempted to persist target data with empty resume token");

  // Always persist target data if we don't already have a resume token.
  if (old_target_data.resume_token().empty()) return true;

  // Don't allow resume token changes to be buffered indefinitely. This allows
  // us to be reasonably up-to-date after a crash and avoids needing to loop
  // over all active queries on shutdown. Especially in the browser we may not
  // get time to do anything interesting while the current tab is closing.
  int64_t new_seconds =
      new_target_data.snapshot_version().timestamp().seconds();
  int64_t old_seconds =
      old_target_data.snapshot_version().timestamp().seconds();
  int64_t time_delta = new_seconds - old_seconds;
  if (time_delta >= kResumeTokenMaxAgeSeconds) return true;

  // Otherwise if the only thing that has changed about a target is its resume
  // token then it's not worth persisting. Note that the RemoteStore keeps an
  // in-memory view of the currently active targets which includes the current
  // resume token, so stream failure or user changes will still use an
  // up-to-date resume token regardless of what we do here.
  size_t changes = change.added_documents().size() +
                   change.modified_documents().size() +
                   change.removed_documents().size();
  return changes > 0;
}

absl::optional<TargetData> LocalStore::GetTargetData(
    const core::Target& target) {
  auto target_id = target_id_by_target_.find(target);
  if (target_id != target_id_by_target_.end()) {
    return target_data_by_target_[target_id->second];
  }
  return target_cache_->GetTarget(target);
}

void LocalStore::NotifyLocalViewChanges(
    const std::vector<local::LocalViewChanges>& view_changes) {
  persistence_->Run("NotifyLocalViewChanges", [&] {
    for (const LocalViewChanges& view_change : view_changes) {
      int target_id = view_change.target_id();

      for (const DocumentKey& key : view_change.removed_keys()) {
        persistence_->reference_delegate()->RemoveReference(key);
      }
      local_view_references_.AddReferences(view_change.added_keys(), target_id);
      local_view_references_.RemoveReferences(view_change.removed_keys(),
                                              target_id);

      if (!view_change.is_from_cache()) {
        const auto& entry = target_data_by_target_.find(target_id);
        HARD_ASSERT(
            entry != target_data_by_target_.end(),
            "Can't set limbo-free snapshot version for unknown target: %s",
            target_id);
        const TargetData& target_data = entry->second;

        // Advance the last limbo free snapshot version
        SnapshotVersion last_limbo_free_snapshot_version =
            target_data.snapshot_version();
        TargetData updated_target_data =
            target_data.WithLastLimboFreeSnapshotVersion(
                last_limbo_free_snapshot_version);
        target_data_by_target_[target_id] = updated_target_data;
      }
    }
  });
}

absl::optional<MutationBatch> LocalStore::GetNextMutationBatch(
    BatchId batch_id) {
  return persistence_->Run("NextMutationBatchAfterBatchID", [&] {
    return mutation_queue_->NextMutationBatchAfterBatchId(batch_id);
  });
}

absl::optional<MaybeDocument> LocalStore::ReadDocument(const DocumentKey& key) {
  return persistence_->Run("ReadDocument",
                           [&] { return local_documents_->GetDocument(key); });
}

BatchId LocalStore::GetHighestUnacknowledgedBatchId() {
  return persistence_->Run("GetHighestUnacknowledgedBatchId", [&] {
    return mutation_queue_->GetHighestUnacknowledgedBatchId();
  });
}

TargetData LocalStore::AllocateTarget(Target target) {
  TargetData target_data = persistence_->Run("Allocate target", [&] {
    absl::optional<TargetData> cached = target_cache_->GetTarget(target);
    // TODO(mcg): freshen last accessed date if cached exists?
    if (!cached) {
      cached = TargetData(std::move(target), target_id_generator_.NextId(),
                          persistence_->current_sequence_number(),
                          QueryPurpose::Listen);
      target_cache_->AddTarget(*cached);
    }
    return *cached;
  });

  // Sanity check to ensure that even when resuming a query it's not currently
  // active.
  TargetId target_id = target_data.target_id();
  if (target_data_by_target_.find(target_id) == target_data_by_target_.end()) {
    target_data_by_target_[target_id] = target_data;
    target_id_by_target_[target_data.target()] = target_id;
  }

  return target_data;
}

void LocalStore::ReleaseTarget(TargetId target_id) {
  persistence_->Run("Release target", [&] {
    auto found = target_data_by_target_.find(target_id);
    HARD_ASSERT(found != target_data_by_target_.end(),
                "Tried to release a non-existent target: %s", target_id);

    TargetData target_data = found->second;

    // References for documents sent via Watch are automatically removed when we
    // delete a query's target data from the reference delegate. Since this does
    // not remove references for locally mutated documents, we have to remove
    // the target associations for these documents manually.
    DocumentKeySet removed =
        local_view_references_.RemoveReferences(target_data.target_id());
    for (const DocumentKey& key : removed) {
      persistence_->reference_delegate()->RemoveReference(key);
    }

    // Note: This also updates the target cache.
    persistence_->reference_delegate()->RemoveTarget(target_data);
    target_data_by_target_.erase(target_id);
    target_id_by_target_.erase(target_data.target());
  });
}

QueryResult LocalStore::ExecuteQuery(const Query& query,
                                     bool use_previous_results) {
  return persistence_->Run("ExecuteQuery", [&] {
    absl::optional<TargetData> target_data = GetTargetData(query.ToTarget());
    SnapshotVersion last_limbo_free_snapshot_version;
    DocumentKeySet remote_keys;

    if (target_data) {
      last_limbo_free_snapshot_version =
          target_data->last_limbo_free_snapshot_version();
      remote_keys = target_cache_->GetMatchingKeys(target_data->target_id());
    }

    model::DocumentMap documents = query_engine_->GetDocumentsMatchingQuery(
        query,
        use_previous_results ? last_limbo_free_snapshot_version
                             : SnapshotVersion::None(),
        use_previous_results ? remote_keys : DocumentKeySet{});
    return QueryResult(std::move(documents), std::move(remote_keys));
  });
}

DocumentKeySet LocalStore::GetRemoteDocumentKeys(TargetId target_id) {
  return persistence_->Run("RemoteDocumentKeysForTarget", [&] {
    return target_cache_->GetMatchingKeys(target_id);
  });
}

LruResults LocalStore::CollectGarbage(LruGarbageCollector* garbage_collector) {
  return persistence_->Run("Collect garbage", [&] {
    return garbage_collector->Collect(target_data_by_target_);
  });
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
