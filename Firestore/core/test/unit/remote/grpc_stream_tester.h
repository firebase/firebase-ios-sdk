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

#ifndef FIRESTORE_CORE_TEST_UNIT_REMOTE_GRPC_STREAM_TESTER_H_
#define FIRESTORE_CORE_TEST_UNIT_REMOTE_GRPC_STREAM_TESTER_H_

#include <functional>
#include <future>  // NOLINT(build/c++11)
#include <initializer_list>
#include <memory>
#include <string>

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/core/database_info.h"
#include "Firestore/core/src/remote/connectivity_monitor.h"
#include "Firestore/core/src/remote/grpc_completion.h"
#include "Firestore/core/src/remote/grpc_connection.h"
#include "Firestore/core/src/remote/grpc_stream.h"
#include "Firestore/core/src/remote/grpc_streaming_reader.h"
#include "Firestore/core/src/remote/grpc_unary_call.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/executor.h"
#include "absl/types/optional.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/status_code_enum.h"

namespace firebase {
namespace firestore {
namespace remote {

class FirebaseMetadataProvider;

std::string GetGrpcErrorCodeName(grpc::StatusCode error);
std::string GetFirestoreErrorName(Error error);
std::string ByteBufferToString(const grpc::ByteBuffer& buffer);
grpc::ByteBuffer MakeByteBuffer(const std::string& str);

enum CompletionResult { Ok, Error };

/**
 * When completing a `GrpcCompletion` using `GrpcStreamTester::ForceFinish`, use
 * `CompletionEndState` to describe the desired state of the completion, thus
 * imitating actual gRPC events. For example:
 *
 * CompletionEndState{Type::Read, Ok} -- as if a read operation was completed
 *    successfully.
 * CompletionEndState{Type::Finish, grpc::Status{grpc::DATA_LOSS,
 *     "Some error"}} - as if a finish operation was completed successfully,
 *     producing "data loss" status.
 */
struct CompletionEndState {
  CompletionEndState(GrpcCompletion::Type type, CompletionResult result)
      : type_{type}, result_{result} {
  }
  CompletionEndState(GrpcCompletion::Type type, const grpc::ByteBuffer& message)
      : type_{type}, result_{Ok}, maybe_message_{message} {
  }
  CompletionEndState(GrpcCompletion::Type type, const grpc::Status& status)
      : type_{type}, result_{Ok}, maybe_status_{status} {
  }
  CompletionEndState(GrpcCompletion::Type type,
                     const grpc::ByteBuffer& message,
                     const grpc::Status& status)
      : type_{type},
        result_{Ok},
        maybe_message_{message},
        maybe_status_{status} {
  }

  void Apply(GrpcCompletion* completion);

  GrpcCompletion::Type type() const {
    return type_;
  }

 private:
  GrpcCompletion::Type type_;
  CompletionResult result_{};
  absl::optional<grpc::ByteBuffer> maybe_message_;
  absl::optional<grpc::Status> maybe_status_;
};

class FakeGrpcQueue {
 public:
  using CompletionCallback = std::function<bool(GrpcCompletion*)>;

  explicit FakeGrpcQueue(grpc::CompletionQueue* grpc_queue);

  // `Extract` functions presume that all the completions that are to be
  // extracted will come off the queue quickly.
  void ExtractCompletions(std::initializer_list<CompletionEndState> results);
  void ExtractCompletions(const CompletionCallback& callback);
  void KeepPolling();
  std::future<void> KeepPolling(const CompletionCallback& callback);

  void Shutdown();

  grpc::CompletionQueue* queue() {
    return grpc_queue_;
  }

 private:
  GrpcCompletion* ExtractCompletion();

  std::unique_ptr<util::Executor> dedicated_executor_;
  grpc::CompletionQueue* grpc_queue_;
  bool is_shut_down_ = false;

  std::promise<void> current_promise_;
};

/**
 * Does the somewhat complicated setup required to create a `GrpcStream` and
 * allows imitating the normal completion of `GrpcCompletion`s.
 */
class GrpcStreamTester {
 public:
  using CompletionCallback = FakeGrpcQueue::CompletionCallback;

  GrpcStreamTester(const std::shared_ptr<util::AsyncQueue>& worker_queue,
                   ConnectivityMonitor* connectivity_monitor);
  ~GrpcStreamTester();

  /** Finishes the stream and shuts down the gRPC completion queue. */
  void Shutdown();

  std::unique_ptr<GrpcStream> CreateStream(GrpcStreamObserver* observer);
  std::unique_ptr<GrpcStreamingReader> CreateStreamingReader();
  std::unique_ptr<GrpcUnaryCall> CreateUnaryCall();

