/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/local/memory_remote_document_cache.h"

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/memory_lru_reference_delegate.h"
#include "Firestore/core/src/local/memory_persistence.h"
#include "Firestore/core/src/local/query_context.h"
#include "Firestore/core/src/local/sizer.h"
#include "Firestore/core/src/model/document.h"
#include "Firestore/core/src/model/overlay.h"
#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace local {

using core::Query;
using model::Document;
using model::DocumentKey;
using model::DocumentKeySet;
using model::ListenSequenceNumber;
using model::MutableDocument;
using model::MutableDocumentMap;
using model::SnapshotVersion;

MemoryRemoteDocumentCache::MemoryRemoteDocumentCache(
    MemoryPersistence* persistence) {
  persistence_ = persistence;
}

void MemoryRemoteDocumentCache::Add(const MutableDocument& document,
                                    const model::SnapshotVersion& read_time) {
  // Note: We create an explicit copy to prevent further modifications.
  docs_ =
      docs_.insert(document.key(), document.Clone().WithReadTime(read_time));

  NOT_NULL(index_manager_);
  index_manager_->AddToCollectionParentIndex(document.key().path().PopLast());
}

void MemoryRemoteDocumentCache::Remove(const DocumentKey& key) {
  docs_ = docs_.erase(key);
}

MutableDocument MemoryRemoteDocumentCache::Get(const DocumentKey& key) const {
  const auto& entry = docs_.get(key);
  // Note: We create an explicit copy to prevent modifications of the backing
  // data.
  return entry ? entry->Clone() : MutableDocument::InvalidDocument(key);
}

MutableDocumentMap MemoryRemoteDocumentCache::GetAll(
    const DocumentKeySet& keys) const {
  MutableDocumentMap results;
  for (const DocumentKey& key : keys) {
    // Make sure each key has a corresponding entry, which is nullopt in case
    // the document is not found.
    // TODO(http://b/32275378): Don't conflate missing / deleted.
    results = results.insert(key, Get(key));
  }
  return results;
}

// This method should only be called from the IndexBackfiller if LevelDB is
// enabled.
MutableDocumentMap MemoryRemoteDocumentCache::GetAll(const std::string&,
                                                     const model::IndexOffset&,
                                                     size_t) const {
  util::ThrowInvalidArgument(
      "getAll(String, IndexOffset, int) is not supported.");
}

MutableDocumentMap MemoryRemoteDocumentCache::GetDocumentsMatchingQuery(
    const core::Query& query,
    const model::IndexOffset& offset,
    absl::optional<size_t> limit,
    const model::OverlayByDocumentKeyMap& mutated_docs) const {
  absl::optional<QueryContext> context;
  return GetDocumentsMatchingQuery(query, offset, context, limit, mutated_docs);
}

MutableDocumentMap MemoryRemoteDocumentCache::GetDocumentsMatchingQuery(
    const core::Query& query,
    const model::IndexOffset& offset,
    absl::optional<QueryContext>&,
    absl::optional<size_t>,
    const model::OverlayByDocumentKeyMap& mutated_docs) const {
  MutableDocumentMap results;

  // Documents are ordered by key, so we can use a prefix scan to narrow down
  // the documents we need to match the query against.
  auto path = query.path();
  DocumentKey prefix{path.Append("")};
  size_t immediate_children_path_length = path.size() + 1;
  for (auto it = docs_.lower_bound(prefix); it != docs_.end(); ++it) {
    const DocumentKey& key = it->first;
    if (!path.IsPrefixOf(key.path())) {
      break;
    }
    const MutableDocument& document = it->second;
    if (key.path().size() > immediate_children_path_length) {
      // Exclude entries from subcollections.
      continue;
    }

    if (model::IndexOffset::FromDocument(document).CompareTo(offset) !=
        util::ComparisonResult::Descending) {
      // The document sorts before the offset.
      continue;
    }

    if (mutated_docs.find(document.key()) == mutated_docs.end() &&
        !query.Matches(document)) {
      continue;
    }

    // Note: We create an explicit copy to prevent modifications on the backing
    // data.
    results = results.insert(key, document.Clone());
  }
  return results;
}

std::vector<DocumentKey> MemoryRemoteDocumentCache::RemoveOrphanedDocuments(
    MemoryLruReferenceDelegate* reference_delegate,
    ListenSequenceNumber upper_bound) {
  std::vector<DocumentKey> removed;
  auto updated_docs = docs_;
  for (const auto& kv : docs_) {
    const DocumentKey& key = kv.first;
    if (!reference_delegate->IsPinnedAtSequenceNumber(upper_bound, key)) {
      updated_docs = updated_docs.erase(key);
      removed.push_back(key);
    }
  }
  docs_ = updated_docs;
  return removed;
}

int64_t MemoryRemoteDocumentCache::CalculateByteSize(const Sizer& sizer) {
  int64_t count = 0;
  for (const auto& kv : docs_) {
    const MutableDocument& document = kv.second;
    count += sizer.CalculateByteSize(document);
  }
  return count;
}

void MemoryRemoteDocumentCache::SetIndexManager(IndexManager* manager) {
  index_manager_ = NOT_NULL(manager);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
