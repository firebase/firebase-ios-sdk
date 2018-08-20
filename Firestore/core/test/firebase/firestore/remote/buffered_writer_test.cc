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

#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

class TestOperation : public GrpcOperation {
 public:
  explicit TestOperation(int* writes_count) : writes_count_{writes_count} {
  }
  void Execute() override {
    ++(*writes_count_);
    // Normally, this would be done by the class that popped the operation from
    // GRPC completion queue, but these tests don't include normal deletion.
    delete this;
  }
  void Complete(bool ok) override {
    // Never called in these tests
  }

 private:
  int* writes_count_ = nullptr;
};

class BufferedWriterTest : public testing::Test {
 public:
  TestOperation* MakeOperation() {
    return new TestOperation{&writes_count};
  }

  int writes_count = 0;
  BufferedWriter writer;
};

TEST_F(BufferedWriterTest, CanDoImmediateWrites) {
  EXPECT_EQ(writes_count, 0);

  writer.EnqueueWrite(MakeOperation());
  EXPECT_EQ(writes_count, 1);
}

TEST_F(BufferedWriterTest, CanDoBufferedWrites) {
  EXPECT_EQ(writes_count, 0);

  writer.EnqueueWrite(MakeOperation());
  writer.EnqueueWrite(MakeOperation());
  writer.EnqueueWrite(MakeOperation());
  EXPECT_EQ(writes_count, 1);

  writer.DequeueNextWrite();
  EXPECT_EQ(writes_count, 2);

  writer.DequeueNextWrite();
  EXPECT_EQ(writes_count, 3);

  // An extra call to `DequeueNextWrite` should be a no-op.
  writer.DequeueNextWrite();
  EXPECT_EQ(writes_count, 3);
}

TEST_F(BufferedWriterTest, CanDiscardUnstartedWrites) {
  EXPECT_EQ(writes_count, 0);

  writer.EnqueueWrite(MakeOperation());
  writer.EnqueueWrite(MakeOperation());
  writer.EnqueueWrite(MakeOperation());
  writer.EnqueueWrite(MakeOperation());
  EXPECT_EQ(writes_count, 1);

  EXPECT_FALSE(writer.empty());
  writer.DiscardUnstartedWrites();
  EXPECT_TRUE(writer.empty());

  writer.EnqueueWrite(MakeOperation());
  // We still haven't acknowledged that the previous write finished, so the
  // writer shouldn't do an immediate write. Clearing the writer shouldn't
  // affect the writer still waiting for the previous operation to complete.
  EXPECT_EQ(writes_count, 1);
  writer.DequeueNextWrite();
  EXPECT_EQ(writes_count, 2);

  // The previously enqueued operations should be cleared.
  writer.DequeueNextWrite();
  writer.DequeueNextWrite();
  writer.DequeueNextWrite();
  EXPECT_EQ(writes_count, 2);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
