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

#include <initializer_list>
#include <memory>

#include "Firestore/core/src/firebase/firestore/remote/connectivity_monitor.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_unary_call.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/test/firebase/firestore/util/grpc_stream_tester.h"
#include "absl/types/optional.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;
using util::CompletionEndState;
using util::GrpcStreamTester;
using util::Status;
using util::StatusOr;
using util::CompletionResult::Error;
using util::CompletionResult::Ok;
using util::internal::ExecutorStd;

class GrpcUnaryCallTest : public testing::Test {
 public:
  GrpcUnaryCallTest()
      : worker_queue{absl::make_unique<ExecutorStd>()},
        connectivity_monitor_{
            absl::make_unique<ConnectivityMonitor>(&worker_queue)},
        tester_{&worker_queue, connectivity_monitor_.get()},
        call_{tester_.CreateUnaryCall()} {
    call_->Start([this](const StatusOr<grpc::ByteBuffer>& result) {
      status_ = result.status();
    });
  }

  ~GrpcUnaryCallTest() {
    tester_.Shutdown();
  }

  GrpcUnaryCall& call() {
    return *call_;
  }

  void ForceFinish(std::initializer_list<CompletionEndState> results) {
    tester_.ForceFinish(call_->context(), results);
  }
  void KeepPollingGrpcQueue() {
    tester_.KeepPollingGrpcQueue();
  }

  const absl::optional<Status>& status() const {
    return status_;
  }

  AsyncQueue worker_queue;

 private:
  std::unique_ptr<ConnectivityMonitor> connectivity_monitor_;
  GrpcStreamTester tester_;

  std::unique_ptr<GrpcUnaryCall> call_;
  absl::optional<Status> status_;
};

TEST_F(GrpcUnaryCallTest, CanFinish) {
  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] { call().FinishImmediately(); });
  EXPECT_FALSE(status().has_value());
}

TEST_F(GrpcUnaryCallTest, CanFinishTwice) {
  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] {
    call().FinishImmediately();
    EXPECT_NO_THROW(call().FinishImmediately());
  });
}

TEST_F(GrpcUnaryCallTest, SuccessfulFinish) {
  ForceFinish({/*Finish*/ Ok});
  EXPECT_TRUE(status().has_value());
}

TEST_F(GrpcUnaryCallTest, Error) {
  ForceFinish({/*Finish*/ Error});
  EXPECT_TRUE(status().has_value());
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
