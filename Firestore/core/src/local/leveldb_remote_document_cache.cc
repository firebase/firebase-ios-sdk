/*
 * Copyright 2018 Google LLC
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

#include "Firestore/core/src/local/leveldb_remote_document_cache.h"

#include <string>
#include <thread>
#include <utility>

#include "Firestore/Protos/nanopb/firestore/local/maybe_document.nanopb.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/leveldb_key.h"
#include "Firestore/core/src/local/leveldb_persistence.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/local/query_context.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/mutable_document.h"
#include "Firestore/core/src/model/overlay.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/util/background_queue.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/string_util.h"
#include "leveldb/db.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using core::Query;
using leveldb::Status;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentVersionMap;
using model::MutableDocument;
using model::MutableDocumentMap;
using model::ResourcePath;
using model::SnapshotVersion;
using nanopb::Message;
using nanopb::StringReader;
using util::BackgroundQueue;
using util::Executor;

/**
 * An accumulator for results produced asynchronously. This accumulates
 * values in a vector to avoid contention caused by accumulating into more
 * complex structures like immutable::SortedMap.
 */
template <typename T>
class AsyncResults {
 public:
  void Insert(T&& value) {
    std::lock_guard<std::mutex> lock(mutex_);
    values_.push_back(std::move(value));
  }

  void Insert(const T& value) {
    std::lock_guard<std::mutex> lock(mutex_);
    values_.push_back(value);
  }

  /**
   * Returns the accumulated result, moving it out of AsyncResults. The
   * AsyncResults object should not be reused.
   */
  std::vector<T> Result() {
    std::lock_guard<std::mutex> lock(mutex_);
    return std::move(values_);
  }

 private:
  std::vector<T> values_;
  std::mutex mutex_;
};

}  // namespace

LevelDbRemoteDocumentCache::LevelDbRemoteDocumentCache(
    LevelDbPersistence* db, LocalSerializer* serializer)
    : db_(db), serializer_(NOT_NULL(serializer)) {
  auto hw_concurrency = std::thread::hardware_concurrency();
  if (hw_concurrency == 0) {
    // If the standard library doesn't know, guess something reasonable.
    hw_concurrency = 4;
  }
  executor_ = Executor::CreateConcurrent("com.google.firebase.firestore.query",
                                         static_cast<int>(hw_concurrency));
}

// Out of line because of unique_ptrs to incomplete types.
LevelDbRemoteDocumentCache::~LevelDbRemoteDocumentCache() = default;

void LevelDbRemoteDocumentCache::Add(const MutableDocument& document,
                                     const SnapshotVersion& read_time) {
  const DocumentKey& key = document.key();
  const ResourcePath& path = key.path();

  std::string ldb_document_key = LevelDbRemoteDocumentKey::Key(key);
  db_->current_transaction()->Put(ldb_document_key,
                                  serializer_->EncodeMaybeDocument(document));

  std::string ldb_read_time_key = LevelDbRemoteDocumentReadTimeKey::Key(
      path.PopLast(), read_time, path.last_segment());
  db_->current_transaction()->Put(ldb_read_time_key, "");

  NOT_NULL(index_manager_);
  index_manager_->AddToCollectionParentIndex(document.key().path().PopLast());
}

void LevelDbRemoteDocumentCache::Remove(const DocumentKey& key) {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(key);
  db_->current_transaction()->Delete(ldb_key);
}

MutableDocument LevelDbRemoteDocumentCache::Get(const DocumentKey& key) const {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(key);
  std::string value;
  Status status = db_->current_transaction()->Get(ldb_key, &value);
  if (status.IsNotFound()) {
    return MutableDocument::InvalidDocument(key);
  } else if (status.ok()) {
    return DecodeMaybeDocument(value, key);
  } else {
    HARD_FAIL("Fetch document for key (%s) failed with status: %s",
              key.ToString(), status.ToString());
  }
}

MutableDocumentMap LevelDbRemoteDocumentCache::GetAll(
    const DocumentKeySet& keys) const {
  BackgroundQueue tasks(executor_.get());
  AsyncResults<std::pair<DocumentKey, MutableDocument>> results;

  LevelDbRemoteDocumentKey current_key;
  auto it = db_->current_transaction()->NewIterator();

  for (const DocumentKey& key : keys) {
    it->Seek(LevelDbRemoteDocumentKey::Key(key));
    if (!it->Valid() || !current_key.Decode(it->key()) ||
        current_key.document_key() != key) {
      results.Insert(
          std::make_pair(key, MutableDocument::InvalidDocument(key)));
    } else {
      const std::string& contents = it->value();
      tasks.Execute([this, &results, &key, contents] {
        results.Insert(std::make_pair(key, DecodeMaybeDocument(contents, key)));
      });
    }
  }

  tasks.AwaitAll();

  MutableDocumentMap map;
  for (const auto& entry : results.Result()) {
    map = map.insert(entry.first, entry.second);
  }
  return map;
}

