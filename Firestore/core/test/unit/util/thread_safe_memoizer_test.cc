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

#include <memory>
#include <string>
#include <thread>
#include <utility>

#include "Firestore/core/test/unit/util/thread_safe_memoizer_testing.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace {

using namespace std::literals::string_literals;
using firebase::firestore::testing::CountDownLatch;
using firebase::firestore::testing::CountingFunc;
using firebase::firestore::testing::FST_RE_DIGIT;
using firebase::firestore::testing::max_practical_parallel_threads_for_testing;
using firebase::firestore::testing::SetOnDestructor;
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
  CountingFunc memoizer_counter("aaa"), memoizer_copy_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_copy_dest(memoizer);

  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");
  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter.func()), "bbb");

  EXPECT_GT(memoizer_counter.invocation_count(), 0);
  EXPECT_GT(memoizer_copy_dest_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest,
     CopyConstructor_NoMemoizedValue_CopyMemoizesFirst) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_copy_dest(memoizer);

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter.func()), "bbb");
  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");

  EXPECT_GT(memoizer_counter.invocation_count(), 0);
  EXPECT_GT(memoizer_copy_dest_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest, CopyConstructor_MemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter.func());
  ThreadSafeMemoizer<std::string> memoizer_copy_dest(memoizer);

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter.func()), "aaa");

  EXPECT_EQ(memoizer_copy_dest_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest, MoveConstructor_NoMemoizedValue) {
  CountingFunc memoizer_move_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_move_dest(std::move(memoizer));

  EXPECT_EQ(memoizer_move_dest.value(memoizer_move_dest_counter.func()), "bbb");

  EXPECT_GT(memoizer_move_dest_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest, MoveConstructor_MemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_move_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter.func());
  ThreadSafeMemoizer<std::string> memoizer_move_dest(std::move(memoizer));

  EXPECT_EQ(memoizer_move_dest.value(memoizer_move_dest_counter.func()), "aaa");

  EXPECT_EQ(memoizer_move_dest_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest,
     CopyAssignment_NoMemoizedValueToNoMemoizedValue_OriginalMemoizesFirst) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_copy_dest;

  memoizer_copy_dest = memoizer;

  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");
  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter.func()), "bbb");
}

TEST(ThreadSafeMemoizerTest,
     CopyAssignment_NoMemoizedValueToNoMemoizedValue_CopyMemoizesFirst) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_copy_dest;

  memoizer_copy_dest = memoizer;

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter.func()), "bbb");
  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");
}

TEST(ThreadSafeMemoizerTest, CopyAssignment_MemoizedValueToNoMemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter.func());
  const auto expected_memoizer_counter_invocation_count =
      memoizer_counter.invocation_count();
  ThreadSafeMemoizer<std::string> memoizer_copy_dest;

  memoizer_copy_dest = memoizer;

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter.func()), "aaa");
  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");
  EXPECT_EQ(memoizer_counter.invocation_count(),
            expected_memoizer_counter_invocation_count);
  EXPECT_EQ(memoizer_copy_dest_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest, CopyAssignment_NoMemoizedValueToMemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_dest_counter1("bbb1"),
      memoizer_copy_dest_counter2("bbb2");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_copy_dest;
  memoizer_copy_dest.value(memoizer_copy_dest_counter1.func());

  memoizer_copy_dest = memoizer;

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter2.func()),
            "bbb2");
  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");
}

