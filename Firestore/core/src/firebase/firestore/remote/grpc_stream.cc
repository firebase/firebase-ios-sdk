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
#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"

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

class StreamOperation : public GrpcOperation {
 public:
  StreamOperation(GrpcStreamDelegate&& delegate,
                  grpc::GenericClientAsyncReaderWriter* call,
                  GrpcCompletionQueue* grpc_queue)
      : delegate_{std::move(delegate)}, call_{call}, grpc_queue_{grpc_queue} {
  }

  void Execute() override {
    if (!grpc_queue_->IsShuttingDown()) {
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

  GrpcStreamDelegate delegate_;
  grpc::GenericClientAsyncReaderWriter* call_ = nullptr;
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

class ClientInitiatedFinish : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override {
    call->Finish(&unused_status_, this);
  }

  void DoComplete(GrpcStreamDelegate* delegate) override {
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
    GrpcOperationsObserver* observer,
    GrpcCompletionQueue* grpc_queue)
    : context_{std::move(context)},
      call_{std::move(call)},
      observer_{observer},
      grpc_queue_{grpc_queue},
      generation_{observer->generation()} {
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

  HARD_ASSERT(state_ <= State::Open, "Finish called twice");
  state_ = State::Finishing;

  buffered_writer_.reset();
  context_->TryCancel();
  Execute<ClientInitiatedFinish>();
}

void GrpcStream::WriteAndFinish(grpc::ByteBuffer&& message) {
  if (!buffered_writer_) {
    // Ignore the write part if the call didn't have a chance to open yet.
    Finish();
    return;
  }

  state_ = State::FinishingWithWrite;
  // Write the last message as soon as possible by discarding anything else that
  // might be buffered.
  buffered_writer_->DiscardUnstartedWrites();
  BufferedWrite(std::move(message));
}

void GrpcStream::BufferedWrite(grpc::ByteBuffer&& message) {
  std::unique_ptr<StreamWrite> write_operation{
      MakeOperation<StreamWrite>(std::move(message))};
  buffered_writer_->Enqueue(std::move(write_operation));
}

bool GrpcStream::SameGeneration() const {
  return generation_ == observer_->generation();
}

// Callbacks

void GrpcStream::OnStart() {
  state_ = State::Open;

  if (SameGeneration()) {
    buffered_writer_ = BufferedWriter{};
    observer_->OnStreamStart();
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
  if (state_ == State::FinishingWithWrite && buffered_writer_->empty()) {
    // Final write succeeded.
    Finish();
    return;
  }

  if (SameGeneration()) {
    buffered_writer_->DequeueNext();
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
  // The observer is not interested in this event.
}

void GrpcStream::OnOperationFailed() {
  HARD_ASSERT(state_ != State::Finished, "Operation failed after stream was "
      "finished. Finish operation should be the last one to complete");
  if (state_ >= State::Finishing) {
    // `Finish` itself cannot fail. If another failed operation already
    // triggered `Finish`, there's nothing to do.
    return;
  }

  buffered_writer_.reset();

  if (SameGeneration()) {
    Execute<ServerInitiatedFinish>();
  } else {
    state_ = State::Finished;
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
