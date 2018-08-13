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

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace remote {

class BufferedWriterTest : public testing::Test {
 public:
  BufferedWriterTest()
      : writer{[this](grpc::ByteBuffer&&) { ++writes_count; }} {
  }

  int writes_count = 0;
  BufferedWriter writer;
};

TEST_F(BufferedWriterTest, ImmediateWrite) {
  EXPECT_EQ(writes_count, 0);
  writer.Enqueue({});
  EXPECT_EQ(writes_count, 1);
}

}
}  // namespace firestore
}  // namespace firebase
