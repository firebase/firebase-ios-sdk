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
#include <map>
#include <memory>
#include <queue>
#include <utility>
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
using util::ByteBufferToString;
using util::CompletionEndState;
using util::GetFirestoreErrorCodeName;
using util::GetGrpcErrorCodeName;
using util::GrpcStreamTester;
using util::MakeByteBuffer;
using util::Status;
using util::StatusOr;
using util::StringFormat;
using util::CompletionResult::Error;
using util::CompletionResult::Ok;
using util::internal::ExecutorStd;
using Type = GrpcCompletion::Type;

class GrpcStreamingReaderTest : public testing::Test {
 public:
  GrpcStreamingReaderTest()
      : worker_queue{absl::make_unique<ExecutorStd>()},
        connectivity_monitor{ConnectivityMonitor::CreateNoOpMonitor()},
        tester{&worker_queue, connectivity_monitor.get()},
        reader{tester.CreateStreamingReader()} {
  }

  ~GrpcStreamingReaderTest() {
    if (reader) {
      // It's okay to call `FinishImmediately` more than once.
      KeepPollingGrpcQueue();
      worker_queue.EnqueueBlocking([&] { reader->FinishImmediately(); });
    }
    tester.Shutdown();
  }

  void ForceFinish(std::initializer_list<CompletionEndState> results) {
    tester.ForceFinish(reader->context(), results);
  }
  void ForceFinish(const GrpcStreamTester::CompletionCallback& callback) {
    tester.ForceFinish(reader->context(), callback);
  }

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
      std::initializer_list<CompletionEndState> results) {
    std::map<GrpcCompletion::Type, std::queue<CompletionEndState>> end_states;
    for (auto result : results) {
      end_states[result.type()].push(result);
    }

    ForceFinish([&](GrpcCompletion* completion) {
      std::queue<CompletionEndState>& end_states_for_type =
          end_states[completion->type()];
      HARD_ASSERT(!end_states_for_type.empty(),
                  "Missing end state for completion of type '%s'",
                  completion->type());

      CompletionEndState end_state = end_states_for_type.front();
      end_states_for_type.pop();
      end_state.Apply(completion);

      for (const auto& kv : end_states) {
        if (!kv.second.empty()) {
          return false;
        }
      }

      // All end states have been applied
      return true;
    });
  }

  void KeepPollingGrpcQueue() {
    tester.KeepPollingGrpcQueue();
  }

  void StartReader() {
    worker_queue.EnqueueBlocking([&] {
      reader->Start(
          [this](const StatusOr<std::vector<grpc::ByteBuffer>>& result) {
            status = result.status();
            if (status->ok()) {
              responses = std::move(result).ValueOrDie();
            }
          });
    });
  }

  AsyncQueue worker_queue;
  std::unique_ptr<ConnectivityMonitor> connectivity_monitor;
  GrpcStreamTester tester;

  std::unique_ptr<GrpcStreamingReader> reader;

  absl::optional<Status> status;
  std::vector<grpc::ByteBuffer> responses;
};

// Method prerequisites -- correct usage of `FinishImmediately`

TEST_F(GrpcStreamingReaderTest, CanFinishBeforeStarting) {
  worker_queue.EnqueueBlocking(
      [&] { EXPECT_NO_THROW(reader->FinishImmediately()); });
}

TEST_F(GrpcStreamingReaderTest, CanFinishAfterStarting) {
  StartReader();

  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking(
      [&] { EXPECT_NO_THROW(reader->FinishImmediately()); });
}

TEST_F(GrpcStreamingReaderTest, CanFinishMoreThanOnce) {
  StartReader();

  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] {
    EXPECT_NO_THROW(reader->FinishImmediately());
    EXPECT_NO_THROW(reader->FinishImmediately());
  });
}

// Method prerequisites -- correct usage of `FinishAndNotify`

TEST_F(GrpcStreamingReaderTest, CanFinishAndNotifyAfterStarting) {
  StartReader();

  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking(
      [&] { EXPECT_NO_THROW(reader->FinishAndNotify(Status::OK())); });
}

TEST_F(GrpcStreamingReaderTest, CanFinishAndNotifyMoreThanOnce) {
  StartReader();

  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] {
    EXPECT_NO_THROW(reader->FinishAndNotify(Status::OK()));
    EXPECT_NO_THROW(reader->FinishAndNotify(Status::OK()));
  });
}

// Method prerequisites -- correct usage of `GetResponseHeaders`

TEST_F(GrpcStreamingReaderTest, CanGetResponseHeadersAfterStarting) {
  StartReader();
  EXPECT_NO_THROW(reader->GetResponseHeaders());
}

TEST_F(GrpcStreamingReaderTest, CanGetResponseHeadersAfterFinishing) {
  StartReader();

  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] {
    reader->FinishImmediately();
    EXPECT_NO_THROW(reader->GetResponseHeaders());
  });
}

// Method prerequisites -- incorrect usage

// Death tests should contain the word "DeathTest" in their name -- see
// https://github.com/google/googletest/blob/master/googletest/docs/advanced.md#death-test-naming
using GrpcStreamingReaderDeathTest = GrpcStreamingReaderTest;

TEST_F(GrpcStreamingReaderDeathTest, CannotStartTwice) {
  StartReader();
  EXPECT_DEATH_IF_SUPPORTED(StartReader(), "");
}

