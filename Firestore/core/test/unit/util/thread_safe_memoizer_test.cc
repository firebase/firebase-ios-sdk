/*
 * Copyright 2025 Google LLC
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

#include "Firestore/core/src/util/thread_safe_memoizer.h"
#include "Firestore/core/test/unit/util/thread_safe_memoizer_testing.h"

#include <memory>
#include <string>

#include "gtest/gtest.h"

namespace {

using firebase::firestore::testing::CountingFunc;
using firebase::firestore::util::ThreadSafeMemoizer;

TEST(ThreadSafeMemoizerTest, DefaultConstructor) {
  ThreadSafeMemoizer<int> memoizer;
  auto func = [] { return std::make_shared<int>(42); };
  ASSERT_EQ(memoizer.value(func), 42);
}

TEST(ThreadSafeMemoizerTest, Value_ShouldReturnComputedValueOnFirstInvocation) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter("rztsygzy5z");
  ASSERT_EQ(memoizer.value(counter.func()), "rztsygzy5z");
}

TEST(ThreadSafeMemoizerTest,
     Value_ShouldReturnMemoizedValueOnSubsequentInvocations) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter("tfj6v4kdxn_%s");
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    ASSERT_EQ(memoizer.value(counter.func()), "tfj6v4kdxn_0");
  }
}

TEST(ThreadSafeMemoizerTest, Value_ShouldOnlyInvokeFunctionOnFirstInvocation) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter("pcgx63yaa8_%s");
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    ASSERT_EQ(memoizer.value(counter.func()), "pcgx63yaa8_0");
  }
}

}  // namespace
