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

#include "Firestore/core/src/firebase/firestore/model/database_id.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/hashing.h"

namespace firebase {
namespace firestore {
namespace model {

constexpr const char* DatabaseId::kDefault;

DatabaseId::DatabaseId(std::string project_id, std::string database_id)
    : project_id_{std::move(project_id)}, database_id_{std::move(database_id)} {
  HARD_ASSERT(!project_id_.empty());
  HARD_ASSERT(!database_id_.empty());
}

util::ComparisonResult DatabaseId::CompareTo(
    const firebase::firestore::model::DatabaseId& rhs) const {
  util::ComparisonResult cmp = util::Compare(project_id_, rhs.project_id_);
  if (!util::Same(cmp)) return cmp;

  return util::Compare(database_id_, rhs.database_id_);
}

size_t DatabaseId::Hash() const {
  return util::Hash(project_id_, database_id_);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