  /**
   * Takes as many completions off gRPC completion queue as there are
   * elements in `results` and completes each of them with the corresponding
   * result, ignoring the actual result from gRPC. If the actual completion has
   * a different `GrpcCompletion::Type` than the corresponding result, this
   * function will fail.
   *
   * This is a blocking function; it will finish quickly if the the gRPC
   * completion queue has at least as many pending completions as there are
   * elements in `results`; otherwise, it will hang.
   *
   * IMPORTANT: there are two gotchas to be aware of when using this function:
   *
   * 1. `FinishImmediately` and `FinishAndNotify` issue a finish operation and
   *   block until it completes. For this reason, `ForceFinish` _cannot_ be used
   *   when finishing a gRPC call manually. Consider:
   *
   *       ForceFinish({{Type::Finish, Ok}}); // Will block forever -- there is
   *           // no finish operation on the queue yet
   *       call->Finish(); // Unreachable
   *   or:
   *       call->Finish(); // Will block forever -- issues a finish operation
   *           // and waits until it completes
   *       ForceFinish({{Type::Finish, Ok}}); // Unreachable
   *
   *   Solution -- use `KeepPollingGrpcQueue` for this case instead.
   *
   * 2. gRPC does _not_ guarantee order in which the tags come off the
   *    completion queue. In practice, when a `GrpcStream` has both read and
   *    write operations in progress, this overload of `ForceFinish` cannot be
   *    used reliably:
   *
   *    ForceFinish({{Type::Read, Ok}, {Type::Write, Ok}}); // Will fail if the
   *        // write happens to come off the queue before read, even though this
   *        // doesn't affect the stream behavior.
   *
   *    Solution: use the overload of `ForceFinish` that takes a callback.
   */
  void ForceFinish(grpc::ClientContext* context,
                   std::initializer_list<CompletionEndState> results);

  /**
   * Will continue taking completions off the completion queue and invoking the
   * given `callback` on them until the `callback` returns true (interpreted as
   * "done"). Use as a failback mechanism for cases that can't be handled by
   * `CompletionEndState`s.
   *
   * This is a blocking function; the `callback` must ensure that it returns
   * `true` before the queue runs out of completions.
   */
  void ForceFinish(grpc::ClientContext* context,
                   const CompletionCallback& callback);

  /**
   * This is a workaround for the fact that it's indeterminate whether it's read
   * or write operation that comes off the completion queue first. Will apply
   * the end states to completions regardless of the relative ordering between
   * different types of completions, but preserving the order within the same
   * type. For example, the following
   *
   *  ForceFinishAnyTypeOrder({
   *    {Type::Write, Ok},
   *    {Type::Read, MakeByteBuffer("foo")},
   *    {Type::Read, Error},
   *  });
   *
   *  will apply "Ok" to the first completion of type "write" that comes off the
   *  queue, apply "Ok" with the message "Foo" to the first completion of type
   *  "read", and apply "Error" to the second completion of type "read".
   */
  void ForceFinishAnyTypeOrder(
      grpc::ClientContext* context,
      std::initializer_list<CompletionEndState> results);

  /**
   * Will asynchronously continuously pull gRPC completion queue and delegate
   * handling all the completions taken off to the given `callback`, until the
   * callback returns true (interpreted as "done"). Returns a future that will
   * finish once the callback returns "done".
   */
  std::future<void> ForceFinishAsync(const CompletionCallback& callback);

  /**
   * Creates a `CompletionCallback` from given `results` which is equivalent to
   * what `ForceFinishAnyTypeOrder` would use, but doesn't run it.
   */
  static CompletionCallback CreateAnyTypeOrderCallback(
      std::initializer_list<CompletionEndState> results);

  /**
   * Will asynchronously continuously pull gRPC completion queue and apply "Ok"
   * to every completion that comes off the queue.
   */
  void KeepPollingGrpcQueue();
  void ShutdownGrpcQueue();

  GrpcConnection* grpc_connection() {
    return &grpc_connection_;
  }

 private:
  std::shared_ptr<util::AsyncQueue> worker_queue_;
  core::DatabaseInfo database_info_;

  grpc::CompletionQueue grpc_queue_;
  FakeGrpcQueue fake_grpc_queue_;
  std::unique_ptr<FirebaseMetadataProvider> firebase_metadata_provider_;
  GrpcConnection grpc_connection_;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_REMOTE_GRPC_STREAM_TESTER_H_
