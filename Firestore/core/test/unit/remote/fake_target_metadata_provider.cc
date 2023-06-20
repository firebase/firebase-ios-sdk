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

#include "Firestore/core/test/unit/remote/fake_target_metadata_provider.h"

#include <utility>

#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_key_set.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/types.h"

namespace firebase {
namespace firestore {
namespace remote {

using local::QueryPurpose;
using local::TargetData;
using model::DocumentKey;
using model::DocumentKeySet;
using model::ResourcePath;
using model::TargetId;

FakeTargetMetadataProvider
FakeTargetMetadataProvider::CreateSingleResultProvider(
    DocumentKey document_key,
    const std::vector<TargetId>& listen_targets,
    const std::vector<TargetId>& limbo_targets) {
  FakeTargetMetadataProvider metadata_provider;
  core::Query query(document_key.path());

  for (TargetId target_id : listen_targets) {
    TargetData target_data(query.ToTarget(), target_id, 0,
                           QueryPurpose::Listen);
    metadata_provider.SetSyncedKeys(DocumentKeySet{document_key}, target_data);
  }
  for (TargetId target_id : limbo_targets) {
    TargetData target_data(query.ToTarget(), target_id, 0,
                           QueryPurpose::LimboResolution);
    metadata_provider.SetSyncedKeys(DocumentKeySet{document_key}, target_data);
  }

  return metadata_provider;
}

FakeTargetMetadataProvider
FakeTargetMetadataProvider::CreateSingleResultProvider(
    DocumentKey document_key, const std::vector<TargetId>& targets) {
  return CreateSingleResultProvider(document_key, targets,
                                    /*limbo_targets=*/{});
}

FakeTargetMetadataProvider
FakeTargetMetadataProvider::CreateEmptyResultProvider(
    const ResourcePath& path, const std::vector<TargetId>& targets) {
  FakeTargetMetadataProvider metadata_provider;
  core::Query query(path);

  for (TargetId target_id : targets) {
    TargetData target_data(query.ToTarget(), target_id, 0,
                           QueryPurpose::Listen);
    metadata_provider.SetSyncedKeys(DocumentKeySet{}, target_data);
  }

  return metadata_provider;
}

void FakeTargetMetadataProvider::SetSyncedKeys(DocumentKeySet keys,
                                               TargetData target_data) {
  synced_keys_[target_data.target_id()] = keys;
  target_data_[target_data.target_id()] = std::move(target_data);
}

DocumentKeySet FakeTargetMetadataProvider::GetRemoteKeysForTarget(
    TargetId target_id) const {
  auto it = synced_keys_.find(target_id);
  HARD_ASSERT(it != synced_keys_.end(), "Cannot process unknown target %s",
              target_id);
  return it->second;
}

absl::optional<TargetData> FakeTargetMetadataProvider::GetTargetDataForTarget(
    TargetId target_id) const {
  auto it = target_data_.find(target_id);
  HARD_ASSERT(it != target_data_.end(), "Cannot process unknown target %s",
              target_id);
  return it->second;
}

const model::DatabaseId& FakeTargetMetadataProvider::GetDatabaseId() const {
  return database_id_;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
