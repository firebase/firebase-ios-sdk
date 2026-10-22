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

#include "Firestore/core/src/remote/grpc_connection.h"

#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/credentials/auth_token.h"
#include "Firestore/core/src/remote/connectivity_monitor.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/test/unit/remote/grpc_stream_tester.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using core::DatabaseInfo;
using credentials::AuthToken;
using credentials::User;
using util::AsyncQueue;
using util::Status;
using util::StatusOr;

using NetworkStatus = ConnectivityMonitor::NetworkStatus;
using ResponsesT = grpc::ByteBuffer;

namespace {

class FakeConnectivityMonitor : public ConnectivityMonitor {
 public:
  explicit FakeConnectivityMonitor(
      const std::shared_ptr<AsyncQueue>& worker_queue)
      : ConnectivityMonitor{worker_queue} {
    SetInitialStatus(NetworkStatus::Available);
  }

  void set_status(NetworkStatus new_status) {
    MaybeInvokeCallbacks(new_status);
  }
};

bool IsConnectivityChange(const Status& status) {
  return status.code() == Error::kErrorUnavailable;
}

class ConnectivityObserver : public GrpcStreamObserver {
 public:
  void OnStreamStart() override {
  }
  void OnStreamRead(const grpc::ByteBuffer&) override {
  }
  void OnStreamFinish(const util::Status& status) override {
    if (IsConnectivityChange(status)) {
      ++connectivity_change_count_;
    }
  }

  int connectivity_change_count() const {
    return connectivity_change_count_;
  }
  int connectivity_change_count_ = 0;
};

}  // namespace

class GrpcConnectionTest : public testing::Test {
 public:
  GrpcConnectionTest()
      : worker_queue{testutil::AsyncQueueForTesting()},
        connectivity_monitor{
            absl::make_unique<FakeConnectivityMonitor>(worker_queue)},
        tester{worker_queue, connectivity_monitor.get()} {
  }

  void SetNetworkStatus(NetworkStatus new_status) {
    worker_queue->EnqueueBlocking(
        [&] { connectivity_monitor->set_status(new_status); });
    // Make sure the callback executes.
    worker_queue->EnqueueBlocking([] {});
  }

  std::shared_ptr<AsyncQueue> worker_queue;
  std::unique_ptr<FakeConnectivityMonitor> connectivity_monitor = nullptr;
  GrpcStreamTester tester;
};

TEST_F(GrpcConnectionTest, GrpcStreamsNoticeChangeInConnectivity) {
  ConnectivityObserver observer;

  std::unique_ptr<GrpcStream> stream = tester.CreateStream(&observer);
  stream->Start();
  EXPECT_EQ(observer.connectivity_change_count(), 0);

  SetNetworkStatus(NetworkStatus::Available);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(observer.connectivity_change_count(), 0);

  tester.KeepPollingGrpcQueue();
  SetNetworkStatus(NetworkStatus::Unavailable);
  EXPECT_EQ(observer.connectivity_change_count(), 1);
}

TEST_F(GrpcConnectionTest, GrpcStreamingCallsNoticeChangeInConnectivity) {
  int change_count = 0;
  std::unique_ptr<GrpcStreamingReader> streaming_call =
      tester.CreateStreamingReader();
  streaming_call->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status& st, bool) {
        if (IsConnectivityChange(st)) {
          ++change_count;
        }
      });

  SetNetworkStatus(NetworkStatus::Available);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(change_count, 0);

  tester.KeepPollingGrpcQueue();
  SetNetworkStatus(NetworkStatus::AvailableViaCellular);
  EXPECT_EQ(change_count, 1);
}

TEST_F(GrpcConnectionTest, GrpcUnaryCallsNoticeChangeInConnectivity) {
  int change_count = 0;
  std::unique_ptr<GrpcUnaryCall> unary_call = tester.CreateUnaryCall();
  unary_call->Start([&](const StatusOr<grpc::ByteBuffer>& result) {
    if (IsConnectivityChange(result.status())) {
      ++change_count;
    }
  });

  SetNetworkStatus(NetworkStatus::Available);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(change_count, 0);

  tester.KeepPollingGrpcQueue();
  SetNetworkStatus(NetworkStatus::AvailableViaCellular);
  EXPECT_EQ(change_count, 1);
}

TEST_F(GrpcConnectionTest, ConnectivityChangeWithSeveralActiveCalls) {
  int changes_count = 0;

  std::unique_ptr<GrpcStreamingReader> foo = tester.CreateStreamingReader();
  foo->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status&, bool) {
        ++changes_count;
        foo.reset();
      });

  std::unique_ptr<GrpcStreamingReader> bar = tester.CreateStreamingReader();
  bar->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status&, bool) {
        ++changes_count;
        bar.reset();
      });

  std::unique_ptr<GrpcStreamingReader> baz = tester.CreateStreamingReader();
  baz->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status&, bool) {
        ++changes_count;
        baz.reset();
      });

  tester.KeepPollingGrpcQueue();
  // Calls will be unregistering themselves with `GrpcConnection` as it notifies
  // them, make sure nothing breaks.
  EXPECT_NO_THROW(SetNetworkStatus(NetworkStatus::Unavailable));
  EXPECT_EQ(changes_count, 3);
}

TEST_F(GrpcConnectionTest, ShutdownFastFinishesActiveCalls) {
  class NoFinishObserver : public GrpcStreamObserver {
   public:
    void OnStreamStart() override {
    }
    void OnStreamRead(const grpc::ByteBuffer&) override {
    }
    void OnStreamFinish(const util::Status&) override {
      FAIL() << "Observer shouldn't have been invoked";
    }
  };

  NoFinishObserver observer;
  std::unique_ptr<GrpcStream> foo = tester.CreateStream(&observer);
  foo->Start();

  std::unique_ptr<GrpcStreamingReader> bar = tester.CreateStreamingReader();
  bar->Start(
      0, [&](const std::vector<ResponsesT>) {},
      [&](const util::Status&, bool) {
        FAIL() << "Callback shouldn't have been invoked";
      });

  std::unique_ptr<GrpcUnaryCall> baz = tester.CreateUnaryCall();
  baz->Start([](const StatusOr<grpc::ByteBuffer>&) {
    FAIL() << "Callback shouldn't have been invoked";
  });

  tester.KeepPollingGrpcQueue();
  worker_queue->EnqueueBlocking([&] { tester.grpc_connection()->Shutdown(); });

  // Destroying a call will throw if it hasn't been properly shut down.
  EXPECT_NO_THROW(foo.reset());
  EXPECT_NO_THROW(bar.reset());
  EXPECT_NO_THROW(baz.reset());
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
