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

#include "Firestore/core/src/firebase/firestore/model/blob.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace model {

TEST(Blob, Getter) {
  Blob a = Blob::CopyFrom(reinterpret_cast<const uint8_t*>("\1\2\3"), 3);
  char* bytes = new char[2];
  bytes[0] = '\4';
  bytes[1] = '\5';
  Blob b = Blob::MoveFrom(reinterpret_cast<uint8_t*>(bytes), 2);

  // It does not matter const char or uint8 here since either way is
  // presented by CPU byte actually.
  const char* buffer = reinterpret_cast<const char*>(a.get());
  EXPECT_EQ(1, buffer[0]);
  EXPECT_EQ(2, buffer[1]);
  EXPECT_EQ(3, buffer[2]);
  buffer = reinterpret_cast<const char*>(b.get());
  EXPECT_EQ(4, buffer[0]);
  EXPECT_EQ(5, buffer[1]);
  // Just do a naive comparison and let compiler auto-cast the integer type.
  EXPECT_TRUE(3 == a.size());
  EXPECT_TRUE(2 == b.size());
}

TEST(Blob, Copy) {
  Blob a = Blob::CopyFrom(reinterpret_cast<const uint8_t*>("abc"), 4);
  Blob b = Blob::CopyFrom(reinterpret_cast<const uint8_t*>("defg"), 5);
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(a.get())));
  EXPECT_EQ(0, strcmp("defg", reinterpret_cast<const char*>(b.get())));
  b = a;
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(a.get())));
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(b.get())));
  Blob c = a;
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(a.get())));
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(c.get())));
}

TEST(Blob, Move) {
  Blob a = Blob::CopyFrom(reinterpret_cast<const uint8_t*>("abc"), 4);
  Blob b = Blob::CopyFrom(reinterpret_cast<const uint8_t*>("defg"), 5);
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(a.get())));
  EXPECT_EQ(0, strcmp("defg", reinterpret_cast<const char*>(b.get())));
  b = std::move(a);
  EXPECT_EQ(0, strcmp("defg", reinterpret_cast<const char*>(a.get())));
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(b.get())));
  std::swap(a, b);
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(a.get())));
  EXPECT_EQ(0, strcmp("defg", reinterpret_cast<const char*>(b.get())));
  Blob c = std::move(a);
  EXPECT_EQ(nullptr, a.get());  // a gets initial nullptr from c.
  EXPECT_EQ(0, strcmp("abc", reinterpret_cast<const char*>(c.get())));
}

TEST(Blob, Comparison) {
  EXPECT_LT(Blob::CopyFrom(reinterpret_cast<const uint8_t*>("\1\2"), 2),
            Blob::CopyFrom(reinterpret_cast<const uint8_t*>("\1\2\3"), 3));
  EXPECT_LT(Blob::CopyFrom(reinterpret_cast<const uint8_t*>("\1\2\3"), 3),
            Blob::CopyFrom(reinterpret_cast<const uint8_t*>("\1\4"), 2));
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase
