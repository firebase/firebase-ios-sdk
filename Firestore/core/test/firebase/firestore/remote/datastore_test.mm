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
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/util/fake_credentials_provider.h"
#include "Firestore/core/test/firebase/firestore/util/grpc_stream_tester.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

#import "Firestore/Protos/objc/google/firestore/v1beta1/Document.pbobjc.h"
#import "Firestore/Protos/objc/google/firestore/v1beta1/Firestore.pbobjc.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using core::DatabaseInfo;
using model::DatabaseId;
using util::AsyncQueue;
using util::MakeByteBuffer;
using util::CompletionEndState;
using util::GrpcStreamTester;
using util::FakeCredentialsProvider;
using util::FakeGrpcQueue;
using util::WrapNSString;
using util::internal::ExecutorLibdispatch;
using util::CompletionResult::Error;
using util::CompletionResult::Ok;
using util::internal::ExecutorStd;
using Type = GrpcCompletion::Type;

namespace {

grpc::ByteBuffer MakeByteBuffer(NSData* data) {
  grpc::Slice slice{[data bytes], [data length]};
  return grpc::ByteBuffer{&slice, 1};
}

grpc::ByteBuffer MakeFakeDocument(const std::string& doc_name) {
  GCFSDocument* doc = [GCFSDocument message];
  doc.name =
      WrapNSString(std::string{"projects/p/databases/d/documents/"} + doc_name);
  GCFSValue* value = [GCFSValue message];
  value.stringValue = @"bar";
  [doc.fields addEntriesFromDictionary:@{
    @"foo" : value,
  }];
  doc.updateTime.seconds = 0;
  doc.updateTime.nanos = 42000;

  GCFSBatchGetDocumentsResponse* response =
      [GCFSBatchGetDocumentsResponse message];
  response.found = doc;
  return MakeByteBuffer([response data]);
}

class FakeDatastore : public Datastore {
 public:
  using Datastore::Datastore;

