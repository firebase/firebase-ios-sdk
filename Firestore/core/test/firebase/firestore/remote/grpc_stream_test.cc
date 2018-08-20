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

#include "Firestore/core/src/firebase/firestore/remote/grpc_operation.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_queue.h"
#include "absl/memory/memory.h"
#include "grpcpp/client_context.h"
#include "grpcpp/create_channel.h"
#include "grpcpp/generic/generic_stub.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

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
    return gen;
  }

  std::vector<std::string> observed_states;
  int gen = 0;
};

class GrpcStreamTest : public testing::Test {
 public:
  enum OperationResult { Ok, Error, Ignore };

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
  void ForceFinish(std::initializer_list<OperationResult> results) {
    grpc_context->TryCancel();

    for (OperationResult result : results) {
      bool ignored_ok = false;
      // TODO(varconst): use a timeout, otherwise this might block if there's
      // a bug.)
      GrpcOperation* operation = grpc_queue.Next(&ignored_ok);
      ASSERT_NE(operation, nullptr);
      if (result == OperationResult::Ok) {
        operation->Complete(true);
      } else if (result == OperationResult::Error) {
        operation->Complete(false);
      }
      // Otherwise, the operation is ignored.
    }
  }
  void ForceFinishAndShutdown(std::initializer_list<OperationResult> results) {
    ForceFinish(results);

    grpc_queue.Shutdown();
    bool unused_ok = false;
    GrpcOperation* should_be_null = grpc_queue.Next(&unused_ok);
    EXPECT_EQ(should_be_null, nullptr);
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
  ForceFinish({/*Start*/ Ok});
  EXPECT_EQ(observer->observed_states, States({"OnStreamStart"}));
}

TEST_F(GrpcStreamTest, CanWriteAfterStreamIsOpen) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});
  EXPECT_NO_THROW(stream->Write({}));
}

TEST_F(GrpcStreamTest, ObserverReceivesOnRead) {
  stream->Start();
  ForceFinish({/*Start*/ Ok, /*Read*/ Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamRead"}));
}

TEST_F(GrpcStreamTest, ReadIsAutomaticallyReadded) {
  stream->Start();
  ForceFinish({/*Start*/ Ok, /*Read*/ Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamRead"}));

  ForceFinish({/*Read*/ Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamRead", "OnStreamRead"}));
}

TEST_F(GrpcStreamTest, ObserverReceivesOnWrite) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->Write({});
  ForceFinish({/*Read*/ Ignore, /*Write*/ Ok});

  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamWrite"}));
}

TEST_F(GrpcStreamTest, CanAddSeveralWrites) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->Write({});
  stream->Write({});
  stream->Write({});
  ForceFinish({/*Read*/ Ignore, /*Write*/ Ok, /*Write*/ Ok, /*Write*/ Ok});

  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamWrite", "OnStreamWrite",
                    "OnStreamWrite"}));
}

TEST_F(GrpcStreamTest, ObserverReceivesOnError) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  // Fail the read, but allow Finish to succeed
  ForceFinish({/*Read*/ Error, /*Finish*/ Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamError"}));
}

TEST_F(GrpcStreamTest, ObserverDoesNotReceiveOnFinishIfCalledByClient) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->Finish();
  ForceFinish({/*Read*/ Ignore, /*Finish*/ Ok});
  EXPECT_EQ(observer->observed_states, States({"OnStreamStart"}));
}

TEST_F(GrpcStreamTest, WriteAndFinish) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->WriteAndFinish({});
  ForceFinish({/*Read*/ Ignore, /*Write*/ Ok, /*Finish*/ Ok});
  // Should be no notification on the final write.
  EXPECT_EQ(observer->observed_states, States({"OnStreamStart"}));
}

TEST_F(GrpcStreamTest, WriteAndFinishDiscardsUnstartedWrites) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->Write({});  // This will have a chance to start
  stream->Write({});  // This will be pending
  stream->Write({});  // This will be pending too

  stream->WriteAndFinish({});
  // Make sure the pending writes were ignored: shut down and drain the queue,
  // so that it's clear they weren't executed.
  ForceFinishAndShutdown(
      {/*Read*/ Ignore, /*First write*/ Ok, /*Final write*/ Ok, /*Finish*/ Ok});

  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamWrite"}));
}

TEST_F(GrpcStreamTest, ErrorOnStart) {
  stream->Start();
  ForceFinish({/*Start*/ Error, /*Finish*/ Ok});

  EXPECT_EQ(observer->observed_states, States({"OnStreamError"}));
}

TEST_F(GrpcStreamTest, ErrorOnWrite) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->Write({});

  ForceFinish({/*Read*/ Ignore, /*Write*/ Error, /*Finish*/ Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamError"}));
}

TEST_F(GrpcStreamTest, ErrorWithPendingWrites) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->Write({});
  stream->Write({});

  ForceFinishAndShutdown({/*Read*/ Ignore, /*Write*/ Error, /*Finish*/ Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamError"}));
}

TEST_F(GrpcStreamTest, ErrorOnLastWrite) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->WriteAndFinish({});

  // Make sure `Finish` is not called when the write fails.
  ForceFinishAndShutdown({/*Read*/ Ignore, /*Write*/ Error});
  // Observer shouldn't be notified about the error.
  EXPECT_EQ(observer->observed_states, States({"OnStreamStart"}));
}

TEST_F(GrpcStreamTest, RaisingGenerationStopsNotifications) {
  stream->Start();
  ForceFinish({/*Start*/ Ok});

  stream->Write({});
  ForceFinish({/*Read*/ Ok, /*Write*/ Ok});
  observer->gen++;
  stream->Write({});
  stream->Finish();

  ForceFinish({/*Read*/ Ok, /*Write*/ Ok, /*Finish*/ Ok});
  EXPECT_EQ(observer->observed_states,
            States({"OnStreamStart", "OnStreamRead", "OnStreamWrite"}));
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
