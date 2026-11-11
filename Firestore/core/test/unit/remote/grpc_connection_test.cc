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

#include <atomic>
#include <chrono>
#include <future>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include "Firestore/core/src/credentials/auth_token.h"
#include "Firestore/core/src/credentials/empty_credentials_provider.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/remote/connectivity_monitor.h"
#include "Firestore/core/src/remote/datastore.h"
#include "Firestore/core/src/remote/firebase_metadata_provider_noop.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/status.h"
#include "Firestore/core/src/util/statusor.h"
#include "Firestore/core/src/util/warnings.h"
#include "Firestore/core/test/unit/remote/create_noop_connectivity_monitor.h"
#include "Firestore/core/test/unit/remote/grpc_stream_tester.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "absl/memory/memory.h"
#include "absl/strings/str_cat.h"
#include "gtest/gtest.h"

SUPPRESS_DOCUMENTATION_WARNINGS_BEGIN()
#include "grpcpp/generic/async_generic_service.h"
#include "grpcpp/security/server_credentials.h"
#include "grpcpp/server.h"
#include "grpcpp/server_builder.h"
SUPPRESS_END()

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

namespace {

// An ephemeral 127.0.0.1 plaintext gRPC server that responds to any unary RPC
// with an empty body and OK status, counting the requests it receives.
class PlaintextLoopbackServer {
 public:
  PlaintextLoopbackServer() {
    grpc::ServerBuilder builder;
    builder.AddListeningPort("127.0.0.1:0", grpc::InsecureServerCredentials(),
                             &port_);
    builder.RegisterAsyncGenericService(&generic_service_);
    cq_ = builder.AddCompletionQueue();
    server_ = builder.BuildAndStart();
    if (server_ != nullptr && port_ > 0) {
      server_thread_ = std::thread([this] { ServeLoop(); });
    }
  }

  ~PlaintextLoopbackServer() {
    if (server_ != nullptr) {
      server_->Shutdown(std::chrono::system_clock::now());
    }
    {
      std::lock_guard<std::mutex> lock(mu_);
      shutting_down_ = true;
      if (cq_ != nullptr) {
        cq_->Shutdown();
      }
    }
    if (server_thread_.joinable()) {
      server_thread_.join();
    } else if (cq_ != nullptr) {
      void* tag = nullptr;
      bool ok = false;
      while (cq_->Next(&tag, &ok)) {
      }
    }
  }

  PlaintextLoopbackServer(const PlaintextLoopbackServer&) = delete;
  PlaintextLoopbackServer& operator=(const PlaintextLoopbackServer&) = delete;

  bool started() const {
    return server_ != nullptr && port_ > 0;
  }

  std::string target() const {
    return absl::StrCat("127.0.0.1:", port_);
  }

  int request_count() const {
    return request_count_.load();
  }

 private:
  enum class Step { kRequest, kRead, kWriteAndFinish };

  struct CallState {
    grpc::GenericServerContext ctx;
    grpc::GenericServerAsyncReaderWriter stream{&ctx};
    grpc::ByteBuffer request;
    Step step = Step::kRequest;
  };

  void SpawnCall() {
    std::lock_guard<std::mutex> lock(mu_);
    if (shutting_down_) {
      return;
    }
    auto* state = new CallState();
    generic_service_.RequestCall(&state->ctx, &state->stream, cq_.get(),
                                 cq_.get(), state);
  }

  void ServeLoop() {
    SpawnCall();
    void* tag = nullptr;
    bool ok = false;
    while (cq_->Next(&tag, &ok)) {
      auto* state = static_cast<CallState*>(tag);
      if (!ok) {
        delete state;
        continue;
      }
      switch (state->step) {
        case Step::kRequest: {
          SpawnCall();
          std::lock_guard<std::mutex> lock(mu_);
          if (shutting_down_) {
            delete state;
            break;
          }
          state->step = Step::kRead;
          state->stream.Read(&state->request, state);
          break;
        }
        case Step::kRead: {
          ++request_count_;
          std::lock_guard<std::mutex> lock(mu_);
          if (shutting_down_) {
            delete state;
            break;
          }
          state->step = Step::kWriteAndFinish;
          state->stream.WriteAndFinish(grpc::ByteBuffer{}, grpc::WriteOptions{},
                                       grpc::Status::OK, state);
          break;
        }
        case Step::kWriteAndFinish:
          delete state;
          break;
      }
    }
  }

  int port_ = 0;
  grpc::AsyncGenericService generic_service_;
  std::unique_ptr<grpc::ServerCompletionQueue> cq_;
  std::unique_ptr<grpc::Server> server_;
  std::mutex mu_;
  bool shutting_down_ = false;
  std::atomic<int> request_count_{0};
  std::thread server_thread_;
};

Status RunEmptyCommit(const DatabaseInfo& db_info) {
  auto queue = testutil::AsyncQueueForTesting();
  auto monitor = CreateNoOpConnectivityMonitor();
  auto metadata = CreateFirebaseMetadataProviderNoOp();
  auto datastore = std::make_shared<Datastore>(
      db_info, queue,
      std::make_shared<credentials::EmptyAuthCredentialsProvider>(),
      std::make_shared<credentials::EmptyAppCheckCredentialsProvider>(),
      monitor.get(), metadata.get());

  std::promise<Status> done;
  std::future<Status> future = done.get_future();
  queue->EnqueueBlocking([&] {
    datastore->Start();
    datastore->CommitMutations(
        {}, [&](const Status& status) { done.set_value(status); });
  });
  Status result = future.get();
  queue->EnqueueBlocking([&] { datastore->Shutdown(); });
  return result;
}

}  // namespace

TEST_F(GrpcConnectionTest,
       InsecureInstanceDoesNotDowngradeTlsInstanceSharingHost) {
  PlaintextLoopbackServer server;
  ASSERT_TRUE(server.started());

  // First instance explicitly disables SSL for `server.target()`, so it
  // connects in plaintext and succeeds against the plaintext server.
  DatabaseInfo insecure_info(model::DatabaseId{"p", "d"}, "insecure-key",
                             server.target(), /*ssl_enabled=*/false);
  Status insecure_status = RunEmptyCommit(insecure_info);
  EXPECT_TRUE(insecure_status.ok()) << insecure_status.ToString();
  EXPECT_EQ(server.request_count(), 1);

  // Second instance targets the exact same host with `ssl_enabled = true`. It
  // must use TLS credentials rather than inheriting plaintext from the first
  // instance, so its TLS handshake against the plaintext server must fail and
  // never transmit the RPC.
  DatabaseInfo tls_info(model::DatabaseId{"p", "d"}, "tls-key", server.target(),
                        /*ssl_enabled=*/true);
  Status tls_status = RunEmptyCommit(tls_info);
  EXPECT_FALSE(tls_status.ok());
  EXPECT_EQ(server.request_count(), 1);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
