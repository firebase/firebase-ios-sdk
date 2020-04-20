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

#include "Firestore/core/src/util/hard_assert.h"

#include <exception>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

void Assert(bool condition) {
  HARD_ASSERT(condition == true);
}

void AssertWithMessage(bool condition) {
  HARD_ASSERT(condition, "condition %s", condition ? "succeeded" : "failed");
}

}  // namespace

TEST(HardAssertTest, Vanilla) {
  Assert(true);

  EXPECT_ANY_THROW(Assert(false));
}

TEST(HardAssertTest, WithMessage) {
  AssertWithMessage(true);

  EXPECT_ANY_THROW(AssertWithMessage(false));
}

TEST(HardAssertTest, NonDefaultThrowHandler) {
  // Used to ensure the original failure handler is restored.
  class ThrowHandlerRestorer {
   public:
    explicit ThrowHandlerRestorer(ThrowHandler orig) : orig_(orig) {
    }
    ~ThrowHandlerRestorer() {
      SetThrowHandler(orig_);
    }

   private:
    ThrowHandler orig_;
  };

  struct FakeException : public std::exception {};
  ThrowHandler prev =
      SetThrowHandler([](ExceptionType, const char*, const char*, const int,
                         const std::string&) { throw FakeException(); });
  ThrowHandlerRestorer _(prev);

  EXPECT_THROW(Assert(false), FakeException);
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
