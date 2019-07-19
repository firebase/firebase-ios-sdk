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

#include <utility>

#include "Firestore/core/src/firebase/firestore/local/local_write_result.h"

namespace firebase {
namespace firestore {
namespace local {

LocalWriteResult::LocalWriteResult(model::BatchId batchId,
                                   model::MaybeDocumentMap&& changes)
    : batchId_(batchId), changes_(std::move(changes)) {
}

model::BatchId LocalWriteResult::GetBatchId() {
  return batchId_;
}

const model::MaybeDocumentMap& LocalWriteResult::GetChanges() {
  return changes_;
}

}  // namespace local
}  // namespace firestore
}  // namespace firebase
