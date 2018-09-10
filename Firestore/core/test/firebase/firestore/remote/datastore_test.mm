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

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using core::DatabaseInfo;
using model::DatabaseId;
using util::AsyncQueue;
using util::internal::ExecutorStd;

namespace {

class NoOpObserver : public GrpcStreamObserver {
 public:
  void OnStreamStart() override {
  }
  void OnStreamRead(const grpc::ByteBuffer& message) override {
  }
  void OnStreamError(const util::Status& status) override {
  }
};

}  // namespace

class DatastoreTest : public testing::Test {
 public:
  DatastoreTest()
      : async_queue{absl::make_unique<ExecutorStd>()},
        datastore{DatabaseInfo{DatabaseId{"foo", "bar"}, "", "", false},
                  &async_queue} {
  }

  ~DatastoreTest() {
    if (!is_shut_down_) {
      Shutdown();
    }
  }

  void Shutdown() {
    is_shut_down_ = true;
    datastore.Shutdown();
  }

 private:
  bool is_shut_down_ = false;

 public:
  AsyncQueue async_queue;
  Datastore datastore;
};

TEST_F(DatastoreTest, CanShutdownWithNoOperations) {
  Shutdown();
}

TEST_F(DatastoreTest, CanShutdownWithPendingOperations) {
  NoOpObserver observer;
  std::unique_ptr<GrpcStream> grpc_stream =
      datastore.CreateGrpcStream("", "", &observer);
  async_queue.EnqueueBlocking([&] { grpc_stream->Start(); });
  async_queue.EnqueueBlocking([&] { grpc_stream->Finish(); });
  Shutdown();
}

TEST_F(DatastoreTest, WhitelistedHeaders) {
  GrpcStream::MetadataT headers = {
      {"date", "date value"},
      {"x-google-backends", "backend value"},
      {"x-google-foo", "should not be in result"},  // Not whitelisted
      {"x-google-gfe-request-trace", "request trace"},
      {"x-google-netmon-label", "netmon label"},
      {"x-google-service", "service 1"},
      {"x-google-service", "service 2"},  // Duplicate names are allowed
  };
  std::string result = Datastore::GetWhitelistedHeadersAsString(headers);
  EXPECT_EQ(result,
            "date: date value\n"
            "x-google-backends: backend value\n"
            "x-google-gfe-request-trace: request trace\n"
            "x-google-netmon-label: netmon label\n"
            "x-google-service: service 1\n"
            "x-google-service: service 2\n");
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
