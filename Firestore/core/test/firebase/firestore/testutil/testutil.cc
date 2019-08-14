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

#include "Firestore/core/src/firebase/firestore/model/transform_mutation.h"
#include "Firestore/core/src/firebase/firestore/model/transform_operation.h"

namespace firebase {
namespace firestore {
namespace testutil {

using model::Document;
using model::DocumentComparator;
using model::DocumentSet;
using model::FieldMask;
using model::FieldPath;
using model::FieldTransform;
using model::FieldValue;
using model::ObjectValue;
using model::Precondition;
using model::TransformOperation;

DocumentComparator DocComparator(absl::string_view field_path) {
  return Query("docs").AddingOrderBy(OrderBy(field_path)).Comparator();
}

DocumentSet DocSet(DocumentComparator comp, std::vector<Document> docs) {
  DocumentSet set{std::move(comp)};
  for (const Document& doc : docs) {
    set = set.insert(doc);
  }
  return set;
}

model::PatchMutation PatchMutation(
    absl::string_view path,
    model::FieldValue::Map values,
    // TODO(rsgowman): Investigate changing update_mask to a set.
    std::vector<model::FieldPath> update_mask) {
  ObjectValue object_value = ObjectValue::Empty();
  std::set<FieldPath> field_mask_paths;

  for (const auto& kv : values) {
    FieldPath field_path = Field(kv.first);
    field_mask_paths.insert(field_path);

    const FieldValue& value = kv.second;
    if (!value.is_string() || value.string_value() != kDeleteSentinel) {
      object_value = object_value.Set(field_path, value);
    }
  }

  bool merge = !update_mask.empty();

  Precondition precondition =
      merge ? Precondition::None() : Precondition::Exists(true);
  FieldMask mask(
      merge ? std::set<FieldPath>(update_mask.begin(), update_mask.end())
            : field_mask_paths);

  return model::PatchMutation(Key(path), std::move(object_value),
                              std::move(mask), precondition);
}

model::TransformMutation TransformMutation(
    absl::string_view key,
    std::vector<std::pair<std::string, TransformOperation>> transforms) {
  std::vector<FieldTransform> field_transforms;

  for (auto&& pair : transforms) {
    auto path = Field(std::move(pair.first));
    TransformOperation&& op_ptr = std::move(pair.second);
    FieldTransform transform(std::move(path), std::move(op_ptr));
    field_transforms.push_back(std::move(transform));
  }

  return model::TransformMutation(Key(key), std::move(field_transforms));
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