TEST_F(GrpcStreamingReaderDeathTest, CannotRestart) {
  StartReader();
  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] { reader->FinishImmediately(); });
  EXPECT_DEATH_IF_SUPPORTED(StartReader(), "");
}

TEST_F(GrpcStreamingReaderTest, CannotFinishAndNotifyBeforeStarting) {
  worker_queue.EnqueueBlocking(
      [&] { EXPECT_ANY_THROW(reader->FinishAndNotify(Status::OK())); });
}

// Normal operation

TEST_F(GrpcStreamingReaderTest, OneSuccessfulRead) {
  StartReader();

  ForceFinishAnyTypeOrder({
      {Type::Write, Ok},
      {Type::Read, MakeByteBuffer("foo")},
      /*Read after last*/ {Type::Read, Error},
  });

  EXPECT_FALSE(status.has_value());

  ForceFinish({{Type::Finish, grpc::Status::OK}});

  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value(), Status::OK());
  ASSERT_EQ(responses.size(), 1);
  EXPECT_EQ(ByteBufferToString(responses[0]), std::string{"foo"});
}

TEST_F(GrpcStreamingReaderTest, TwoSuccessfulReads) {
  StartReader();

  ForceFinishAnyTypeOrder({
      {Type::Write, Ok},
      {Type::Read, MakeByteBuffer("foo")},
      {Type::Read, MakeByteBuffer("bar")},
      /*Read after last*/ {Type::Read, Error},
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
  StartReader();

  ForceFinishAnyTypeOrder({{Type::Write, Ok}, {Type::Read, Ok}});
  EXPECT_FALSE(status.has_value());

  KeepPollingGrpcQueue();
  worker_queue.EnqueueBlocking([&] { reader->FinishImmediately(); });

  EXPECT_FALSE(status.has_value());
  EXPECT_TRUE(responses.empty());
}

// Errors

TEST_F(GrpcStreamingReaderTest, ErrorOnWrite) {
  StartReader();

  bool failed_write = false;
  // Callback is used because it's indeterminate whether one or two read
  // operations will have a chance to succeed.
  ForceFinish([&](GrpcCompletion* completion) {
    switch (completion->type()) {
      case Type::Read:
        completion->Complete(true);
        break;

      case Type::Write:
        failed_write = true;
        completion->Complete(false);
        break;

      default:
        EXPECT_TRUE(false) << "Unexpected completion type "
                           << static_cast<int>(completion->type());
        break;
    }

    return failed_write;
  });

  ForceFinish(
      {{Type::Read, Error},
       {Type::Finish, grpc::Status{grpc::StatusCode::RESOURCE_EXHAUSTED, ""}}});
  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value().code(), FirestoreErrorCode::ResourceExhausted);
  EXPECT_TRUE(responses.empty());
}

TEST_F(GrpcStreamingReaderTest, ErrorOnFirstRead) {
  StartReader();

  ForceFinishAnyTypeOrder({
      {Type::Write, Ok},
      {Type::Read, Error},
  });

  ForceFinish(
      {{Type::Finish, grpc::Status{grpc::StatusCode::UNAVAILABLE, ""}}});
  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value().code(), FirestoreErrorCode::Unavailable);
  EXPECT_TRUE(responses.empty());
}

TEST_F(GrpcStreamingReaderTest, ErrorOnSecondRead) {
  StartReader();

  ForceFinishAnyTypeOrder({
      {Type::Write, Ok},
      {Type::Read, Ok},
      {Type::Read, Error},
  });

  ForceFinish({{Type::Finish, grpc::Status{grpc::StatusCode::DATA_LOSS, ""}}});
  ASSERT_TRUE(status.has_value());
  EXPECT_EQ(status.value().code(), FirestoreErrorCode::DataLoss);
  EXPECT_TRUE(responses.empty());
}

// Callback destroys reader

TEST_F(GrpcStreamingReaderTest, CallbackCanDestroyStreamOnSuccess) {
  worker_queue.EnqueueBlocking([&] {
    reader->Start([this](const StatusOr<std::vector<grpc::ByteBuffer>>&) {
      reader.reset();
    });
  });

  ForceFinishAnyTypeOrder({
      {Type::Write, Ok},
      {Type::Read, MakeByteBuffer("foo")},
      /*Read after last*/ {Type::Read, Error},
  });

  EXPECT_NE(reader, nullptr);
  EXPECT_NO_THROW(ForceFinish({{Type::Finish, grpc::Status::OK}}));
  EXPECT_EQ(reader, nullptr);
}

TEST_F(GrpcStreamingReaderTest, CallbackCanDestroyStreamOnError) {
  worker_queue.EnqueueBlocking([&] {
    reader->Start([this](const StatusOr<std::vector<grpc::ByteBuffer>>&) {
      reader.reset();
    });
  });

  ForceFinishAnyTypeOrder({
      {Type::Write, Ok},
      {Type::Read, Error},
  });

  grpc::Status error_status{grpc::StatusCode::DATA_LOSS, ""};
  EXPECT_NE(reader, nullptr);
  EXPECT_NO_THROW(ForceFinish({{Type::Finish, error_status}}));
  EXPECT_EQ(reader, nullptr);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
