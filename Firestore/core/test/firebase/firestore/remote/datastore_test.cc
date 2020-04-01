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
#include <vector>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1/firestore.nanopb.h"
#include "Firestore/core/src/firebase/firestore/model/mutation.h"
#include "Firestore/core/src/firebase/firestore/nanopb/message.h"
#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_util.h"
#include "Firestore/core/src/firebase/firestore/remote/datastore.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_nanopb.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/remote/fake_credentials_provider.h"
#include "Firestore/core/test/firebase/firestore/remote/grpc_stream_tester.h"
#include "Firestore/core/test/firebase/firestore/testutil/async_testing.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "absl/memory/memory.h"
#include "absl/strings/str_cat.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

namespace {

using auth::CredentialsProvider;
using core::DatabaseInfo;
using model::DatabaseId;
using model::Document;
using model::MaybeDocument;
using nanopb::MakeArray;
using nanopb::Message;
using testing::Not;
using testutil::Value;
using util::AsyncQueue;
using util::Executor;
using util::Status;
using util::StatusOr;

using Type = GrpcCompletion::Type;

grpc::ByteBuffer MakeFakeDocument(const std::string& doc_name) {
  Serializer serializer{DatabaseId{"p", "d"}};
  Message<google_firestore_v1_BatchGetDocumentsResponse> response;

  response->which_result =
      google_firestore_v1_BatchGetDocumentsResponse_found_tag;
  google_firestore_v1_Document& doc = response->found;
  doc.name = serializer.EncodeString(
      absl::StrCat("projects/p/databases/d/documents/", doc_name));
  doc.has_update_time = true;
  doc.update_time.seconds = 0;
  doc.update_time.nanos = 42000;

  doc.fields_count = 1;
  doc.fields =
      MakeArray<google_firestore_v1_Document_FieldsEntry>(doc.fields_count);
  google_firestore_v1_Document_FieldsEntry& entry = doc.fields[0];

  entry.key = serializer.EncodeString("foo");
  entry.value = serializer.EncodeFieldValue(Value("bar"));

  return MakeByteBuffer(response);
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
    const std::shared_ptr<AsyncQueue>& worker_queue,
    std::shared_ptr<CredentialsProvider> credentials) {
  return std::make_shared<FakeDatastore>(database_info, worker_queue,
                                         credentials);
}

}  // namespace

class DatastoreTest : public testing::Test {
 public:
  DatastoreTest()
      : database_info{DatabaseId{"p", "d"}, "", "localhost", false},
        worker_queue{testutil::AsyncQueueForTesting()},
        datastore{CreateDatastore(database_info, worker_queue, credentials)},
        fake_grpc_queue{datastore->queue()} {
    // Deliberately don't `Start` the `Datastore` to prevent normal gRPC
    // completion queue polling; the test is using `FakeGrpcQueue`.
  }

  ~DatastoreTest() {
    if (!is_shut_down) {
      Shutdown();
    }
    // Ensure that nothing remains on the AsyncQueue before destroying it.
    worker_queue->EnqueueBlocking([] {});
  }

  void Shutdown() {
    is_shut_down = true;
    datastore->Shutdown();
  }

  void ForceFinish(std::initializer_list<CompletionEndState> end_states) {
    datastore->CancelLastCall();
    fake_grpc_queue.ExtractCompletions(end_states);
    worker_queue->EnqueueBlocking([] {});
  }

  void ForceFinishAnyTypeOrder(
      std::initializer_list<CompletionEndState> end_states) {
    datastore->CancelLastCall();
    fake_grpc_queue.ExtractCompletions(
        GrpcStreamTester::CreateAnyTypeOrderCallback(end_states));
    worker_queue->EnqueueBlocking([] {});
  }

  bool is_shut_down = false;
  DatabaseInfo database_info;
  std::shared_ptr<FakeCredentialsProvider> credentials =
      std::make_shared<FakeCredentialsProvider>();

  std::shared_ptr<AsyncQueue> worker_queue;
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
  bool done = false;
  Status resulting_status;
  datastore->CommitMutations({}, [&](const Status& status) {
    done = true;
    resulting_status = status;
  });
  // Make sure Auth has a chance to run.
  worker_queue->EnqueueBlocking([] {});

  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  EXPECT_TRUE(resulting_status.ok());
}

TEST_F(DatastoreTest, LookupDocumentsOneSuccessfulRead) {
  bool done = false;
  std::vector<MaybeDocument> resulting_docs;
  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const StatusOr<std::vector<MaybeDocument>>& maybe_documents) {
        done = true;
        if (maybe_documents.ok()) {
          resulting_docs = maybe_documents.ValueOrDie();
        }
        resulting_status = maybe_documents.status();
      });
  // Make sure Auth has a chance to run.
  worker_queue->EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder(
      {{Type::Read, MakeFakeDocument("foo/1")},
       {Type::Write, CompletionResult::Ok},
       /*Read after last*/ {Type::Read, CompletionResult::Error}});
  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  EXPECT_EQ(resulting_docs.size(), 1);
  EXPECT_EQ(resulting_docs[0].key().ToString(), "foo/1");
  EXPECT_TRUE(resulting_status.ok());
}

