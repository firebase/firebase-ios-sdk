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

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)

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

namespace internal {

StreamWrite* BufferedWriter::EnqueueWrite(grpc::ByteBuffer&& write) {
  queue_.push(write);
  return TryStartWrite();
}

StreamWrite* BufferedWriter::TryStartWrite() {
  if (queue_.empty() || has_active_write_) {
    return nullptr;
  }

  has_active_write_ = true;
  grpc::ByteBuffer message = std::move(queue_.front());
  queue_.pop();
  return StreamOperation::ExecuteOperation<StreamWrite>(
      stream_, call_, firestore_queue_, std::move(message));
}

StreamWrite* BufferedWriter::DequeueNextWrite() {
  has_active_write_ = false;
  return TryStartWrite();
}

}  // namespace internal

using internal::BufferedWriter;

GrpcStream::GrpcStream(
    std::unique_ptr<grpc::ClientContext> context,
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
    GrpcStreamObserver* observer,
    AsyncQueue* firestore_queue)
    : context_{std::move(context)},
      call_{std::move(call)},
      observer_{observer},
      firestore_queue_{firestore_queue},
      // Store the current generation of the observer.
      generation_{observer->generation()},
      buffered_writer_{this, call_.get(), firestore_queue_} {
}

GrpcStream::~GrpcStream() {
  HARD_ASSERT(operations_.empty(),
              "GrpcStream is being destroyed without proper shutdown");
}

void GrpcStream::Start() {
  HARD_ASSERT(state_ == State::NotStarted, "Stream is already started");
  state_ = State::Starting;
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
    HARD_ASSERT(operations_.empty(),
                "Non-started stream has pending operations");
    state_ = State::Finished;
    return;
  }

  HARD_ASSERT(state_ < State::Finishing, "Finish called twice");
  state_ = State::Finishing;

  // Important: since the stream always has a pending read operation,
  // cancellation has to be called, or else the read would hang forever, and
  // finish operation will never get completed.
  //
  // (on the other hand, when an operation fails, cancellation should not be
  // called, otherwise the real failure cause will be overwritten by status
  // "canceled".)
  context_->TryCancel();
  // TODO(varconst): is issuing a finish operation necessary in this case? We
  // don't care about the status, but perhaps it will make the server notice
  // client disconnecting sooner?
  Execute<ClientInitiatedFinish>();

  FastFinishOperationsBlocking();
}

void GrpcStream::FastFinishOperationsBlocking() {
  // TODO(varconst): reset buffered_writer_? Should not be necessary, because it
  // should never be called again after state_ == State::Finished.

  HARD_ASSERT(state_ == State::Finishing,
              "Fast-finishing operations must only be done when the stream is "
              "finishing");

  for (auto operation : operations_) {
    // `GrpcStream` cannot cancel the completion of any operations that might
    // already have been enqueued on the Firestore queue, so instead turn those
    // completions into no-ops.
    operation->UnsetObserver();
  }

  for (auto operation : operations_) {
    // This is blocking.
    operation->WaitUntilOffQueue();
  }
  operations_.clear();

  state_ = State::Finished;
}

bool GrpcStream::WriteAndFinish(grpc::ByteBuffer&& message) {
  HARD_ASSERT(state_ == State::Open,
              "WriteAndFinish called for a stream "
              "that is not open");

  bool did_last_write = false;
  StreamWrite* last_write_operation = BufferedWrite(std::move(message));
  // Only bother with the last write if there is no active write at the moment.
  if (last_write_operation) {
    last_write_operation->UnsetObserver();
    // Empirically, the write normally takes less than a millisecond to finish
    // (both with and without network connection), and never more than several
    // dozen milliseconds. Nevertheless, ensure `WriteAndFinish` doesn't hang if
    // there happen to be circumstances under which the write may block
    // indefinitely (in that case, rely on the fact that canceling GRPC call
    // makes all pending operations come back from the queue quickly).
    auto status =
        last_write_operation->WaitUntilOffQueue(std::chrono::milliseconds(500));
    if (status == std::future_status::ready) {
      RemoveOperation(last_write_operation);
      did_last_write = true;
    }
  }

  Finish();
  return did_last_write;
}

StreamWrite* GrpcStream::BufferedWrite(grpc::ByteBuffer&& message) {
  StreamWrite* maybe_write = buffered_writer_.EnqueueWrite(std::move(message));
  if (maybe_write) {
    operations_.push_back(maybe_write);
  }
  return maybe_write;
}

bool GrpcStream::SameGeneration() const {
  return generation_ == observer_->generation();
}

GrpcStream::MetadataT GrpcStream::GetResponseHeaders() const {
  HARD_ASSERT(
      state_ >= State::Open,
      "Initial server metadata is only received after the stream opens");
  MetadataT result;
  auto grpc_metadata = context_->GetServerInitialMetadata();
  auto to_str = [](grpc::string_ref ref) {
    return std::string{ref.begin(), ref.end()};
  };
  for (const auto& kv : grpc_metadata) {
    result[to_str(kv.first)] = to_str(kv.second);
  }
  return result;
}

// Callbacks

void GrpcStream::OnStart() {
  HARD_ASSERT(state_ == State::Starting,
              "Expected to be in 'Starting' state when OnStart is invoked");
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
  // Observer is not interested in this event.
  if (SameGeneration() && state_ == State::Open) {
    StreamWrite* maybe_write = buffered_writer_.DequeueNextWrite();
    if (maybe_write) {
      operations_.push_back(maybe_write);
    }
  }
}

void GrpcStream::OnOperationFailed() {
  if (state_ >= State::Finishing) {
    // `Finish` itself cannot fail. If another failed operation already
    // triggered `Finish`, there's nothing to do.
    return;
  }

  state_ = State::Finishing;

  if (SameGeneration()) {
    Execute<RemoteInitiatedFinish>();
  } else {
    // The only reason to finish would be to get the status; if the observer is
    // no longer interested, there is no need to do that.
    FastFinishOperationsBlocking();
  }
}

void GrpcStream::OnFinishedByServer(const grpc::Status& status) {
  FastFinishOperationsBlocking();

  if (SameGeneration()) {
    observer_->OnStreamError(Datastore::ToFirestoreStatus(status));
  }
}

void GrpcStream::OnFinishedByClient() {
  // The observer is not interested in this event -- since it initiated the
  // finish operation, the observer must know the reason.
}

void GrpcStream::RemoveOperation(const StreamOperation* to_remove) {
  auto found = std::find(operations_.begin(), operations_.end(), to_remove);
  HARD_ASSERT(found != operations_.end(), "Missing StreamOperation");
  operations_.erase(found);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
