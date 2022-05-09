/*
 * Copyright 2020 Google LLC
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

#include <sstream>
#include <utility>

#include "Firestore/core/src/core/transaction_options.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace core {
namespace {

TEST(TransactionOptionsTest, ZeroArgConstructor) {
  TransactionOptions options;
  EXPECT_EQ(options.max_attempts(), 5);
}

TEST(TransactionOptionsTest, CopyConstructor) {
  TransactionOptions options1;
  options1.set_max_attempts(999);

  TransactionOptions options2(options1);

  EXPECT_EQ(options2.max_attempts(), 999);
}

TEST(TransactionOptionsTest, MoveConstructor) {
  TransactionOptions options1;
  options1.set_max_attempts(999);

  TransactionOptions options2(std::move(options1));

  EXPECT_EQ(options2.max_attempts(), 999);
}

TEST(TransactionOptionsTest, CopyAssignmentOperator) {
  TransactionOptions options1;
  options1.set_max_attempts(999);
  TransactionOptions options2;
  options2.set_max_attempts(123);

  options2 = options1;

  EXPECT_EQ(options2.max_attempts(), 999);
}

TEST(TransactionOptionsTest, MoveAssignmentOperator) {
  TransactionOptions options1;
  options1.set_max_attempts(999);
  TransactionOptions options2;
  options2.set_max_attempts(123);

  options2 = std::move(options1);

  EXPECT_EQ(options2.max_attempts(), 999);
}

TEST(TransactionOptionsTest, SetMaxAttempts) {
  TransactionOptions options;
  options.set_max_attempts(10);
  EXPECT_EQ(options.max_attempts(), 10);
  options.set_max_attempts(20);
  EXPECT_EQ(options.max_attempts(), 20);
  options.set_max_attempts(1);
  EXPECT_EQ(options.max_attempts(), 1);
}

TEST(TransactionOptionsTest, SetMaxAttemptsFailsOnInvalidMaxAttempts) {
  TransactionOptions options;
  EXPECT_ANY_THROW(options.set_max_attempts(0));
  EXPECT_ANY_THROW(options.set_max_attempts(-1));
  EXPECT_ANY_THROW(options.set_max_attempts(-999));
  EXPECT_ANY_THROW(options.set_max_attempts(INT32_MIN));
}

TEST(TransactionOptionsTest, ToString) {
  TransactionOptions options;
  options.set_max_attempts(999);
  EXPECT_EQ(options.ToString(), "TransactionOptions(max_attempts=999)");
}

TEST(TransactionOptionsTest, WriteToOstream) {
  TransactionOptions options;
  options.set_max_attempts(999);
  std::ostringstream out;

  out << options;

  EXPECT_EQ(out.str(), options.ToString());
}

}  // namespace
}  // namespace core
}  // namespace firestore
}  // namespace firebase
