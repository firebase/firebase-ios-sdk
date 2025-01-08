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

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace {

using namespace std::string_literals;
using firebase::firestore::testing::CountingFunc;
using firebase::firestore::testing::FST_RE_DIGIT;
using firebase::firestore::util::ThreadSafeMemoizer;
using testing::MatchesRegex;

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
  auto func = counter.func();
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    const auto regex = "tfj6v4kdxn_"s + FST_RE_DIGIT + "+";
    ASSERT_THAT(memoizer.value(func), MatchesRegex(regex));
  }
}

TEST(ThreadSafeMemoizerTest, Value_ShouldOnlyInvokeFunctionOnFirstInvocation) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter("pcgx63yaa8_%s");
  auto func = counter.func();
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    const auto regex = "pcgx63yaa8_"s + FST_RE_DIGIT + "+";
    ASSERT_THAT(memoizer.value(func), MatchesRegex(regex));
  }
}

}  // namespace
