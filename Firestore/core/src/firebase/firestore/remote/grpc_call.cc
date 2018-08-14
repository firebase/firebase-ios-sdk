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

#include "Firestore/core/src/firebase/firestore/remote/grpc_call.h"

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

class StreamStart : public GrpcOperation {
 public:
  using GrpcOperation::GrpcOperation;

  void Execute(grpc::GenericClientAsyncReaderWriter* call,
               grpc::ClientContext* context) override {
    call->StartCall(this);
  }

 private:
  void DoComplete() override {
    delegate_.OnStart();
  }
};

class StreamRead : public GrpcOperation {
 public:
  using GrpcOperation::GrpcOperation;

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

class StreamWrite : public GrpcOperation {
 public:
  StreamWrite(GrpcCall::Delegate&& delegate, grpc::ByteBuffer&& message)
      : GrpcOperation{std::move(delegate)}, message_{std::move(message)} {
  }

  void Execute(grpc::GenericClientAsyncReaderWriter* call,
               grpc::ClientContext* context) override {
    call->Write(message_, this);
  }

 private:
  void DoComplete() override {
    delegate_.OnWrite();
  }

  // OBC comment! https://github.com/grpc/grpc/issues/13019, 5)
  grpc::ByteBuffer message_;
};

class ServerInitiatedFinish : public GrpcOperation {
 public:
  using GrpcOperation::GrpcOperation;

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

class ClientInitiatedFinish : public GrpcOperation {
 public:
  using GrpcOperation::GrpcOperation;

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

GrpcCall::GrpcCall(std::unique_ptr<grpc::ClientContext> context,
                   std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
                   GrpcOperationsObserver* observer,
                   GrpcCompletionQueue* grpc_queue)
    : context_{std::move(context)},
      call_{std::move(call)},
      observer_{observer},
      grpc_queue_{grpc_queue},
      generation_{observer->generation()},
      buffered_writer_{[this](grpc::ByteBuffer&& message) {
        WriteImmediately(std::move(message));
      }} {
}

void GrpcCall::Start() {
  HARD_ASSERT(!is_started_, "Call is already started");
  is_started_ = true;
  Execute<StreamStart>();
}

void GrpcCall::Read() {
  HARD_ASSERT(!has_pending_read_,
              "Cannot schedule another read operation before the previous read "
              "finishes");
  has_pending_read_ = true;
  Execute<StreamRead>();
}

void GrpcCall::Write(grpc::ByteBuffer&& message) {
  if (write_and_finish_) {
    return;
  }
  buffered_writer_.Enqueue(std::move(message));
}

void GrpcCall::Finish() {
  buffered_writer_.Stop();
  Execute<ClientInitiatedFinish>();
}

void GrpcCall::WriteImmediately(grpc::ByteBuffer&& message) {
  Execute<StreamWrite>(std::move(message));
}

void GrpcCall::WriteAndFinish(grpc::ByteBuffer&& message) {
  if (!buffered_writer_.IsStarted()) {
    // Ignore the write if the call didn't have a chance to open yet.
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

bool GrpcCall::Delegate::SameGeneration() const {
  return call_->generation_ == call_->observer_->generation();
}

void GrpcCall::Delegate::OnStart() {
  if (SameGeneration()) {
    call_->buffered_writer_.Start();
    call_->observer_->OnStreamStart();
  }
}

void GrpcCall::Delegate::OnRead(const grpc::ByteBuffer& message) {
  call_->has_pending_read_ = false;
  if (SameGeneration()) {
    call_->observer_->OnStreamRead(message);
  }
}

void GrpcCall::Delegate::OnWrite() {
  if (call_->write_and_finish_ && call_->buffered_writer_.empty()) {
    // Final write succeeded.
    call_->Finish();
    return;
  }

  if (SameGeneration()) {
    call_->buffered_writer_.OnSuccessfulWrite();
    call_->observer_->OnStreamWrite();
  }
}

void GrpcCall::Delegate::OnFinishedWithServerError(const grpc::Status& status) {
  if (SameGeneration()) {
    call_->observer_->OnStreamError(ToFirestoreStatus(status));
  }
}

void GrpcCall::Delegate::OnOperationFailed() {
  call_->buffered_writer_.Stop();
  if (call_->write_and_finish_ && call_->buffered_writer_.empty()) {
    return;
  }
  if (SameGeneration()) {
    call_->Execute<ServerInitiatedFinish>();
  }
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
