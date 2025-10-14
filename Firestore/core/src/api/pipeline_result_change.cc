/*
 * Copyright 2025 Google
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

#include "Firestore/core/src/api/pipeline_result_change.h"

#include "Firestore/core/src/util/hashing.h"

namespace firebase {
namespace firestore {
namespace api {

size_t PipelineResultChange::Hash() const {
  return util::Hash(type_, result_, old_index_, new_index_);
}

bool operator==(const PipelineResultChange& lhs,
                const PipelineResultChange& rhs) {
  return lhs.type() == rhs.type() && lhs.result() == rhs.result() &&
         lhs.old_index() == rhs.old_index() &&
         lhs.new_index() == rhs.new_index();
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
