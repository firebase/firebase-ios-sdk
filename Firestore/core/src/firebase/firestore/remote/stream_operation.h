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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_H_

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)
#include <utility>

#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcStream;

/**
 * An operation that notifies the corresponding `GrpcStream` on its completion.
 *
 * All created operations are expected to be put on the GRPC completion queue.
 * Operation expects that once it's received back from the GRPC completion
 * queue, `Complete()` will be called on it. `Complete` doesn't notify the
 * observing stream immediately; instead, it schedules the notification on the
 * Firestore async queue. If the stream doesn't want to be notified, it should
 * call `UnsetObserver` on the operation.
 *
 * Operation is "self-owned"; operation deletes itself in its `Complete` method.
 *
 * Operation expects all GRPC objects pertaining to the current stream to remain
 * valid until the operation comes back from the GRPC completion queue.
 */
class StreamOperation : public GrpcOperation {
 public:
  explicit StreamOperation(GrpcStream* stream);

  /**
   * Puts the operation on the GRPC completion queue.
   *
   * Must be called on the Firestore async queue.
   */
  void Execute() override;

  /**
   * Marks the operation as having come back from the GRPC completion queue and
   * puts notifying the observing stream on the Firestore async queue. The given
   * `ok` value indicates whether the operation completed successfully.
   *
   * This function deletes the operation.
   *
   * Must be called outside of Firestore async queue.
   */
  void Complete(bool ok) override;

  void UnsetObserver();

  // This is a blocking function; it blocks until the operation comes back from
  // the GRPC completion queue. It is important to only call this function when
  // the operation is sure to come back from the queue quickly.
  void WaitUntilOffQueue();
  std::future_status WaitUntilOffQueue(std::chrono::milliseconds timeout);

 private:
  virtual void DoExecute(grpc::GenericClientAsyncReaderWriter* call) = 0;
  virtual void DoComplete(GrpcStream* stream) = 0;

  GrpcStream* stream_ = nullptr;
  grpc::GenericClientAsyncReaderWriter* call_ = nullptr;
  util::AsyncQueue* firestore_queue_ = nullptr;

  std::promise<void> off_queue_;
  std::future<void> off_queue_future_;
};

class StreamStart : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;
};

class StreamRead : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;

  grpc::ByteBuffer message_;
};

// Completion of `StreamWrite` only means that GRPC is ready to accept the next
// write, not that the write has actually been sent on the wire.
class StreamWrite : public StreamOperation {
 public:
  StreamWrite(GrpcStream* stream, grpc::ByteBuffer&& message)
      : StreamOperation{stream}, message_{std::move(message)} {
  }

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;

  // Note that even though `grpc::GenericClientAsyncReaderWriter::Write` takes
  // the byte buffer by const reference, it expects the buffer's lifetime to
  // extend beyond `Write` (the buffer must be valid until the completion queue
  // returns the tag associated with the write, see
  // https://github.com/grpc/grpc/issues/13019#issuecomment-336932929, #5).
  grpc::ByteBuffer message_;
};

//
class RemoteInitiatedFinish : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;

  grpc::Status grpc_status_;
};

// Unlike `RemoteInitiatedFinish`, the stream is not interested in the status.
class ClientInitiatedFinish : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;

  // Stream isn't interested in the status when finishing is initiated by
  // client, but there has to be a valid object for GRPC purposes.
  grpc::Status unused_status_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_H_
