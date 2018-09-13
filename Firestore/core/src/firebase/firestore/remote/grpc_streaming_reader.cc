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

#include "Firestore/core/src/firebase/firestore/remote/grpc_streaming_reader.h"

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)
#include <utility>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;
using util::Status;

GrpcStreamingReader::GrpcStreamingReader(
    std::unique_ptr<grpc::ClientContext> context,
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
    AsyncQueue* worker_queue,
    const grpc::ByteBuffer& request)
    : context_{std::move(context)},
      call_{std::move(call)},
      worker_queue_{worker_queue},
      request_{request} {
}

GrpcStreamingReader::~GrpcStreamingReader() {
  HARD_ASSERT(!current_completion_,
              "GrpcStreamingReader is being destroyed without proper shutdown");
}

void GrpcStreamingReader::Start(CallbackT&& callback) {
  callback_ = std::move(callback);

  // Coalesce the sending of initial metadata with the first write.
  context_->set_initial_metadata_corked(true);
  call_->StartCall(nullptr);

  WriteRequest();
}

void GrpcStreamingReader::WriteRequest() {
  SetCompletion([this](const GrpcCompletion* /*ignored*/) { Read(); });
  *current_completion_->message() = std::move(request_);

  // It is important to indicate to the server that there will be no follow-up
  // writes; otherwise, the call will never finish.
  call_->WriteLast(*current_completion_->message(), grpc::WriteOptions{},
                   current_completion_);
}

void GrpcStreamingReader::Read() {
  SetCompletion([this](const GrpcCompletion* completion) {
    // Accumulate responses
    responses_.push_back(*completion->message());
    Read();
  });

  call_->Read(current_completion_->message(), current_completion_);
}

void GrpcStreamingReader::Cancel() {
  if (!current_completion_) {
    // Nothing to cancel.
    return;
  }

  context_->TryCancel();
  FastFinishCompletion();

  SetCompletion([this](const GrpcCompletion*) {
    // Deliberately ignored
  });
  call_->Finish(current_completion_->status(), current_completion_);
  FastFinishCompletion();
}

void GrpcStreamingReader::FastFinishCompletion() {
  current_completion_->Cancel();
  // This function blocks.
  current_completion_->WaitUntilOffQueue();
  current_completion_ = nullptr;
}

void GrpcStreamingReader::OnOperationFailed() {
  // The next read attempt after the server has sent the last response will also
  // fail; in other words, `OnOperationFailed` will always be invoked, even when
  // `Finish` will produce a successful status.
  SetCompletion([this](const GrpcCompletion* completion) {
    callback_(Status::FromGrpcStatus(*completion->status()), responses_);
    // This `GrpcStreamingReader`'s lifetime might have been ended by the
    // callback.
  });
  call_->Finish(current_completion_->status(), current_completion_);
}

void GrpcStreamingReader::SetCompletion(const OnSuccess& on_success) {
  // Can't move into lambda until C++14.
  GrpcCompletion::Callback decorated =
      [this, on_success](bool ok, const GrpcCompletion* completion) {
        current_completion_ = nullptr;

        if (ok) {
          on_success(completion);
        } else {
          OnOperationFailed();
        }
      };

  HARD_ASSERT(!current_completion_,
              "Creating a new completion before the previous one is done");
  current_completion_ = new GrpcCompletion{worker_queue_, std::move(decorated)};
}

GrpcStreamingReader::MetadataT GrpcStreamingReader::GetResponseHeaders() const {
  return context_->GetServerInitialMetadata();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
