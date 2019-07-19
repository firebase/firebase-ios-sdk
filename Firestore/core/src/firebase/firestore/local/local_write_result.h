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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_WRITE_RESULT_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_WRITE_RESULT_H_

#include "Firestore/core/src/firebase/firestore/model/document_map.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

namespace firebase {
namespace firestore {
namespace local {

/** The result of a write to the local store. */
class LocalWriteResult {
 public:
  LocalWriteResult(model::BatchId batchID,
                            model::MaybeDocumentMap&& changes);
  model::BatchId GetBatchId();

  const model::MaybeDocumentMap& GetChanges();

 private:
  model::BatchId batchId_;

  model::MaybeDocumentMap& changes_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_MUTATION_QUEUE_H_
