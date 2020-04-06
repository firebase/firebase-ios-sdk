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

#include "Firestore/core/src/firebase/firestore/local/leveldb_remote_document_cache.h"

#include <string>
#include <thread>  // NOLINT(build/c++11)
#include <utility>

#include "Firestore/Protos/nanopb/firestore/local/maybe_document.nanopb.h"
#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_key.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_persistence.h"
#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"
#include "Firestore/core/src/firebase/firestore/model/document_key_set.h"
#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/nanopb/message.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/util/background_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/string_util.h"
#include "leveldb/db.h"

namespace firebase {
namespace firestore {
namespace local {
namespace {

using core::Query;
using leveldb::Status;
using model::Document;
using model::DocumentKey;
using model::DocumentKeySet;
using model::DocumentMap;
using model::MaybeDocument;
using model::MaybeDocumentMap;
using model::OptionalMaybeDocumentMap;
using model::ResourcePath;
using model::SnapshotVersion;
using nanopb::ByteString;
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

void LevelDbRemoteDocumentCache::Add(const MaybeDocument& document,
                                     const SnapshotVersion& read_time) {
  const DocumentKey& key = document.key();
  const ResourcePath& path = key.path();

  std::string ldb_document_key = LevelDbRemoteDocumentKey::Key(key);
  db_->current_transaction()->Put(ldb_document_key,
                                  serializer_->EncodeMaybeDocument(document));

  std::string ldb_read_time_key = LevelDbRemoteDocumentReadTimeKey::Key(
      path.PopLast(), read_time, path.last_segment());
  db_->current_transaction()->Put(ldb_read_time_key, "");

  db_->index_manager()->AddToCollectionParentIndex(
      document.key().path().PopLast());
}

void LevelDbRemoteDocumentCache::Remove(const DocumentKey& key) {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(key);
  db_->current_transaction()->Delete(ldb_key);
}

absl::optional<MaybeDocument> LevelDbRemoteDocumentCache::Get(
    const DocumentKey& key) {
  std::string ldb_key = LevelDbRemoteDocumentKey::Key(key);
  std::string value;
  Status status = db_->current_transaction()->Get(ldb_key, &value);
  if (status.IsNotFound()) {
    return absl::nullopt;
  } else if (status.ok()) {
    return DecodeMaybeDocument(value, key);
  } else {
    HARD_FAIL("Fetch document for key (%s) failed with status: %s",
              key.ToString(), status.ToString());
  }
}

OptionalMaybeDocumentMap LevelDbRemoteDocumentCache::GetAll(
    const DocumentKeySet& keys) {
  BackgroundQueue tasks(executor_.get());
  AsyncResults<std::pair<DocumentKey, absl::optional<MaybeDocument>>> results;

  LevelDbRemoteDocumentKey current_key;
  auto it = db_->current_transaction()->NewIterator();

  for (const DocumentKey& key : keys) {
    it->Seek(LevelDbRemoteDocumentKey::Key(key));
    if (!it->Valid() || !current_key.Decode(it->key()) ||
        current_key.document_key() != key) {
      results.Insert(std::make_pair(key, absl::nullopt));
    } else {
      const std::string& contents = it->value();
      tasks.Execute([this, &results, &key, contents] {
        results.Insert(std::make_pair(key, DecodeMaybeDocument(contents, key)));
      });
    }
  }

  tasks.AwaitAll();

  OptionalMaybeDocumentMap map;
  for (const auto& entry : results.Result()) {
    map = map.insert(entry.first, entry.second);
  }
  return map;
}

DocumentMap LevelDbRemoteDocumentCache::GetAllExisting(
    const DocumentKeySet& keys) {
  DocumentMap results;

  OptionalMaybeDocumentMap docs = LevelDbRemoteDocumentCache::GetAll(keys);
  for (const auto& kv : docs) {
    const DocumentKey& key = kv.first;
    const auto& maybe_doc = kv.second;
    if (maybe_doc && maybe_doc->is_document()) {
      results = results.insert(key, Document(*maybe_doc));
    }
  }

  return results;
}

DocumentMap LevelDbRemoteDocumentCache::GetMatching(
    const Query& query, const SnapshotVersion& since_read_time) {
  HARD_ASSERT(
      !query.IsCollectionGroupQuery(),
      "CollectionGroup queries should be handled in LocalDocumentsView");

  // Use the query path as a prefix for testing if a document matches the query.
  const ResourcePath& query_path = query.path();
  size_t immediate_children_path_length = query_path.size() + 1;

  if (since_read_time != SnapshotVersion::None()) {
    // Execute an index-free query and filter by read time. This is safe since
    // all document changes to queries that have a
    // last_limbo_free_snapshot_version (`since_read_time`) have a read time
    // set.
    std::string start_key = LevelDbRemoteDocumentReadTimeKey::KeyPrefix(
        query_path, since_read_time);
    auto it = db_->current_transaction()->NewIterator();
    it->Seek(util::ImmediateSuccessor(start_key));

    DocumentKeySet remote_keys;

    LevelDbRemoteDocumentReadTimeKey current_key;
    for (; it->Valid() && current_key.Decode(it->key()); it->Next()) {
      const ResourcePath& collection_path = current_key.collection_path();
      if (collection_path != query_path) {
        break;
      }

      const SnapshotVersion& read_time = current_key.read_time();
      if (read_time > since_read_time) {
        DocumentKey document_key(query_path.Append(current_key.document_id()));
        remote_keys = remote_keys.insert(document_key);
      }
    }

    return LevelDbRemoteDocumentCache::GetAllExisting(remote_keys);
  } else {
    BackgroundQueue tasks(executor_.get());
    AsyncResults<Document> results;

    // Documents are ordered by key, so we can use a prefix scan to narrow down
    // the documents we need to match the query against.
    std::string start_key = LevelDbRemoteDocumentKey::KeyPrefix(query_path);
    auto it = db_->current_transaction()->NewIterator();
    it->Seek(start_key);

    LevelDbRemoteDocumentKey current_key;
    for (; it->Valid() && current_key.Decode(it->key()); it->Next()) {
      // The query is actually returning any path that starts with the query
      // path prefix which may include documents in subcollections. For example,
      // a query on 'rooms' will return rooms/abc/messages/xyx but we shouldn't
      // match it. Fix this by discarding rows with document keys more than one
      // segment longer than the query path.
      const DocumentKey& document_key = current_key.document_key();
      if (document_key.path().size() != immediate_children_path_length) {
        continue;
      }

      if (!query_path.IsPrefixOf(document_key.path())) {
        break;
      }

      const std::string& contents = it->value();
      tasks.Execute([this, &results, document_key, contents] {
        MaybeDocument maybe_doc = DecodeMaybeDocument(contents, document_key);
        if (maybe_doc.is_document()) {
          results.Insert(Document(maybe_doc));
        }
      });
    }

    tasks.AwaitAll();

    DocumentMap map;
    for (const Document& doc : results.Result()) {
      map = map.insert(doc.key(), doc);
    }
    return map;
  }
}

MaybeDocument LevelDbRemoteDocumentCache::DecodeMaybeDocument(
    absl::string_view encoded, const DocumentKey& key) {
  StringReader reader{encoded};

  auto message = Message<firestore_client_MaybeDocument>::TryParse(&reader);
  MaybeDocument maybe_document =
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

}  // namespace local
}  // namespace firestore
}  // namespace firebase
