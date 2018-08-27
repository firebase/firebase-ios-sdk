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

#include "Firestore/core/src/firebase/firestore/remote/buffered_writer.h"

#include "Firestore/core/test/firebase/firestore/util/grpc_tests_util.h"
#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::GrpcStreamFixture;

namespace {

// A no-op observer.
struct Observer : GrpcStreamObserver {
  void OnStreamStart() override {
  }
  void OnStreamRead(const grpc::ByteBuffer& message) override {
  }
  void OnStreamError(const util::Status& status) override {
  }
  int generation() const override {
    return 0;
  }
};

}

class BufferedWriterTest : public testing::Test {
 public:
  BufferedWriterTest()
      : observer{absl::make_unique<Observer>()} {
    fixture.CreateStream(observer.get());
    writer = absl::make_unique<BufferedWriter>(&fixture.stream(), fixture.call(),
                                               &fixture.async_queue());
  }

  std::unique_ptr<Observer> observer;
  GrpcStreamFixture fixture;
  std::unique_ptr<BufferedWriter> writer;
};

TEST_F(BufferedWriterTest, CanDoBufferedWrites) {
  fixture.async_queue().EnqueueBlocking([&] {
    return;
    fixture.stream().Start();


    EXPECT_NE(writer->EnqueueWrite({}), nullptr);
    EXPECT_EQ(writer->EnqueueWrite({}), nullptr);
    EXPECT_EQ(writer->EnqueueWrite({}), nullptr);

    EXPECT_NE(writer->DequeueNextWrite(), nullptr);
    EXPECT_NE(writer->DequeueNextWrite(), nullptr);

    // An extra call to `DequeueNextWrite` should be a no-op.
    EXPECT_EQ(writer->EnqueueWrite({}), nullptr);

    EXPECT_NE(writer->EnqueueWrite({}), nullptr);
  });
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
