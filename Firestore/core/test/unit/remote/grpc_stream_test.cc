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

#include "Firestore/core/src/remote/grpc_stream.h"

#include <functional>
#include <initializer_list>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/remote/connectivity_monitor.h"
#include "Firestore/core/src/remote/grpc_completion.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/executor.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/string_format.h"
#include "Firestore/core/test/unit/remote/create_noop_connectivity_monitor.h"
#include "Firestore/core/test/unit/remote/grpc_stream_tester.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/memory/memory.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;
using util::Executor;
using util::Status;
using util::StringFormat;
using Type = GrpcCompletion::Type;

namespace {

class Observer : public GrpcStreamObserver {
 public:
  void OnStreamStart() override {
    observed_states.push_back("OnStreamStart");
  }
  void OnStreamRead(const grpc::ByteBuffer& message) override {
    std::string str = ByteBufferToString(message);
    if (str.empty()) {
      observed_states.push_back("OnStreamRead");
    } else {
      observed_states.push_back(StringFormat("OnStreamRead(%s)", str));
    }
  }
  void OnStreamFinish(const util::Status& status) override {
    observed_states.push_back(StringFormat(
        "OnStreamFinish(%s)", GetFirestoreErrorName(status.code())));
  }

  std::vector<std::string> observed_states;
};

class DestroyingObserver : public GrpcStreamObserver {
 public:
  enum class Destroy { OnStart, OnRead, OnFinish };

  explicit DestroyingObserver(Destroy destroy_when)
      : destroy_when{destroy_when} {
  }

  void OnStreamStart() override {
    if (destroy_when == Destroy::OnStart) {
      shutdown();
    }
  }
  void OnStreamRead(const grpc::ByteBuffer&) override {
    if (destroy_when == Destroy::OnRead) {
      shutdown();
    }
  }
  void OnStreamFinish(const util::Status&) override {
    if (destroy_when == Destroy::OnFinish) {
      shutdown();
    }
  }

  Destroy destroy_when;
  std::function<void()> shutdown;
};

}  // namespace

class GrpcStreamTest : public testing::Test {
 public:
  GrpcStreamTest()
      : worker_queue{testutil::AsyncQueueForTesting()},
        connectivity_monitor{CreateNoOpConnectivityMonitor()},
        tester{worker_queue, connectivity_monitor.get()},
        observer{absl::make_unique<Observer>()},
        stream{tester.CreateStream(observer.get())} {
  }

  ~GrpcStreamTest() {
    // It's okay to call `FinishImmediately` more than once.
    if (stream) {
      KeepPollingGrpcQueue();
      worker_queue->EnqueueBlocking([&] { stream->FinishImmediately(); });
    }
    tester.Shutdown();
  }

  void ForceFinish(std::initializer_list<CompletionEndState> results) {
    tester.ForceFinish(stream->context(), results);
  }
  void ForceFinish(const GrpcStreamTester::CompletionCallback& callback) {
    tester.ForceFinish(stream->context(), callback);
  }
  void KeepPollingGrpcQueue() {
    tester.KeepPollingGrpcQueue();
  }
  void ShutdownGrpcQueue() {
    tester.ShutdownGrpcQueue();
  }

  const std::vector<std::string>& observed_states() const {
    return observer->observed_states;
  }

  // This is to make `EXPECT_EQ` a little shorter and work around macro
  // limitations related to initializer lists.
  std::vector<std::string> States(std::initializer_list<std::string> states) {
    return {states};
  }

  void UnexpectedType(GrpcCompletion* completion) {
    ADD_FAILURE() << "Unexpected completion type "
                  << static_cast<int>(completion->type());
  }

  std::shared_ptr<AsyncQueue> worker_queue;

  std::unique_ptr<ConnectivityMonitor> connectivity_monitor;
  GrpcStreamTester tester;

  std::unique_ptr<Observer> observer;
  std::unique_ptr<GrpcStream> stream;
};

// API usage

TEST_F(GrpcStreamTest, FinishIsIdempotent) {
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_NO_THROW(stream->FinishImmediately()); });

  worker_queue->EnqueueBlocking([&] { stream->Start(); });
  KeepPollingGrpcQueue();

  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(stream->FinishImmediately());
    EXPECT_NO_THROW(stream->FinishAndNotify(Status::OK()));
    EXPECT_NO_THROW(stream->FinishImmediately());
    EXPECT_NO_THROW(stream->WriteAndFinish({}));
  });
}

TEST_F(GrpcStreamTest, CanGetResponseHeadersAfterStarting) {
  worker_queue->EnqueueBlocking([&] {
    stream->Start();
    EXPECT_NO_THROW(stream->GetResponseHeaders());
  });
}

