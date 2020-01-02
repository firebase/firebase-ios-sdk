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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_PERSISTENCE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_PERSISTENCE_H_

#include <memory>
#include <set>
#include <string>

#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_index_manager.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_lru_reference_delegate.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_mutation_queue.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_query_cache.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_remote_document_cache.h"
#include "Firestore/core/src/firebase/firestore/local/leveldb_transaction.h"
#include "Firestore/core/src/firebase/firestore/local/local_serializer.h"
#include "Firestore/core/src/firebase/firestore/local/persistence.h"
#include "Firestore/core/src/firebase/firestore/util/path.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"

namespace firebase {
namespace firestore {
namespace core {

class DatabaseInfo;

}  // namespace core

namespace local {

class LevelDbLruReferenceDelegate;
struct LruParams;

/** A LevelDB-backed implementation of the Persistence interface. */
class LevelDbPersistence : public Persistence {
 public:
  /**
   * Creates a LevelDB in the given directory and returns it or a Status object
   * containing details of the failure.
   */
  static util::StatusOr<std::unique_ptr<LevelDbPersistence>> Create(
      util::Path dir, LocalSerializer serializer, const LruParams& lru_params);

  /**
   * Finds a suitable directory to serve as the root of all Firestore local
   * storage.
   */
  static util::StatusOr<util::Path> AppDataDirectory();

  /**
   * Computes a unique storage directory for the given identifying components of
   * local storage.
   *
   * @param database_info The identifying information for the local storage
   *     instance.
   * @param documents_dir The root document directory relative to which
   *     the storage directory will be created. Usually just
   *     `LevelDbPersistence::AppDataDirectory()`.
   * @return A storage directory unique to the instance identified by
   *     `database_info`.
   */
  static util::Path StorageDirectory(const core::DatabaseInfo& database_info,
                                     const util::Path& documents_dir);

  LevelDbTransaction* current_transaction();

  leveldb::DB* ptr() {
    return db_.get();
  }

  const std::set<std::string> users() const {
    return users_;
  }

  static util::Status ClearPersistence(const core::DatabaseInfo& database_info);

  int64_t CalculateByteSize();

  // MARK: Persistence overrides

  model::ListenSequenceNumber current_sequence_number() const override;

  void Shutdown() override;

  LevelDbMutationQueue* GetMutationQueueForUser(
      const auth::User& user) override;

  LevelDbQueryCache* query_cache() override;

  LevelDbRemoteDocumentCache* remote_document_cache() override;

  LevelDbIndexManager* index_manager() override;

  LevelDbLruReferenceDelegate* reference_delegate() override;

 protected:
  void RunInternal(absl::string_view label,
                   std::function<void()> block) override;

 private:
  LevelDbPersistence(std::unique_ptr<leveldb::DB> db,
                     util::Path directory,
                     std::set<std::string> users,
                     LocalSerializer serializer,
                     const LruParams& lru_params);

  /**
   * Ensures that the given directory exists.
   */
  static util::Status EnsureDirectory(const util::Path& dir);

  /** Opens the database within the given directory. */
  static util::StatusOr<std::unique_ptr<leveldb::DB>> OpenDb(
      const util::Path& dir);

  static constexpr const char* kReservedPathComponent = "firestore";

  std::unique_ptr<leveldb::DB> db_;

  util::Path directory_;
  std::set<std::string> users_;
  LocalSerializer serializer_;
  bool started_ = false;

  std::unique_ptr<LevelDbMutationQueue> current_mutation_queue_;
  std::unique_ptr<LevelDbQueryCache> query_cache_;
  std::unique_ptr<LevelDbRemoteDocumentCache> document_cache_;
  std::unique_ptr<LevelDbIndexManager> index_manager_;
  std::unique_ptr<LevelDbLruReferenceDelegate> reference_delegate_;

  std::unique_ptr<LevelDbTransaction> transaction_;
};

/** Returns a standard set of read options. */
leveldb::ReadOptions StandardReadOptions();

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LEVELDB_PERSISTENCE_H_
