/*
 * Copyright 2022 Google LLC
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

#include "Firestore/core/src/local/document_overlay_cache.h"

#include <utility>

#include "Firestore/core/src/immutable/sorted_set.h"
#include "Firestore/core/src/model/document_key.h"
#include "Firestore/core/src/model/overlay.h"

namespace firebase {
namespace firestore {
namespace local {

using model::DocumentKey;
using model::DocumentKeySet;
using model::Overlay;
using model::OverlayByDocumentKeyMap;

void DocumentOverlayCache::GetOverlays(OverlayByDocumentKeyMap& dest,
                                       const DocumentKeySet& keys) const {
  for (const DocumentKey& key : keys) {
    absl::optional<Overlay> overlay = GetOverlay(key);
    if (overlay.has_value()) {
      dest[key] = std::move(overlay).value();
    }
  }
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
