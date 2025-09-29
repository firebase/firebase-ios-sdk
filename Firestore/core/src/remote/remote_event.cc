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

#include "Firestore/core/src/remote/remote_event.h"

#include <string>
#include <utility>

#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/testing_hooks.h"

namespace firebase {
namespace firestore {
namespace remote {

using core::DocumentViewChange;
using core::Target;
using local::QueryPurpose;
using local::TargetData;
using model::DatabaseId;
using model::DocumentKey;
using model::DocumentKeySet;
using model::MutableDocument;
using model::SnapshotVersion;
using model::TargetId;
using nanopb::ByteString;
using util::TestingHooks;

// TargetChange

bool operator==(const TargetChange& lhs, const TargetChange& rhs) {
  return lhs.resume_token() == rhs.resume_token() &&
         lhs.current() == rhs.current() &&
         lhs.added_documents() == rhs.added_documents() &&
         lhs.modified_documents() == rhs.modified_documents() &&
         lhs.removed_documents() == rhs.removed_documents();
}

// TargetState

void TargetState::UpdateResumeToken(ByteString resume_token) {
  if (!resume_token.empty()) {
    has_pending_changes_ = true;
    resume_token_ = std::move(resume_token);
  }
}

TargetChange TargetState::ToTargetChange() const {
  DocumentKeySet added_documents;
  DocumentKeySet modified_documents;
  DocumentKeySet removed_documents;

  for (const auto& entry : document_changes_) {
    const DocumentKey& document_key = entry.first;
    DocumentViewChange::Type change_type = entry.second;

    switch (change_type) {
      case DocumentViewChange::Type::Added:
        added_documents = added_documents.insert(document_key);
        break;
      case DocumentViewChange::Type::Modified:
        modified_documents = modified_documents.insert(document_key);
        break;
      case DocumentViewChange::Type::Removed:
        removed_documents = removed_documents.insert(document_key);
        break;
      default:
        HARD_FAIL("Encountered invalid change type: %s", change_type);
    }
  }

  return TargetChange{resume_token(), current(), std::move(added_documents),
                      std::move(modified_documents),
                      std::move(removed_documents)};
}

void TargetState::ClearPendingChanges() {
  has_pending_changes_ = false;
  document_changes_.clear();
}

void TargetState::RecordPendingTargetRequest() {
  ++outstanding_responses_;
}

void TargetState::RecordTargetResponse() {
  --outstanding_responses_;
}

void TargetState::MarkCurrent() {
  has_pending_changes_ = true;
  current_ = true;
}

void TargetState::AddDocumentChange(const DocumentKey& document_key,
                                    DocumentViewChange::Type type) {
  has_pending_changes_ = true;
  document_changes_[document_key] = type;
}

void TargetState::RemoveDocumentChange(const DocumentKey& document_key) {
  has_pending_changes_ = true;
  document_changes_.erase(document_key);
}

// WatchChangeAggregator

WatchChangeAggregator::WatchChangeAggregator(
    TargetMetadataProvider* target_metadata_provider)
    : target_metadata_provider_{NOT_NULL(target_metadata_provider)} {
}

void WatchChangeAggregator::HandleDocumentChange(
    const DocumentWatchChange& document_change) {
  for (TargetId target_id : document_change.updated_target_ids()) {
    const auto& new_doc = document_change.new_document();
    if (new_doc && new_doc->is_found_document()) {
      AddDocumentToTarget(target_id, *new_doc);
    } else if (new_doc && new_doc->is_no_document()) {
      RemoveDocumentFromTarget(target_id, document_change.document_key(),
                               document_change.new_document());
    }
  }

  for (TargetId target_id : document_change.removed_target_ids()) {
    RemoveDocumentFromTarget(target_id, document_change.document_key(),
                             document_change.new_document());
  }
}

void WatchChangeAggregator::HandleTargetChange(
    const WatchTargetChange& target_change) {
  for (TargetId target_id : GetTargetIds(target_change)) {
    TargetState& target_state = EnsureTargetState(target_id);

    switch (target_change.state()) {
      case WatchTargetChangeState::NoChange:
        if (IsActiveTarget(target_id)) {
          target_state.UpdateResumeToken(target_change.resume_token());
        }
        continue;
      case WatchTargetChangeState::Added:
        // We need to decrement the number of pending acks needed from watch for
        // this target_id.
        target_state.RecordTargetResponse();
        if (!target_state.IsPending()) {
          // We have a freshly added target, so we need to reset any state that
          // we had previously. This can happen e.g. when remove and add back a
          // target for existence filter mismatches.
          target_state.ClearPendingChanges();
        }
        target_state.UpdateResumeToken(target_change.resume_token());
        continue;
      case WatchTargetChangeState::Removed:
        // We need to keep track of removed targets so we can post-filter and
        // remove any target changes. We need to decrement the number of pending
        // acks needed from watch for this target_id.
        target_state.RecordTargetResponse();
        if (!target_state.IsPending()) {
          RemoveTarget(target_id);
        }
        HARD_ASSERT(target_change.cause().ok(),
                    "WatchChangeAggregator does not handle errored targets");
        continue;
      case WatchTargetChangeState::Current:
        if (IsActiveTarget(target_id)) {
          target_state.MarkCurrent();
          target_state.UpdateResumeToken(target_change.resume_token());
        }
        continue;
      case WatchTargetChangeState::Reset:
        if (IsActiveTarget(target_id)) {
          // Reset the target and synthesizes removes for all existing
          // documents. The backend will re-add any documents that still match
          // the target before it sends the next global snapshot.
          ResetTarget(target_id);
          target_state.UpdateResumeToken(target_change.resume_token());
        }
        continue;
    }
    HARD_FAIL("Unknown target watch change state: %s", target_change.state());
  }
}

std::vector<TargetId> WatchChangeAggregator::GetTargetIds(
    const WatchTargetChange& target_change) const {
  if (!target_change.target_ids().empty()) {
    return target_change.target_ids();
  }

  std::vector<TargetId> result;
  for (const auto& entry : target_states_) {
    if (IsActiveTarget(entry.first)) {
      result.push_back(entry.first);
    }
  }

  return result;
}

namespace {

TestingHooks::ExistenceFilterMismatchInfo
create_existence_filter_mismatch_info_for_testing_hooks(
    int local_cache_count,
    const ExistenceFilterWatchChange& existence_filter,
    const DatabaseId& database_id,
    absl::optional<BloomFilter> bloom_filter,
    BloomFilterApplicationStatus status) {
  absl::optional<TestingHooks::BloomFilterInfo> bloom_filter_info;
  if (existence_filter.filter().bloom_filter_parameters().has_value()) {
    const BloomFilterParameters& bloom_filter_parameters =
        existence_filter.filter().bloom_filter_parameters().value();
    bloom_filter_info = {
        status == BloomFilterApplicationStatus::kSuccess,
        bloom_filter_parameters.hash_count,
        static_cast<int>(bloom_filter_parameters.bitmap.size()),
        bloom_filter_parameters.padding, std::move(bloom_filter)};
  }

  return {local_cache_count, existence_filter.filter().count(),
          database_id.project_id(), database_id.database_id(),
          std::move(bloom_filter_info)};
}

bool IsSingleDocumentTarget(const core::TargetOrPipeline target_or_pipeline) {
  // TODO(pipeline): We only handle the non-pipeline case because realtime
  // pipeline does not support single document lookup yet.
  return !target_or_pipeline.IsPipeline() &&
         target_or_pipeline.target().IsDocumentQuery();
}

}  // namespace

void WatchChangeAggregator::HandleExistenceFilter(
    const ExistenceFilterWatchChange& existence_filter) {
  TargetId target_id = existence_filter.target_id();
  int expected_count = existence_filter.filter().count();

  absl::optional<TargetData> target_data = TargetDataForActiveTarget(target_id);
  if (target_data) {
    const core::TargetOrPipeline& target_or_pipeline =
        target_data->target_or_pipeline();

    if (!IsSingleDocumentTarget(target_or_pipeline)) {
      int current_size = GetCurrentDocumentCountForTarget(target_id);
      if (current_size != expected_count) {
        // Apply bloom filter to identify and mark removed documents.
        absl::optional<BloomFilter> bloom_filter =
            ParseBloomFilter(existence_filter);
        BloomFilterApplicationStatus status =
            bloom_filter.has_value()
                ? ApplyBloomFilter(bloom_filter.value(), existence_filter,
                                   current_size)
                : BloomFilterApplicationStatus::kSkipped;
        if (status != BloomFilterApplicationStatus::kSuccess) {
          // If bloom filter application fails, we reset the mapping and
          // trigger re-run of the query.
          ResetTarget(target_id);
          const QueryPurpose purpose =
              status == BloomFilterApplicationStatus::kFalsePositive
                  ? QueryPurpose::ExistenceFilterMismatchBloom
                  : QueryPurpose::ExistenceFilterMismatch;
          pending_target_resets_.insert({target_id, purpose});
        }

        TestingHooks::GetInstance().NotifyOnExistenceFilterMismatch(
            create_existence_filter_mismatch_info_for_testing_hooks(
                current_size, existence_filter,
                target_metadata_provider_->GetDatabaseId(),
                std::move(bloom_filter), status));
      }
    } else {
      if (expected_count == 0) {
        // The existence filter told us the document does not exist. We deduce
        // that this document does not exist and apply a deleted document to our
        // updates. Without applying this deleted document there might be
        // another query that will raise this document as part of a snapshot
        // until it is resolved, essentially exposing inconsistency between
        // queries.
        DocumentKey key{target_or_pipeline.target().path()};
        RemoveDocumentFromTarget(
            target_id, key,
            MutableDocument::NoDocument(key, SnapshotVersion::None()));
      } else {
        HARD_ASSERT(expected_count == 1,
                    "Single document existence filter with count: %s",
                    expected_count);
      }
    }
  }
}

absl::optional<BloomFilter> WatchChangeAggregator::ParseBloomFilter(
    const ExistenceFilterWatchChange& existence_filter) {
  const absl::optional<BloomFilterParameters>& bloom_filter_parameters =
      existence_filter.filter().bloom_filter_parameters();
  if (!bloom_filter_parameters.has_value()) {
    return absl::nullopt;
  }

  util::StatusOr<BloomFilter> maybe_bloom_filter =
      BloomFilter::Create(bloom_filter_parameters.value().bitmap,
                          bloom_filter_parameters.value().padding,
                          bloom_filter_parameters.value().hash_count);
  if (!maybe_bloom_filter.ok()) {
    LOG_WARN("Creating BloomFilter failed: %s",
             maybe_bloom_filter.status().error_message());
    return absl::nullopt;
  }

  BloomFilter bloom_filter = std::move(maybe_bloom_filter).ValueOrDie();

  if (bloom_filter.bit_count() == 0) {
    return absl::nullopt;
  }

  return bloom_filter;
}

BloomFilterApplicationStatus WatchChangeAggregator::ApplyBloomFilter(
    const BloomFilter& bloom_filter,
    const ExistenceFilterWatchChange& existence_filter,
    int current_count) {
  int expected_count = existence_filter.filter().count();

  int removed_document_count =
      FilterRemovedDocuments(bloom_filter, existence_filter.target_id());

  return (expected_count == (current_count - removed_document_count))
             ? BloomFilterApplicationStatus::kSuccess
             : BloomFilterApplicationStatus::kFalsePositive;
}

int WatchChangeAggregator::FilterRemovedDocuments(
    const BloomFilter& bloom_filter, int target_id) {
  const DocumentKeySet existing_keys =
      target_metadata_provider_->GetRemoteKeysForTarget(target_id);
  int removalCount = 0;
  for (const DocumentKey& key : existing_keys) {
    const DatabaseId& database_id = target_metadata_provider_->GetDatabaseId();
    std::string document_path = util::StringFormat(
        "projects/%s/databases/%s/documents/%s", database_id.project_id(),
        database_id.database_id(), key.ToString());

    if (!bloom_filter.MightContain(document_path)) {
      RemoveDocumentFromTarget(target_id, key,
                               /*updatedDocument=*/absl::nullopt);
      removalCount++;
    }
  }
  return removalCount;
}

RemoteEvent WatchChangeAggregator::CreateRemoteEvent(
    const SnapshotVersion& snapshot_version) {
  std::unordered_map<TargetId, TargetChange> target_changes;

  for (auto& entry : target_states_) {
    TargetId target_id = entry.first;
    TargetState& target_state = entry.second;

    absl::optional<TargetData> target_data =
        TargetDataForActiveTarget(target_id);
    if (target_data) {
      if (target_state.current() &&
          IsSingleDocumentTarget(target_data->target_or_pipeline())) {
        // Document queries for document that don't exist can produce an empty
        // result set. To update our local cache, we synthesize a document
        // delete if we have not previously received the document. This resolves
        // the limbo state of the document, removing it from
        // SyncEngine::limbo_document_refs_.
        DocumentKey key{target_data->target_or_pipeline().target().path()};
        if (pending_document_updates_.find(key) ==
                pending_document_updates_.end() &&
            !TargetContainsDocument(target_id, key)) {
          RemoveDocumentFromTarget(
              target_id, key,
              MutableDocument::NoDocument(key, snapshot_version));
        }
      }

      if (target_state.HasPendingChanges()) {
        target_changes[target_id] = target_state.ToTargetChange();
        target_state.ClearPendingChanges();
      }
    }
  }

  DocumentKeySet resolved_limbo_documents;

  // We extract the set of limbo-only document updates as the GC logic
  // special-cases documents that do not appear in the target cache.
  //
  // TODO(gsoltis): Expand on this comment.
  for (const auto& entry : pending_document_target_mappings_) {
    bool is_only_limbo_target = true;

    for (TargetId target_id : entry.second) {
      absl::optional<TargetData> target_data =
          TargetDataForActiveTarget(target_id);
      if (target_data &&
          target_data->purpose() != QueryPurpose::LimboResolution) {
        is_only_limbo_target = false;
        break;
      }
    }

    if (is_only_limbo_target) {
      resolved_limbo_documents = resolved_limbo_documents.insert(entry.first);
    }
  }

  RemoteEvent remote_event{snapshot_version, std::move(target_changes),
                           std::move(pending_target_resets_),
                           std::move(pending_document_updates_),
                           std::move(resolved_limbo_documents)};

  // Re-initialize the current state to ensure that we do not modify the
  // generated `RemoteEvent`.
  pending_document_updates_.clear();
  pending_document_target_mappings_.clear();
  pending_target_resets_.clear();

  return remote_event;
}

void WatchChangeAggregator::AddDocumentToTarget(
    TargetId target_id, const MutableDocument& document) {
  if (!IsActiveTarget(target_id)) {
    return;
  }

  DocumentViewChange::Type change_type =
      TargetContainsDocument(target_id, document.key())
          ? DocumentViewChange::Type::Modified
          : DocumentViewChange::Type::Added;

  TargetState& target_state = EnsureTargetState(target_id);
  target_state.AddDocumentChange(document.key(), change_type);

  pending_document_updates_[document.key()] = document;
  pending_document_target_mappings_[document.key()].insert(target_id);
}

void WatchChangeAggregator::RemoveDocumentFromTarget(
    TargetId target_id,
    const DocumentKey& key,
    const absl::optional<MutableDocument>& updated_document) {
  if (!IsActiveTarget(target_id)) {
    return;
  }

  TargetState& target_state = EnsureTargetState(target_id);
  if (TargetContainsDocument(target_id, key)) {
    target_state.AddDocumentChange(key, DocumentViewChange::Type::Removed);
  } else {
    // The document may have entered and left the target before we raised a
    // snapshot, so we can just ignore the change.
    target_state.RemoveDocumentChange(key);
  }
  pending_document_target_mappings_[key].insert(target_id);

  if (updated_document) {
    pending_document_updates_[key] = *updated_document;
  }
}

void WatchChangeAggregator::RemoveTarget(TargetId target_id) {
  target_states_.erase(target_id);
}

int WatchChangeAggregator::GetCurrentDocumentCountForTarget(
    TargetId target_id) {
  TargetState& target_state = EnsureTargetState(target_id);
  TargetChange target_change = target_state.ToTargetChange();
  return target_metadata_provider_->GetRemoteKeysForTarget(target_id).size() +
         target_change.added_documents().size() -
         target_change.removed_documents().size();
}

void WatchChangeAggregator::RecordPendingTargetRequest(TargetId target_id) {
  // For each request we get we need to record we need a response for it.
  TargetState& target_state = EnsureTargetState(target_id);
  target_state.RecordPendingTargetRequest();
}

TargetState& WatchChangeAggregator::EnsureTargetState(TargetId target_id) {
  return target_states_[target_id];
}

bool WatchChangeAggregator::IsActiveTarget(TargetId target_id) const {
  return TargetDataForActiveTarget(target_id) != absl::nullopt;
}

absl::optional<TargetData> WatchChangeAggregator::TargetDataForActiveTarget(
    TargetId target_id) const {
  auto target_state = target_states_.find(target_id);
  return target_state != target_states_.end() &&
                 target_state->second.IsPending()
             ? absl::optional<TargetData>{}
             : target_metadata_provider_->GetTargetDataForTarget(target_id);
}

void WatchChangeAggregator::ResetTarget(TargetId target_id) {
  auto current_target_state = target_states_.find(target_id);
  HARD_ASSERT(current_target_state != target_states_.end() &&
                  !(current_target_state->second.IsPending()),
              "Should only reset active targets");

  target_states_[target_id] = {};

  // Trigger removal for any documents currently mapped to this target. These
  // removals will be part of the initial snapshot if Watch does not resend
  // these documents.
  DocumentKeySet existing_keys =
      target_metadata_provider_->GetRemoteKeysForTarget(target_id);

  for (const DocumentKey& key : existing_keys) {
    RemoveDocumentFromTarget(target_id, key, absl::nullopt);
  }
}

bool WatchChangeAggregator::TargetContainsDocument(TargetId target_id,
                                                   const DocumentKey& key) {
  const DocumentKeySet& existing_keys =
      target_metadata_provider_->GetRemoteKeysForTarget(target_id);
  return existing_keys.contains(key);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
