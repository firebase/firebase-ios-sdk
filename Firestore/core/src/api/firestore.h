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

#ifndef FIRESTORE_CORE_SRC_API_FIRESTORE_H_
#define FIRESTORE_CORE_SRC_API_FIRESTORE_H_

#include <memory>
#include <mutex>
#include <string>

#include "Firestore/core/src/api/api_fwd.h"
#include "Firestore/core/src/api/load_bundle_task.h"
#include "Firestore/core/src/api/settings.h"
#include "Firestore/core/src/core/core_fwd.h"
#include "Firestore/core/src/credentials/credentials_fwd.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/util/byte_stream.h"
#include "Firestore/core/src/util/status_fwd.h"

namespace firebase {
namespace firestore {

namespace remote {
class FirebaseMetadataProvider;
}  // namespace remote

namespace util {
class AsyncQueue;
class Executor;

struct Empty;
}  // namespace util

namespace api {

class PersistentCacheIndexManager;

extern const int kDefaultTransactionMaxAttempts;

class Firestore : public std::enable_shared_from_this<Firestore> {
 public:
  Firestore() = default;

  Firestore(model::DatabaseId database_id,
            std::string persistence_key,
            std::shared_ptr<credentials::AuthCredentialsProvider>
                auth_credentials_provider,
            std::shared_ptr<credentials::AppCheckCredentialsProvider>
                app_check_credentials_provider,
            std::shared_ptr<util::AsyncQueue> worker_queue,
            std::unique_ptr<remote::FirebaseMetadataProvider>
                firebase_metadata_provider,
            void* extension);

  ~Firestore();

  void Dispose();

  const model::DatabaseId& database_id() const {
    return database_id_;
  }

  const std::string& persistence_key() const {
    return persistence_key_;
  }

  const std::shared_ptr<core::FirestoreClient>& client();

  const std::shared_ptr<util::AsyncQueue>& worker_queue();

  void* extension() {
    return extension_;
  }

  const Settings& settings() const;
  void set_settings(const Settings& settings);

  void set_user_executor(std::unique_ptr<util::Executor> user_executor);

  std::shared_ptr<const PersistentCacheIndexManager>
  persistent_cache_index_manager();

  CollectionReference GetCollection(const std::string& collection_path);
  DocumentReference GetDocument(const std::string& document_path);
  WriteBatch GetBatch();
  core::Query GetCollectionGroup(std::string collection_id);

  // The default value for `max_attempts` is `kDefaultTransactionMaxAttempts`.
  void RunTransaction(core::TransactionUpdateCallback update_callback,
                      core::TransactionResultCallback result_callback,
                      int max_attempts);

  void Terminate(util::StatusCallback callback);
  void ClearPersistence(util::StatusCallback callback);
  void WaitForPendingWrites(util::StatusCallback callback);
  std::unique_ptr<ListenerRegistration> AddSnapshotsInSyncListener(
      std::unique_ptr<core::EventListener<util::Empty>> listener);

  void EnableNetwork(util::StatusCallback callback);
  void DisableNetwork(util::StatusCallback callback);

  void SetIndexConfiguration(const std::string& config,
                             const util::StatusCallback& callback);

  std::shared_ptr<api::LoadBundleTask> LoadBundle(
      std::unique_ptr<util::ByteStream> bundle_data);
  void GetNamedQuery(const std::string& name, api::QueryCallback callback);

  /**
   * Sets the language of the public API in the format of
   * "gl-<language>/<version>" where version might be blank, e.g. `gl-objc/`.
   */
  static void SetClientLanguage(std::string language_token);

 private:
  void EnsureClientConfigured();
  core::DatabaseInfo MakeDatabaseInfo() const;

  model::DatabaseId database_id_;
  std::shared_ptr<credentials::AppCheckCredentialsProvider>
      app_check_credentials_provider_;
  std::shared_ptr<credentials::AuthCredentialsProvider>
      auth_credentials_provider_;
  std::string persistence_key_;

  std::shared_ptr<const PersistentCacheIndexManager>
      persistent_cache_index_manager_;

  std::shared_ptr<util::Executor> user_executor_;
  std::shared_ptr<util::AsyncQueue> worker_queue_;

  std::unique_ptr<remote::FirebaseMetadataProvider> firebase_metadata_provider_;

  void* extension_ = nullptr;

  Settings settings_;

  mutable std::mutex mutex_;

  std::shared_ptr<core::FirestoreClient> client_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_FIRESTORE_H_
