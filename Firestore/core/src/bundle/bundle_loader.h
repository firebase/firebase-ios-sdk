/*
 * Copyright 2021 Google LLC
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
#ifndef FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_LOADER_H_
#define FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_LOADER_H_

#include <memory>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/load_bundle_task.h"
#include "Firestore/core/src/bundle/bundle_callback.h"
#include "Firestore/core/src/bundle/bundle_element.h"
#include "Firestore/core/src/bundle/bundled_document_metadata.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/document_map.h"
#include "Firestore/core/src/util/statusor.h"

namespace firebase {
namespace firestore {
namespace bundle {

using AddElementResult =
    util::StatusOr<absl::optional<api::LoadBundleTaskProgress>>;

inline api::LoadBundleTaskProgress SuccessProgress(
    const bundle::BundleMetadata metadata) {
  return {metadata.total_documents(), metadata.total_documents(),
          metadata.total_bytes(), metadata.total_bytes(),
          api::LoadBundleTaskState::Success};
}

inline api::LoadBundleTaskProgress InitialProgress(
    const bundle::BundleMetadata metadata) {
  return {0, metadata.total_documents(), 0, metadata.total_bytes(),
          api::LoadBundleTaskState::InProgress};
}

class BundleLoader {
 public:
  BundleLoader(BundleCallback* callback, BundleMetadata metadata)
      : callback_(callback), metadata_(std::move(metadata)) {
  }

  /**
   * Adds an element from the bundle to the loader.
   *
   * @return a new progress if adding the element leads to a new progress,
   * otherwise returns `nullopt`. If an error occurred, returns a not `ok()`
   * status.
   */
  AddElementResult AddElement(std::unique_ptr<BundleElement> element,
                              uint64_t byte_size);

  /**
   * Applies the loaded documents and queries to local store. Returns the
   * document view changes. If an error occurred, returns a not `ok()` status.
   */
  util::StatusOr<model::MaybeDocumentMap> ApplyChanges();

 private:
  /**
   * @return A map whose keys are the query names in the loading bundle, and
   * values are matching document keys.
   */
  std::unordered_map<std::string, model::DocumentKeySet>
  GetQueryDocumentMapping();

  BundleCallback* callback_ = nullptr;
  BundleMetadata metadata_;
  std::vector<NamedQuery> queries_;
  std::unordered_map<model::DocumentKey,
                     BundledDocumentMetadata,
                     model::DocumentKeyHash>
      documents_metadata_;
  model::MaybeDocumentMap documents_;

  uint64_t bytes_loaded_ = 0;
  absl::optional<model::DocumentKey> current_document_;
};

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_LOADER_H_