MutableDocumentMap LevelDbRemoteDocumentCache::GetAllExisting(
    DocumentVersionMap&& remote_map,
    const core::Query& query,
    const model::OverlayByDocumentKeyMap& mutated_docs) const {
  BackgroundQueue tasks(executor_.get());
  AsyncResults<std::pair<DocumentKey, MutableDocument>> results;
  for (const auto& key_version : remote_map) {
    tasks.Execute([this, &results, &key_version, query, &mutated_docs] {
      auto document = Get(key_version.first).WithReadTime(key_version.second);
      if (document.is_found_document() &&
          // Either the document matches the given query, or it is mutated.
          (query.Matches(document) ||
           mutated_docs.find(key_version.first) != mutated_docs.end())) {
        results.Insert(std::make_pair(key_version.first, std::move(document)));
      }
    });
  }
  tasks.AwaitAll();

  MutableDocumentMap map;
  for (const auto& entry : results.Result()) {
    map = map.insert(entry.first, entry.second);
  }
  return map;
}

MutableDocumentMap LevelDbRemoteDocumentCache::GetAll(
    const std::string& collection_group,
    const model::IndexOffset& offset,
    size_t limit) const {
  HARD_ASSERT(limit > 0u, "Limit should be at least 1");
  const auto parents = index_manager_->GetCollectionParents(collection_group);
  std::vector<ResourcePath> collections;
  collections.reserve(parents.size());
  for (const auto& parent : parents) {
    collections.push_back(parent.Append(collection_group));
  }

  MutableDocumentMap result;
  for (auto path = collections.cbegin();
       path != collections.cend() && result.size() < limit; path++) {
    const auto remote_docs =
        GetDocumentsMatchingQuery(Query(*path), offset, limit - result.size());
    for (const auto& doc : remote_docs) {
      result = result.insert(doc.first, doc.second);
    }
  }
  return result;
}

MutableDocumentMap LevelDbRemoteDocumentCache::GetDocumentsMatchingQuery(
    const core::Query& query,
    const model::IndexOffset& offset,
    absl::optional<size_t> limit,
    const model::OverlayByDocumentKeyMap& mutated_docs) const {
  absl::optional<QueryContext> context;
  return GetDocumentsMatchingQuery(query, offset, context, limit, mutated_docs);
}

MutableDocumentMap LevelDbRemoteDocumentCache::GetDocumentsMatchingQuery(
    const core::Query& query,
    const model::IndexOffset& offset,
    absl::optional<QueryContext>& context,
    absl::optional<size_t> limit,
    const model::OverlayByDocumentKeyMap& mutated_docs) const {
  // Use the query path as a prefix for testing if a document matches the query.

  // Execute an index-free query and filter by read time. This is safe since
  // all document changes to queries that have a
  // last_limbo_free_snapshot_version (`since_read_time`) have a read time
  // set.
  auto path = query.path();
  std::string start_key =
      LevelDbRemoteDocumentReadTimeKey::KeyPrefix(path, offset.read_time());
  auto it = db_->current_transaction()->NewIterator();
  it->Seek(util::ImmediateSuccessor(start_key));

  DocumentVersionMap remote_map;

  LevelDbRemoteDocumentReadTimeKey current_key;
  for (; it->Valid() && current_key.Decode(it->key()) &&
         (!limit.has_value() || remote_map.size() < limit);
       it->Next()) {
    const ResourcePath& collection_path = current_key.collection_path();
    if (collection_path != path) {
      break;
    }

    const SnapshotVersion& read_time = current_key.read_time();
    if (read_time > offset.read_time()) {
      DocumentKey document_key(path.Append(current_key.document_id()));
      remote_map[document_key] = read_time;
    } else if (read_time == offset.read_time()) {
      DocumentKey document_key(path.Append(current_key.document_id()));
      if (document_key > offset.document_key()) {
        remote_map[document_key] = read_time;
      }
    }
  }

  if (context.has_value()) {
    // The next step is going to check every document in remote_map, so it will
    // go through total of remote_map.size() documents.
    context.value().IncrementDocumentReadCount(remote_map.size());
  }

  return LevelDbRemoteDocumentCache::GetAllExisting(std::move(remote_map),
                                                    query, mutated_docs);
}

MutableDocument LevelDbRemoteDocumentCache::DecodeMaybeDocument(
    absl::string_view encoded, const DocumentKey& key) const {
  StringReader reader{encoded};

  auto message = Message<firestore_client_MaybeDocument>::TryParse(&reader);
  MutableDocument maybe_document =
      serializer_->DecodeMaybeDocument(&reader, *message);

  if (!reader.ok()) {
    HARD_FAIL("MaybeDocument proto failed to parse: %s",
              reader.status().ToString());
  }
  HARD_ASSERT(maybe_document.key() == key,
              "Read document has key (%s) instead of expected key (%s).",
              maybe_document.key().ToString(), key.ToString());

  return maybe_document;
}

void LevelDbRemoteDocumentCache::SetIndexManager(IndexManager* manager) {
  index_manager_ = NOT_NULL(manager);
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
