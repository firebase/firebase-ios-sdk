/*
 * Copyright 2019 Google
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

#include "Firestore/core/src/nanopb/writer.h"

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {

using testing::ContainerEq;

TEST(ByteStringWriterTest, Reserves) {
  ByteStringWriter writer;
  ASSERT_EQ(writer.capacity(), 0);

  auto append = [&](const char* str) { writer.Append(str, strlen(str)); };

  // Initially, just copy whatever's given into an exactly sized buffer
  append("food");
  ASSERT_EQ(writer.size(), 4);
  ASSERT_EQ(writer.capacity(), 4);

  // Double by that amount if appending less
  for (size_t i = 5; i <= 8; i++) {
    append("!");
    ASSERT_EQ(writer.size(), i);
    ASSERT_EQ(writer.capacity(), 8);
  }

  // Exceeding the doubled amount will resize to that
  std::vector<uint8_t> large(20, 'a');
  writer.Append(large.data(), large.size());
  ASSERT_EQ(writer.size(), 28);
  ASSERT_EQ(writer.capacity(), 28);
}

TEST(BasicStringWriterTest, Releases) {
  ByteStringWriter writer;

  writer.Append("foo", 3);

  ByteString contents = writer.Release();
  EXPECT_EQ(writer.capacity(), 0);
  EXPECT_NE(contents.get(), nullptr);

  EXPECT_EQ(contents, ByteString("foo"));

  // The first Release gives away the buffer and resets the writer. The second
  // release shows that there's nothing to return after resetting.
  ByteString second = writer.Release();
  EXPECT_EQ(second.get(), nullptr);
}

}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase
