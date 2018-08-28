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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_TESTS_UTIL_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_TESTS_UTIL_H_

#include <initializer_list>
#include <memory>
#include <utility>

#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "absl/memory/memory.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"

namespace firebase {
namespace firestore {
namespace util {

enum OperationResult { Ok, Error };

/**
 * Does the somewhat complicated setup required to create a `GrpcStream` and
 * allows imitating the normal completion of `StreamOperation`s.
 */
class GrpcStreamFixture {
 public:
  GrpcStreamFixture();
  ~GrpcStreamFixture();

  // Must be called before the stream can be used.
  void InitializeStream(remote::GrpcStreamObserver* observer);
  std::unique_ptr<remote::GrpcStream> CreateStream(
      remote::GrpcStreamObserver* observer);
  /** Finishes the stream and shuts down the gRPC completion queue. */
  void Shutdown();

  /**
   * Takes as many operations off gRPC completion queue as there are elements in
   * `results` and completes each operation with the corresponding result,
   * ignoring the actual result from gRPC.
   *
   * This is a blocking function; it will finish quickly if the the gRPC
   * completion queue has at least as many pending operations as there are
   * elements in `results`; otherwise, it will hang.
   */
  void ForceFinish(std::initializer_list<OperationResult> results);

  /**
   * Using a separate executor, keep polling gRPC completion queue and tell all
   * the operations that come off the queue that they finished successfully,
   * ignoring the actual result from gRPC.
   *
   * Call this method before calling the blocking functions `GrpcStream::Finish`
   * or `GrpcStream::WriteAndFinish`, otherwise they would hang.
   */
  void KeepPollingGrpcQueue();

  remote::GrpcStream& stream() {
    return *grpc_stream_;
  }
  AsyncQueue& async_queue() {
    return async_queue_;
  }
  grpc::GenericClientAsyncReaderWriter* call() {
    return grpc_call_;
  }

 private:
  void ShutdownGrpcQueue();

  std::unique_ptr<internal::ExecutorStd> dedicated_executor_;
  AsyncQueue async_queue_;

  grpc::GenericStub grpc_stub_;
  grpc::CompletionQueue grpc_queue_;
  grpc::ClientContext* grpc_context_ = nullptr;
  grpc::GenericClientAsyncReaderWriter* grpc_call_ = nullptr;

  std::unique_ptr<remote::GrpcStream> grpc_stream_;
  bool is_shut_down_ = false;
};

GrpcStreamFixture::GrpcStreamFixture()
    : async_queue_{absl::make_unique<internal::ExecutorStd>()},
      dedicated_executor_{absl::make_unique<internal::ExecutorStd>()},
      grpc_stub_{grpc::CreateChannel("", grpc::InsecureChannelCredentials())} {
}

void GrpcStreamFixture::InitializeStream(remote::GrpcStreamObserver* observer) {
  auto grpc_context_owning = absl::make_unique<grpc::ClientContext>();
  grpc_context_ = grpc_context_owning.get();

  auto grpc_call_owning =
      grpc_stub_.PrepareCall(grpc_context_owning.get(), "", &grpc_queue_);
  grpc_call_ = grpc_call_owning.get();

  grpc_stream_ = absl::make_unique<remote::GrpcStream>(
      std::move(grpc_context_owning), std::move(grpc_call_owning), observer,
      &async_queue_);
}

std::unique_ptr<remote::GrpcStream> GrpcStreamFixture::CreateStream(
    remote::GrpcStreamObserver* observer) {
  InitializeStream(observer);
  return std::move(grpc_stream_);
}

GrpcStreamFixture::~GrpcStreamFixture() {
  // Make sure the stream and gRPC completion queue are properly shut down.
  Shutdown();
}

void GrpcStreamFixture::Shutdown() {
  async_queue_.EnqueueBlocking([&] {
    if (!grpc_stream_->IsFinished()) {
      KeepPollingGrpcQueue();
      grpc_stream_->Finish();
    }
    ShutdownGrpcQueue();
    // Wait for gRPC completion queue to drain
    dedicated_executor_->ExecuteBlocking([] {});
  });
}

void GrpcStreamFixture::ShutdownGrpcQueue() {
  if (is_shut_down_) {
    return;
  }
  is_shut_down_ = true;

  grpc_queue_.Shutdown();
}

// This is a very hacky way to simulate GRPC finishing operations without
// actually connecting to the server: cancel the stream, which will make the
// operation fail fast and be returned from the completion queue, then
// complete the operation.
void GrpcStreamFixture::ForceFinish(
    std::initializer_list<OperationResult> results) {
  dedicated_executor_->ExecuteBlocking([&] {
    // GRPC allows calling `TryCancel` more than once.
    grpc_context_->TryCancel();

    for (OperationResult result : results) {
      bool ignored_ok = false;
      void* tag = nullptr;
      grpc_queue_.Next(&tag, &ignored_ok);
      auto operation = static_cast<remote::GrpcOperation*>(tag);
      operation->Complete(result == OperationResult::Ok);
    }
  });

  async_queue_.EnqueueBlocking([] {});
}

void GrpcStreamFixture::KeepPollingGrpcQueue() {
  dedicated_executor_->Execute([&] {
    void* tag = nullptr;
    bool ignored_ok = false;
    while (grpc_queue_.Next(&tag, &ignored_ok)) {
      static_cast<remote::GrpcOperation*>(tag)->Complete(true);
    }
  });
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_TESTS_UTIL_H_
