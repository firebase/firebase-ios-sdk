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

#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/auth/user.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace util {

using auth::Token;
using auth::User;
using core::DatabaseInfo;
using internal::ExecutorStd;
using model::DatabaseId;
using remote::ConnectivityMonitor;
using remote::GrpcCompletion;
using remote::GrpcStream;
using remote::GrpcStreamingReader;
using remote::GrpcStreamObserver;

// MockGrpcQueue

MockGrpcQueue::MockGrpcQueue(AsyncQueue* worker_queue)
    : dedicated_executor_{absl::make_unique<ExecutorStd>()},
      worker_queue_{worker_queue} {
  dedicated_executor_->Execute([this] { PollGrpcQueue(); });
}

void MockGrpcQueue::Shutdown() {
  if (is_shut_down_) {
    return;
  }
  is_shut_down_ = true;

  grpc_queue_.Shutdown();
  // Wait for gRPC completion queue to drain
  dedicated_executor_->ExecuteBlocking([] {});
}

void MockGrpcQueue::PollGrpcQueue() {
  void* tag = nullptr;
  bool ignored_ok = false;
  while (grpc_queue_.Next(&tag, &ignored_ok)) {
    worker_queue_->Enqueue([this, tag] {
      pending_completions_.push(static_cast<GrpcCompletion*>(tag));
    });
  }
}

void MockGrpcQueue::RunCompletions(
    std::initializer_list<CompletionResult> results) {
  HARD_ASSERT(pending_completions_.size() >= results.size(), "");

  worker_queue_->EnqueueRelaxed([this, results] {
    for (CompletionResult result : results) {
      GrpcCompletion* completion = pending_completions_.front();
      pending_completions_.pop();
      completion->Complete(result == CompletionResult::Ok);
    }
  });

  worker_queue_->EnqueueBlocking([] {});
}

// GrpcStreamTester

GrpcStreamTester::GrpcStreamTester()
    : GrpcStreamTester{absl::make_unique<ConnectivityMonitor>(nullptr)} {
}

GrpcStreamTester::GrpcStreamTester(
    std::unique_ptr<ConnectivityMonitor> connectivity_monitor)
    : worker_queue_{absl::make_unique<ExecutorStd>()},
      mock_grpc_queue_{&worker_queue_},
      database_info_{DatabaseId{"foo", "bar"}, "", "", false},
      grpc_connection_{database_info_, &worker_queue_, mock_grpc_queue_.queue(),
                       std::move(connectivity_monitor)} {
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
  return grpc_connection_.CreateStream("", Token{"", User{}}, observer);
}

std::unique_ptr<GrpcStreamingReader> GrpcStreamTester::CreateStreamingReader() {
  return grpc_connection_.CreateStreamingReader("", Token{"", User{}},
                                                grpc::ByteBuffer{});
}

void GrpcStreamTester::ShutdownGrpcQueue() {
  mock_grpc_queue_.Shutdown();
}

// This is a very hacky way to simulate gRPC finishing operations without
// actually connecting to the server: cancel the stream, which will make all
// operations fail fast and be returned from the completion queue, then
// complete the associated completion.
void GrpcStreamTester::RunCompletions(
    grpc::ClientContext* grpc_context,
    std::initializer_list<CompletionResult> results) {
  // gRPC allows calling `TryCancel` more than once.
  grpc_context->TryCancel();
  mock_grpc_queue_.RunCompletions(results);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