  grpc::CompletionQueue* queue() {
    return grpc_queue();
  }
  void CancelLastCall() {
    LastCall()->context()->TryCancel();
  }
};

std::shared_ptr<FakeDatastore> CreateDatastore(
    const DatabaseInfo& database_info,
    AsyncQueue* worker_queue,
    CredentialsProvider* credentials) {
  return std::make_shared<FakeDatastore>(
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
        database_info{DatabaseId{"p", "d"}, "", "", false},
        datastore{CreateDatastore(database_info, &worker_queue, &credentials)},
        fake_grpc_queue{datastore->queue()} {
    // Deliberately don't `Start` the `Datastore` to prevent normal gRPC
    // completion queue polling; the test is using `FakeGrpcQueue`.
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

  void ForceFinish(std::initializer_list<CompletionEndState> end_states) {
    datastore->CancelLastCall();
    fake_grpc_queue.ExtractCompletions(end_states);
    worker_queue.EnqueueBlocking([] {});
  }

  void ForceFinishAnyTypeOrder(
      std::initializer_list<CompletionEndState> end_states) {
    datastore->CancelLastCall();
    fake_grpc_queue.ExtractCompletions(
        GrpcStreamTester::CreateAnyTypeOrderCallback(end_states));
    worker_queue.EnqueueBlocking([] {});
  }

  bool is_shut_down = false;
  DatabaseInfo database_info;
  FakeCredentialsProvider credentials;

  AsyncQueue worker_queue;
  std::shared_ptr<FakeDatastore> datastore;

  std::unique_ptr<ConnectivityMonitor> connectivity_monitor;
  FakeGrpcQueue fake_grpc_queue;
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

// Normal operation

TEST_F(DatastoreTest, CommitMutationsSuccess) {
  __block bool done = false;
  __block NSError* resulting_error = nullptr;
  datastore->CommitMutations(@[], ^(NSError* _Nullable error) {
    done = true;
    resulting_error = error;
  });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  EXPECT_EQ(resulting_error, nullptr);
}

TEST_F(DatastoreTest, LookupDocumentsOneSuccessfulRead) {
  __block bool done = false;
  __block NSArray<FSTMaybeDocument*>* resulting_docs = nullptr;
  __block NSError* resulting_error = nullptr;
  datastore->LookupDocuments({},
                             ^(NSArray<FSTMaybeDocument*>* _Nullable documents,
                               NSError* _Nullable error) {
                               done = true;
                               resulting_docs = documents;
                               resulting_error = error;
                             });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Read, MakeFakeDocument("foo/1")},
                           {Type::Write, Ok},
                           /*Read after last*/ {Type::Read, Error}});
  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  ASSERT_NE(resulting_docs, nullptr);
  EXPECT_EQ(resulting_docs.count, 1);
  EXPECT_EQ([[resulting_docs objectAtIndex:0] key].ToString(), "foo/1");
  EXPECT_EQ(resulting_error, nullptr);
}

TEST_F(DatastoreTest, LookupDocumentsTwoSuccessfulReads) {
  __block bool done = false;
  __block NSArray<FSTMaybeDocument*>* resulting_docs = nullptr;
  __block NSError* resulting_error = nullptr;
  datastore->LookupDocuments({},
                             ^(NSArray<FSTMaybeDocument*>* _Nullable documents,
                               NSError* _Nullable error) {
                               done = true;
                               resulting_docs = documents;
                               resulting_error = error;
                             });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Write, Ok},
                           {Type::Read, MakeFakeDocument("foo/1")},
                           {Type::Read, MakeFakeDocument("foo/2")},
                           /*Read after last*/ {Type::Read, Error}});
  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  ASSERT_NE(resulting_docs, nullptr);
  EXPECT_EQ(resulting_docs.count, 2);
  EXPECT_EQ([[resulting_docs objectAtIndex:0] key].ToString(), "foo/1");
  EXPECT_EQ([[resulting_docs objectAtIndex:1] key].ToString(), "foo/2");
  EXPECT_EQ(resulting_error, nullptr);
}

// gRPC errors

TEST_F(DatastoreTest, CommitMutationsError) {
  __block bool done = false;
  __block NSError* resulting_error = nullptr;
  datastore->CommitMutations(@[], ^(NSError* _Nullable error) {
    done = true;
    resulting_error = error;
  });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_NE(resulting_error, nullptr);
}

TEST_F(DatastoreTest, LookupDocumentsErrorBeforeFirstRead) {
  __block bool done = false;
  __block NSError* resulting_error = nullptr;
  datastore->LookupDocuments({},
                             ^(NSArray<FSTMaybeDocument*>* _Nullable documents,
                               NSError* _Nullable error) {
                               done = true;
                               resulting_error = error;
                             });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Read, Error}, {Type::Write, Error}});
  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_NE(resulting_error, nullptr);
}

TEST_F(DatastoreTest, LookupDocumentsErrorAfterFirstRead) {
  __block bool done = false;
  __block NSArray<FSTMaybeDocument*>* resulting_docs = nullptr;
  __block NSError* resulting_error = nullptr;
  datastore->LookupDocuments({},
                             ^(NSArray<FSTMaybeDocument*>* _Nullable documents,
                               NSError* _Nullable error) {
                               done = true;
                               resulting_error = error;
                             });
  // Make sure Auth has a chance to run.
  worker_queue.EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Write, Ok},
                           {Type::Read, MakeFakeDocument("foo/1")},
                           {Type::Read, Error}});
  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_EQ(resulting_docs, nullptr);
  EXPECT_NE(resulting_error, nullptr);
}

// Auth errors

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

// TODO(varconst): this test currently fails due to a gRPC issue, see here
// https://github.com/firebase/firebase-ios-sdk/pull/1935#discussion_r224900667
// for details. Reenable when/if possible.
TEST_F(DatastoreTest, DISABLED_AuthOutlivesDatastore) {
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
