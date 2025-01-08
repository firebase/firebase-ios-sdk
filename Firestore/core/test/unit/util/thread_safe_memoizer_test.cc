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
#include <thread>

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace {

using namespace std::string_literals;
using firebase::firestore::testing::CountDownLatch;
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

  const auto expected = memoizer.value(func);
  // Do not hardcode "tfj6v4kdxn_0" as the expected value because
  // ThreadSafeMemoizer.value() documents that it _may_ call the given function
  // multiple times.
  ASSERT_THAT(memoizer.value(func),
              MatchesRegex("tfj6v4kdxn_"s + FST_RE_DIGIT + "+"));

  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    ASSERT_EQ(memoizer.value(func), expected);
  }
}

TEST(ThreadSafeMemoizerTest, Value_ShouldOnlyInvokeFunctionOnFirstInvocation) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter;
  auto func = counter.func();
  memoizer.value(func);
  // Do not hardcode 1 as the expected invocation count because
  // ThreadSafeMemoizer.value() documents that it _may_ call the given function
  // multiple times.
  const auto expected_invocation_count = counter.invocation_count();
  for (int i = 0; i < 100; i++) {
    memoizer.value(func);
  }
  EXPECT_EQ(counter.invocation_count(), expected_invocation_count);
}

TEST(ThreadSafeMemoizerTest, Value_ShouldNotInvokeTheFunctionAfterMemoizing) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter;
  auto func = counter.func();

  const auto hardware_concurrency = std::thread::hardware_concurrency();
  const int num_threads = hardware_concurrency != 0 ? hardware_concurrency : 4;
  std::vector<std::thread> threads;
  CountDownLatch latch(num_threads);
  std::atomic<bool> value_has_been_memoized{false};
  for (auto i = num_threads; i > 0; i--) {
    threads.emplace_back([&, i] {
      latch.arrive_and_wait();
      for (int j = 0; j < 100; j++) {
        if (value_has_been_memoized.load(std::memory_order_acquire)) {
          const auto invocation_count_before = counter.invocation_count();
          memoizer.value(func);
          SCOPED_TRACE("thread i=" + std::to_string(i) +
                       " j=" + std::to_string(j));
          EXPECT_EQ(counter.invocation_count(), invocation_count_before);
        } else {
          memoizer.value(func);
          value_has_been_memoized.store(true, std::memory_order_release);
        }
      }
    });
  }

  for (auto& thread : threads) {
    thread.join();
  }
}

TEST(ThreadSafeMemoizerTest,
     CopyConstructor_NoMemoizedValue_OriginalMemoizesFirst) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_copy(memoizer);

  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");
  EXPECT_EQ(memoizer_copy.value(memoizer_copy_counter.func()), "bbb");

  EXPECT_GT(memoizer_counter.invocation_count(), 0);
  EXPECT_GT(memoizer_copy_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest,
     CopyConstructor_NoMemoizedValue_CopyMemoizesFirst) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_copy(memoizer);

  EXPECT_EQ(memoizer_copy.value(memoizer_copy_counter.func()), "bbb");
  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");

  EXPECT_GT(memoizer_counter.invocation_count(), 0);
  EXPECT_GT(memoizer_copy_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest, CopyConstructor_MemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter.func());
  ThreadSafeMemoizer<std::string> memoizer_copy(memoizer);

  EXPECT_EQ(memoizer_copy.value(memoizer_copy_counter.func()), "aaa");

  EXPECT_EQ(memoizer_copy_counter.invocation_count(), 0);
}

}  // namespace
