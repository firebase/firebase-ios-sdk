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

#include <ostream>
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/to_string.h"

namespace firebase {
namespace firestore {
namespace model {

MutationBatch::MutationBatch(int batch_id,
                             Timestamp local_write_time,
                             std::vector<Mutation>&& mutations)
    : batch_id_(batch_id),
      local_write_time_(std::move(local_write_time)),
      mutations_(std::move(mutations)) {
  HARD_ASSERT(!mutations_.empty(), "Cannot create an empty mutation batch");
}

bool operator==(const MutationBatch& lhs, const MutationBatch& rhs) {
  return lhs.batch_id() == rhs.batch_id() &&
         lhs.local_write_time() == rhs.local_write_time() &&
         lhs.mutations() == rhs.mutations();
}

std::ostream& operator<<(std::ostream& os, const MutationBatch& batch) {
  return os << "MutationBatch(id=" << batch.batch_id_
            << ", local_write_time=" << batch.local_write_time_
            << ", mutations=" << util::ToString(batch.mutations_) << ")";
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
