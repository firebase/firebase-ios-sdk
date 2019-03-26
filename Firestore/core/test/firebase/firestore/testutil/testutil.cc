/*
 * Copyright 2018 Google
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

#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"

#include <set>

namespace firebase {
namespace firestore {
namespace testutil {

std::unique_ptr<model::PatchMutation> PatchMutation(
    absl::string_view path,
    const model::FieldValue::Map& values,
    // TODO(rsgowman): Investigate changing update_mask to a set.
    const std::vector<model::FieldPath>* update_mask) {
  model::ObjectValue object_value = model::ObjectValue::Empty();
  std::set<model::FieldPath> object_mask;

  for (const auto& kv : values) {
    model::FieldPath field_path = Field(kv.first);
    object_mask.insert(field_path);
    // TODO(rsgowman): This will abort if kv.second.string_value.type() !=
    // String
    if (kv.second.string_value() != kDeleteSentinel) {
      object_value = object_value.Set(field_path, kv.second);
    }
  }

  bool merge = update_mask != nullptr;

  if (merge) {
    return absl::make_unique<model::PatchMutation>(
        Key(path), std::move(object_value),
        model::FieldMask(update_mask->begin(), update_mask->end()),
        model::Precondition::None());
  } else {
    return absl::make_unique<model::PatchMutation>(
        Key(path), std::move(object_value), model::FieldMask(object_mask),
        model::Precondition::Exists(true));
  }
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
