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

#include "Firestore/core/src/firebase/firestore/remote/stream_operation.h"

#include "Firestore/core/src/firebase/firestore/remote/grpc_call.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

void StreamOperation::Execute() {
  HARD_ASSERT(SameGeneration(), "Stale stream operation");
  DoExecute(call.get());
}

void StreamOperation::Complete(const bool ok) {
  if (SameGeneration()) {
    OnCompletion(stream, ok);
  }
}

bool StreamOperation::SameGeneration() const {
  return stream_.generation() == generation_;
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
