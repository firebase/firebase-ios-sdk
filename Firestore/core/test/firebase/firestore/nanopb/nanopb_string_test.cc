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

#include "Firestore/core/src/firebase/firestore/nanopb/nanopb_string.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace nanopb {

TEST(String, DefaultConstructor) {
  String str;
  ASSERT_EQ(nullptr, str.data());
}

TEST(String, FromStdString) {
  std::string original{"foo"};
  String copy{original};
  ASSERT_EQ(copy, original);

  original = "bar";
  ASSERT_EQ(copy, "foo");
}

TEST(String, FromCString) {
  char original[] = {'f', 'o', 'o', '\0'};
  String copy{original};
  ASSERT_EQ(copy, original);

  original[0] = 'b';
  ASSERT_EQ(copy, "foo");
}

TEST(String, WrapByteArray) {
  auto original =
      static_cast<pb_bytes_array_t*>(malloc(PB_BYTES_ARRAY_T_ALLOCSIZE(4)));
  memcpy(original->bytes, "foo", 4);  // null terminator
  original->size = 3;

  String wrapper = String::Wrap(original);
  ASSERT_EQ(wrapper, absl::string_view{"foo"});

  original->bytes[0] = 'b';
  ASSERT_EQ(wrapper, absl::string_view{"boo"});
}

TEST(String, Release) {
  String value{"foo"};

  pb_bytes_array_t* released = value.release();
  ASSERT_EQ(released->size, 3);
  ASSERT_EQ(memcmp(released->bytes, "foo", 3), 0);
  ASSERT_EQ(value.get(), nullptr);

  free(released);
}

TEST(String, Comparison) {
  String abc{"abc"};
  String def{"def"};

  String abc2{"abc"};

  ASSERT_TRUE(abc == abc);
  ASSERT_TRUE(abc == abc2);
  ASSERT_TRUE(abc != def);

  ASSERT_TRUE(abc < def);
  ASSERT_TRUE(abc <= def);
  ASSERT_TRUE(abc <= abc2);

  ASSERT_TRUE(def > abc);
  ASSERT_TRUE(def >= abc);
  ASSERT_TRUE(abc2 >= abc);
}

}  //  namespace nanopb
}  //  namespace firestore
}  //  namespace firebase
