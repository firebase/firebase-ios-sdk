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

#include "Firestore/core/src/firebase/firestore/remote/grpc_completion.h"

#include <utility>

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;

GrpcCompletion::GrpcCompletion(AsyncQueue* worker_queue, Action&& action)
    : worker_queue_{worker_queue}, action_{std::move(action)} {
}

void GrpcCompletion::Cancel() {
  worker_queue_->VerifyIsCurrentQueue();

  action_ = {};
}

void GrpcCompletion::WaitUntilOffQueue() {
  worker_queue_->VerifyIsCurrentQueue();

  if (!off_queue_future_.valid()) {
    off_queue_future_ = off_queue_.get_future();
  }
  return off_queue_future_.wait();
}

std::future_status GrpcCompletion::WaitUntilOffQueue(
    std::chrono::milliseconds timeout) {
  worker_queue_->VerifyIsCurrentQueue();

  if (!off_queue_future_.valid()) {
    off_queue_future_ = off_queue_.get_future();
  }
  return off_queue_future_.wait_for(timeout);
}

void GrpcCompletion::Complete(bool ok) {
  // This mechanism allows `GrpcStream` to know when the operation is off the
  // GRPC completion queue (and thus this operation no longer requires the
  // underlying GRPC objects to be valid).
  off_queue_.set_value();

  worker_queue_->Enqueue([this, ok] {
    if (action_) {
      action_(ok, this);
    }
    delete this;
  });
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
