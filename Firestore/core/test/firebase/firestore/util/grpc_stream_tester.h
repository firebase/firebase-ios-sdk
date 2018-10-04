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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_STREAM_TESTER_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_STREAM_TESTER_H_

#include <initializer_list>
#include <memory>

#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/remote/connectivity_monitor.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_completion.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_connection.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_streaming_reader.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_unary_call.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "absl/types/optional.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"

namespace firebase {
namespace firestore {
namespace util {

enum CompletionResult { Ok, Error };
struct CompletionEndState {
  CompletionEndState(CompletionResult result)  // NOLINT(runtime/explicit)
      : result{result} {
  }
  CompletionEndState(const grpc::Status& status)  // NOLINT(runtime/explicit)
      : result{Ok}, maybe_status{status} {
  }

  CompletionResult result;
  absl::optional<grpc::Status> maybe_status;
};

class FakeGrpcQueue {
 public:
  FakeGrpcQueue();

  void ExtractCompletions(std::initializer_list<CompletionEndState> results);
  void KeepPolling();

  void Shutdown();

  grpc::CompletionQueue* queue() {
    return &grpc_queue_;
  }

 private:
  std::unique_ptr<internal::ExecutorStd> dedicated_executor_;
  grpc::CompletionQueue grpc_queue_;
  bool is_shut_down_ = false;
};

/**
 * Does the somewhat complicated setup required to create a `GrpcStream` and
 * allows imitating the normal completion of `GrpcCompletion`s.
 */
class GrpcStreamTester {
 public:
  GrpcStreamTester(AsyncQueue* worker_queue,
                   remote::ConnectivityMonitor* connectivity_monitor);
  ~GrpcStreamTester();

  /** Finishes the stream and shuts down the gRPC completion queue. */
  void Shutdown();

  std::unique_ptr<remote::GrpcStream> CreateStream(
      remote::GrpcStreamObserver* observer);
  std::unique_ptr<remote::GrpcStreamingReader> CreateStreamingReader();
  std::unique_ptr<remote::GrpcUnaryCall> CreateUnaryCall();

  /**
   * Takes as many completions off gRPC completion queue as there are elements
   * in `results` and completes each of them with the corresponding result,
   * ignoring the actual result from gRPC.
   *
   * This is a blocking function; it will finish quickly if the the gRPC
   * completion queue has at least as many pending completions as there are
   * elements in `results`; otherwise, it will hang.
   */
  void ForceFinish(grpc::ClientContext* context,
                   std::initializer_list<CompletionEndState> results);

  void KeepPollingGrpcQueue();
  void ShutdownGrpcQueue();

 private:
  AsyncQueue* worker_queue_ = nullptr;
  core::DatabaseInfo database_info_;

  FakeGrpcQueue mock_grpc_queue_;
  remote::GrpcConnection grpc_connection_;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_GRPC_STREAM_TESTER_H_
