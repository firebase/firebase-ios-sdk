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

#include "Firestore/core/src/firebase/firestore/remote/grpc_stream.h"

#include <initializer_list>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/stream.h"
#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/src/firebase/firestore/util/executor_std.h"
#include "Firestore/core/test/firebase/firestore/util/grpc_tests_util.h"
#include "absl/memory/memory.h"
#include "grpcpp/client_context.h"
#include "grpcpp/completion_queue.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using auth::CredentialsProvider;
using auth::EmptyCredentialsProvider;
using auth::Token;
using auth::TokenListener;
using util::AsyncQueue;
using util::GrpcStreamFixture;
using util::OperationResult;
using util::OperationResult::Error;
using util::OperationResult::Ok;
using util::TimerId;
using util::internal::ExecutorStd;

namespace {

class MockCredentialsProvider : public EmptyCredentialsProvider {
 public:
  void GetToken(TokenListener completion) override {
    observed_states_.push_back("GetToken");
    EmptyCredentialsProvider::GetToken(std::move(completion));
  }

  void InvalidateToken() override {
    observed_states_.push_back("InvalidateToken");
    EmptyCredentialsProvider::InvalidateToken();
  }

  const std::vector<std::string>& observed_states() const {
    return observed_states_;
  }

 private:
  std::vector<std::string> observed_states_;
};

class TestStream : public Stream {
 public:
  TestStream(GrpcStreamFixture* fixture,
             CredentialsProvider* credentials_provider)
      : Stream{&fixture->async_queue(), credentials_provider,
               /*Datastore=*/nullptr, TimerId::ListenStreamIdle,
               TimerId::ListenStreamConnectionBackoff},
        fixture_{fixture} {
  }

   void WriteEmptyBuffer() {
     Write({});
   }

 private:
  std::unique_ptr<GrpcStream> CreateGrpcStream(
      Datastore* datastore, absl::string_view token) override {
    return fixture_->CreateStream(this);
  }
  void FinishGrpcStream(GrpcStream* stream) override {
    stream->Finish();
  }

  void DoOnStreamStart() override {
    observed_states_.push_back("OnStreamStart");
  }
  util::Status DoOnStreamRead(const grpc::ByteBuffer& message) override {
    observed_states_.push_back("OnStreamRead");
    return util::Status::OK();
  }
  void DoOnStreamFinish(const util::Status& status) override {
    observed_states_.push_back("OnStreamFinish");
  }

  std::string GetDebugName() const override {
    return "";
  }

  GrpcStreamFixture* fixture_ = nullptr;
  std::vector<std::string> observed_states_;
};

}  // namespace

class StreamTest : public testing::Test {
 public:
  StreamTest()
      : firestore_stream{
            std::make_shared<TestStream>(&fixture_, &credentials_provider_)} {
  }

  ~StreamTest() {
    async_queue().EnqueueBlocking([&] {
      if (firestore_stream->IsStarted()) {
        fixture_.KeepPollingGrpcQueue();
        firestore_stream->Stop();
      }
    });
    fixture_.Shutdown();
  }

  AsyncQueue& async_queue() {
    return fixture_.async_queue();
  }

 private:
  GrpcStreamFixture fixture_;
  MockCredentialsProvider credentials_provider_;

 public:
  std::shared_ptr<TestStream> firestore_stream;
};

TEST_F(StreamTest, CanStart) {
  async_queue().EnqueueBlocking(
      [&] {
      EXPECT_NO_THROW(firestore_stream->Start());
      EXPECT_TRUE(firestore_stream->IsStarted());
      EXPECT_FALSE(firestore_stream->IsOpen());
  });
}

TEST_F(StreamTest, CannotStartTwice) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_ANY_THROW(firestore_stream->Start());
  });
}

TEST_F(StreamTest, CanFinishBeforeStarting) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Stop());
  });
}

TEST_F(StreamTest, CanFinishAfterStarting) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_TRUE(firestore_stream->IsStarted());
    EXPECT_NO_THROW(firestore_stream->Stop());
    EXPECT_FALSE(firestore_stream->IsStarted());
  });
}

TEST_F(StreamTest, CanFinishTwice) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(firestore_stream->Start());
    EXPECT_NO_THROW(firestore_stream->Stop());
    EXPECT_NO_THROW(firestore_stream->Stop());
  });
}

TEST_F(StreamTest, CannotWriteBeforeOpen) {
  async_queue().EnqueueBlocking([&] {
    EXPECT_ANY_THROW(firestore_stream->WriteEmptyBuffer());
    firestore_stream->Start();
    EXPECT_ANY_THROW(firestore_stream->WriteEmptyBuffer());
  });
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
