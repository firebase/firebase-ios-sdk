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

#include "Firestore/core/src/local/memory_persistence.h"

#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/local/listen_sequence.h"
#include "Firestore/core/src/local/lru_garbage_collector.h"
#include "Firestore/core/src/local/memory_document_overlay_cache.h"
#include "Firestore/core/src/local/memory_eager_reference_delegate.h"
#include "Firestore/core/src/local/memory_index_manager.h"
#include "Firestore/core/src/local/memory_lru_reference_delegate.h"
#include "Firestore/core/src/local/memory_mutation_queue.h"
#include "Firestore/core/src/local/memory_remote_document_cache.h"
#include "Firestore/core/src/local/memory_target_cache.h"
#include "Firestore/core/src/local/reference_delegate.h"
#include "Firestore/core/src/local/sizer.h"
#include "Firestore/core/src/local/target_data.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace local {

using credentials::User;
using model::ListenSequenceNumber;

std::unique_ptr<MemoryPersistence>
MemoryPersistence::WithEagerGarbageCollector() {
  std::unique_ptr<MemoryPersistence> persistence(new MemoryPersistence());
  auto delegate =
      absl::make_unique<MemoryEagerReferenceDelegate>(persistence.get());
  persistence->set_reference_delegate(std::move(delegate));
  return persistence;
}

std::unique_ptr<MemoryPersistence> MemoryPersistence::WithLruGarbageCollector(
    LruParams lru_params, std::unique_ptr<Sizer> sizer) {
  std::unique_ptr<MemoryPersistence> persistence(new MemoryPersistence());
  auto delegate = absl::make_unique<MemoryLruReferenceDelegate>(
      persistence.get(), lru_params, std::move(sizer));
  persistence->set_reference_delegate(std::move(delegate));
  return persistence;
}

MemoryPersistence::MemoryPersistence()
    : target_cache_(this),
      remote_document_cache_(this),
      overlay_migration_manager_(),
      started_(true) {
}

MemoryPersistence::~MemoryPersistence() = default;

ListenSequenceNumber MemoryPersistence::current_sequence_number() const {
  return reference_delegate_->current_sequence_number();
}

void MemoryPersistence::set_reference_delegate(
    std::unique_ptr<ReferenceDelegate> delegate) {
  reference_delegate_ = std::move(delegate);
}

void MemoryPersistence::Shutdown() {
  // No durable state to ensure is closed on shutdown.
  HARD_ASSERT(started_, "MemoryPersistence shutdown without start!");
  started_ = false;
}

MemoryMutationQueue* MemoryPersistence::GetMutationQueue(const User& user,
                                                         IndexManager*) {
  auto iter = mutation_queues_.find(user);
  if (iter == mutation_queues_.end()) {
    auto queue = absl::make_unique<MemoryMutationQueue>(this, user);
    MemoryMutationQueue* result = queue.get();

    mutation_queues_.emplace(user, std::move(queue));
    return result;
  } else {
    return iter->second.get();
  }
}

MemoryTargetCache* MemoryPersistence::target_cache() {
  return &target_cache_;
}

MemoryBundleCache* MemoryPersistence::bundle_cache() {
  return &bundle_cache_;
}

MemoryGlobalsCache* MemoryPersistence::globals_cache() {
  return &globals_cache_;
}

MemoryDocumentOverlayCache* MemoryPersistence::GetDocumentOverlayCache(
    const User& user) {
  auto iter = document_overlay_caches_.find(user);
  if (iter == document_overlay_caches_.end()) {
    auto document_overlay_cache =
        absl::make_unique<MemoryDocumentOverlayCache>();
    MemoryDocumentOverlayCache* result = document_overlay_cache.get();

    document_overlay_caches_.emplace(user, std::move(document_overlay_cache));
    return result;
  } else {
    return iter->second.get();
  }
}

OverlayMigrationManager* MemoryPersistence::GetOverlayMigrationManager(
    const credentials::User&) {
  return &overlay_migration_manager_;
}

MemoryRemoteDocumentCache* MemoryPersistence::remote_document_cache() {
  return &remote_document_cache_;
}

MemoryIndexManager* MemoryPersistence::GetIndexManager(
    const credentials::User&) {
  return &index_manager_;
}

ReferenceDelegate* MemoryPersistence::reference_delegate() {
  return reference_delegate_.get();
}

void MemoryPersistence::ReleaseOtherUserSpecificComponents(const std::string&) {
}

void MemoryPersistence::DeleteAllFieldIndexes() {
}

void MemoryPersistence::RunInternal(absl::string_view label,
                                    std::function<void()> block) {
  TransactionGuard guard(reference_delegate_.get(), label);

  block();
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
