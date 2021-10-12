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

#include "Firestore/core/src/remote/stream.h"

#include <initializer_list>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/remote/grpc_completion.h"
#include "Firestore/core/src/remote/grpc_connection.h"
#include "Firestore/core/src/remote/grpc_stream.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/test/unit/remote/create_noop_connectivity_monitor.h"
#include "Firestore/core/test/unit/remote/fake_credentials_provider.h"
#include "Firestore/core/test/unit/remote/grpc_stream_tester.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/memory/memory.h"
#include "absl/strings/str_cat.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {
namespace {

using credentials::AppCheckCredentialsProvider;
using credentials::AuthCredentialsProvider;
using credentials::AuthToken;
using credentials::User;
using util::AsyncQueue;
using util::StringFormat;
using util::TimerId;

using Type = GrpcCompletion::Type;

const auto kIdleTimerId = TimerId::ListenStreamIdle;
const auto kBackoffTimerId = TimerId::ListenStreamConnectionBackoff;
const auto kHealthCheckTimerId = TimerId::HealthCheckTimeout;

class TestStream : public Stream {
 public:
  TestStream(const std::shared_ptr<AsyncQueue>& worker_queue,
             GrpcStreamTester* tester,
             std::shared_ptr<AuthCredentialsProvider> auth_credentials_provider,
             std::shared_ptr<AppCheckCredentialsProvider>
                 app_check_credentials_provider)
      : Stream{worker_queue,
               auth_credentials_provider,
               app_check_credentials_provider,
               /*GrpcConnection=*/nullptr,
               kBackoffTimerId,
               kIdleTimerId,
               kHealthCheckTimerId},
        tester_{tester} {
  }

  void WriteEmptyBuffer() {
    Write({});
  }

  void FailNextStreamRead() {
    fail_next_stream_read_ = true;
  }

  const std::vector<std::string>& observed_states() const {
    return observed_states_;
  }

  grpc::ClientContext* context() {
    return context_;
  }

 private:
  std::unique_ptr<GrpcStream> CreateGrpcStream(GrpcConnection*,
                                               const AuthToken&,
                                               const std::string&) override {
    auto result = tester_->CreateStream(this);
    context_ = result->context();
    return result;
  }
  void TearDown(GrpcStream* stream) override {
    stream->FinishImmediately();
  }

  void NotifyStreamOpen() override {
    observed_states_.push_back("NotifyStreamOpen");
  }

  util::Status NotifyStreamResponse(const grpc::ByteBuffer& message) override {
    std::string str = ByteBufferToString(message);
    if (str.empty()) {
      observed_states_.push_back("NotifyStreamResponse");
    } else {
      observed_states_.push_back(StringFormat("NotifyStreamResponse(%s)", str));
    }

    if (fail_next_stream_read_) {
      fail_next_stream_read_ = false;
      // The parent stream will issue a finish operation and block until it's
      // completed, so asynchronously polling gRPC queue is necessary.
      tester_->KeepPollingGrpcQueue();
      return util::Status{Error::kErrorInternal, ""};
    }
    return util::Status::OK();
  }

  void NotifyStreamClose(const util::Status& status) override {
    std::string message = absl::StrCat(
        "NotifyStreamClose(", GetFirestoreErrorName(status.code()), ")");
    observed_states_.push_back(message);
  }

  std::string GetDebugName() const override {
    return "";
  }

  GrpcStreamTester* tester_ = nullptr;
  std::vector<std::string> observed_states_;
  bool fail_next_stream_read_ = false;

  grpc::ClientContext* context_ = nullptr;
};

}  // namespace

class StreamTest : public testing::Test {
 public:
  StreamTest()
      : worker_queue{testutil::AsyncQueueForTesting()},
        connectivity_monitor{CreateNoOpConnectivityMonitor()},
        tester{worker_queue, connectivity_monitor.get()},
        app_check_credentials{std::make_shared<
            FakeCredentialsProvider<std::string, std::string>>()},
        auth_credentials{
            std::make_shared<FakeCredentialsProvider<AuthToken, User>>()},
        firestore_stream{std::make_shared<TestStream>(
            worker_queue, &tester, auth_credentials, app_check_credentials)} {
  }

