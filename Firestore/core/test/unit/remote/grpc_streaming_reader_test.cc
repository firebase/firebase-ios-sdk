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
#include <utility>
#include <vector>

#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/string_format.h"
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
using util::StringFormat;
using Type = GrpcCompletion::Type;
using ResponsesT = grpc::ByteBuffer;

class GrpcStreamingReaderTest : public testing::Test {
 public:
  GrpcStreamingReaderTest()
      : worker_queue{testutil::AsyncQueueForTesting()},
        connectivity_monitor{CreateNoOpConnectivityMonitor()},
        tester{worker_queue, connectivity_monitor.get()},
        reader{tester.CreateStreamingReader()} {
  }

  ~GrpcStreamingReaderTest() {
    if (reader) {
      // It's okay to call `FinishImmediately` more than once.
      KeepPollingGrpcQueue();
      worker_queue->EnqueueBlocking([&] { reader->FinishImmediately(); });
    }
    tester.Shutdown();
  }

  void ForceFinish(std::initializer_list<CompletionEndState> results) {
    tester.ForceFinish(reader->context(), results);
  }
  void ForceFinish(const GrpcStreamTester::CompletionCallback& callback) {
    tester.ForceFinish(reader->context(), callback);
  }
  void ForceFinishAnyTypeOrder(
      std::initializer_list<CompletionEndState> results) {
    tester.ForceFinishAnyTypeOrder(reader->context(), results);
  }

  void KeepPollingGrpcQueue() {
    tester.KeepPollingGrpcQueue();
  }

  void StartReader(size_t expected_response_count) {
    worker_queue->EnqueueBlocking([&] {
      reader->Start(
          expected_response_count,
          [&](std::vector<ResponsesT> result) {
            responses = std::move(result);
          },
          [&](const util::Status& st, bool) { status = st; });
    });
  }

  std::shared_ptr<AsyncQueue> worker_queue;
  std::unique_ptr<ConnectivityMonitor> connectivity_monitor;
  GrpcStreamTester tester;

  std::unique_ptr<GrpcStreamingReader> reader;

  absl::optional<Status> status;
  std::vector<grpc::ByteBuffer> responses;
};

// API usage

TEST_F(GrpcStreamingReaderTest, FinishImmediatelyIsIdempotent) {
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_NO_THROW(reader->FinishImmediately()); });

  StartReader(0);

  KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(reader->FinishImmediately());
    EXPECT_NO_THROW(reader->FinishAndNotify(Status::OK()));
    EXPECT_NO_THROW(reader->FinishImmediately());
  });
}

// Method prerequisites -- correct usage of `GetResponseHeaders`

TEST_F(GrpcStreamingReaderTest, CanGetResponseHeadersAfterStarting) {
  StartReader(0);
  EXPECT_NO_THROW(reader->GetResponseHeaders());
}

TEST_F(GrpcStreamingReaderTest, CanGetResponseHeadersAfterFinishing) {
  StartReader(0);

  KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking([&] {
    reader->FinishImmediately();
    EXPECT_NO_THROW(reader->GetResponseHeaders());
  });
}

// Method prerequisites -- incorrect usage

TEST_F(GrpcStreamingReaderTest, CannotFinishAndNotifyBeforeStarting) {
  // No callback has been assigned.
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_ANY_THROW(reader->FinishAndNotify(Status::OK())); });
}

// Normal operation

TEST_F(GrpcStreamingReaderTest, OneSuccessfulRead) {
  StartReader(1);

  ForceFinishAnyTypeOrder({
      {Type::Write, CompletionResult::Ok},
      {Type::Read, MakeByteBuffer("foo")},
      /*Read after last*/ {Type::Read, CompletionResult::Error},
  });

  EXPECT_FALSE(status.has_value());

  ForceFinish({{Type::Finish, grpc::Status::OK}});

  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value(), Status::OK());
  ASSERT_EQ(responses.size(), 1);
  EXPECT_EQ(ByteBufferToString(responses[0]), std::string{"foo"});
}

