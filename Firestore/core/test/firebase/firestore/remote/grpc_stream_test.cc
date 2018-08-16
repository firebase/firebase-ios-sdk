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

#include <grpcpp/client_context.h>
#include <grpcpp/create_channel.h>
#include <grpcpp/generic/generic_stub.h>
#include <grpcpp/support/byte_buffer.h>
#include "gtest/gtest.h"

#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_queue.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace remote {

class Observer : public GrpcStreamObserver {
 public:
  void OnStreamStart() override {
    observed_states.push_back("OnStreamStart");
  }
  void OnStreamRead(const grpc::ByteBuffer& message) override {
    observed_states.push_back("OnStreamRead");
  }
  void OnStreamWrite() override {
    observed_states.push_back("OnStreamWrite");
  }
  void OnStreamError(const util::Status& status) override {
    observed_states.push_back("OnStreamError");
  }

  int generation() const override {
    return 0;
  }

  std::vector<std::string> observed_states;
};

class GrpcStreamTest : public testing::Test {
 public:
  enum OperationResult { Ok, NotOk, Ignore };

  GrpcStreamTest() {
    grpc::GenericStub grpc_stub{grpc::CreateChannel(
        "", grpc::SslCredentials(grpc::SslCredentialsOptions()))};

    auto grpc_context_owning = absl::make_unique<grpc::ClientContext>();
    grpc_context = grpc_context_owning.get();
    auto grpc_call = grpc_stub.PrepareCall(grpc_context_owning.get(), "",
                                           grpc_queue.queue());
    observer = absl::make_unique<Observer>();
    stream = GrpcStream::MakeStream(std::move(grpc_context_owning),
                                    std::move(grpc_call), observer.get(),
                                    &grpc_queue);
  }

  // This is a very hacky way to simulate GRPC finishing operations without
  // actually connecting to the server: cancel the stream, which will make the
  // operation fail fast and be returned from the completion queue, then
  // complete the operation. It relies on `ClientContext::TryCancel` not
  // complaining about being invoked more than once.
  void ForceFinishOperations(std::initializer_list<OperationResult> results) {
    grpc_context->TryCancel();
    for (OperationResult result : results) {
      bool ignored_ok = false;
      GrpcOperation* operation = grpc_queue.Next(&ignored_ok);
      ASSERT_NE(operation, nullptr);
      if (result == OperationResult::Ok) {
        operation->Complete(true);
      } else if (result == OperationResult::NotOk) {
        operation->Complete(false);
      }
      // Otherwise, the operation is ignored.
    }
  }

  // This is to make `EXPECT_EQ` a little shorter and work around macro
  // limitations related to initializer lists.
  std::vector<std::string> States(std::initializer_list<std::string> states) {
    return {states};
  }

  grpc::ClientContext* grpc_context = nullptr;
  GrpcCompletionQueue grpc_queue;
  std::unique_ptr<Observer> observer;
  std::shared_ptr<GrpcStream> stream;
};

TEST_F(GrpcStreamTest, CannotStartTwice) {
  EXPECT_NO_THROW(stream->Start());
  EXPECT_ANY_THROW(stream->Start());
}

TEST_F(GrpcStreamTest, CannotWriteBeforeStreamIsOpen) {
  EXPECT_ANY_THROW(stream->Write({}));
  stream->Start();
  EXPECT_ANY_THROW(stream->Write({}));
}

TEST_F(GrpcStreamTest, CanFinishBeforeStarting) {
  EXPECT_NO_THROW(stream->Finish());
}

TEST_F(GrpcStreamTest, CanFinishAfterStarting) {
  stream->Start();
  EXPECT_NO_THROW(stream->Finish());
}

TEST_F(GrpcStreamTest, CannotFinishTwice) {
  stream->Start();
  EXPECT_NO_THROW(stream->Finish());
  EXPECT_ANY_THROW(stream->Finish());
}

TEST_F(GrpcStreamTest, CanWriteAndFinishBeforeStarting) {
  EXPECT_NO_THROW(stream->WriteAndFinish({}));
}

TEST_F(GrpcStreamTest, CanWriteAndFinishAfterStarting) {
  stream->Start();
  EXPECT_NO_THROW(stream->WriteAndFinish({}));
}

TEST_F(GrpcStreamTest, ObserverReceivesOnStart) {
  stream->Start();
  ForceFinishOperations({Ok});
  EXPECT_EQ(observer->observed_states, States({"OnStreamStart"}));
}

TEST_F(GrpcStreamTest, CanWriteAfterStreamIsOpen) {
  stream->Start();
  ForceFinishOperations({Ok});
  EXPECT_NO_THROW(stream->Write({}));
}

TEST_F(GrpcStreamTest, ObserverReceivesOnRead) {
  stream->Start();
  ForceFinishOperations({Ok, Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamRead"}));
}

TEST_F(GrpcStreamTest, ReadIsAutomaticallyReadded) {
  stream->Start();
  ForceFinishOperations({Ok, Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamRead"}));
  ForceFinishOperations({Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamRead", "OnStreamRead"}));
}

TEST_F(GrpcStreamTest, ObserverReceivesOnWrite) {
  stream->Start();
  ForceFinishOperations({Ok});
  stream->Write({});
  ForceFinishOperations({Ignore, Ok});  // Ignore the read operation
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamWrite"}));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
