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

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"

namespace firebase {
namespace firestore {
namespace remote {

using internal::GrpcStreamDelegate;

namespace {

util::Status ToFirestoreStatus(const grpc::Status& from) {
  if (from.ok()) {
    return {};
  }
  return {Datastore::ToFirestoreErrorCode(from.error_code()),
          from.error_message()};
}

// Operations

// An operation that notifies the corresponding stream on its completion (via
// `GrpcStreamDelegate`). The stream is guaranteed to be valid as long as the
// operation exists.
class StreamOperation : public GrpcOperation {
 public:
  StreamOperation(GrpcStreamDelegate&& delegate,
                  grpc::GenericClientAsyncReaderWriter* call,
                  GrpcCompletionQueue* grpc_queue)
      : delegate_{std::move(delegate)}, call_{call}, grpc_queue_{grpc_queue} {
  }

  void Execute() override {
    if (!grpc_queue_->IsShutDown()) {
      DoExecute(call_);
    }
  }

  void Complete(bool ok) override {
    if (ok) {
      DoComplete(&delegate_);
    } else {
      // Failed operation means this stream is irrecoverably broken; use the
      // same error-handling policy for all operations.
      delegate_.OnOperationFailed();
    }
  }

 private:
  virtual void DoExecute(grpc::GenericClientAsyncReaderWriter* call) = 0;
  virtual void DoComplete(GrpcStreamDelegate* delegate) = 0;

  // Delegate contains a strong reference to the stream.
  GrpcStreamDelegate delegate_;
  grpc::GenericClientAsyncReaderWriter* call_ = nullptr;
  // Make execution a no-op if the queue is shutting down.
  GrpcCompletionQueue* grpc_queue_ = nullptr;
};

class StreamStart : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override {
    call->StartCall(this);
  }

  void DoComplete(GrpcStreamDelegate* delegate) override {
    delegate->OnStart();
  }
};

class StreamRead : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override {
    call->Read(&message_, this);
  }

  void DoComplete(GrpcStreamDelegate* delegate) override {
    delegate->OnRead(message_);
  }

  grpc::ByteBuffer message_;
};

class StreamWrite : public StreamOperation {
 public:
  StreamWrite(GrpcStreamDelegate&& delegate,
              grpc::GenericClientAsyncReaderWriter* call,
              GrpcCompletionQueue* grpc_queue,
              grpc::ByteBuffer&& message)
      : StreamOperation{std::move(delegate), call, grpc_queue},
        message_{std::move(message)} {
  }

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override {
    call->Write(message_, this);
  }

  void DoComplete(GrpcStreamDelegate* delegate) override {
    delegate->OnWrite();
  }

  // Note that even though `grpc::GenericClientAsyncReaderWriter::Write` takes
  // the byte buffer by const reference, it expects the buffer's lifetime to
  // extend beyond `Write` (the buffer must be valid until the completion queue
  // returns the tag associated with the write, see
  // https://github.com/grpc/grpc/issues/13019#issuecomment-336932929, #5).
  grpc::ByteBuffer message_;
};

class ServerInitiatedFinish : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override {
    call->Finish(&grpc_status_, this);
  }

 private:
  void DoComplete(GrpcStreamDelegate* delegate) override {
    // Note: calling Finish on a GRPC call should never fail, according to the
    // docs
    delegate->OnFinishedByServer(grpc_status_);
  }

  grpc::Status grpc_status_;
};

// Unlike `ServerInitiatedFinish`, the observer is not interested in the status.
class ClientInitiatedFinish : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override {
    call->Finish(&unused_status_, this);
  }

  void DoComplete(GrpcStreamDelegate* delegate) override {
    // TODO(varconst): log if status is not "ok" or "canceled".
    delegate->OnFinishedByClient();
  }

  // Firestore stream isn't interested in the status when finishing is initiated
  // by client.
  grpc::Status unused_status_;
};

}  // namespace

// Call