TEST_F(DatastoreTest, LookupDocumentsTwoSuccessfulReads) {
  bool done = false;
  std::vector<MaybeDocument> resulting_docs;
  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const StatusOr<std::vector<MaybeDocument>>& maybe_documents) {
        done = true;
        if (maybe_documents.ok()) {
          resulting_docs = maybe_documents.ValueOrDie();
        }
        resulting_status = maybe_documents.status();
      });
  // Make sure Auth has a chance to run.
  worker_queue->EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder(
      {{Type::Write, CompletionResult::Ok},
       {Type::Read, MakeFakeDocument("foo/1")},
       {Type::Read, MakeFakeDocument("foo/2")},
       /*Read after last*/ {Type::Read, CompletionResult::Error}});
  ForceFinish({{Type::Finish, grpc::Status::OK}});

  EXPECT_TRUE(done);
  EXPECT_EQ(resulting_docs.size(), 2);
  EXPECT_EQ(resulting_docs[0].key().ToString(), "foo/1");
  EXPECT_EQ(resulting_docs[1].key().ToString(), "foo/2");
  EXPECT_TRUE(resulting_status.ok());
}

// gRPC errors

TEST_F(DatastoreTest, CommitMutationsError) {
  bool done = false;
  Status resulting_status;
  datastore->CommitMutations({}, [&](const Status& status) {
    done = true;
    resulting_status = status;
  });
  // Make sure Auth has a chance to run.
  worker_queue->EnqueueBlocking([] {});

  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_FALSE(resulting_status.ok());
  EXPECT_EQ(resulting_status.code(), Error::kUnavailable);
}

TEST_F(DatastoreTest, LookupDocumentsErrorBeforeFirstRead) {
  bool done = false;
  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const StatusOr<std::vector<MaybeDocument>>& maybe_documents) {
        done = true;
        resulting_status = maybe_documents.status();
      });
  // Make sure Auth has a chance to run.
  worker_queue->EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Read, CompletionResult::Error},
                           {Type::Write, CompletionResult::Error}});
  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_FALSE(resulting_status.ok());
  EXPECT_EQ(resulting_status.code(), Error::kUnavailable);
}

TEST_F(DatastoreTest, LookupDocumentsErrorAfterFirstRead) {
  bool done = false;
  std::vector<MaybeDocument> resulting_docs;
  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const StatusOr<std::vector<MaybeDocument>>& maybe_documents) {
        done = true;
        resulting_status = maybe_documents.status();
      });
  // Make sure Auth has a chance to run.
  worker_queue->EnqueueBlocking([] {});

  ForceFinishAnyTypeOrder({{Type::Write, CompletionResult::Ok},
                           {Type::Read, MakeFakeDocument("foo/1")},
                           {Type::Read, CompletionResult::Error}});
  ForceFinish({{Type::Finish, grpc::Status{grpc::UNAVAILABLE, ""}}});

  EXPECT_TRUE(done);
  EXPECT_TRUE(resulting_docs.empty());
  EXPECT_FALSE(resulting_status.ok());
  EXPECT_EQ(resulting_status.code(), Error::kUnavailable);
}

// Auth errors

TEST_F(DatastoreTest, CommitMutationsAuthFailure) {
  credentials->FailGetToken();

  Status resulting_status;
  datastore->CommitMutations(
      {}, [&](const Status& status) { resulting_status = status; });
  worker_queue->EnqueueBlocking([] {});
  EXPECT_FALSE(resulting_status.ok());
}

TEST_F(DatastoreTest, LookupDocumentsAuthFailure) {
  credentials->FailGetToken();

  Status resulting_status;
  datastore->LookupDocuments(
      {}, [&](const StatusOr<std::vector<MaybeDocument>>& maybe_documents) {
        resulting_status = maybe_documents.status();
      });
  worker_queue->EnqueueBlocking([] {});
  EXPECT_FALSE(resulting_status.ok());
}

TEST_F(DatastoreTest, AuthAfterDatastoreHasBeenShutDown) {
  credentials->DelayGetToken();

  worker_queue->EnqueueBlocking([&] {
    datastore->CommitMutations({}, [](const Status& status) {
      FAIL() << "Callback shouldn't be invoked";
    });
  });
  Shutdown();

  EXPECT_NO_THROW(credentials->InvokeGetToken());
}

TEST_F(DatastoreTest, AuthOutlivesDatastore) {
  credentials->DelayGetToken();

  worker_queue->EnqueueBlocking([&] {
    datastore->CommitMutations({}, [](const Status& status) {
      FAIL() << "Callback shouldn't be invoked";
    });
  });
  Shutdown();
  datastore.reset();

  EXPECT_NO_THROW(credentials->InvokeGetToken());
}

// Error classification

MATCHER(IsPermanentError,
        negation ? "not permanent error" : "permanent error") {
  return Datastore::IsPermanentError(Status{arg, ""});
}

TEST_F(DatastoreTest, IsPermanentError) {
  EXPECT_THAT(Error::kCancelled, Not(IsPermanentError()));
  EXPECT_THAT(Error::kResourceExhausted, Not(IsPermanentError()));
  EXPECT_THAT(Error::kUnavailable, Not(IsPermanentError()));
  // User info doesn't matter:
  EXPECT_FALSE(Datastore::IsPermanentError(
      Status{Error::kUnavailable, "Connectivity lost"}));
  // "unauthenticated" is considered a recoverable error due to expired token.
  EXPECT_THAT(Error::kUnauthenticated, Not(IsPermanentError()));

  EXPECT_THAT(Error::kDataLoss, IsPermanentError());
  EXPECT_THAT(Error::kAborted, IsPermanentError());
}

MATCHER(IsPermanentWriteError,
        negation ? "not permanent error" : "permanent error") {
  return Datastore::IsPermanentWriteError(Status{arg, ""});
}

TEST_F(DatastoreTest, IsPermanentWriteError) {
  EXPECT_THAT(Error::kUnauthenticated, Not(IsPermanentWriteError()));
  EXPECT_THAT(Error::kDataLoss, IsPermanentWriteError());
  EXPECT_THAT(Error::kAborted, Not(IsPermanentWriteError()));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
