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
#include <vector>

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"
#include "Firestore/core/test/firebase/firestore/util/grpc_stream_tester.h"
#include "absl/memory/memory.h"
#include "grpcpp/support/byte_buffer.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::AsyncQueue;
using util::CompletionResult;
using util::GrpcStreamTester;
using util::CompletionResult::Error;
using util::CompletionResult::Ok;

namespace {

class Observer : public GrpcStreamObserver {
 public:
  void OnStreamStart() override {
    observed_states.push_back("OnStreamStart");
  }
  void OnStreamRead(const grpc::ByteBuffer& message) override {
    observed_states.push_back("OnStreamRead");
  }
  void OnStreamFinish(const util::Status& status) override {
    observed_states.push_back("OnStreamFinish");
  }

  std::vector<std::string> observed_states;
};

}  // namespace

class GrpcStreamTest : public testing::Test {
 public:
  GrpcStreamTest()
      : observer_{absl::make_unique<Observer>()},
        stream_{tester_.CreateStream(observer_.get())} {
  }

  ~GrpcStreamTest() {
    if (!stream_->IsFinished()) {
      RunCompletionsImmediately();
      worker_queue().EnqueueBlocking([&] { stream_->Finish(); });
    }
    tester_.Shutdown();
  }

  GrpcStream& stream() {
    return *stream_;
  }
  AsyncQueue& worker_queue() {
    return tester_.worker_queue();
  }

  void RunCompletions(std::initializer_list<CompletionResult> results) {
    tester_.RunCompletions(stream_->context(), results);
  }

  void RunCompletionsImmediately() {
    tester_.RunCompletionsImmediately();
  }

  void ShutdownGrpcQueue() {
    tester_.ShutdownGrpcQueue();
  }

  const std::vector<std::string>& observed_states() const {
    return observer_->observed_states;
  }

  // This is to make `EXPECT_EQ` a little shorter and work around macro
  // limitations related to initializer lists.
  std::vector<std::string> States(std::initializer_list<std::string> states) {
    return {states};
  }

  bool ObserverHas(const std::string& state) const {
    return std::find(observed_states().begin(), observed_states().end(),
                     state) != observed_states().end();
  }

  void FinishStream() {
    RunCompletionsImmediately();
    stream().Finish();
  }

 private:
  GrpcStreamTester tester_;
  std::unique_ptr<Observer> observer_;
  std::unique_ptr<GrpcStream> stream_;
};

TEST_F(GrpcStreamTest, CanFinishBeforeStarting) {
  worker_queue().EnqueueBlocking([&] { EXPECT_NO_THROW(stream().Finish()); });
}

TEST_F(GrpcStreamTest, CanFinishAfterStarting) {
  worker_queue().EnqueueBlocking([&] {
    stream().Start();
    EXPECT_NO_THROW(FinishStream());
  });
}

TEST_F(GrpcStreamTest, CanFinishTwice) {
  worker_queue().EnqueueBlocking([&] {
    EXPECT_NO_THROW(FinishStream());
    EXPECT_NO_THROW(FinishStream());
  });
}

TEST_F(GrpcStreamTest, CanWriteAndFinishAfterStarting) {
  worker_queue().EnqueueBlocking([&] {
    stream().Start();
    RunCompletionsImmediately();
    EXPECT_NO_THROW(stream().WriteAndFinish({}));
  });
}

TEST_F(GrpcStreamTest, ObserverReceivesOnStart) {
  worker_queue().EnqueueBlocking([&] { stream().Start(); });
  EXPECT_EQ(observed_states(), States({"OnStreamStart"}));
}

TEST_F(GrpcStreamTest, CanWriteAfterStreamIsOpen) {
  worker_queue().EnqueueBlocking([&] {
    stream().Start();
    EXPECT_NO_THROW(stream().Write({}));
  });
}

TEST_F(GrpcStreamTest, ObserverReceivesOnRead) {
  worker_queue().EnqueueBlocking([&] { stream().Start(); });
  RunCompletions({/*Read*/ Ok});
  EXPECT_EQ(observed_states(), States({"OnStreamStart", "OnStreamRead"}));
}

TEST_F(GrpcStreamTest, ReadIsAutomaticallyReadded) {
  worker_queue().EnqueueBlocking([&] { stream().Start(); });
  RunCompletions({/*Read*/ Ok});
  EXPECT_EQ(observed_states(), States({"OnStreamStart", "OnStreamRead"}));

  RunCompletions({/*Read*/ Ok});
  EXPECT_EQ(observed_states(),
            States({"OnStreamStart", "OnStreamRead", "OnStreamRead"}));
}

TEST_F(GrpcStreamTest, CanAddSeveralWrites) {
  worker_queue().EnqueueBlocking([&] {
    stream().Start();
    stream().Write({});
    stream().Write({});
    stream().Write({});
  });
  RunCompletions({/*Read*/ Ok, /*Write*/ Ok, /*Read*/ Ok, /*Write*/ Ok,
                  /*Read*/ Ok, /*Write*/ Ok});

  EXPECT_EQ(observed_states(), States({"OnStreamStart", "OnStreamRead",
                                       "OnStreamRead", "OnStreamRead"}));
}

TEST_F(GrpcStreamTest, ObserverReceivesOnError) {
  worker_queue().EnqueueBlocking([&] { stream().Start(); });

  // Fail the read, but allow the rest to succeed.
  RunCompletions(
      {/*Read*/ Error});  // Will put a "Finish" operation on the queue
  // Once gRPC queue shutdown succeeds, "Finish" operation is guaranteed to be
  // extracted from gRPC completion queue (but the completion may not have run
  // yet).
  ShutdownGrpcQueue();
  // Finally, ensure `GrpcCompletion` for "Finish" operation has a chance to run
  // on the worker queue.
  worker_queue().EnqueueBlocking([] {});

  EXPECT_EQ(observed_states(), States({"OnStreamStart", "OnStreamFinish"}));
}

TEST_F(GrpcStreamTest, ObserverDoesNotReceiveOnFinishIfCalledByClient) {
  worker_queue().EnqueueBlocking([&] {
    stream().Start();
    stream().Finish();
  });
  EXPECT_FALSE(ObserverHas("OnStreamFinish"));
}

TEST_F(GrpcStreamTest, WriteAndFinish) {
  worker_queue().EnqueueBlocking([&] {
    stream().Start();
    bool did_last_write = stream().WriteAndFinish({});
    EXPECT_TRUE(did_last_write);
  });
  EXPECT_TRUE(ObserverHas("OnStreamStart"));
  EXPECT_FALSE(ObserverHas("OnStreamFinish"));
}

TEST_F(GrpcStreamTest, ErrorOnWrite) {
  worker_queue().EnqueueBlocking([&] {
    stream().Start();
    stream().Write({});
  });

  RunCompletions({/*Write*/ Error, /*Read*/ Error});
  // Give `GrpcStream` a chance to enqueue a finish operation
  RunCompletions({/*Finish*/ Ok});

  EXPECT_EQ(observed_states().back(), "OnStreamFinish");
}

TEST_F(GrpcStreamTest, ErrorWithPendingWrites) {
  worker_queue().EnqueueBlocking([&] {
    stream().Start();
    stream().Write({});
    stream().Write({});
  });

  RunCompletions({/*Write*/ Ok, /*Write*/ Error});
  // Give `GrpcStream` a chance to enqueue a finish operation
  RunCompletions({/*Read*/ Error, /*Finish*/ Ok});

  EXPECT_EQ(observed_states().back(), "OnStreamFinish");
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