TEST(ThreadSafeMemoizerTest, CopyAssignment_MemoizedValueToMemoizedValue) {
  CountingFunc memoizer_counter1("aaa1"), memoizer_counter2("aaa2"),
      memoizer_copy_dest_counter1("bbb1"), memoizer_copy_dest_counter2("bbb2");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter1.func());
  const auto expected_memoizer_counter1_invocation_count =
      memoizer_counter1.invocation_count();
  ThreadSafeMemoizer<std::string> memoizer_copy_dest;
  memoizer_copy_dest.value(memoizer_copy_dest_counter1.func());
  const auto expected_memoizer_copy_dest_counter1_invocation_count =
      memoizer_copy_dest_counter1.invocation_count();

  memoizer_copy_dest = memoizer;

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter2.func()),
            "aaa1");
  EXPECT_EQ(memoizer.value(memoizer_counter2.func()), "aaa1");
  EXPECT_EQ(memoizer_counter1.invocation_count(),
            expected_memoizer_counter1_invocation_count);
  EXPECT_EQ(memoizer_copy_dest_counter1.invocation_count(),
            expected_memoizer_copy_dest_counter1_invocation_count);
}

TEST(ThreadSafeMemoizerTest, MoveAssignment_MemoizedValueToNoMemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_move_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter.func());
  ThreadSafeMemoizer<std::string> memoizer_move_dest;

  memoizer_move_dest = std::move(memoizer);

  EXPECT_EQ(memoizer_move_dest.value(memoizer_move_dest_counter.func()), "aaa");
  EXPECT_EQ(memoizer_move_dest_counter.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTest, MoveAssignment_NoMemoizedValueToMemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_move_dest_counter1("bbb1"),
      memoizer_move_dest_counter2("bbb2");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_move_dest;
  memoizer_move_dest.value(memoizer_move_dest_counter1.func());

  memoizer_move_dest = std::move(memoizer);

  EXPECT_EQ(memoizer_move_dest.value(memoizer_move_dest_counter2.func()),
            "bbb2");
}

TEST(ThreadSafeMemoizerTest, MoveAssignment_MemoizedValueToMemoizedValue) {
  CountingFunc memoizer_counter1("aaa1"), memoizer_counter2("aaa2"),
      memoizer_move_dest_counter1("bbb1"), memoizer_move_dest_counter2("bbb2");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter1.func());
  const auto expected_memoizer_counter1_invocation_count =
      memoizer_counter1.invocation_count();
  ThreadSafeMemoizer<std::string> memoizer_move_dest;
  memoizer_move_dest.value(memoizer_move_dest_counter1.func());
  const auto expected_memoizer_move_dest_counter1_invocation_count =
      memoizer_move_dest_counter1.invocation_count();

  memoizer_move_dest = std::move(memoizer);

  EXPECT_EQ(memoizer_move_dest.value(memoizer_move_dest_counter2.func()),
            "aaa1");
  EXPECT_EQ(memoizer_counter1.invocation_count(),
            expected_memoizer_counter1_invocation_count);
  EXPECT_EQ(memoizer_move_dest_counter1.invocation_count(),
            expected_memoizer_move_dest_counter1_invocation_count);
}

TEST(ThreadSafeMemoizerTest,
     CopyConstructor_CopySourceKeepsMemoizedValueAlive) {
  CountingFunc memoizer_counter;
  std::atomic<bool> destroyed{false};
  auto memoizer = std::make_unique<ThreadSafeMemoizer<SetOnDestructor>>();
  memoizer->value([&] { return std::make_shared<SetOnDestructor>(destroyed); });

  auto memoizer_copy_dest =
      std::make_unique<ThreadSafeMemoizer<SetOnDestructor>>(*memoizer);

  ASSERT_FALSE(destroyed.load());
  memoizer_copy_dest.reset();
  ASSERT_FALSE(destroyed.load());
  memoizer.reset();
  ASSERT_TRUE(destroyed.load());
}

TEST(ThreadSafeMemoizerTest, CopyAssignment_CopySourceKeepsMemoizedValueAlive) {
  CountingFunc memoizer_counter;
  std::atomic<bool> destroyed{false};
  auto memoizer = std::make_unique<ThreadSafeMemoizer<SetOnDestructor>>();
  memoizer->value([&] { return std::make_shared<SetOnDestructor>(destroyed); });
  auto memoizer_copy_dest =
      std::make_unique<ThreadSafeMemoizer<SetOnDestructor>>();

  *memoizer_copy_dest = *memoizer;

  ASSERT_FALSE(destroyed.load());
  memoizer_copy_dest.reset();
  ASSERT_FALSE(destroyed.load());
  memoizer.reset();
  ASSERT_TRUE(destroyed.load());
}