TEST_F(GrpcStreamingReaderTest, TwoSuccessfulReads) {
  StartReader(2);

  ForceFinishAnyTypeOrder({
      {Type::Write, CompletionResult::Ok},
      {Type::Read, MakeByteBuffer("foo")},
      {Type::Read, MakeByteBuffer("bar")},
      /*Read after last*/ {Type::Read, CompletionResult::Error},
  });
  EXPECT_FALSE(status.has_value());

  ForceFinish({{Type::Finish, grpc::Status::OK}});

  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value(), Status::OK());
  ASSERT_EQ(responses.size(), 2);
  EXPECT_EQ(ByteBufferToString(responses[0]), std::string{"foo"});
  EXPECT_EQ(ByteBufferToString(responses[1]), std::string{"bar"});
}

TEST_F(GrpcStreamingReaderTest, FinishWhileReading) {
  StartReader(1);

  ForceFinishAnyTypeOrder({{Type::Write, CompletionResult::Ok},
                           {Type::Read, CompletionResult::Ok}});
  EXPECT_FALSE(status.has_value());

  KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking([&] { reader->FinishImmediately(); });

  EXPECT_FALSE(status.has_value());
  ASSERT_EQ(responses.size(), 1);
}

// Errors

TEST_F(GrpcStreamingReaderTest, ErrorOnWrite) {
  StartReader(1);

  bool failed_write = false;
  auto future = tester.ForceFinishAsync([&](GrpcCompletion* completion) {
    switch (completion->type()) {
      case Type::Read:
        // After a write is failed, fail the read too.
        completion->Complete(!failed_write);
        return false;

      case Type::Write:
        failed_write = true;
        completion->Complete(false);
        return false;

      case Type::Finish:
        EXPECT_TRUE(failed_write);
        *completion->status() = grpc::Status{grpc::RESOURCE_EXHAUSTED, ""};
        completion->Complete(true);
        return true;

      default:
        ADD_FAILURE() << "Unexpected completion type "
                      << static_cast<int>(completion->type());
        return false;
    }
  });
  future.wait();
  worker_queue->EnqueueBlocking([] {});

  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value().code(), Error::kErrorResourceExhausted);
  EXPECT_TRUE(responses.empty());
}

TEST_F(GrpcStreamingReaderTest, ErrorOnFirstRead) {
  StartReader(1);

  ForceFinishAnyTypeOrder({
      {Type::Write, CompletionResult::Ok},
      {Type::Read, CompletionResult::Error},
  });

  ForceFinish(
      {{Type::Finish, grpc::Status{grpc::StatusCode::UNAVAILABLE, ""}}});
  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value().code(), Error::kErrorUnavailable);
  EXPECT_TRUE(responses.empty());
}

TEST_F(GrpcStreamingReaderTest, ErrorOnSecondRead) {
  StartReader(2);

  ForceFinishAnyTypeOrder({
      {Type::Write, CompletionResult::Ok},
      {Type::Read, CompletionResult::Ok},
      {Type::Read, CompletionResult::Error},
  });

  ForceFinish({{Type::Finish, grpc::Status{grpc::StatusCode::DATA_LOSS, ""}}});
  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value().code(), Error::kErrorDataLoss);
  EXPECT_TRUE(responses.empty());
}

// Callback destroys reader

TEST_F(GrpcStreamingReaderTest, CallbackCanDestroyReaderOnSuccess) {
  worker_queue->EnqueueBlocking([&] {
    reader->Start(
        1, [&](std::vector<ResponsesT>) {},
        [&](const util::Status&, bool) { reader.reset(); });
  });

  ForceFinishAnyTypeOrder({
      {Type::Write, CompletionResult::Ok},
      {Type::Read, MakeByteBuffer("foo")},
      /*Read after last*/ {Type::Read, CompletionResult::Error},
  });

  EXPECT_NE(reader, nullptr);
  EXPECT_NO_THROW(ForceFinish({{Type::Finish, grpc::Status::OK}}));
  EXPECT_EQ(reader, nullptr);
}

TEST_F(GrpcStreamingReaderTest, CallbackCanDestroyReaderOnError) {
  worker_queue->EnqueueBlocking([&] {
    reader->Start(
        1, [&](std::vector<ResponsesT>) {},
        [&](const util::Status&, bool) { reader.reset(); });
  });

  ForceFinishAnyTypeOrder({
      {Type::Write, CompletionResult::Ok},
      {Type::Read, CompletionResult::Error},
  });

  grpc::Status error_status{grpc::StatusCode::DATA_LOSS, ""};
  EXPECT_NE(reader, nullptr);
  EXPECT_NO_THROW(ForceFinish({{Type::Finish, error_status}}));
  EXPECT_EQ(reader, nullptr);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
