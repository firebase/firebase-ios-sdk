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

#include "Firestore/core/src/remote/grpc_streaming_reader.h"

#include <utility>

#include "Firestore/core/src/remote/grpc_connection.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;
using util::Status;

GrpcStreamingReader::GrpcStreamingReader(
    std::unique_ptr<grpc::ClientContext> context,
    std::unique_ptr<grpc::GenericClientAsyncReaderWriter> call,
    const std::shared_ptr<util::AsyncQueue>& worker_queue,
    GrpcConnection* grpc_connection,
    const grpc::ByteBuffer& request)
    : stream_{absl::make_unique<GrpcStream>(std::move(context),
                                            std::move(call),
                                            worker_queue,
                                            grpc_connection,
                                            this)},
      request_{request} {
}

void GrpcStreamingReader::Start(size_t expected_response_count,
                                ResponsesCallback&& responses_callback,
                                CloseCallback&& close_callback) {
  expected_response_count_ = expected_response_count;
  responses_callback_ = std::move(responses_callback);
  close_callback_ = std::move(close_callback);
  stream_->Start();
}

void GrpcStreamingReader::FinishImmediately() {
  stream_->FinishImmediately();
}

void GrpcStreamingReader::FinishAndNotify(const Status& status) {
  stream_->FinishAndNotify(status);
}

void GrpcStreamingReader::OnStreamStart() {
  // It is important to indicate to the server that there will be no follow-up
  // writes; otherwise, the call will never finish.
  stream_->WriteLast(std::move(request_));
}

void GrpcStreamingReader::OnStreamRead(const grpc::ByteBuffer& message) {
  // Accumulate responses, responses_callback_ will be fired if
  // GrpcStreamingReader has received all the responses.
  responses_.push_back(message);
  if (responses_.size() == expected_response_count_) {
    callback_fired_ = true;
    responses_callback_(responses_);
  }
}

void GrpcStreamingReader::OnStreamFinish(const util::Status& status) {
  // Handle the case where 0 document reads required.
  // OnStreamRead will never be triggered,
  // but we still need to return an empty vector of documents.
  if (status.ok() && !callback_fired_) {
    callback_fired_ = true;
    responses_callback_(responses_);
  }

  // Invoking the callback ends this reader's lifetime.
  close_callback_(status, callback_fired_);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
