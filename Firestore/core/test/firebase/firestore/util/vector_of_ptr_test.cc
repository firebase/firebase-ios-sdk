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

#include "Firestore/core/src/firebase/firestore/util/vector_of_ptr.h"

#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(VectorOfPtrTest, DefaultConstructor) {
  vector_of_ptr<std::shared_ptr<int>> values;
  EXPECT_EQ(0, values.size());
}

TEST(VectorOfPtrTest, PushBack) {
  vector_of_ptr<std::shared_ptr<int>> values;
  values.push_back(std::make_shared<int>(0));
  values.push_back(std::make_shared<int>(42));
  EXPECT_EQ(2, values.size());
}

TEST(VectorOfPtrTest, BracedInitialization) {
  vector_of_ptr<std::shared_ptr<int>> brace_initialized_ints{
      std::make_shared<int>(0), std::make_shared<int>(1)};

  EXPECT_EQ(2, brace_initialized_ints.size());

  brace_initialized_ints = {};
  EXPECT_EQ(0, brace_initialized_ints.size());
}

TEST(VectorOfPtrTest, WorksWithUniquePtr) {
  vector_of_ptr<std::unique_ptr<int>> values;
  values.push_back(absl::make_unique<int>(42));

  auto pointer = absl::make_unique<int>(0);
  values.push_back(std::move(pointer));

  ASSERT_EQ(2, values.size());
}

TEST(VectorOfPtrTest, EqualityIsValueEquality) {
  using int_ptr_vector = vector_of_ptr<std::shared_ptr<int>>;
  int_ptr_vector lhs = {std::make_shared<int>(0), std::make_shared<int>(1)};
  int_ptr_vector rhs = {std::make_shared<int>(0), std::make_shared<int>(1)};
  int_ptr_vector other = {std::make_shared<int>(1), std::make_shared<int>(0)};
  int_ptr_vector contains_nulls = {nullptr, nullptr};
  int_ptr_vector empty;

  EXPECT_EQ(empty, int_ptr_vector());

  EXPECT_EQ(lhs, lhs);
  EXPECT_EQ(lhs, rhs);
  EXPECT_NE(lhs, other);
  EXPECT_NE(lhs, contains_nulls);
  EXPECT_NE(lhs, empty);

  EXPECT_EQ(contains_nulls, contains_nulls);
  EXPECT_NE(contains_nulls, lhs);
}

TEST(VectorOfPtrTest, IterationIsOnPointers) {
  std::shared_ptr<int> pointers[] = {std::make_shared<int>(-1),
                                     std::make_shared<int>(42)};
  vector_of_ptr<std::shared_ptr<int>> vector = {pointers[0], pointers[1]};

  size_t pos = 0;
  for (const std::shared_ptr<int>& element : vector) {
    ASSERT_EQ(*pointers[pos], *element);
    ++pos;
  }
  ASSERT_EQ(pos, sizeof(pointers) / sizeof(pointers[0]));
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