  ~StreamTest() {
    worker_queue->EnqueueBlocking([&] {
      if (firestore_stream && firestore_stream->IsStarted()) {
        KeepPollingGrpcQueue();
        firestore_stream->Stop();
      }
    });
    tester.Shutdown();
  }

  void ForceFinish(std::initializer_list<CompletionEndState> results) {
    tester.ForceFinish(firestore_stream->context(), results);
  }
  void ForceFinish(const GrpcStreamTester::CompletionCallback& callback) {
    tester.ForceFinish(firestore_stream->context(), callback);
  }

  void KeepPollingGrpcQueue() {
    tester.KeepPollingGrpcQueue();
  }

  void StartStream() {
    worker_queue->EnqueueBlocking([&] { firestore_stream->Start(); });
    worker_queue->EnqueueBlocking([] {});
  }

  const std::vector<std::string>& observed_states() const {
    return firestore_stream->observed_states();
  }

  // This is to make `EXPECT_EQ` a little shorter and work around macro
  // limitations related to initializer lists.
  std::vector<std::string> States(std::initializer_list<std::string> states) {
    return {states};
  }

  std::shared_ptr<AsyncQueue> worker_queue;

  std::unique_ptr<ConnectivityMonitor> connectivity_monitor;
  GrpcStreamTester tester;

  std::shared_ptr<FakeCredentialsProvider<std::string, std::string>>
      app_check_credentials;
  std::shared_ptr<FakeCredentialsProvider<AuthToken, User>> auth_credentials;
  std::shared_ptr<TestStream> firestore_stream;
};

// Method prerequisites -- correct usage of `Start`

TEST_F(StreamTest, CanStart) {
  worker_queue->EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());

    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_TRUE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
  });
}

TEST_F(StreamTest, CanRestart) {
  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_NO_THROW(firestore_stream->Stop());
    EXPECT_NO_THROW(firestore_stream->Start());
  });
}

// Method prerequisites -- correct usage of `Stop`

TEST_F(StreamTest, CanStopBeforeStarting) {
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_NO_THROW(firestore_stream->Stop()); });
}

TEST_F(StreamTest, CanStopAfterStarting) {
  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_TRUE(firestore_stream->IsStarted());

    EXPECT_NO_THROW(firestore_stream->Stop());
    EXPECT_FALSE(firestore_stream->IsStarted());
  });
}

TEST_F(StreamTest, CanStopTwice) {
  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Stop());
    EXPECT_NO_THROW(firestore_stream->Stop());

    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_NO_THROW(firestore_stream->Stop());
    EXPECT_NO_THROW(firestore_stream->Stop());
  });
}

// Incorrect usage of the interface

TEST_F(StreamTest, CannotStartTwice) {
  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_ANY_THROW(firestore_stream->Start());
  });
}

TEST_F(StreamTest, CannotWriteBeforeOpen) {
  worker_queue->EnqueueBlocking([&] {
    EXPECT_ANY_THROW(firestore_stream->WriteEmptyBuffer());
    firestore_stream->Start();
    EXPECT_ANY_THROW(firestore_stream->WriteEmptyBuffer());
  });
}

// Observer

TEST_F(StreamTest, ObserverReceivesStreamOpen) {
  StartStream();
  worker_queue->EnqueueBlocking([&] {
    EXPECT_TRUE(firestore_stream->IsStarted());
    EXPECT_TRUE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(), States({"NotifyStreamOpen"}));
  });
}

TEST_F(StreamTest, ObserverReceivesStreamRead) {
  StartStream();

  ForceFinish({
      {Type::Read, MakeByteBuffer("foo")},
      {Type::Read, MakeByteBuffer("bar")},
  });

  worker_queue->EnqueueBlocking([&] {
    EXPECT_TRUE(firestore_stream->IsStarted());
    EXPECT_TRUE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(),
              States({"NotifyStreamOpen", "NotifyStreamResponse(foo)",
                      "NotifyStreamResponse(bar)"}));
  });
}

