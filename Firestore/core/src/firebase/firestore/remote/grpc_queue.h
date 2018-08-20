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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_QUEUE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_QUEUE_H_

#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "grpcpp/completion_queue.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcOperation;

/**
 * An owning wrapper around `grpc::CompletionQueue` that allows checking whether
 * the queue has been shut down.
 *
 * Because `grpc::CompletionQueue` only provides polling methods, this class too
 * cannot be used to add operations to the queue.
 */
class GrpcCompletionQueue {
 public:
  ~GrpcCompletionQueue();

  // Retrieves the next completed operation; this is a blocking function.
  //
  // The caller is responsible for deallocating the returned `GrpcOperation`.
  //
  // In case a non-null operation is returned, the given `ok` pointer will be
  // updated to indicate whether the operation has finished. If a null pointer
  // is returned, `ok` will be unchanged.
  //
  // Will return a null pointer to indicate the queue has been shut down and
  // fully drained; calling `Next` after the previous call has returned a null
  // pointer is invalid.
  GrpcOperation* Next(bool* ok);

  // Initiates a shutdown of the underlying GRPC completion queue. Queue can
  // be destroyed once `Shutdown` has been called and the queue has been fully
  // drained (`Next` has returned a null pointer).
  // Calling this function mroe than once is invalid.
  void Shutdown();
  bool IsShutDown() const {
    return is_shut_down_;
  }

  // Returns the underlying GRPC object.
  grpc::CompletionQueue* queue() {
    return &queue_;
  }

 private:
  grpc::CompletionQueue queue_;
  bool is_shut_down_ = false;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_QUEUE_H_
