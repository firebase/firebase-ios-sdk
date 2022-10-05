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

#include "Firestore/core/test/unit/local/counting_query_engine.h"

#include "Firestore/core/src/local/local_documents_view.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/mutation_batch.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::DocumentKeySet;
using model::DocumentMap;
using model::MutationByDocumentKeyMap;
using model::OverlayByDocumentKeyMap;
using model::SnapshotVersion;

// MARK: - CountingQueryEngine

CountingQueryEngine::CountingQueryEngine() = default;
CountingQueryEngine::~CountingQueryEngine() = default;

void CountingQueryEngine::Initialize(LocalDocumentsView* local_documents) {
  remote_documents_ = absl::make_unique<WrappedRemoteDocumentCache>(
      local_documents->remote_document_cache(), this);
  mutation_queue_ = absl::make_unique<WrappedMutationQueue>(
      local_documents->mutation_queue(), this);
  document_overlay_cache_ = absl::make_unique<WrappedDocumentOverlayCache>(
      local_documents->document_overlay_cache(), this);
  local_documents_ = absl::make_unique<LocalDocumentsView>(
      remote_documents_.get(), mutation_queue_.get(),
      document_overlay_cache_.get(), local_documents->index_manager());
  QueryEngine::Initialize(local_documents_.get());
}

void CountingQueryEngine::ResetCounts() {
  mutations_read_by_query_ = 0;
  mutations_read_by_key_ = 0;
  documents_read_by_query_ = 0;
  documents_read_by_key_ = 0;
  overlays_read_by_key_ = 0;
  overlays_read_by_collection_ = 0;
  overlays_read_by_collection_group_ = 0;
}

// MARK: - WrappedMutationQueue

void WrappedMutationQueue::Start() {
  subject_->Start();
}

bool WrappedMutationQueue::IsEmpty() {
  return subject_->IsEmpty();
}

void WrappedMutationQueue::AcknowledgeBatch(
    const model::MutationBatch& batch, const nanopb::ByteString& stream_token) {
  subject_->AcknowledgeBatch(batch, stream_token);
}

model::MutationBatch WrappedMutationQueue::AddMutationBatch(
    const Timestamp& local_write_time,
    std::vector<model::Mutation>&& base_mutations,
    std::vector<model::Mutation>&& mutations) {
  return subject_->AddMutationBatch(local_write_time, std::move(base_mutations),
                                    std::move(mutations));
}

void WrappedMutationQueue::RemoveMutationBatch(
    const model::MutationBatch& batch) {
  subject_->RemoveMutationBatch(batch);
}

std::vector<model::MutationBatch> WrappedMutationQueue::AllMutationBatches() {
  auto result = subject_->AllMutationBatches();
  query_engine_->mutations_read_by_key_ += result.size();
  return result;
}

std::vector<model::MutationBatch>
WrappedMutationQueue::AllMutationBatchesAffectingDocumentKeys(
    const model::DocumentKeySet& document_keys) {
  auto result =
      subject_->AllMutationBatchesAffectingDocumentKeys(document_keys);
  query_engine_->mutations_read_by_key_ += result.size();
  return result;
}

std::vector<model::MutationBatch>
WrappedMutationQueue::AllMutationBatchesAffectingDocumentKey(
    const model::DocumentKey& key) {
  auto result = subject_->AllMutationBatchesAffectingDocumentKey(key);
  query_engine_->mutations_read_by_key_ += result.size();
  return result;
}

std::vector<model::MutationBatch>
WrappedMutationQueue::AllMutationBatchesAffectingQuery(
    const core::Query& query) {
  auto result = subject_->AllMutationBatchesAffectingQuery(query);
  query_engine_->mutations_read_by_query_ += result.size();
  return result;
}

absl::optional<model::MutationBatch> WrappedMutationQueue::LookupMutationBatch(
    model::BatchId batch_id) {
  return subject_->LookupMutationBatch(batch_id);
}

