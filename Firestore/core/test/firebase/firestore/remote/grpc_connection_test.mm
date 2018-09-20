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

#include <memory>
#include <string>

#include "Firestore/core/src/firebase/firestore/auth/token.h"
#include "Firestore/core/src/firebase/firestore/remote/connectivity_monitor.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_connection.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "Firestore/core/test/firebase/firestore/util/grpc_stream_tester.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::Token;
using auth::User;
using core::DatabaseInfo;
using model::DatabaseId;
using util::AsyncQueue;
using util::Status;
using util::internal::ExecutorStd;
using NetworkStatus = ConnectivityMonitor::NetworkStatus;

namespace {

class MockConnectivityMonitor : public ConnectivityMonitor {
 public:
  MockConnectivityMonitor(AsyncQueue* worker_queue)
      : ConnectivityMonitor{worker_queue} {
    SetInitialStatus(NetworkStatus::Reachable);
  }

  void set_status(NetworkStatus new_status) {
    MaybeInvokeCallbacks(new_status);
  }
};

bool IsConnectivityChange(const Status& status) {
  return status.code() == FirestoreErrorCode::Unavailable &&
         status.error_message() == "Network connectivity changed";
}

class ConnectivityObserver : public GrpcStreamObserver {
 public:
  void OnStreamStart() override {
  }
  void OnStreamRead(const grpc::ByteBuffer& message) override {
  }
  void OnStreamError(const util::Status& status) override {
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
      : worker_queue{absl::make_unique<ExecutorStd>()},
        database_info_{DatabaseId{"foo", "bar"}, "", "", false},
        mock_grpc_queue{&worker_queue} {
    auto connectivity_monitor_owning =
        absl::make_unique<MockConnectivityMonitor>(&worker_queue);
    connectivity_monitor = connectivity_monitor_owning.get();
    grpc_connection = absl::make_unique<GrpcConnection>(
        database_info_, &worker_queue, mock_grpc_queue.queue(),
        std::move(connectivity_monitor_owning));
  }

  void SetNetworkStatus(NetworkStatus new_status) {
    connectivity_monitor->set_status(new_status);
    // Make sure the callback executes.
    worker_queue.EnqueueBlocking([] {});
  }

 private:
  DatabaseInfo database_info_;

 public:
  AsyncQueue worker_queue;
  MockConnectivityMonitor* connectivity_monitor = nullptr;
  util::MockGrpcQueue mock_grpc_queue;
  std::unique_ptr<GrpcConnection> grpc_connection;
};

TEST_F(GrpcConnectionTest, GrpcStreamsNoticeChangeInConnectivity) {
  ConnectivityObserver observer;

  auto stream = grpc_connection->CreateStream("", Token{"", User{}}, &observer);
  stream->Start();
  EXPECT_EQ(observer.connectivity_change_count(), 0);

  SetNetworkStatus(NetworkStatus::Reachable);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(observer.connectivity_change_count(), 0);

  mock_grpc_queue.KeepPolling();
  SetNetworkStatus(NetworkStatus::Unreachable);
  EXPECT_EQ(observer.connectivity_change_count(), 1);
}

TEST_F(GrpcConnectionTest, GrpcUnaryCallsNoticeChangeInConnectivity) {
  int change_count = 0;

  auto unary_call = grpc_connection->CreateUnaryCall("", Token{"", User{}},
                                                     grpc::ByteBuffer{});
  unary_call->Start([&](const Status& status, const grpc::ByteBuffer&) {
    if (IsConnectivityChange(status)) {
      ++change_count;
    }
  });

  SetNetworkStatus(NetworkStatus::Reachable);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(change_count, 0);

  mock_grpc_queue.KeepPolling();
  SetNetworkStatus(NetworkStatus::Unreachable);
  EXPECT_EQ(change_count, 1);
}

TEST_F(GrpcConnectionTest, GrpcStreamingCallsNoticeChangeInConnectivity) {
  int change_count = 0;
  auto streaming_call = grpc_connection->CreateStreamingReader(
      "", Token{"", User{}}, grpc::ByteBuffer{});
  streaming_call->Start(
      [&](const Status& status, const std::vector<grpc::ByteBuffer>&) {
        if (IsConnectivityChange(status)) {
          ++change_count;
        }
      });

  SetNetworkStatus(NetworkStatus::Reachable);
  // Same status shouldn't trigger a callback.
  EXPECT_EQ(change_count, 0);

  mock_grpc_queue.KeepPolling();
  SetNetworkStatus(NetworkStatus::ReachableViaCellular);
  EXPECT_EQ(change_count, 1);
}

TEST_F(GrpcConnectionTest, ConnectivityChangeWithSeveralActiveCalls) {
  int changes_count = 0;
  auto unary_call_foo = grpc_connection->CreateUnaryCall("", Token{"", User{}},
                                                         grpc::ByteBuffer{});
  unary_call_foo->Start([&](const Status&, const grpc::ByteBuffer&) {
    unary_call_foo.reset();
    ++changes_count;
  });
  auto unary_call_bar = grpc_connection->CreateUnaryCall("", Token{"", User{}},
                                                         grpc::ByteBuffer{});
  unary_call_bar->Start([&](const Status&, const grpc::ByteBuffer&) {
    unary_call_bar.reset();
    ++changes_count;
  });
  auto unary_call_baz = grpc_connection->CreateUnaryCall("", Token{"", User{}},
                                                         grpc::ByteBuffer{});
  unary_call_baz->Start([&](const Status&, const grpc::ByteBuffer&) {
    unary_call_baz.reset();
    ++changes_count;
  });

  mock_grpc_queue.KeepPolling();
  EXPECT_NO_THROW(SetNetworkStatus(NetworkStatus::Unreachable));
  EXPECT_EQ(changes_count, 3);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
