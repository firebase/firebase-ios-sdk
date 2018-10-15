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
#include "Firestore/core/src/firebase/firestore/util/executor_libdispatch.h"
#include "Firestore/core/test/firebase/firestore/util/fake_credentials_provider.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using core::DatabaseInfo;
using model::DatabaseId;
using util::AsyncQueue;
using util::FakeCredentialsProvider;
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

std::shared_ptr<Datastore> CreateDatastore(const DatabaseInfo& database_info,
                                           AsyncQueue* worker_queue,
                                           CredentialsProvider* credentials) {
  return std::make_shared<Datastore>(
      database_info, worker_queue, credentials,
      [[FSTSerializerBeta alloc]
          initWithDatabaseID:&database_info.database_id()]);
}

}  // namespace

class DatastoreTest : public testing::Test {
 public:
  DatastoreTest()
      : worker_queue{absl::make_unique<ExecutorLibdispatch>(
            dispatch_queue_create("datastore_test", DISPATCH_QUEUE_SERIAL))},
        database_info{DatabaseId{"foo", "bar"}, "", "", false},
        datastore{CreateDatastore(database_info, &worker_queue, &credentials)} {
  }

  ~DatastoreTest() {
    if (!is_shut_down) {
      Shutdown();
    }
  }

  void Shutdown() {
    is_shut_down = true;
    datastore->Shutdown();
  }

  bool is_shut_down = false;
  DatabaseInfo database_info;
  FakeCredentialsProvider credentials;

  AsyncQueue worker_queue;
  std::shared_ptr<Datastore> datastore;
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

TEST_F(DatastoreTest, CommitMutationsAuthFailure) {
  credentials.FailGetToken();

  __block NSError* resulting_error = nullptr;
  datastore->CommitMutations(@[], ^(NSError* _Nullable error) {
    resulting_error = error;
  });
  worker_queue.EnqueueBlocking([] {});
  EXPECT_NE(resulting_error, nullptr);
}

TEST_F(DatastoreTest, LookupDocumentsAuthFailure) {
  credentials.FailGetToken();

  __block NSError* resulting_error = nullptr;
  datastore->LookupDocuments(
      {}, ^(NSArray<FSTMaybeDocument*>* docs, NSError* _Nullable error) {
        resulting_error = error;
      });
  worker_queue.EnqueueBlocking([] {});
  EXPECT_NE(resulting_error, nullptr);
}

TEST_F(DatastoreTest, AuthAfterDatastoreHasBeenShutDown) {
  credentials.DelayGetToken();

  worker_queue.EnqueueBlocking([&] {
    datastore->CommitMutations(@[], ^(NSError* _Nullable error) {
      FAIL() << "Callback shouldn't be invoked";
    });
  });
  Shutdown();

  EXPECT_NO_THROW(credentials.InvokeGetToken());
}

TEST_F(DatastoreTest, AuthOutlivesDatastore) {
  credentials.DelayGetToken();

  worker_queue.EnqueueBlocking([&] {
    datastore->CommitMutations(@[], ^(NSError* _Nullable error) {
      FAIL() << "Callback shouldn't be invoked";
    });
  });
  Shutdown();
  datastore.reset();

  EXPECT_NO_THROW(credentials.InvokeGetToken());
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
