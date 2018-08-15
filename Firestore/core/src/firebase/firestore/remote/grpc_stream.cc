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
  StreamOperation(internal::GrpcStreamDelegate&& delegate,
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
      DoComplete();
    } else {
      delegate_.OnOperationFailed();
    }
  }

 protected:
  internal::GrpcStreamDelegate delegate_;

 private:
  virtual void DoExecute(grpc::GenericClientAsyncReaderWriter* call) = 0;
  virtual void DoComplete() = 0;

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

  void DoComplete() override {
    delegate_.OnStart();
  }
};

class StreamRead : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

 private:
  void DoExecute(grpc::GenericClientAsyncReaderWriter* call) override {
    call->Read(&message_, this);
  }

  void DoComplete() override {
    delegate_.OnRead(message_);
  }

  grpc::ByteBuffer message_;
};

class StreamWrite : public StreamOperation {
 public:
  StreamWrite(internal::GrpcStreamDelegate&& delegate,
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

  void DoComplete() override {
    delegate_.OnWrite();
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
  void DoComplete() override {
    // Note: calling Finish on a GRPC call should never fail, according to the
    // docs
    delegate_.OnFinishedWithServerError(grpc_status_);
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

  void DoComplete() override {
    // Nothing to do
  }

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
  HARD_ASSERT(!is_started_, "Call is already started");
  is_started_ = true;
  Execute<StreamStart>();
}

void GrpcStream::Read() {
  HARD_ASSERT(!has_pending_read_,
              "Cannot schedule another read operation before the previous read "
              "finishes");
  if (write_and_finish_) {
    return;
  }

  has_pending_read_ = true;
  Execute<StreamRead>();
}

void GrpcStream::Write(grpc::ByteBuffer&& message) {
  if (write_and_finish_) {
    return;
  }

  BufferedWrite(std::move(message));
}

void GrpcStream::Finish() {
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

  write_and_finish_ = true;
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
  if (write_and_finish_ && buffered_writer_->empty()) {
    // Final write succeeded.
    Finish();
    return;
  }

  if (SameGeneration()) {
    buffered_writer_->DequeueNext();
    observer_->OnStreamWrite();
  }
}

void GrpcStream::OnFinishedWithServerError(const grpc::Status& status) {
  if (SameGeneration()) {
    observer_->OnStreamError(ToFirestoreStatus(status));
  }
}

void GrpcStream::OnOperationFailed() {
  if (write_and_finish_ && buffered_writer_->empty()) {
    return;
  }
  buffered_writer_.reset();
  if (SameGeneration()) {
    Execute<ServerInitiatedFinish>();
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
