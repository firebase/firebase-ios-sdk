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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_

#include <chrono>
#include <future>

#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {
namespace remote {

class GrpcStream;

// An operation that notifies the corresponding stream on its completion (via
// `GrpcStreamDelegate`). The stream is guaranteed to be valid as long as the
// operation exists.
class StreamOperation : public GrpcOperation {
 public:
  // TODO(varconst): make call and queue getters on stream to minimize passing
  // data around?
  StreamOperation(GrpcStream* stream,
                  grpc::GenericClientAsyncReaderWriter* call,
                  util::AsyncQueue* firestore_queue);

  template <typename Op, typename... Args>
  static Op* ExecuteOperation(GrpcStream* stream,
                              grpc::GenericClientAsyncReaderWriter* call,
                              util::AsyncQueue* firestore_queue,
                              Args... args) {
    Op* op = new Op{stream, call, firestore_queue, std::move(args)...};
    op->Execute();
    return op;
  }

  void Execute() override;
  void Complete(bool ok) override;

  void UnsetObserver();
  void WaitUntilOffQueue();
  std::future_status WaitUntilOffQueue(std::chrono::milliseconds timeout);

 private:
  virtual void DoExecute(grpc::GenericClientAsyncReaderWriter* call) = 0;
  virtual void DoComplete(GrpcStream* stream) = 0;

  GrpcStream* stream_ = nullptr;
  grpc::GenericClientAsyncReaderWriter* call_ = nullptr;
  util::AsyncQueue* firestore_queue_ = nullptr;

  std::promise<void> off_queue_;
};

class StreamStart : public StreamOperation {
 private:
  friend class StreamOperation;
  using StreamOperation::StreamOperation;

  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;
};

class StreamRead : public StreamOperation {
 private:
  friend class StreamOperation;
  using StreamOperation::StreamOperation;

  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;

  grpc::ByteBuffer message_;
};

class StreamWrite : public StreamOperation {
 private:
  friend class StreamOperation;
  StreamWrite(GrpcStream* stream,
              grpc::GenericClientAsyncReaderWriter* call,
              util::AsyncQueue* firestore_queue,
              grpc::ByteBuffer&& message)
      : StreamOperation{stream, call, firestore_queue},
        message_{std::move(message)} {
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

class RemoteInitiatedFinish : public StreamOperation {
 private:
  friend class StreamOperation;
  using StreamOperation::StreamOperation;

  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;

  grpc::Status grpc_status_;
};

// Unlike `RemoteInitiatedFinish`, the observer is not interested in the status.
class ClientInitiatedFinish : public StreamOperation {
 private:
  friend class StreamOperation;
  using StreamOperation::StreamOperation;

  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override;
  void DoComplete(GrpcStream* stream) override;

  // Firestore stream isn't interested in the status when finishing is initiated
  // by client.
  grpc::Status unused_status_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_STREAM_OPERATION_
