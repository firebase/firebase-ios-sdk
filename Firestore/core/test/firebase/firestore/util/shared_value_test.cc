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

#include "Firestore/core/src/firebase/firestore/util/shared_value.h"

#include <memory>
#include <string>

#include "absl/memory/memory.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(SharedValueTest, DefaultConstructs) {
  shared_value<int> shared;
  ASSERT_EQ(shared.get(), nullptr);
}

TEST(SharedValueTest, Copies) {
  std::string value("hello world");
  shared_value<std::string> shared(value);
  EXPECT_EQ(*shared, "hello world");

  shared_value<std::string> shared2(shared);
  EXPECT_EQ(*shared2, "hello world");
}

TEST(SharedValueTest, Moves) {
  auto unique = absl::make_unique<int>(42);
  int* raw = unique.get();

  shared_value<std::unique_ptr<int>> shared(std::move(unique));
  EXPECT_EQ((*shared).get(), raw);

  shared_value<std::unique_ptr<int>> shared2(std::move(shared));
  EXPECT_EQ((*shared2).get(), raw);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
