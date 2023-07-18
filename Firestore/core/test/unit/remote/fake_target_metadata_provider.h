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

#ifndef FIRESTORE_CORE_TEST_UNIT_REMOTE_FAKE_TARGET_METADATA_PROVIDER_H_
#define FIRESTORE_CORE_TEST_UNIT_REMOTE_FAKE_TARGET_METADATA_PROVIDER_H_

#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/remote/remote_event.h"

namespace firebase {
namespace firestore {
namespace remote {

/**
 * An implementation of `TargetMetadataProvider` that provides controlled access
 * to the `TargetMetadataProvider` callbacks. Any target accessed via these
 * callbacks must be registered beforehand via the factory methods or via
 * `SetSyncedKeys`.
 */
class FakeTargetMetadataProvider : public TargetMetadataProvider {
 public:
  /**
   * Creates a `FakeTargetMetadataProvider` that behaves as if there's an
   * established listen for each of the given targets, where each target has
   * previously seen query results containing just the given `document_key`.
   *
   * Internally this means that the `GetRemoteKeysForTarget` callback for these
   * targets will return just the `document_key` and that the provided targets
   * will be returned as active from the `GetTargetDataForTarget` target.
   */
  static FakeTargetMetadataProvider CreateSingleResultProvider(
      model::DocumentKey document_key,
      const std::vector<model::TargetId>& targets);
  static FakeTargetMetadataProvider CreateSingleResultProvider(
      model::DocumentKey document_key,
      const std::vector<model::TargetId>& targets,
      const std::vector<model::TargetId>& limbo_targets);

  /**
   * Creates a `FakeTargetMetadataProvider` that behaves as if there's an
   * established listen for each of the given targets, where each target has not
   * seen any previous document.
   *
   * Internally this means that the `GetRemoteKeysForTarget` callback for these
   * targets will return an empty set of document keys and that the provided
   * targets will be returned as active from the `GetTargetDataForTarget`
   * target.
   */
  static FakeTargetMetadataProvider CreateEmptyResultProvider(
      const model::ResourcePath& path,
      const std::vector<model::TargetId>& targets);

  /** Sets or replaces the local state for the provided target data. */
  void SetSyncedKeys(model::DocumentKeySet keys, local::TargetData target_data);

  model::DocumentKeySet GetRemoteKeysForTarget(
      model::TargetId target_id) const override;
  absl::optional<local::TargetData> GetTargetDataForTarget(
      model::TargetId target_id) const override;
  const model::DatabaseId& GetDatabaseId() const override;

  /**
   * Sets the database_id to a custom value, used for getting Document's full
   * path.
   */
  void SetDatabaseId(model::DatabaseId database_id) {
    database_id_ = std::move(database_id);
  }

 private:
  std::unordered_map<model::TargetId, model::DocumentKeySet> synced_keys_;
  std::unordered_map<model::TargetId, local::TargetData> target_data_;
  model::DatabaseId database_id_ =
      model::DatabaseId("test-project", "(default)");
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_REMOTE_FAKE_TARGET_METADATA_PROVIDER_H_
