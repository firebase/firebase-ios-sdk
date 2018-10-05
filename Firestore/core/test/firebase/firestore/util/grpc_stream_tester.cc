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

using auth::Token;
using auth::User;
using internal::ExecutorStd;
using model::DatabaseId;
using remote::ConnectivityMonitor;
using remote::GrpcCompletion;
using remote::GrpcStream;
using remote::GrpcStreamingReader;
using remote::GrpcStreamObserver;
using util::CompletionEndState;

// FakeGrpcQueue

FakeGrpcQueue::FakeGrpcQueue()
    : dedicated_executor_{absl::make_unique<ExecutorStd>()} {
}

void FakeGrpcQueue::Shutdown() {
  if (is_shut_down_) {
    return;
  }
  is_shut_down_ = true;

  grpc_queue_.Shutdown();
  // Wait for gRPC completion queue to drain
  dedicated_executor_->ExecuteBlocking([] {});
}

void FakeGrpcQueue::ExtractCompletions(
    std::initializer_list<CompletionEndState> end_states) {
  dedicated_executor_->ExecuteBlocking([&] {
    for (CompletionEndState end_state : end_states) {
      bool ignored_ok = false;
      void* tag = nullptr;
      grpc_queue_.Next(&tag, &ignored_ok);
      auto completion = static_cast<remote::GrpcCompletion*>(tag);
      if (end_state.maybe_status) {
        *completion->status() = end_state.maybe_status.value();
      }
      completion->Complete(end_state.result == CompletionResult::Ok);
    }
  });
}

void FakeGrpcQueue::KeepPolling() {
  dedicated_executor_->Execute([&] {
    void* tag = nullptr;
    bool ignored_ok = false;
    while (grpc_queue_.Next(&tag, &ignored_ok)) {
      static_cast<GrpcCompletion*>(tag)->Complete(true);
    }
  });
}

// GrpcStreamTester

GrpcStreamTester::GrpcStreamTester(AsyncQueue* worker_queue,
                                   ConnectivityMonitor* connectivity_monitor)
    : worker_queue_{NOT_NULL(worker_queue)},
      database_info_{DatabaseId{"foo", "bar"}, "", "", false},
      grpc_connection_{database_info_, worker_queue, mock_grpc_queue_.queue(),
                       connectivity_monitor} {
}

GrpcStreamTester::~GrpcStreamTester() {
  // Make sure the stream and gRPC completion queue are properly shut down.
  Shutdown();
}

void GrpcStreamTester::Shutdown() {
  worker_queue_->EnqueueBlocking([&] { ShutdownGrpcQueue(); });
}

std::unique_ptr<GrpcStream> GrpcStreamTester::CreateStream(
    GrpcStreamObserver* observer) {
  return grpc_connection_.CreateStream("", Token{"", User{}}, observer);
}

std::unique_ptr<GrpcStreamingReader> GrpcStreamTester::CreateStreamingReader() {
  return grpc_connection_.CreateStreamingReader("", Token{"", User{}},
                                                grpc::ByteBuffer{});
}

std::unique_ptr<remote::GrpcUnaryCall> GrpcStreamTester::CreateUnaryCall() {
  return grpc_connection_.CreateUnaryCall("", Token{"", User{}},
                                          grpc::ByteBuffer{});
}

void GrpcStreamTester::ShutdownGrpcQueue() {
  mock_grpc_queue_.Shutdown();
}

// This is a very hacky way to simulate gRPC finishing operations without
// actually connecting to the server: cancel the stream, which will make all
// operations fail fast and be returned from the completion queue, then
// complete the associated completion.
void GrpcStreamTester::ForceFinish(
    grpc::ClientContext* context,
    std::initializer_list<CompletionEndState> end_states) {
  // gRPC allows calling `TryCancel` more than once.
  context->TryCancel();
  mock_grpc_queue_.ExtractCompletions(end_states);
  worker_queue_->EnqueueBlocking([] {});
}

void GrpcStreamTester::KeepPollingGrpcQueue() {
  mock_grpc_queue_.KeepPolling();
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
