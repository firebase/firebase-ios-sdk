// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <algorithm>
#include <unordered_set>
#include <utility>

#include "Firestore/core/src/local/index_backfiller.h"
#include "Firestore/core/src/local/index_manager.h"
#include "Firestore/core/src/local/local_documents_view.h"
#include "Firestore/core/src/local/local_store.h"
#include "Firestore/core/src/local/local_write_result.h"
#include "Firestore/core/src/local/persistence.h"
#include "Firestore/core/src/model/field_index.h"
#include "Firestore/core/src/util/log.h"

namespace firebase {
namespace firestore {
namespace local {

namespace {

using model::IndexOffset;

/**
 * The maximum number of documents to process each time Backfill() is called.
 */
static const int kMaxDocumentsToProcess = 50;

}  // namespace

IndexBackfiller::IndexBackfiller() {
  max_documents_to_process_ = kMaxDocumentsToProcess;
}

int IndexBackfiller::WriteIndexEntries(const LocalStore* local_store) {
  IndexManager* index_manager = local_store->index_manager();
  std::unordered_set<std::string> processed_collection_groups;
  int documents_remaining = max_documents_to_process_;
  while (documents_remaining > 0) {
    const auto collection_group =
        index_manager->GetNextCollectionGroupToUpdate();
    if (!collection_group ||
        (processed_collection_groups.find(collection_group.value()) !=
         processed_collection_groups.end())) {
      break;
    }
    LOG_DEBUG("Processing collection: %s", collection_group.value());
    documents_remaining -= WriteEntriesForCollectionGroup(
        local_store, collection_group.value(), documents_remaining);
    processed_collection_groups.insert(collection_group.value());
  }
  return max_documents_to_process_ - documents_remaining;
}

int IndexBackfiller::WriteEntriesForCollectionGroup(
    const LocalStore* local_store,
    const std::string& collection_group,
    int documents_remaining_under_cap) const {
  IndexManager* index_manager = local_store->index_manager();
  const auto local_documents_view = local_store->local_documents();

  // Use the earliest offset of all field indexes to query the local cache.
  const auto existing_offset = index_manager->GetMinOffset(collection_group);
  const auto next_batch = local_documents_view->GetNextDocuments(
      collection_group, existing_offset, documents_remaining_under_cap);
  index_manager->UpdateIndexEntries(next_batch.changes());

  const auto new_offset = GetNewOffset(existing_offset, next_batch);
  LOG_DEBUG("Updating offset: %s", new_offset.ToString());
  index_manager->UpdateCollectionGroup(collection_group, new_offset);

  return next_batch.changes().size();
}

model::IndexOffset IndexBackfiller::GetNewOffset(
    const IndexOffset& existing_offset,
    const LocalWriteResult& lookup_result) const {
  auto max_offset = existing_offset;
  for (const auto& entry : lookup_result.changes()) {
    auto new_offset = IndexOffset::FromDocument(entry.second);
    if (new_offset.CompareTo(max_offset) ==
        util::ComparisonResult::Descending) {
      max_offset = std::move(new_offset);
    }
  }
  return IndexOffset(
      max_offset.read_time(), max_offset.document_key(),
      std::max(lookup_result.batch_id(), existing_offset.largest_batch_id()));
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