TEST_F(GrpcStreamTest, CanGetResponseHeadersAfterFinishing) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });
  KeepPollingGrpcQueue();

  worker_queue->EnqueueBlocking([&] {
    stream->FinishImmediately();
    EXPECT_NO_THROW(stream->GetResponseHeaders());
  });
}

// Read and write

TEST_F(GrpcStreamTest, ReadIsAutomaticallyReadded) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });

  ForceFinish({{Type::Read, MakeByteBuffer("foo")}});
  EXPECT_EQ(observed_states(), States({"OnStreamStart", "OnStreamRead(foo)"}));

  ForceFinish({{Type::Read, MakeByteBuffer("bar")}});
  EXPECT_EQ(observed_states(), States({"OnStreamStart", "OnStreamRead(foo)",
                                       "OnStreamRead(bar)"}));
}

TEST_F(GrpcStreamTest, CanAddSeveralWrites) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });

  worker_queue->EnqueueBlocking([&] {
    stream->Write({});
    stream->Write({});
    stream->Write({});
  });

  int reads = 0;
  int writes = 0;
  ForceFinish([&](GrpcCompletion* completion) {
    switch (completion->type()) {
      case Type::Read:
        ++reads;
        completion->Complete(true);
        break;
      case Type::Write:
        ++writes;
        completion->Complete(true);
        break;
      default:
        UnexpectedType(completion);
        break;
    }

    bool done = writes == 3;
    return done;
  });

  EXPECT_EQ(writes, 3);
  EXPECT_EQ(observed_states().size(), reads + /*Start*/ 1);
  EXPECT_EQ(observed_states().back(), "OnStreamRead");
}

// Observer

TEST_F(GrpcStreamTest, ObserverReceivesOnStart) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });
  // `Start` is a synchronous operation.
  EXPECT_EQ(observed_states(), States({"OnStreamStart"}));
}

// `ObserverReceivesOnRead` is tested in `ReadIsAutomaticallyReadded`

TEST_F(GrpcStreamTest, ObserverReceivesOnError) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });

  ForceFinish({{Type::Read, CompletionResult::Error},
               {Type::Finish, grpc::Status{grpc::RESOURCE_EXHAUSTED, ""}}});

  EXPECT_EQ(observed_states(),
            States({"OnStreamStart", "OnStreamFinish(ResourceExhausted)"}));
}

TEST_F(GrpcStreamTest,
       ObserverDoesNotReceiveNotificationFromFinishImmediately) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });
  KeepPollingGrpcQueue();

  worker_queue->EnqueueBlocking([&] { stream->FinishImmediately(); });
  EXPECT_EQ(observed_states(), States({"OnStreamStart"}));
}

TEST_F(GrpcStreamTest, ObserverReceivesNotificationFromFinishAndNotify) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });
  KeepPollingGrpcQueue();

  worker_queue->EnqueueBlocking(
      [&] { stream->FinishAndNotify(Status(Error::kErrorUnavailable, "")); });
  EXPECT_EQ(observed_states(),
            States({"OnStreamStart", "OnStreamFinish(Unavailable)"}));
}

// Finishing

TEST_F(GrpcStreamTest, WriteAndFinish) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });
  KeepPollingGrpcQueue();

  worker_queue->EnqueueBlocking([&] {
    // Ignore the returned result; last write may or may not finish fast enough
    EXPECT_EQ(observed_states(), States({"OnStreamStart"}));
  });
}

// Errors

// Error on read is tested in `ObserverReceivesOnError`

TEST_F(GrpcStreamTest, ErrorOnWrite) {
  worker_queue->EnqueueBlocking([&] {
    stream->Start();
    stream->Write({});
  });

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
        *completion->status() = grpc::Status{grpc::ABORTED, ""};
        completion->Complete(true);
        return true;

      default:
        UnexpectedType(completion);
        return false;
    }
  });
  future.wait();
  worker_queue->EnqueueBlocking([] {});

  EXPECT_EQ(observed_states().back(), "OnStreamFinish(Aborted)");
}

