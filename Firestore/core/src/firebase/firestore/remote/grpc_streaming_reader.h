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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAMING_READER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAMING_READER_H_

#include <functional>
#include <map>
#include <memory>
#include <vector>

#include "Firestore/core/src/firebase/firestore/remote/grpc_completion.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "grpcpp/client_context.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {
namespace remote {

/**
 * Sends a single request to the server, reads one or more streaming server
 * responses, and invokes the given callback with the accumulated responses.
 */
class GrpcStreamingReader {
 public:
  using MetadataT = std::multimap<grpc::string_ref, grpc::string_ref>;
  /**
   * The first argument is status of the call; the second argument is a vector
   * of accumulated server responses.
   */
  using CallbackT = std::function<void(const util::Status&,
                                       const std::vector<grpc::ByteBuffer>&)>;

  GrpcStreamingReader(
      std::unique_ptr<grpc::ClientContext> context,
      std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
      util::AsyncQueue* worker_queue,
      const grpc::ByteBuffer& request);
  ~GrpcStreamingReader();

  /**
   * Starts the call; the given `callback` will be invoked with the accumulated
   * results of the call. If the call fails, the `callback` will be invoked with
   * a non-ok status.
   */
  void Start(CallbackT&& callback);

  /**
   * If the call is in progress, attempts to cancel the call; otherwise, it's
   * a no-op. Cancellation is done on best-effort basis; however:
   * - the call is guaranteed to be finished when this function returns;
   * - this function is blocking but should finish very fast (order of
   *   milliseconds).
   *
   * If this function succeeds in cancelling the call, the callback will not be
   * invoked.
   */
  void Cancel();

  /**
   * Returns the metadata received from the server.
   *
   * Can only be called once the `GrpcStreamingReader` has finished.
   */
  MetadataT GetResponseHeaders() const;

 private:
  void WriteRequest();
  void Read();

  void OnOperationFailed();

  using OnSuccess = std::function<void(const GrpcCompletion*)>;
  void SetCompletion(const OnSuccess& callback);
  void FastFinishCompletion();

  // See comments in `GrpcStream` on lifetime issues for gRPC objects.
  std::unique_ptr<grpc::ClientContext> context_;
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call_;

  util::AsyncQueue* worker_queue_ = nullptr;

  // There is never more than a single pending completion; the full chain is:
  // write -> read -> [read...] -> finish
  GrpcCompletion* current_completion_ = nullptr;

  CallbackT callback_;
  grpc::ByteBuffer request_;
  std::vector<grpc::ByteBuffer> responses_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAMING_READER_H_
