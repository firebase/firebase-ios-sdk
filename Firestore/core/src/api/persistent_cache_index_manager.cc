/*
 * Copyright 2023 Google LLC
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

#include "Firestore/core/src/api/persistent_cache_index_manager.h"

#include <utility>

#include "Firestore/core/src/core/firestore_client.h"

namespace firebase {
namespace firestore {
namespace api {

PersistentCacheIndexManager::PersistentCacheIndexManager(
    std::shared_ptr<core::FirestoreClient> client)
    : client_(std::move(client)) {
}

void PersistentCacheIndexManager::EnableIndexAutoCreation() const {
  client_->SetIndexAutoCreationEnabled(true);
}

void PersistentCacheIndexManager::DisableIndexAutoCreation() const {
  client_->SetIndexAutoCreationEnabled(false);
}

void PersistentCacheIndexManager::DeleteAllFieldIndexes() const {
  client_->DeleteAllFieldIndexes();
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
