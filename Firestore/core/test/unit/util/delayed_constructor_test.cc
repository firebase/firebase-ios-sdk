/*
 * Copyright 2017 Google
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

#include "Firestore/core/src/util/delayed_constructor.h"

#include <string>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(DelayedConstructorTest, NoDefaultConstructor) {
  static int constructed = 0;

  struct NoDefault {
    NoDefault() = delete;
    NoDefault(const NoDefault&) = delete;

    explicit NoDefault(int) {
      constructed += 1;
    }
  };

  DelayedConstructor<NoDefault> value;
  EXPECT_EQ(0, constructed);

  value.Init(0);
  EXPECT_EQ(1, constructed);
}

TEST(DelayedConstructorTest, NonCopyableType) {
  static int constructed = 0;

  struct NonCopyable {
    NonCopyable() {
      constructed += 1;
    }
    NonCopyable(const NonCopyable&) = delete;
  };

  DelayedConstructor<NonCopyable> value;
  EXPECT_EQ(0, constructed);

  value.Init();
  EXPECT_EQ(1, constructed);
}

TEST(DelayedConstructorTest, CopyableType) {
  static int constructed = 0;

  struct Copyable {
    Copyable() = delete;
    Copyable(const Copyable&) {
      constructed += 1;
    }

    // Constructs the value without exposing a default constructor
    explicit Copyable(int) {
    }
  };

  DelayedConstructor<Copyable> value;
  EXPECT_EQ(0, constructed);

  value.Init(Copyable(0));
  EXPECT_EQ(1, constructed);
}

TEST(DelayedConstructorTest, MoveOnlyType) {
  static int constructed = 0;

  struct MoveOnly {
    MoveOnly() = delete;
    MoveOnly(MoveOnly&&) {
      constructed += 1;
    }

    // Constructs the value without exposing a default constructor
    explicit MoveOnly(int) {
    }
  };

  DelayedConstructor<MoveOnly> value;
  EXPECT_EQ(0, constructed);

  value.Init(MoveOnly(0));
  EXPECT_EQ(1, constructed);
}

TEST(DelayedConstructorTest, CallsDestructor) {
  static int constructed = 0;
  static int destructed = 0;

  struct Counter {
    Counter() {
      constructed += 1;
    }

    ~Counter() {
      destructed += 1;
    }
  };

  {
    DelayedConstructor<Counter> value;
    EXPECT_EQ(0, constructed);
    EXPECT_EQ(0, destructed);

    value.Init();
    EXPECT_EQ(1, constructed);
    EXPECT_EQ(0, destructed);
  }

  EXPECT_EQ(1, constructed);
  EXPECT_EQ(1, destructed);
}

TEST(DelayedConstructorTest, SingleConstructorArg) {
  DelayedConstructor<std::string> str;
  str.Init("foo");

  EXPECT_EQ(*str, std::string("foo"));
}

TEST(DelayedConstructorTest, MultipleConstructorArgs) {
  DelayedConstructor<std::string> str;
  str.Init(3, 'a');

  EXPECT_EQ(*str, std::string("aaa"));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
