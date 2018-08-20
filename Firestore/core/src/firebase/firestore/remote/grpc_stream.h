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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H

#include <memory>
#include <utility>

#include "Firestore/core/src/firebase/firestore/remote/buffered_writer.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_queue.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/types/optional.h"
#include "grpcpp/client_context.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace internal {
class GrpcStreamDelegate;
}

/**
 * A gRPC bidirectional stream that notifies the given `observer` about stream
 * events.
 *
 * The stream has to be explicitly opened (via `Start`) before it can be used.
 * The stream is always listening for new messages from the server. The stream
 * can be used to send messages to the server (via `Write`); messages are queued
 * and sent out one by one. Both sent and received messages are raw bytes;
 * serialization and deserialization are left to the caller.
 *
 * The stream stores the generation number of the observer at the time of its
 * creation; once observer increases its generation number, the stream will stop
 * notifying it of events.
 *
 * The stream is disposable; once it finishes, it cannot be restarted.
 *
 * This class is a wrapper over `grpc::GenericClientAsyncReaderWriter`.
 */
class GrpcStream : public std::enable_shared_from_this<GrpcStream> {
 public:
  // Implementation of the stream relies on its memory being managed by
  // `shared_ptr`.
  //
  // The given `grpc_queue` must wrap the same underlying completion queue as
  // the `call`.
  static std::shared_ptr<GrpcStream> MakeStream(
      std::unique_ptr<grpc::ClientContext> context,
      std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
      GrpcStreamObserver* observer,
      GrpcCompletionQueue* grpc_queue);

  void Start();

  void Write(grpc::ByteBuffer&& message);

  // Does not produce a notification. Once this method is called, the stream can
  // no longer be used.
  //
  // Can be called on a stream before it opens. It is invalid to finish a stream
  // more than once.
  void Finish();

  // Writes the given message and finishes the stream as soon as the write
  // succeeds. Any non-started writes will be discarded. Neither write nor
  // finish will notify the observer.
  //
  // If the stream hasn't opened yet, `WriteAndFinish` is equivalent to
  // `Finish` -- the write will be ignored.
  void WriteAndFinish(grpc::ByteBuffer&& message);

 private:
  friend class internal::GrpcStreamDelegate;

  GrpcStream(std::unique_ptr<grpc::ClientContext> context,
             std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
             GrpcStreamObserver* observer,
             GrpcCompletionQueue* grpc_queue);

  void Read();
  void BufferedWrite(grpc::ByteBuffer&& message);

  // Called by `GrpcStreamDelegate`.
  void OnStart();
  void OnRead(const grpc::ByteBuffer& message);
  void OnWrite();
  void OnOperationFailed();
  void OnFinishedByServer(const grpc::Status& status);
  void OnFinishedByClient();

  bool SameGeneration() const;

  template <typename Op, typename... Args>
  Op* MakeOperation(Args... args);

  // Creates and immediately executes an operation; ownership is released.
  template <typename Op, typename... Args>
  void Execute(Args... args) {
    MakeOperation<Op>(args...)->Execute();
  }

  // The gRPC objects that have to be valid until the last gRPC operation
  // associated with this call finishes. Note that `grpc::ClientContext` is not
  // reference-counted.
  //
  // Important: `call_` has to be destroyed before `context_`, so declaration
  // order matters here. Despite the unique pointer, `call_` is actually
  // a non-owning handle, and the memory it refers to will be released once
  // `context_` (which is owning) is released.
  std::unique_ptr<grpc::ClientContext> context_;
  std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call_;

  GrpcCompletionQueue* grpc_queue_ = nullptr;

  GrpcStreamObserver* observer_ = nullptr;
  int generation_ = -1;
  // Buffered writer is created once the stream opens.
  absl::optional<BufferedWriter> buffered_writer_;

  enum class State {
    NotStarted,
    Started,
    Open,
    // The stream is waiting to send the last write and will finish as soon as
    // it completes.
    LastWrite,
    Finishing,
    Finished
  };
  State state_ = State::NotStarted;

  // For sanity checks
  bool has_pending_read_ = false;
};

namespace internal {

// The link between `GrpcStream` and `StreamOperation`s that is used by
// operations to notify the stream once they are completed.
//
// The delegate has a `shared_ptr` to the stream to ensure that the stream's
// lifetime lasts as long as any of the operations it issued still exists.
//
// The delegate allows making `GrpcStream::OnStream[Event]` functions private
// without too much proliferation of friendship.
class GrpcStreamDelegate {
 public:
  explicit GrpcStreamDelegate(std::shared_ptr<GrpcStream>&& stream)
      : stream_{std::move(stream)} {
  }

  void OnStart() {
    stream_->OnStart();
  }
  void OnRead(const grpc::ByteBuffer& message) {
    stream_->OnRead(message);
  }
  void OnWrite() {
    stream_->OnWrite();
  }
  void OnOperationFailed() {
    stream_->OnOperationFailed();
  }
  void OnFinishedByServer(const grpc::Status& status) {
    stream_->OnFinishedByServer(status);
  }
  void OnFinishedByClient() {
    stream_->OnFinishedByClient();
  }

 private:
  std::shared_ptr<GrpcStream> stream_;
};

}  // namespace internal

template <typename Op, typename... Args>
Op* GrpcStream::MakeOperation(Args... args) {
  return new Op{internal::GrpcStreamDelegate{shared_from_this()}, call_.get(),
                grpc_queue_, std::move(args)...};
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_REMOTE_GRPC_STREAM_H
