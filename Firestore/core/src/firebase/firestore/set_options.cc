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

#include "Firestore/core/include/firebase/firestore/set_options.h"

#include <algorithm>
#include <utility>
#include <vector>

namespace firebase {
namespace firestore {

SetOptions::SetOptions(Type type, std::vector<FieldPath> fields)
    : type_(type), fields_(std::move(fields)) {
}

SetOptions::~SetOptions() {
}

/* static */
SetOptions SetOptions::Merge() { return SetOptions{Type::kMergeAll, {}}; }

/* static */
SetOptions SetOptions::MergeField(const std::vector<std::string>& fields) {
  std::vector<FieldPath> field_paths;
  for (const std::string& field : fields) {
    field_paths.push_back(FieldPath::FromDotSeparatedString(field));
  }
  return SetOptions{Type::kMergeSpecific, std::move(field_paths)};
}

/* static */
SetOptions SetOptions::MergeField(const std::vector<FieldPath>& fields) {
  return SetOptions{Type::kMergeSpecific, fields};
}

}  // namespace firestore
}  // namespace firebase
