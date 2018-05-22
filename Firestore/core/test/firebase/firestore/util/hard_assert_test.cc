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

#include <exception>

#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
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

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
