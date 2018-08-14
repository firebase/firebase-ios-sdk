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
  explicit StreamOperation(GrpcStream::Delegate&& delegate)
      : delegate_{std::move(delegate)} {
  }

  void Complete(bool ok) override {
    if (ok) {
      DoComplete();
    } else {
      delegate_.OnOperationFailed();
    }
  }

 protected:
  GrpcStream::Delegate delegate_;

 private:
  virtual void DoComplete() = 0;
};

class StreamStart : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

  void Execute(grpc::GenericClientAsyncReaderWriter* call,
               grpc::ClientContext* context) override {
    call->StartCall(this);
  }

 private:
  void DoComplete() override {
    delegate_.OnStart();
  }
};

class StreamRead : public StreamOperation {
 public:
  using StreamOperation::StreamOperation;

  void Execute(grpc::GenericClientAsyncReaderWriter* call,
               grpc::ClientContext* context) override {
    call->Read(&message_, this);
  }

 private:
  void DoComplete() override {
    delegate_.OnRead(message_);
  }

  grpc::ByteBuffer message_;
};

class StreamWrite : public StreamOperation {
 public:
  StreamWrite(GrpcStream::Delegate&& delegate, grpc::ByteBuffer&& message)
      : StreamOperation{std::move(delegate)}, message_{std::move(message)} {
  }

  void Execute(grpc::GenericClientAsyncReaderWriter* call,
               grpc::ClientContext* context) override {
    call->Write(message_, this);
  }

 private:
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

  void Execute(grpc::GenericClientAsyncReaderWriter* call,
               grpc::ClientContext* context) override {
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

  void Execute(grpc::GenericClientAsyncReaderWriter* call,
               grpc::ClientContext* context) override {
    context->TryCancel();
    call->Finish(&unused_status_, this);
  }

 private:
  void DoComplete() override {
    // Nothing to do
  }

  grpc::Status unused_status_;
};

}  // namespace

// Call

GrpcStream::GrpcStream(std::unique_ptr<grpc::ClientContext> context,
                   std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
                   StreamOperationsObserver* observer,
                   GrpcCompletionQueue* grpc_queue)
    : context_{std::move(context)},
      stream_{std::move(call)},
      observer_{observer},
      grpc_queue_{grpc_queue},
      generation_{observer->generation()},
      buffered_writer_{[this](grpc::ByteBuffer&& message) {
        WriteImmediately(std::move(message));
      }} {
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
  buffered_writer_.Enqueue(std::move(message));
}

void GrpcStream::WriteImmediately(grpc::ByteBuffer&& message) {
  HARD_ASSERT(is_started_,
              "WriteImmediately called before the call has started");
  Execute<StreamWrite>(std::move(message));
}

void GrpcStream::Finish() {
  buffered_writer_.Stop();
  Execute<ClientInitiatedFinish>();
}

void GrpcStream::WriteAndFinish(grpc::ByteBuffer&& message) {
  if (!buffered_writer_.IsStarted()) {
    // Ignore the write part if the call didn't have a chance to open yet.
    Finish();
    return;
  }

  write_and_finish_ = true;
  // Write the last message as soon as possible by discarding anything else that
  // might be buffered.
  buffered_writer_.Clear();
  buffered_writer_.Enqueue(std::move(message));
}

// Delegate

bool GrpcStream::Delegate::SameGeneration() const {
  return stream_->generation_ == stream_->observer_->generation();
}

void GrpcStream::Delegate::OnStart() {
  if (SameGeneration()) {
    stream_->buffered_writer_.Start();
    stream_->observer_->OnStreamStart();
  }
}

void GrpcStream::Delegate::OnRead(const grpc::ByteBuffer& message) {
  stream_->has_pending_read_ = false;
  if (SameGeneration()) {
    stream_->observer_->OnStreamRead(message);
  }
}

void GrpcStream::Delegate::OnWrite() {
  if (stream_->write_and_finish_ && stream_->buffered_writer_.empty()) {
    // Final write succeeded.
    stream_->Finish();
    return;
  }

  if (SameGeneration()) {
    stream_->buffered_writer_.OnSuccessfulWrite();
    stream_->observer_->OnStreamWrite();
  }
}

void GrpcStream::Delegate::OnFinishedWithServerError(const grpc::Status& status) {
  if (SameGeneration()) {
    stream_->observer_->OnStreamError(ToFirestoreStatus(status));
  }
}

void GrpcStream::Delegate::OnOperationFailed() {
  stream_->buffered_writer_.Stop();
  if (stream_->write_and_finish_ && stream_->buffered_writer_.empty()) {
    return;
  }
  if (SameGeneration()) {
    stream_->Execute<ServerInitiatedFinish>();
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
