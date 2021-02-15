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

#include "Firestore/core/src/api/bundle_types.h"
#include "Firestore/core/src/bundle/bundle_callback.h"
#include "Firestore/core/src/bundle/bundle_element.h"
#include "Firestore/core/src/model/document_map.h"
#include "Firestore/core/src/util/statusor.h"

namespace firebase {
namespace firestore {
namespace bundle {

class BundleLoader {
 public:
  /**
   * Adds an element from the bundle to the loader.
   *
   * @return a new progress if adding the element leads to a new progress,
   * otherwise returns `nullopt`.
   */
  util::StatusOr<LoadBundleTaskProgress> AddElement(BundleElement element,
                                                    uint64_t byte_size);

  /**
   * Applies the loaded documents and queries to local store. Returns the
   * document view changes.
   */
  model::MaybeDocumentMap ApplyChanges();

 private:
  BundleCallback callback_;
};

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_LOADER_H_
