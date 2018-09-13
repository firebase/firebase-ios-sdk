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

#include "Firestore/core/test/firebase/firestore/util/grpc_stream_tester.h"

#include <utility>

#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {

using internal::ExecutorStd;
using remote::GrpcCompletion;
using remote::GrpcStream;
using remote::GrpcStreamingReader;
using remote::GrpcStreamObserver;

GrpcStreamTester::GrpcStreamTester()
    : worker_queue_{absl::make_unique<ExecutorStd>()},
      dedicated_executor_{absl::make_unique<ExecutorStd>()},
      grpc_stub_{grpc::CreateChannel("", grpc::InsecureChannelCredentials())} {
}

GrpcStreamTester::~GrpcStreamTester() {
  // Make sure the stream and gRPC completion queue are properly shut down.
  Shutdown();
}

void GrpcStreamTester::Shutdown() {
  worker_queue_.EnqueueBlocking([&] { ShutdownGrpcQueue(); });
}

std::unique_ptr<GrpcStream> GrpcStreamTester::CreateStream(
    GrpcStreamObserver* observer) {
  auto grpc_context_owning = absl::make_unique<grpc::ClientContext>();
  grpc_context_ = grpc_context_owning.get();
  auto grpc_call =
      grpc_stub_.PrepareCall(grpc_context_owning.get(), "", &grpc_queue_);

  return absl::make_unique<GrpcStream>(std::move(grpc_context_owning),
                                       std::move(grpc_call), observer,
                                       &worker_queue_);
}

std::unique_ptr<GrpcStreamingReader> GrpcStreamTester::CreateStreamingReader() {
  auto grpc_context_owning = absl::make_unique<grpc::ClientContext>();
  grpc_context_ = grpc_context_owning.get();
  auto grpc_call =
      grpc_stub_.PrepareCall(grpc_context_owning.get(), "", &grpc_queue_);

  return absl::make_unique<GrpcStreamingReader>(
      std::move(grpc_context_owning), std::move(grpc_call), &worker_queue_,
      grpc::ByteBuffer{});
}

void GrpcStreamTester::ShutdownGrpcQueue() {
  if (is_shut_down_) {
    return;
  }
  is_shut_down_ = true;

  grpc_queue_.Shutdown();
  // Wait for gRPC completion queue to drain
  dedicated_executor_->ExecuteBlocking([] {});
}

// This is a very hacky way to simulate gRPC finishing operations without
// actually connecting to the server: cancel the stream, which will make all
// operations fail fast and be returned from the completion queue, then
// complete the associated completion.
void GrpcStreamTester::ForceFinish(
    std::initializer_list<CompletionResult> results) {
  dedicated_executor_->ExecuteBlocking([&] {
    // gRPC allows calling `TryCancel` more than once.
    grpc_context_->TryCancel();

    for (CompletionResult result : results) {
      bool ignored_ok = false;
      void* tag = nullptr;
      grpc_queue_.Next(&tag, &ignored_ok);
      auto completion = static_cast<remote::GrpcCompletion*>(tag);
      completion->Complete(result == CompletionResult::Ok);
    }
  });

  worker_queue_.EnqueueBlocking([] {});
}

void GrpcStreamTester::KeepPollingGrpcQueue() {
  dedicated_executor_->Execute([&] {
    void* tag = nullptr;
    bool ignored_ok = false;
    while (grpc_queue_.Next(&tag, &ignored_ok)) {
      static_cast<GrpcCompletion*>(tag)->Complete(true);
    }
  });
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
