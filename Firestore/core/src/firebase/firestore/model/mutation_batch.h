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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATION_BATCH_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATION_BATCH_H_

#include <memory>
#include <vector>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * A BatchID that was searched for and not found or a batch ID value known to be
 * before all known batches.
 *
 * BatchId values from the local store are non-negative so this value is before
 * all batches.
 */
constexpr BatchId kBatchIdUnknown = -1;

// TODO(rsgowman): Port MutationBatchResult

/**
 * A batch of mutations that will be sent as one unit to the backend. Batches
 * can be marked as a tombstone if the mutation queue does not remove them
 * immediately. When a batch is a tombstone it has no mutations.
 */
class MutationBatch {
 public:
  /**
   * A batch ID that was searched for and not found or a batch ID value known to
   * be before all known batches.
   *
   * Batch ID values from the local store are non-negative so this value is
   * before all batches.
   */
  constexpr static int kUnknown = -1;

  MutationBatch(int batch_id,
                Timestamp local_write_time,
                std::vector<std::unique_ptr<Mutation>>&& mutations);

  // TODO(rsgowman): Port ApplyToRemoteDocument()
  // TODO(rsgowman): Port ApplyToLocalView()
  // TODO(rsgowman): Port GetKeys()

  int batch_id() const {
    return batch_id_;
  }

  /**
   * Returns the local time at which the mutation batch was created / written;
   * used to assign local times to server timestamps, etc.
   */
  const Timestamp& local_write_time() const {
    return local_write_time_;
  }

  const std::vector<std::unique_ptr<Mutation>>& mutations() const {
    return mutations_;
  }

 private:
  int batch_id_;
  const Timestamp local_write_time_;
  std::vector<std::unique_ptr<Mutation>> mutations_;
};

bool operator==(const MutationBatch& lhs, const MutationBatch& rhs);

inline bool operator!=(const MutationBatch& lhs, const MutationBatch& rhs) {
  return !(lhs == rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATION_BATCH_H_