absl::optional<model::MutationBatch>
WrappedMutationQueue::NextMutationBatchAfterBatchId(model::BatchId batch_id) {
  return subject_->LookupMutationBatch(batch_id);
}

model::BatchId WrappedMutationQueue::GetHighestUnacknowledgedBatchId() {
  return subject_->GetHighestUnacknowledgedBatchId();
}

void WrappedMutationQueue::PerformConsistencyCheck() {
  subject_->PerformConsistencyCheck();
}

nanopb::ByteString WrappedMutationQueue::GetLastStreamToken() {
  return subject_->GetLastStreamToken();
}

void WrappedMutationQueue::SetLastStreamToken(nanopb::ByteString stream_token) {
  subject_->SetLastStreamToken(stream_token);
}

// MARK: - WrappedRemoteDocumentCache

void WrappedRemoteDocumentCache::Add(const model::MutableDocument& document,
                                     const model::SnapshotVersion& read_time) {
  subject_->Add(document, read_time);
}

void WrappedRemoteDocumentCache::Remove(const model::DocumentKey& key) {
  subject_->Remove(key);
}

model::MutableDocument WrappedRemoteDocumentCache::Get(
    const model::DocumentKey& key) const {
  auto result = subject_->Get(key);
  query_engine_->documents_read_by_key_ += result.is_found_document() ? 1 : 0;
  return result;
}

model::MutableDocumentMap WrappedRemoteDocumentCache::GetAll(
    const model::DocumentKeySet& keys) const {
  auto result = subject_->GetAll(keys);
  for (const auto& key_doc : result) {
    query_engine_->documents_read_by_key_ +=
        key_doc.second.is_found_document() ? 1 : 0;
  }
  return result;
}

model::MutableDocumentMap WrappedRemoteDocumentCache::GetAll(
    const std::string& collection_group,
    const model::IndexOffset& offset,
    size_t limit) const {
  auto result = subject_->GetAll(collection_group, offset, limit);
  query_engine_->documents_read_by_query_ += result.size();
  return result;
}

model::MutableDocumentMap WrappedRemoteDocumentCache::GetAll(
    const model::ResourcePath& path,
    const model::IndexOffset& offset,
    absl::optional<size_t>) const {
  auto result = subject_->GetAll(path, offset);
  query_engine_->documents_read_by_query_ += result.size();
  return result;
}

// MARK: - WrappedDocumentOverlayCache

absl::optional<model::Overlay> WrappedDocumentOverlayCache::GetOverlay(
    const model::DocumentKey& key) const {
  ++query_engine_->overlays_read_by_key_;
  return subject_->GetOverlay(key);
}

void WrappedDocumentOverlayCache::SaveOverlays(
    int largest_batch_id, const MutationByDocumentKeyMap& overlays) {
  subject_->SaveOverlays(largest_batch_id, overlays);
}

void WrappedDocumentOverlayCache::RemoveOverlaysForBatchId(int batch_id) {
  subject_->RemoveOverlaysForBatchId(batch_id);
}

OverlayByDocumentKeyMap WrappedDocumentOverlayCache::GetOverlays(
    const model::ResourcePath& collection, int since_batch_id) const {
  auto result = subject_->GetOverlays(collection, since_batch_id);
  query_engine_->overlays_read_by_collection_ += result.size();
  return result;
}

OverlayByDocumentKeyMap WrappedDocumentOverlayCache::GetOverlays(
    absl::string_view collection_group,
    int since_batch_id,
    std::size_t count) const {
  auto result = subject_->GetOverlays(collection_group, since_batch_id, count);
  query_engine_->overlays_read_by_collection_group_ += result.size();
  return result;
}

int WrappedDocumentOverlayCache::GetOverlayCount() const {
  HARD_FAIL("WrappedDocumentOverlayCache::GetOverlayCount() not implemented");
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