TEST_F(GrpcStreamTest, ErrorWithPendingWrites) {
  worker_queue->EnqueueBlocking([&] {
    stream->Start();
    stream->Write({});
    stream->Write({});
    stream->Write({});
  });

  bool failed_write = false;
  auto future = tester.ForceFinishAsync([&](GrpcCompletion* completion) {
    switch (completion->type()) {
      case Type::Read:
        completion->Complete(!failed_write);
        return false;
      case Type::Write:
        failed_write = true;
        completion->Complete(false);
        return false;
      case Type::Finish:
        EXPECT_TRUE(failed_write);
        *completion->status() = grpc::Status{grpc::UNAVAILABLE, ""};
        completion->Complete(true);
        return true;
      default:
        UnexpectedType(completion);
        return false;
    }
  });
  future.wait();
  worker_queue->EnqueueBlocking([] {});

  EXPECT_EQ(observed_states().back(), "OnStreamFinish(Unavailable)");
}

// Stream destroyed by observer

TEST_F(GrpcStreamTest, ObserverCanFinishAndDestroyStreamOnStart) {
  using Destroy = DestroyingObserver::Destroy;
  DestroyingObserver destroying_observer{Destroy::OnStart};
  stream = tester.CreateStream(&destroying_observer);
  destroying_observer.shutdown = [&] {
    KeepPollingGrpcQueue();
    stream->FinishImmediately();
    stream.reset();
  };

  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(stream->Start());
    EXPECT_EQ(stream, nullptr);
  });
}

TEST_F(GrpcStreamTest, ObserverCanFinishAndDestroyStreamOnRead) {
  using Destroy = DestroyingObserver::Destroy;
  DestroyingObserver destroying_observer{Destroy::OnRead};
  stream = tester.CreateStream(&destroying_observer);
  destroying_observer.shutdown = [&] {
    KeepPollingGrpcQueue();
    stream->FinishImmediately();
    stream.reset();
  };

  worker_queue->EnqueueBlocking([&] { stream->Start(); });

  EXPECT_NE(stream, nullptr);
  EXPECT_NO_THROW(ForceFinish({{Type::Read, MakeByteBuffer("foo")}}));
  EXPECT_EQ(stream, nullptr);
}

TEST_F(GrpcStreamTest, ObserverCanImmediatelyDestroyStreamOnError) {
  using Destroy = DestroyingObserver::Destroy;
  DestroyingObserver destroying_observer{Destroy::OnFinish};
  stream = tester.CreateStream(&destroying_observer);
  destroying_observer.shutdown = [&] { stream.reset(); };

  worker_queue->EnqueueBlocking([&] { stream->Start(); });

  ForceFinish({{Type::Read, CompletionResult::Error}});
  EXPECT_NE(stream, nullptr);
  EXPECT_NO_THROW(ForceFinish({{Type::Finish, CompletionResult::Ok}}));
  EXPECT_EQ(stream, nullptr);
}

TEST_F(GrpcStreamTest, ObserverCanImmediatelyDestroyStreamOnFinishAndNotify) {
  using Destroy = DestroyingObserver::Destroy;
  DestroyingObserver destroying_observer{Destroy::OnFinish};
  stream = tester.CreateStream(&destroying_observer);
  destroying_observer.shutdown = [&] { stream.reset(); };

  worker_queue->EnqueueBlocking([&] { stream->Start(); });
  EXPECT_NE(stream, nullptr);

  KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking([&] {
    EXPECT_NO_THROW(stream->FinishAndNotify(util::Status::OK()));
    EXPECT_EQ(stream, nullptr);
  });
}

// Double finish

TEST_F(GrpcStreamTest, DoubleFinish_FailThenFinishImmediately) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });

  ForceFinish({{Type::Read, CompletionResult::Error}});
  KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_NO_THROW(stream->FinishImmediately()); });
}

TEST_F(GrpcStreamTest, DoubleFinish_FailThenWriteAndFinish) {
  worker_queue->EnqueueBlocking([&] { stream->Start(); });

  ForceFinish({{Type::Read, CompletionResult::Error}});
  KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking(
      [&] { EXPECT_NO_THROW(stream->WriteAndFinish({})); });
}

TEST_F(GrpcStreamTest, DoubleFinish_FailThenFailAgain) {
  worker_queue->EnqueueBlocking([&] {
    stream->Start();
    stream->Write({});
  });

  int failures_count = 0;
  auto future = tester.ForceFinishAsync([&](GrpcCompletion* completion) {
    switch (completion->type()) {
      case Type::Read:
      case Type::Write:
        ++failures_count;
        completion->Complete(false);
        return failures_count == 2;
      default:
        UnexpectedType(completion);
        return true;
    }
  });
  future.wait();
  worker_queue->EnqueueBlocking([] {});

  // Normally, "Finish" never fails, but for the test it's easier to abuse the
  // finish operation that has already been enqueued by `OnOperationFailed`
  // rather than adding a new operation.
  ForceFinish({{Type::Finish, CompletionResult::Error}});
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
