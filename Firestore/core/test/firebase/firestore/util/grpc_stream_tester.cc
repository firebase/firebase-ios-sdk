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

GrpcStreamTester::GrpcStreamTester()
    : async_queue_{absl::make_unique<internal::ExecutorStd>()},
      dedicated_executor_{absl::make_unique<internal::ExecutorStd>()},
      grpc_stub_{grpc::CreateChannel("", grpc::InsecureChannelCredentials())} {
}

void GrpcStreamTester::InitializeStream(remote::GrpcStreamObserver* observer) {
  auto grpc_context_owning = absl::make_unique<grpc::ClientContext>();
  grpc_context_ = grpc_context_owning.get();

  auto grpc_call_owning =
      grpc_stub_.PrepareCall(grpc_context_owning.get(), "", &grpc_queue_);
  grpc_call_ = grpc_call_owning.get();

  grpc_stream_ = absl::make_unique<remote::GrpcStream>(
      std::move(grpc_context_owning), std::move(grpc_call_owning), observer,
      &async_queue_);
}

std::unique_ptr<remote::GrpcStream> GrpcStreamTester::CreateStream(
    remote::GrpcStreamObserver* observer) {
  InitializeStream(observer);
  return std::move(grpc_stream_);
}

GrpcStreamTester::~GrpcStreamTester() {
  // Make sure the stream and gRPC completion queue are properly shut down.
  Shutdown();
}

void GrpcStreamTester::Shutdown() {
  async_queue_.EnqueueBlocking([&] {
    if (grpc_stream_ && !grpc_stream_->IsFinished()) {
      KeepPollingGrpcQueue();
      grpc_stream_->Finish();
    }
    ShutdownGrpcQueue();
  });
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

  async_queue_.EnqueueBlocking([] {});
}

void GrpcStreamTester::KeepPollingGrpcQueue() {
  dedicated_executor_->Execute([&] {
    void* tag = nullptr;
    bool ignored_ok = false;
    while (grpc_queue_.Next(&tag, &ignored_ok)) {
      static_cast<remote::GrpcCompletion*>(tag)->Complete(true);
    }
  });
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
