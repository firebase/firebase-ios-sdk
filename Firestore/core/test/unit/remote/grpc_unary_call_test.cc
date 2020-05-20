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

#include "Firestore/core/src/remote/grpc_unary_call.h"

#include <initializer_list>
#include <memory>

#include "Firestore/core/src/remote/connectivity_monitor.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/test/unit/remote/create_noop_connectivity_monitor.h"
#include "Firestore/core/test/unit/remote/grpc_stream_tester.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/types/optional.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;
using util::Status;
using util::StatusOr;
using Type = GrpcCompletion::Type;

class GrpcUnaryCallTest : public testing::Test {
 public:
  GrpcUnaryCallTest()
      : worker_queue{testutil::AsyncQueueForTesting()},
        connectivity_monitor{CreateNoOpConnectivityMonitor()},
        tester{worker_queue, connectivity_monitor.get()},
        call{tester.CreateUnaryCall()} {
  }

  ~GrpcUnaryCallTest() {
    if (call) {
      // It's okay to call `FinishImmediately` more than once.
      KeepPollingGrpcQueue();
      worker_queue->EnqueueBlocking([&] { call->FinishImmediately(); });
    }
    tester.Shutdown();
  }

  void StartCall() {
    call->Start([this](const StatusOr<grpc::ByteBuffer>& result) {
      status = result.status();
      if (status.value().ok()) {
        response = result.ValueOrDie();
      }
    });
  }

  void ForceFinish(std::initializer_list<CompletionEndState> results) {
    tester.ForceFinish(call->context(), results);
  }
  void KeepPollingGrpcQueue() {
    tester.KeepPollingGrpcQueue();
  }

  std::shared_ptr<AsyncQueue> worker_queue;

  std::unique_ptr<ConnectivityMonitor> connectivity_monitor;
  GrpcStreamTester tester;

  std::unique_ptr<GrpcUnaryCall> call;
  grpc::ByteBuffer response;
  absl::optional<Status> status;
};

// Correct API usage

TEST_F(GrpcUnaryCallTest, FinishImmediatelyIsIdempotent) {
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_NO_THROW(call->FinishImmediately()); });

  StartCall();

  KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(call->FinishImmediately());
    EXPECT_NO_THROW(call->FinishImmediately());
  });
}

TEST_F(GrpcUnaryCallTest, CanGetResponseHeadersAfterStarting) {
  StartCall();
  EXPECT_NO_THROW(call->GetResponseHeaders());
}

TEST_F(GrpcUnaryCallTest, CanGetResponseHeadersAfterFinishing) {
  StartCall();

  KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking([&] {
    call->FinishImmediately();
    EXPECT_NO_THROW(call->GetResponseHeaders());
  });
}

TEST_F(GrpcUnaryCallTest, CannotFinishAndNotifyBeforeStarting) {
  // No callback has been assigned.
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_ANY_THROW(call->FinishAndNotify(Status::OK())); });
}

// Normal operation

TEST_F(GrpcUnaryCallTest, Success) {
  StartCall();

  ForceFinish({{Type::Finish, MakeByteBuffer("foo"), grpc::Status::OK}});

  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value(), Status::OK());
  EXPECT_EQ(ByteBufferToString(response), std::string{"foo"});
}

TEST_F(GrpcUnaryCallTest, Error) {
  StartCall();

  ForceFinish({{Type::Finish, MakeByteBuffer("foo"),
                grpc::Status{grpc::UNAVAILABLE, ""}}});

  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value().code(), Error::kErrorUnavailable);
  EXPECT_TRUE(ByteBufferToString(response).empty());
}

// Callback destroys reader

TEST_F(GrpcUnaryCallTest, CallbackCanDestroyCallOnSuccess) {
  worker_queue->EnqueueBlocking([&] {
    call->Start([this](const StatusOr<grpc::ByteBuffer>&) { call.reset(); });
  });

  EXPECT_NE(call, nullptr);
  EXPECT_NO_THROW(ForceFinish({{Type::Finish, grpc::Status::OK}}));
  EXPECT_EQ(call, nullptr);
}

TEST_F(GrpcUnaryCallTest, CallbackCanDestroyCallOnError) {
  worker_queue->EnqueueBlocking([&] {
    call->Start([this](const StatusOr<grpc::ByteBuffer>&) { call.reset(); });
  });

  grpc::Status error_status{grpc::StatusCode::UNAVAILABLE, ""};
  EXPECT_NE(call, nullptr);
  EXPECT_NO_THROW(ForceFinish({{Type::Finish, error_status}}));
  EXPECT_EQ(call, nullptr);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
