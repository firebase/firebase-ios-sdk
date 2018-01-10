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

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

#include <exception>

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

void AssertWithExpression(bool condition) {
  FIREBASE_ASSERT_WITH_EXPRESSION(condition, 1 + 2 + 3);
}

void Assert(bool condition) {
  FIREBASE_ASSERT(condition == true);
}

void AssertMessageWithExpression(bool condition) {
  FIREBASE_ASSERT_MESSAGE_WITH_EXPRESSION(condition, 1 + 2 + 3, "connection %s",
                                          condition ? "succeeded" : "failed");
}

}  // namespace

TEST(Assert, WithExpression) {
  AssertWithExpression(true);

  EXPECT_ANY_THROW(AssertWithExpression(false));
}

TEST(Assert, Vanilla) {
  Assert(true);

  EXPECT_ANY_THROW(Assert(false));
}

TEST(Assert, WithMessageAndExpression) {
  AssertMessageWithExpression(true);

  EXPECT_ANY_THROW(AssertMessageWithExpression(false));
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