TEST(ThreadSafeMemoizerTest,
     MoveConstructor_MoveSourceDoesNotKeepMemoizedValueAlive) {
  CountingFunc memoizer_counter;
  std::atomic<bool> destroyed{false};
  ThreadSafeMemoizer<SetOnDestructor> memoizer;
  memoizer.value([&] { return std::make_shared<SetOnDestructor>(destroyed); });

  auto memoizer_move_dest =
      std::make_unique<ThreadSafeMemoizer<SetOnDestructor>>(
          std::move(memoizer));

  ASSERT_FALSE(destroyed.load());
  memoizer_move_dest.reset();
  ASSERT_TRUE(destroyed.load());
}

TEST(ThreadSafeMemoizerTest,
     MoveAssignment_MoveSourceDoesNotKeepMemoizedValueAlive) {
  CountingFunc memoizer_counter;
  std::atomic<bool> destroyed{false};
  ThreadSafeMemoizer<SetOnDestructor> memoizer;
  memoizer.value([&] { return std::make_shared<SetOnDestructor>(destroyed); });
  auto memoizer_move_dest =
      std::make_unique<ThreadSafeMemoizer<SetOnDestructor>>();

  *memoizer_move_dest = std::move(memoizer);

  ASSERT_FALSE(destroyed.load());
  memoizer_move_dest.reset();
  ASSERT_TRUE(destroyed.load());
}

TEST(ThreadSafeMemoizerTest, TSAN_ConcurrentCallsToValueShouldNotDataRace) {
  ThreadSafeMemoizer<int> memoizer;
  const auto num_threads = max_practical_parallel_threads_for_testing() * 4;
  CountDownLatch latch(num_threads);
  std::vector<std::thread> threads;
  for (auto i = num_threads; i > 0; --i) {
    threads.emplace_back([i, &latch, &memoizer] {
      latch.arrive_and_wait();
      memoizer.value([i] { return std::make_shared<int>(i); });
    });
  }
  for (auto&& thread : threads) {
    thread.join();
  }
}

TEST(ThreadSafeMemoizerTest, TSAN_ValueInACopyShouldNotDataRace) {
  ThreadSafeMemoizer<int> memoizer;
  memoizer.value([&] { return std::make_shared<int>(1111); });
  std::unique_ptr<ThreadSafeMemoizer<int>> memoizer_copy;
  // NOTE: Always use std::memory_order_relaxed when loading from and storing
  // into this variable to avoid creating a happens-before releationship, which
  // would defeat the purpose of this test.
  std::atomic<ThreadSafeMemoizer<int>*> memoizer_copy_atomic(nullptr);

  std::thread thread1([&] {
    memoizer_copy = std::make_unique<ThreadSafeMemoizer<int>>(memoizer);
    memoizer_copy_atomic.store(memoizer_copy.get(), std::memory_order_relaxed);
  });
  std::thread thread2([&] {
    ThreadSafeMemoizer<int>* memoizer_ptr = nullptr;
    while (true) {
      memoizer_ptr = memoizer_copy_atomic.load(std::memory_order_relaxed);
      if (memoizer_ptr) {
        break;
      }
      std::this_thread::yield();
    }
    memoizer_ptr->value([&] { return std::make_shared<int>(2222); });
  });

  thread1.join();
  thread2.join();

  const auto memoizer_copy_value =
      memoizer_copy->value([&] { return std::make_shared<int>(3333); });
  EXPECT_EQ(memoizer_copy_value, 1111);
}

}  // namespace