TEST_F(StreamTest, ObserverReceivesStreamClose) {
  StartStream();
  worker_queue->EnqueueBlocking([&] {
    KeepPollingGrpcQueue();
    firestore_stream->Stop();

    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(),
              States({"NotifyStreamOpen", "NotifyStreamClose(Ok)"}));
  });
}

TEST_F(StreamTest, ObserverReceivesStreamCloseOnError) {
  StartStream();

  ForceFinish({{Type::Read, CompletionResult::Error},
               {Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  worker_queue->EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(),
              States({"NotifyStreamOpen", "NotifyStreamClose(Unavailable)"}));
  });
}

// Write

TEST_F(StreamTest, SeveralWrites) {
  StartStream();

  worker_queue->EnqueueBlocking([&] {
    firestore_stream->WriteEmptyBuffer();
    firestore_stream->WriteEmptyBuffer();
  });

  int writes = 0;
  ForceFinish([&](GrpcCompletion* completion) {
    switch (completion->type()) {
      case Type::Read:
        completion->Complete(true);
        break;

      case Type::Write:
        ++writes;
        completion->Complete(true);
        break;

      default:
        ADD_FAILURE() << "Unexpected completion type "
                      << static_cast<int>(completion->type());
        break;
    }

    return writes == 2;
  });
  // Writes don't notify the observer, so just the fact that this test didn't
  // hang or crash indicates success.
}

// Auth edge cases

TEST_F(StreamTest, AuthFailureOnStart) {
  auth_credentials->FailGetToken();
  worker_queue->EnqueueBlocking([&] { firestore_stream->Start(); });

  worker_queue->EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states(), States({"NotifyStreamClose(Unknown)"}));
  });
}

TEST_F(StreamTest, AuthWhenStreamHasBeenStopped) {
  auth_credentials->DelayGetToken();

  worker_queue->EnqueueBlocking([&] {
    firestore_stream->Start();
    firestore_stream->Stop();
  });

  EXPECT_NO_THROW(auth_credentials->InvokeGetToken());
}

TEST_F(StreamTest, AuthOutlivesStream) {
  auth_credentials->DelayGetToken();

  worker_queue->EnqueueBlocking([&] {
    firestore_stream->Start();
    firestore_stream->Stop();
    firestore_stream.reset();
  });

  EXPECT_NO_THROW(auth_credentials->InvokeGetToken());
}

// AppCheck edge cases

TEST_F(StreamTest, AppCheckWhenStreamHasBeenStopped) {
  app_check_credentials->DelayGetToken();

  worker_queue->EnqueueBlocking([&] {
    firestore_stream->Start();
    firestore_stream->Stop();
  });

  EXPECT_NO_THROW(app_check_credentials->InvokeGetToken());
}

TEST_F(StreamTest, AppCheckOutlivesStream) {
  app_check_credentials->DelayGetToken();

  worker_queue->EnqueueBlocking([&] {
    firestore_stream->Start();
    firestore_stream->Stop();
    firestore_stream.reset();
  });

  EXPECT_NO_THROW(app_check_credentials->InvokeGetToken());
}

// Idleness

TEST_F(StreamTest, ClosesOnIdle) {
  StartStream();

  worker_queue->EnqueueBlocking([&] { firestore_stream->MarkIdle(); });

  EXPECT_TRUE(worker_queue->IsScheduled(kIdleTimerId));
  KeepPollingGrpcQueue();
  worker_queue->RunScheduledOperationsUntil(kIdleTimerId);

  worker_queue->EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states().back(), "NotifyStreamClose(Ok)");
  });
}

TEST_F(StreamTest, CancelIdleCheck) {
  StartStream();

  worker_queue->EnqueueBlocking([&] { firestore_stream->MarkIdle(); });
  EXPECT_TRUE(worker_queue->IsScheduled(kIdleTimerId));

  worker_queue->EnqueueBlocking([&] { firestore_stream->CancelIdleCheck(); });
  EXPECT_FALSE(worker_queue->IsScheduled(kIdleTimerId));
}

