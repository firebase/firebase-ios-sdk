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

#include "Firestore/core/src/firebase/firestore/remote/remote_event.h"

#include <utility>

#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Remote/FSTRemoteEvent.h"

using firebase::firestore::core::DocumentViewChangeType;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::DocumentKeySet;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;

namespace firebase {
namespace firestore {
namespace remote {

TargetState::TargetState() : resume_token_{[NSData data]} {
}

void TargetState::UpdateResumeToken(NSData* resume_token) {
  if (resume_token.length > 0) {
    has_pending_changes_ = true;
    resume_token_ = [resume_token copy];
  }
}

void TargetState::ClearPendingChanges() {
  has_pending_changes_ = false;
  document_changes_.clear();
}

FSTTargetChange* TargetState::ToTargetChange() const {
  DocumentKeySet added_documents;
  DocumentKeySet modified_documents;
  DocumentKeySet removed_documents;

  for (const auto& entry : document_changes_) {
    const DocumentKey& document_key = entry.first;
    DocumentViewChangeType change_type = entry.second;

    switch (change_type) {
      case DocumentViewChangeType::Added:
        added_documents = added_documents.insert(document_key);
        break;
      case DocumentViewChangeType::Modified:
        modified_documents = modified_documents.insert(document_key);
        break;
      case DocumentViewChangeType::Removed:
        removed_documents = removed_documents.insert(document_key);
        break;
      default:
        HARD_FAIL("Encountered invalid change type: %s", change_type);
    }
  }

  return [[FSTTargetChange alloc]
      initWithResumeToken:resume_token()
                  current:IsCurrent()
           addedDocuments:std::move(added_documents)
        modifiedDocuments:std::move(modified_documents)
         removedDocuments:std::move(removed_documents)];
}

void TargetState::RecordTargetRequest() {
  ++outstanding_responses_;
}

void TargetState::RecordTargetResponse() {
  --outstanding_responses_;
}

void TargetState::MarkCurrent() {
  has_pending_changes_ = true;
  is_current_ = true;
}

void TargetState::AddDocumentChange(const DocumentKey& document_key,
                                    DocumentViewChangeType type) {
  has_pending_changes_ = true;
  document_changes_[document_key] = type;
}

void TargetState::RemoveDocumentChange(const DocumentKey& document_key) {
  has_pending_changes_ = true;
  document_changes_.erase(document_key);
}

// WatchChangeAggregator

void WatchChangeAggregator::HandleDocumentChange(
    const DocumentWatchChange& document_change) {
  for (TargetId target_id : document_change.updated_target_ids()) {
    if ([document_change.new_document() isKindOfClass:[FSTDocument class]]) {
      AddDocumentToTarget(target_id, document_change.new_document());
    } else if ([document_change.new_document()
                   isKindOfClass:[FSTDeletedDocument class]]) {
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
  // TODO
}

void WatchChangeAggregator::HandleExistenceFilter(
    const ExistenceFilterWatchChange& existence_filter) {
  // TODO
}

FSTRemoteEvent* WatchChangeAggregator::CreateRemoteEvent(
    const SnapshotVersion& snapshot_version) {
  // TODO
  return nil;
}

void WatchChangeAggregator::RecordTargetRequest(TargetId target_id) {
  // For each request we get we need to record we need a response for it.
  TargetState& target_state = EnsureTargetState(target_id);
  target_state.RecordTargetRequest();
}

void WatchChangeAggregator::RemoveTarget(TargetId target_id) {
  target_states_.erase(target_id);
}

void WatchChangeAggregator::AddDocumentToTarget(TargetId target_id, FSTMaybeDocument* document
                                                ) {
  if (!IsActiveTarget(target_id)) {
    return;
  }

  DocumentViewChangeType change_type =
      TargetContainsDocument(target_id, document.key)
          ? DocumentViewChangeType::Modified
          : DocumentViewChangeType::Added;

  TargetState& target_state = EnsureTargetState(target_id);
  target_state.AddDocumentChange(document.key, change_type);

  pending_document_updates_[document.key] = document;
  pending_document_target_mappings_[document.key].insert(target_id);
}

void WatchChangeAggregator::RemoveDocumentFromTarget(
    TargetId target_id,
    const DocumentKey& key,
    FSTMaybeDocument* _Nullable updated_document) {
  if (!IsActiveTarget(target_id)) {
    return;
  }

  TargetState& target_state = EnsureTargetState(target_id);
  if (TargetContainsDocument(target_id, key)) {
    target_state.AddDocumentChange(key, DocumentViewChangeType::Removed);
  } else {
    // The document may have entered and left the target before we raised a
    // snapshot, so we can just ignore the change.
    target_state.RemoveDocumentChange(key);
  }
  pending_document_target_mappings_[key].insert(target_id);

  if (updated_document) {
    pending_document_updates_[key] = updated_document;
  }
}

bool WatchChangeAggregator::TargetContainsDocument(TargetId target_id,
                                                   const DocumentKey& key) {
  const DocumentKeySet& existing_keys =
      [target_metadata_provider_ remoteKeysForTarget:target_id];
  return existing_keys.contains(key);
}

bool WatchChangeAggregator::IsActiveTarget(TargetId target_id) const {
  return QueryDataForActiveTarget(target_id) != nil;
}

FSTQueryData* WatchChangeAggregator::QueryDataForActiveTarget(TargetId target_id) const {
  auto target_state = target_states_.find(target_id);
  return target_state != target_states_.end() && target_state->second.IsPending()
             ? nil
             : [target_metadata_provider_ queryDataForTarget:target_id];
}

TargetState& WatchChangeAggregator::EnsureTargetState(TargetId target_id) {
  return target_states_[target_id];
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
