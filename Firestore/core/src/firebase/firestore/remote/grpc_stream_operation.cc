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

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream_operation.h"

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;

GrpcStreamOperation::GrpcStreamOperation(GrpcStream* stream)
    : stream_{stream},
      call_{stream->call()},
      firestore_queue_{stream->firestore_queue()} {
}

void GrpcStreamOperation::UnsetObserver() {
  firestore_queue_->VerifyIsCurrentQueue();

  stream_ = nullptr;
}

void GrpcStreamOperation::Execute() {
  firestore_queue_->VerifyIsCurrentQueue();

  DoExecute(call_);
}

void GrpcStreamOperation::WaitUntilOffQueue() {
  firestore_queue_->VerifyIsCurrentQueue();

  if (!off_queue_future_.valid()) {
    off_queue_future_ = off_queue_.get_future();
  }
  return off_queue_future_.wait();
}

std::future_status GrpcStreamOperation::WaitUntilOffQueue(
    std::chrono::milliseconds timeout) {
  firestore_queue_->VerifyIsCurrentQueue();

  if (!off_queue_future_.valid()) {
    off_queue_future_ = off_queue_.get_future();
  }
  return off_queue_future_.wait_for(timeout);
}

void GrpcStreamOperation::Complete(bool ok) {
  // This mechanism allows `GrpcStream` to know when the operation is off the
  // GRPC completion queue (and thus this operation no longer requires the
  // underlying GRPC objects to be valid).
  off_queue_.set_value();

  firestore_queue_->Enqueue([this, ok] {
    if (stream_) {
      stream_->RemoveOperation(this);

      if (ok) {
        DoComplete(stream_);
      } else {
        // Failed operation means this stream is unrecoverably broken; use the
        // same error-handling policy for all operations.
        stream_->OnOperationFailed();
      }
    }

    delete this;
  });
}

// Start

void StreamStart::DoExecute(grpc::GenericClientAsyncReaderWriter* call) {
  call->StartCall(this);
}

void StreamStart::DoComplete(GrpcStream* stream) {
  stream->OnStart();
}

// Read

void StreamRead::DoExecute(grpc::GenericClientAsyncReaderWriter* call) {
  call->Read(&message_, this);
}

void StreamRead::DoComplete(GrpcStream* stream) {
  stream->OnRead(message_);
}

// Write

void StreamWrite::DoExecute(grpc::GenericClientAsyncReaderWriter* call) {
  call->Write(message_, this);
}

void StreamWrite::DoComplete(GrpcStream* stream) {
  stream->OnWrite();
}

// RemoteInitiatedFinish

void RemoteInitiatedFinish::DoExecute(
    grpc::GenericClientAsyncReaderWriter* call) {
  call->Finish(&grpc_status_, this);
}

void RemoteInitiatedFinish::DoComplete(GrpcStream* stream) {
  // Note: calling Finish on a GRPC call should never fail, according to the
  // docs
  stream->OnFinishedByServer(grpc_status_);
}

// ClientInitiatedFinish

void ClientInitiatedFinish::DoExecute(
    grpc::GenericClientAsyncReaderWriter* call) {
  call->Finish(&unused_status_, this);
}

void ClientInitiatedFinish::DoComplete(GrpcStream* stream) {
  stream->OnFinishedByClient();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
