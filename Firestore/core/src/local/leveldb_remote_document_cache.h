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

#ifndef FIRESTORE_CORE_SRC_LOCAL_LEVELDB_REMOTE_DOCUMENT_CACHE_H_
#define FIRESTORE_CORE_SRC_LOCAL_LEVELDB_REMOTE_DOCUMENT_CACHE_H_

#include <memory>
#include <string>
#include <thread>  // NOLINT(build/c++11)
#include <vector>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/leveldb_index_manager.h"
#include "Firestore/core/src/local/remote_document_cache.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/model/overlay.h"
#include "Firestore/core/src/model/types.h"
#include "absl/strings/string_view.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {

namespace util {
class Executor;
}  // namespace util

namespace model {
class MutableDocument;
class SnapshotVersion;
}  // namespace model

namespace local {

class LevelDbPersistence;
class LocalSerializer;

/** Cached Remote Documents backed by leveldb. */
class LevelDbRemoteDocumentCache : public RemoteDocumentCache {
 public:
  LevelDbRemoteDocumentCache(LevelDbPersistence* db,
                             LocalSerializer* serializer);
  ~LevelDbRemoteDocumentCache();

  void Add(const model::MutableDocument& document,
           const model::SnapshotVersion& read_time) override;
  void Remove(const model::DocumentKey& key) override;

  model::MutableDocument Get(const model::DocumentKey& key) const override;
  model::MutableDocumentMap GetAll(
      const model::DocumentKeySet& keys) const override;
  model::MutableDocumentMap GetAll(const std::string& collection_group,
                                   const model::IndexOffset& offset,
                                   size_t limit) const override;
  model::MutableDocumentMap GetDocumentsMatchingQuery(
      const core::Query& query,
      const model::IndexOffset& offset,
      absl::optional<size_t> limit = absl::nullopt,
      const model::OverlayByDocumentKeyMap& mutated_docs = {}) const override;

  void SetIndexManager(IndexManager* manager) override;

 private:
  /**
   * Looks up a set of entries in the cache, returning only existing entries of
   * Type::Document together with its SnapshotVersion.
   */
  model::MutableDocumentMap GetAllExisting(
      model::DocumentVersionMap&& remote_map,
      const core::Query& query,
      const model::OverlayByDocumentKeyMap& mutated_docs = {}) const;

  model::MutableDocument DecodeMaybeDocument(
      absl::string_view encoded, const model::DocumentKey& key) const;

  // The LevelDbRemoteDocumentCache instance is owned by LevelDbPersistence.
  LevelDbPersistence* db_;
  // The LevelDbIndexManager instance is owned by LevelDbPersistence.
  IndexManager* index_manager_ = nullptr;
  // Owned by LevelDbPersistence.
  LocalSerializer* serializer_ = nullptr;

  std::unique_ptr<util::Executor> executor_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_LEVELDB_REMOTE_DOCUMENT_CACHE_H_
