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

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using auth::EmptyCredentialsProvider;
using core::DatabaseInfo;
using model::DatabaseId;
using util::AsyncQueue;
using util::internal::ExecutorLibdispatch;

namespace {

class NoOpObserver : public GrpcStreamObserver {
 public:
  void OnStreamStart() override {
  }
  void OnStreamRead(const grpc::ByteBuffer& message) override {
  }
  void OnStreamFinish(const util::Status& status) override {
  }
};

std::unique_ptr<Datastore> CreateDatastore(const DatabaseInfo& database_info,
                                           AsyncQueue* async_queue,
                                           CredentialsProvider* credentials) {
  return absl::make_unique<Datastore>(
      database_info, async_queue, credentials,
      [[FSTSerializerBeta alloc]
          initWithDatabaseID:&database_info.database_id()]);
}

}  // namespace

class DatastoreTest : public testing::Test {
 public:
  DatastoreTest()
      : async_queue{absl::make_unique<ExecutorLibdispatch>(
            dispatch_queue_create("datastore_test", DISPATCH_QUEUE_SERIAL))},
        database_info_{DatabaseId{"foo", "bar"}, "", "", false},
        datastore{
            CreateDatastore(database_info_, &async_queue, &credentials_)} {
  }

  ~DatastoreTest() {
    if (!is_shut_down_) {
      Shutdown();
    }
  }

  void Shutdown() {
    is_shut_down_ = true;
    datastore->Shutdown();
  }

 private:
  bool is_shut_down_ = false;
  DatabaseInfo database_info_;
  EmptyCredentialsProvider credentials_;

 public:
  AsyncQueue async_queue;
  std::unique_ptr<Datastore> datastore;
};

TEST_F(DatastoreTest, CanShutdownWithNoOperations) {
  Shutdown();
}

TEST_F(DatastoreTest, WhitelistedHeaders) {
  GrpcStream::Metadata headers = {
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