TEST_F(StreamTest, WriteCancelsIdle) {
  StartStream();

  worker_queue->EnqueueBlocking([&] { firestore_stream->MarkIdle(); });
  EXPECT_TRUE(worker_queue->IsScheduled(kIdleTimerId));

  worker_queue->EnqueueBlocking([&] { firestore_stream->WriteEmptyBuffer(); });
  EXPECT_FALSE(worker_queue->IsScheduled(kIdleTimerId));
}

// Backoff

TEST_F(StreamTest, Backoff) {
  StartStream();
  EXPECT_FALSE(worker_queue->IsScheduled(kBackoffTimerId));

  // "ResourceExhausted" sets backoff to max, virtually guaranteeing that the
  // backoff won't kick in in-between the checks.
  ForceFinish({{Type::Read, CompletionResult::Error},
               {Type::Finish, grpc::Status{grpc::RESOURCE_EXHAUSTED, ""}}});
  EXPECT_FALSE(worker_queue->IsScheduled(kBackoffTimerId));

  StartStream();
  EXPECT_TRUE(worker_queue->IsScheduled(kBackoffTimerId));
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_FALSE(firestore_stream->IsOpen()); });

  worker_queue->RunScheduledOperationsUntil(kBackoffTimerId);
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_TRUE(firestore_stream->IsOpen()); });

  ForceFinish({{Type::Read, CompletionResult::Error},
               {Type::Finish, grpc::Status{grpc::RESOURCE_EXHAUSTED, ""}}});
  worker_queue->EnqueueBlocking([&] { firestore_stream->InhibitBackoff(); });
  StartStream();
  EXPECT_FALSE(worker_queue->IsScheduled(kBackoffTimerId));
}

// Errors

// Error on read is tested in `ObserverReceivesStreamCloseOnError`.

TEST_F(StreamTest, ErrorOnWrite) {
  StartStream();
  worker_queue->EnqueueBlocking([&] { firestore_stream->WriteEmptyBuffer(); });

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
        *completion->status() = grpc::Status{grpc::UNAUTHENTICATED, ""};
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

  worker_queue->EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states().back(), "NotifyStreamClose(Unauthenticated)");
  });
}

TEST_F(StreamTest, ClientSideErrorOnRead) {
  StartStream();

  firestore_stream->FailNextStreamRead();
  ForceFinish({{Type::Read, CompletionResult::Ok}});

  worker_queue->EnqueueBlocking([&] {
    EXPECT_FALSE(firestore_stream->IsStarted());
    EXPECT_FALSE(firestore_stream->IsOpen());
    EXPECT_EQ(observed_states().back(), "NotifyStreamClose(Internal)");
  });
}

TEST_F(StreamTest, RefreshesTokenUponExpiration) {
  StartStream();
  ForceFinish({{Type::Read, CompletionResult::Error},
               {Type::Finish, grpc::Status{grpc::UNAUTHENTICATED, ""}}});
  // Error "Unauthenticated" should invalidate the token.
  EXPECT_EQ(auth_credentials->observed_states(),
            States({"GetToken", "InvalidateToken"}));
  EXPECT_EQ(app_check_credentials->observed_states(),
            States({"GetToken", "InvalidateToken"}));

  worker_queue->EnqueueBlocking([&] { firestore_stream->InhibitBackoff(); });
  StartStream();
  ForceFinish({{Type::Read, CompletionResult::Error},
               {Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});
  // Simulate a different error -- token should not be invalidated this time.
  EXPECT_EQ(auth_credentials->observed_states(),
            States({"GetToken", "InvalidateToken", "GetToken"}));
  EXPECT_EQ(app_check_credentials->observed_states(),
            States({"GetToken", "InvalidateToken", "GetToken"}));
}

TEST_F(StreamTest, TokenIsNotInvalidatedOnceStreamIsHealthy) {
  StartStream();
  worker_queue->RunScheduledOperationsUntil(kHealthCheckTimerId);
  ForceFinish({{Type::Read, CompletionResult::Error},
               {Type::Finish, grpc::Status{grpc::UNAUTHENTICATED, ""}}});
  // Error "Unauthenticated" on a healthy connection should not invalidate the
  // token.
  EXPECT_EQ(auth_credentials->observed_states(), States({"GetToken"}));
  EXPECT_EQ(app_check_credentials->observed_states(), States({"GetToken"}));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
