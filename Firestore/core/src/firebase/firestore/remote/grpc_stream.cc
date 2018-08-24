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

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"

#include <future>

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;

// `GrpcStream` communicates with gRPC via `StreamOperation`s:
//
// - for each method in its public API that wraps an invocation of a method on
//   `grpc::GenericClientAsyncReaderWriter`, `GrpcStream` creates a new
//   `StreamOperation` (`GrpcStream` itself doesn't invoke a single method on
//   `grpc::GenericClientAsyncReaderWriter`);
//
// - `StreamOperation` knows how to execute itself. `StreamOperation::Execute`
//   will call the underlying call to gRPC and place the operation itself on
//   gRPC completion queue;
//
// - `GrpcStream` expects another class (in practice, `RemoteStore`) to take
//   completed tags off gRPC completion queue and call `Complete` on them;
//
// - `StreamOperation::Complete` will invoke a corresponding callback on the
//   `GrpcStream`. In turn, `GrpcStream` will decide whether to notify the
//   observer;
//
// - `StreamOperation` stores a `GrpcStreamDelegate` and actually invokes
//   callbacks on this class, which straightforwardly redirects them to
//   `GrpcStream`. The delegate has a shared pointer to the `GrpcStream`. This
//   means that even after the caller lets go of its `shared_ptr` to
//   `GrpcStream`, the stream object will still be valid until the last
//   operation issued by the stream completes;
//
// - `StreamOperation`s are owned by the `GrpcStream`. Note that the ownership
//   goes both ways: the stream is the sole owner of each operation, but each
//   operation extends the lifetime of the stream as long as it exists.
//   Operations call `GrpcStream::RemoveOperation` in its
//   `StreamOperation::Complete` method. If the operation contained the last
//   reference to the stream, it might trigger `GrpcStream` destruction;
//
// - `GrpcStream` doesn't know anything about Firestore `AsyncQueue`s. It's the
//   responsibility of the callers to invoke its methods in appropriate
//   execution contexts.

GrpcStream::GrpcStream(
    std::unique_ptr<grpc::ClientContext> context,
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
    GrpcStreamObserver* observer,
    AsyncQueue* firestore_queue,
    GrpcCompletionQueue* grpc_queue)
    : context_{std::move(context)},
      call_{std::move(call)},
      observer_{observer},
      firestore_queue_{firestore_queue},
      grpc_queue_{grpc_queue},
      // Store the current generation of the observer.
      generation_{observer->generation()},
      buffered_writer_{this} {
}

std::unique_ptr<GrpcStream> GrpcStream::MakeStream(
    std::unique_ptr<grpc::ClientContext> context,
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
    GrpcStreamObserver* observer,
    AsyncQueue* firestore_queue,
    GrpcCompletionQueue* grpc_queue) {
  // `make_shared` requires a public constructor. There are workarounds, but
  // efficiency is not a big concern here.
  return std::unique_ptr<GrpcStream>(
      new GrpcStream{std::move(context), std::move(call), observer,
                     firestore_queue, grpc_queue});
}

GrpcStream::~GrpcStream() {
  HARD_ASSERT(operations_.empty(),
              "GrpcStream is being destroyed without a call to Finish");
}

void GrpcStream::Start() {
  HARD_ASSERT(state_ == State::NotStarted, "Stream is already started");
  state_ = State::Started;
  Execute<StreamStart>();
}

void GrpcStream::Read() {
  HARD_ASSERT(!has_pending_read_,
              "Cannot schedule another read operation before the previous read "
              "finishes");
  HARD_ASSERT(state_ == State::Open, "Read called when the stream is not open");

  has_pending_read_ = true;
  Execute<StreamRead>();
}

void GrpcStream::Write(grpc::ByteBuffer&& message) {
  HARD_ASSERT(state_ == State::Open,
              "Write called when the stream is not open");
  BufferedWrite(std::move(message));
}

void GrpcStream::Finish() {
  if (state_ == State::NotStarted) {
    return;
  }

  HARD_ASSERT(state_ < State::Dying, "Finish called twice");
  state_ = State::Dying;

  buffered_writer_ = BufferedWriter{this};

  // Important: since the stream always has a pending read operation,
  // cancellation has to be called, or else the read would hang forever, and
  // finish operation will never get completed (an operation cannot be completed
  // before all previously-enqueued operations complete).
  //
  // On the other hand, when an operation fails, cancellation should not be
  // called, otherwise the real failure cause will be overwritten by status
  // "canceled".
  context_->TryCancel();
  Execute<ClientInitiatedFinish>();  // TODO: is it necessary?

  for (auto operation : operations_) {
    operation->Cancel();
  }

  for (auto operation : operations_) {
    operation->WaitUntilOffQueue();
  }
  operations_.clear();
}

void GrpcStream::WriteAndFinish(grpc::ByteBuffer&& message) {
  if (state_ < State::Open) {
    // Ignore the write part if the call didn't have a chance to open yet.
    Finish();
    return;
  }

  state_ = State::LastWrite;
  // Write the last message as soon as possible by discarding anything else that
  // might be buffered.
  buffered_writer_.DiscardUnstartedWrites();
  BufferedWrite(std::move(message));
}

void GrpcStream::BufferedWrite(grpc::ByteBuffer&& message) {
  buffered_writer_.EnqueueWrite(std::move(message));
}

bool GrpcStream::SameGeneration() const {
  return generation_ == observer_->generation();
}

// Callbacks

void GrpcStream::OnStart() {
  state_ = State::Open;

  if (SameGeneration()) {
    observer_->OnStreamStart();
    // Start listening for new messages.
    Read();
  }
}

void GrpcStream::OnRead(const grpc::ByteBuffer& message) {
  has_pending_read_ = false;

  if (SameGeneration()) {
    observer_->OnStreamRead(message);
    if (state_ == State::Open) {
      // Continue waiting for new messages indefinitely as long as there is an
      // interested observer and the stream is open.
      Read();
    }
  }
}

void GrpcStream::OnWrite() {
  if (state_ == State::LastWrite && buffered_writer_.empty()) {
    // Final write succeeded.
    Finish();
    return;
  }
  if (state_ <= State::LastWrite) {
    buffered_writer_.DequeueNextWrite();
  }

  if (SameGeneration()) {
    observer_->OnStreamWrite();
  }
}

void GrpcStream::OnFinishedByServer(const grpc::Status& status) {
  state_ = State::Finished;

  if (SameGeneration()) {
    observer_->OnStreamError(Datastore::ToFirestoreStatus(status));
  }
}

void GrpcStream::OnFinishedByClient() {
  state_ = State::Finished;
  // The observer is not interested in this event -- since it initiated the
  // finish operation, the observer must know the reason.
}

void GrpcStream::OnOperationFailed() {
  if (state_ >= State::LastWrite) {
    // `Finish` itself cannot fail. If another failed operation already
    // triggered `Finish`, there's nothing to do.
    return;
  }

  buffered_writer_ = BufferedWriter{this};
  
  if (SameGeneration()) {
    state_ = State::Finishing;
    Execute<ServerInitiatedFinish>();
  } else {
    // The only reason to finish would be to get the status; if the observer is
    // no longer interested, there is no need to do that.
    state_ = State::Finished;
  }
}

void GrpcStream::RemoveOperation(const StreamOperation* to_remove) {
  auto found = std::find(operations_.begin(), operations_.end(), to_remove);
  HARD_ASSERT(found != operations_.end(), "Missing StreamOperation");
  // Note that the operation might have contained the last reference to this
  // stream, so this call might trigger `GrpcStream::~GrpcStream`.
  operations_.erase(found);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
