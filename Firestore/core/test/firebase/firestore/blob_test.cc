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

#include "Firestore/core/include/firebase/firestore/blob.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

TEST(Blob, Getter) {
  Blob a = Blob::CopyFrom("\1\2\3", 3);
  char* bytes = new char[2];
  bytes[0] = '\4';
  bytes[1] = '\5';
  Blob b = Blob::MoveFrom(bytes, 2);

  // Get
  const char* buffer = static_cast<const char*>(a.Get());
  EXPECT_EQ(1, buffer[0]);
  EXPECT_EQ(2, buffer[1]);
  EXPECT_EQ(3, buffer[2]);
  buffer = static_cast<const char*>(b.Get());
  EXPECT_EQ(4, buffer[0]);
  EXPECT_EQ(5, buffer[1]);
  // Just do a naive comparison and let compiler auto-cast the integer type.
  EXPECT_TRUE(3 == a.size());
  EXPECT_TRUE(2 == b.size());

  // Release
  buffer = static_cast<const char*>(a.Release());
  EXPECT_EQ(1, buffer[0]);
  EXPECT_EQ(2, buffer[1]);
  EXPECT_EQ(3, buffer[2]);
  delete buffer;
  buffer = static_cast<const char*>(b.Release());
  EXPECT_EQ(4, buffer[0]);
  EXPECT_EQ(5, buffer[1]);
  delete buffer;
  // Just do a naive comparison and let compiler auto-cast the integer type.
  EXPECT_TRUE(0 == a.size());
  EXPECT_TRUE(0 == b.size());
}

TEST(Blob, Copy) {
  Blob a = Blob::CopyFrom("abc", 4);
  Blob b = Blob::CopyFrom("def", 4);
  EXPECT_EQ(0, strcmp("abc", static_cast<const char*>(a.Get())));
  EXPECT_EQ(0, strcmp("def", static_cast<const char*>(b.Get())));
  b = a;
  EXPECT_EQ(0, strcmp("abc", static_cast<const char*>(a.Get())));
  EXPECT_EQ(0, strcmp("abc", static_cast<const char*>(b.Get())));
}

TEST(Blob, Swap) {
  Blob a = Blob::CopyFrom("abc", 4);
  Blob b = Blob::CopyFrom("def", 4);
  EXPECT_EQ(0, strcmp("abc", static_cast<const char*>(a.Get())));
  EXPECT_EQ(0, strcmp("def", static_cast<const char*>(b.Get())));
  b.Swap(a);
  EXPECT_EQ(0, strcmp("def", static_cast<const char*>(a.Get())));
  EXPECT_EQ(0, strcmp("abc", static_cast<const char*>(b.Get())));
}

TEST(Blob, Comparison) {
  EXPECT_TRUE(Blob::CopyFrom("\1\2", 2) < Blob::CopyFrom("\1\2\3", 3));
  EXPECT_TRUE(Blob::CopyFrom("\1\2\3", 3) < Blob::CopyFrom("\1\4", 2));
}

}  // namespace firestore
}  // namespace firebase
