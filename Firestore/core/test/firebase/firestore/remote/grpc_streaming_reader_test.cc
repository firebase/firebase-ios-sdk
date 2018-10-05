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
#include <vector>

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
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

class GrpcStreamingReaderTest : public testing::Test {
 public:
  GrpcStreamingReaderTest()
      : worker_queue{absl::make_unique<ExecutorStd>()},
        connectivity_monitor_{
            absl::make_unique<ConnectivityMonitor>(&worker_queue)},
        tester_{&worker_queue, connectivity_monitor_.get()},
        reader_{tester_.CreateStreamingReader()} {
    reader_->Start(
        [this](const StatusOr<std::vector<grpc::ByteBuffer>>& result) {
          status_ = result.status();
          if (status_->ok()) {
            responses_ = std::move(result).ValueOrDie();
          }
        });
  }

  ~GrpcStreamingReaderTest() {
    tester_.Shutdown();
  }

  GrpcStreamingReader& reader() {
    return *reader_;
  }

  void ForceFinish(std::initializer_list<CompletionEndState> results) {
    tester_.ForceFinish(reader_->context(), results);
  }
  void KeepPollingGrpcQueue() {
    tester_.KeepPollingGrpcQueue();
  }

  const absl::optional<Status>& status() const {
    return status_;
  }
  const std::vector<grpc::ByteBuffer>& responses() const {
    return responses_;
  }

  AsyncQueue worker_queue;

 private:
  std::unique_ptr<ConnectivityMonitor> connectivity_monitor_;
  GrpcStreamTester tester_;

  std::unique_ptr<GrpcStreamingReader> reader_;
  absl::optional<Status> status_;
  std::vector<grpc::ByteBuffer> responses_;
};

TEST_F(GrpcStreamingReaderTest, OneSuccessfulRead) {
  ForceFinish({/*Write*/ Ok, /*Read*/ Ok, /*Read after last*/ Error});
  EXPECT_FALSE(status().has_value());

  ForceFinish({/*Finish*/ grpc::Status::OK});
  EXPECT_TRUE(status().has_value());
  EXPECT_EQ(responses().size(), 1);
}

TEST_F(GrpcStreamingReaderTest, TwoSuccessfulReads) {
  ForceFinish(
      {/*Write*/ Ok, /*Read*/ Ok, /*Read*/ Ok, /*Read after last*/ Error});
  EXPECT_FALSE(status().has_value());

  ForceFinish({/*Finish*/ grpc::Status::OK});
  EXPECT_TRUE(status().has_value());
  EXPECT_EQ(responses().size(), 2);
}

TEST_F(GrpcStreamingReaderTest, ErrorOnWrite) {
  ForceFinish({/*Write*/ Error, /*Read*/ Error});
  EXPECT_FALSE(status().has_value());

  ForceFinish(
      {/*Finish*/ grpc::Status{grpc::StatusCode::RESOURCE_EXHAUSTED, ""}});
  EXPECT_TRUE(status().has_value());
  EXPECT_TRUE(responses().empty());
}

TEST_F(GrpcStreamingReaderTest, CanFinish) {
  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] { reader().FinishImmediately(); });
  EXPECT_FALSE(status().has_value());
  EXPECT_TRUE(responses().empty());
}

TEST_F(GrpcStreamingReaderTest, CanFinishTwice) {
  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] {
    reader().FinishImmediately();
    EXPECT_NO_THROW(reader().FinishImmediately());
  });
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
