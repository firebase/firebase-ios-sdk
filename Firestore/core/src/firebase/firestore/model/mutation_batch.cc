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

#include "Firestore/core/src/firebase/firestore/model/mutation_batch.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace model {

namespace {

/**
 * Compares two vectors of unique pointers, and ensures the Mutation contents of
 * the pointer (not just the memory address itself) is equal.
 */
bool deep_equals(const std::vector<std::unique_ptr<Mutation>>& lhs,
                 const std::vector<std::unique_ptr<Mutation>>& rhs) {
  if (lhs.size() != rhs.size()) return false;

  for (size_t i = 0; i < lhs.size(); i++) {
    if (!lhs[i] && !rhs[i])
      continue;
    else if (!lhs[i] || !rhs[i])
      return false;
    else if (*lhs[i] != *rhs[i])
      return false;
  }

  return true;
}

}  // namespace

MutationBatch::MutationBatch(int batch_id,
                             Timestamp local_write_time,
                             std::vector<std::unique_ptr<Mutation>>&& mutations)
    : batch_id_(batch_id),
      local_write_time_(std::move(local_write_time)),
      mutations_(std::move(mutations)) {
  HARD_ASSERT(!mutations_.empty(), "Cannot create an empty mutation batch");
}

bool operator==(const MutationBatch& lhs, const MutationBatch& rhs) {
  return lhs.batch_id() == rhs.batch_id() &&
         lhs.local_write_time() == rhs.local_write_time() &&
         deep_equals(lhs.mutations(), rhs.mutations());
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