GrpcStream::GrpcStream(
    std::unique_ptr<grpc::ClientContext> context,
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
    GrpcStreamObserver* observer,
    GrpcCompletionQueue* grpc_queue)
    : context_{std::move(context)},
      call_{std::move(call)},
      observer_{observer},
      grpc_queue_{grpc_queue},
      generation_{observer->generation()} {
}

std::shared_ptr<GrpcStream> GrpcStream::MakeStream(
    std::unique_ptr<grpc::ClientContext> context,
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
    GrpcStreamObserver* observer,
    GrpcCompletionQueue* grpc_queue) {
  // `make_shared` requires a public constructor. There are workarounds, but
  // efficiency is not a big concern here.
  return std::shared_ptr<GrpcStream>(new GrpcStream{
      std::move(context), std::move(call), observer, grpc_queue});
}

void GrpcStream::Start() {
  HARD_ASSERT(state_ == State::NotStarted, "Call is already started");
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

  HARD_ASSERT(state_ < State::Finishing, "Finish called twice");
  state_ = State::Finishing;

  buffered_writer_.reset();
  // Important: since the stream always has a pending read operation,
  // cancellation has to be called, or else the read would hang forever, and
  // finish operation will never get completed (an operation cannot be completed
  // before all previously-enqueued operations complete).
  //
  // On the other hand, when an operation fails, cancellation should not be
  // called, otherwise the real failure cause will be overwritten by status
  // "canceled".
  Execute<ClientInitiatedFinish>();
}

void GrpcStream::WriteAndFinish(grpc::ByteBuffer&& message) {
  if (state_ < State::Open) {
    // Ignore the write part if the call didn't have a chance to open yet.
    Finish();
    return;
  }

  HARD_ASSERT(buffered_writer_,
              "Write requested when there is no valid buffered_writer_");
  state_ = State::LastWrite;
  // Write the last message as soon as possible by discarding anything else that
  // might be buffered.
  buffered_writer_->DiscardUnstartedWrites();
  BufferedWrite(std::move(message));
}

void GrpcStream::BufferedWrite(grpc::ByteBuffer&& message) {
  HARD_ASSERT(buffered_writer_,
              "Write requested when there is no valid buffered_writer_");
  std::unique_ptr<StreamWrite> write_operation{
      MakeOperation<StreamWrite>(std::move(message))};
  buffered_writer_->EnqueueWrite(std::move(write_operation));
}

bool GrpcStream::SameGeneration() const {
  return generation_ == observer_->generation();
}

// Callbacks

void GrpcStream::OnStart() {
  state_ = State::Open;
  buffered_writer_ = BufferedWriter{};

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
    // While the stream is open, continue waiting for new messages
    // indefinitely.
    Read();
  }
}

void GrpcStream::OnWrite() {
  if (state_ == State::LastWrite && buffered_writer_->empty()) {
    // Final write succeeded.
    Finish();
    return;
  }

  if (SameGeneration()) {
    buffered_writer_->DequeueNextWrite();
    observer_->OnStreamWrite();
  }
}

void GrpcStream::OnFinishedByServer(const grpc::Status& status) {
  state_ = State::Finished;

  if (SameGeneration()) {
    observer_->OnStreamError(ToFirestoreStatus(status));
  }
}

void GrpcStream::OnFinishedByClient() {
  state_ = State::Finished;
  // The observer is not interested in this event -- since it initiated the
  // finish operation, the observer must know the reason.
}

void GrpcStream::OnOperationFailed() {
  HARD_ASSERT(state_ != State::Finished,
              "Operation failed after stream was "
              "finished. Finish operation should be the last one to complete");
  if (state_ >= State::LastWrite) {
    // `Finish` itself cannot fail. If another failed operation already
    // triggered `Finish`, there's nothing to do.
    return;
  }

  buffered_writer_.reset();

  if (SameGeneration()) {
    state_ = State::Finishing;
    Execute<ServerInitiatedFinish>();
  } else {
    // The only reason to finish would be to get the status; if the observer is
    // no longer interested, there is no need to do that.
    state_ = State::Finished;
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
