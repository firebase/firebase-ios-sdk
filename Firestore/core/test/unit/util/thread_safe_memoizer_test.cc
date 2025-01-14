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
using firebase::firestore::testing::GenerateRandomBool;
using firebase::firestore::testing::max_practical_parallel_threads_for_testing;
using firebase::firestore::testing::SetOnDestructor;
using firebase::firestore::util::ThreadSafeMemoizer;
using testing::MatchesRegex;
using testing::StartsWith;

/**
 * Performs a copy or move assignment (chosen randomly) on the given memoizer
 * and then ensure that it behaves as expected. This is useful for testing the
 * "move" logic because a moved-from object, according to the C++ standard, is
 * in a "valid, but unspecified" state and the only operations it is guaranteed
 * to support are assignment and destruction.
 */
void VerifyWorksAfterBeingAssigned(ThreadSafeMemoizer<std::string>& memoizer);

TEST(ThreadSafeMemoizerTest, DefaultConstructor) {
  ThreadSafeMemoizer<int> memoizer;
  auto func = [] { return std::make_shared<int>(42); };
  EXPECT_EQ(memoizer.value(func), 42);
}

TEST(ThreadSafeMemoizerTest, Value_ShouldReturnComputedValueOnFirstInvocation) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter("rztsygzy5z");
  EXPECT_EQ(memoizer.value(counter.func()), "rztsygzy5z");
}

TEST(ThreadSafeMemoizerTest,
     Value_ShouldReturnMemoizedValueOnSubsequentInvocations) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter("tfj6v4kdxn_%s");
  auto func = counter.func();

  memoizer.value(func);

  ASSERT_EQ(memoizer.value(func), "tfj6v4kdxn_0");
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    ASSERT_EQ(memoizer.value(func), "tfj6v4kdxn_0");
  }
}

TEST(ThreadSafeMemoizerTest, Value_ShouldOnlyInvokeFunctionOnFirstInvocation) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter;
  auto func = counter.func();
  memoizer.value(func);

  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    memoizer.value(func);
    EXPECT_EQ(counter.invocation_count(), 1);
  }
}

TEST(ThreadSafeMemoizerTest, Value_ShouldNotInvokeTheFunctionAfterMemoizing) {
  ThreadSafeMemoizer<std::string> memoizer;
  CountingFunc counter("jhvyg8aym4_invocation=%s_thread=%c");

  const int num_threads = max_practical_parallel_threads_for_testing();
  std::vector<std::thread> threads;
  CountDownLatch latch(num_threads);
  std::atomic<bool> has_memoized_value{false};

  for (auto i = num_threads; i > 0; i--) {
    threads.emplace_back([&, i] {
      // Create a std::function that increments a local count when invoked.
      const std::string thread_id = std::to_string(i);
      int my_func_invocation_count = 0;
      auto func = [&, wrapped_func = counter.func(thread_id)] {
        my_func_invocation_count++;
        return wrapped_func();
      };

      // Wait for all the other threads to get here before proceeding, to
      // maximize concurrent access to the ThreadSafeMemoizer object.
      latch.arrive_and_wait();

      // Give all the threads a chance to exit the busy wait in
      // arrive_and_wait() to reduce the chance of unintended "happens-before"
      // relationships between threads being established.
      for (auto k = num_threads * 2; k > 0; --k) {
        std::this_thread::yield();
      }

      // Make an initial invocation of memoizer.value(). If some other thread
      // is known to have already set the memoized value then ensure that our
      // local function is _not_ invoked; otherwise, announce to the other
      // threads that there is _now_ a memoized value.
      const int expected_func_invocation_count = [&] {
        const bool had_memoized_value =
            has_memoized_value.load(std::memory_order_acquire);
        auto memoized_value = memoizer.value(func);

        SCOPED_TRACE("thread i=" + thread_id + " had_memoized_value=" +
                     std::to_string(had_memoized_value) +
                     " memoized_value=" + memoized_value);
        if (had_memoized_value) {
          EXPECT_EQ(my_func_invocation_count, 0);
          return 0;
        } else {
          has_memoized_value.store(true, std::memory_order_release);
          EXPECT_GE(my_func_invocation_count, 0);
          EXPECT_LE(my_func_invocation_count, 1);
          return my_func_invocation_count;
        }
      }();

      // Make subsequent invocations of memoizer.value() and ensure that our
      // local function is _not_ invoked, since we are guaranteed that a value
      // was already memoized, either by us or by some other thread.
      for (int j = 0; j < 100; j++) {
        auto memoized_value = memoizer.value(func);
        SCOPED_TRACE("thread i=" + thread_id + " j=" + std::to_string(j) +
                     " memoized_value=" + memoized_value);
        EXPECT_EQ(my_func_invocation_count, expected_func_invocation_count);
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

  EXPECT_EQ(memoizer_counter.invocation_count(), 1);
  EXPECT_EQ(memoizer_copy_dest_counter.invocation_count(), 1);
}

TEST(ThreadSafeMemoizerTest,
     CopyConstructor_NoMemoizedValue_CopyMemoizesFirst) {
  CountingFunc memoizer_counter("aaa"), memoizer_copy_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  ThreadSafeMemoizer<std::string> memoizer_copy_dest(memoizer);

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter.func()), "bbb");
  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");

  EXPECT_EQ(memoizer_counter.invocation_count(), 1);
  EXPECT_EQ(memoizer_copy_dest_counter.invocation_count(), 1);
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

  EXPECT_EQ(memoizer_move_dest_counter.invocation_count(), 1);
  VerifyWorksAfterBeingAssigned(memoizer);
}

TEST(ThreadSafeMemoizerTest, MoveConstructor_MemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_move_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter.func());
  ThreadSafeMemoizer<std::string> memoizer_move_dest(std::move(memoizer));

  EXPECT_EQ(memoizer_move_dest.value(memoizer_move_dest_counter.func()), "aaa");

  EXPECT_EQ(memoizer_move_dest_counter.invocation_count(), 0);
  VerifyWorksAfterBeingAssigned(memoizer);
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
  ThreadSafeMemoizer<std::string> memoizer_copy_dest;

  memoizer_copy_dest = memoizer;

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter.func()), "aaa");
  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");
  EXPECT_EQ(memoizer_counter.invocation_count(), 1);
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
  ThreadSafeMemoizer<std::string> memoizer_copy_dest;
  memoizer_copy_dest.value(memoizer_copy_dest_counter1.func());

  memoizer_copy_dest = memoizer;

  EXPECT_EQ(memoizer_copy_dest.value(memoizer_copy_dest_counter2.func()),
            "aaa1");
  EXPECT_EQ(memoizer.value(memoizer_counter2.func()), "aaa1");
  EXPECT_EQ(memoizer_counter1.invocation_count(), 1);
  EXPECT_EQ(memoizer_copy_dest_counter1.invocation_count(), 1);
}

TEST(ThreadSafeMemoizerTest, CopyAssignment_CopyToSelf_NoMemoizedValue) {
  CountingFunc memoizer_counter("aaa");
  ThreadSafeMemoizer<std::string> memoizer;
  auto& looks_like_another_memoizer = memoizer;
  ASSERT_EQ(&memoizer, &looks_like_another_memoizer);

  memoizer = looks_like_another_memoizer;

  EXPECT_EQ(memoizer.value(memoizer_counter.func()), "aaa");
  EXPECT_EQ(memoizer_counter.invocation_count(), 1);
}

TEST(ThreadSafeMemoizerTest, CopyAssignment_CopyToSelf_MemoizedValue) {
  CountingFunc memoizer_counter("aaa_%s");
  auto func = memoizer_counter.func();
  ThreadSafeMemoizer<std::string> memoizer;
  auto& looks_like_another_memoizer = memoizer;
  ASSERT_EQ(&memoizer, &looks_like_another_memoizer);
  memoizer.value(func);

  memoizer = looks_like_another_memoizer;

  EXPECT_EQ(memoizer.value(func), "aaa_0");
  EXPECT_EQ(memoizer_counter.invocation_count(), 1);
}

TEST(ThreadSafeMemoizerTest, MoveAssignment_MemoizedValueToNoMemoizedValue) {
  CountingFunc memoizer_counter("aaa"), memoizer_move_dest_counter("bbb");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter.func());
  ThreadSafeMemoizer<std::string> memoizer_move_dest;

  memoizer_move_dest = std::move(memoizer);

  EXPECT_EQ(memoizer_move_dest.value(memoizer_move_dest_counter.func()), "aaa");
  EXPECT_EQ(memoizer_move_dest_counter.invocation_count(), 0);
  VerifyWorksAfterBeingAssigned(memoizer);
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
  VerifyWorksAfterBeingAssigned(memoizer);
}

TEST(ThreadSafeMemoizerTest, MoveAssignment_MemoizedValueToMemoizedValue) {
  CountingFunc memoizer_counter1("aaa1"), memoizer_counter2("aaa2"),
      memoizer_move_dest_counter1("bbb1"), memoizer_move_dest_counter2("bbb2");
  ThreadSafeMemoizer<std::string> memoizer;
  memoizer.value(memoizer_counter1.func());
  ThreadSafeMemoizer<std::string> memoizer_move_dest;
  memoizer_move_dest.value(memoizer_move_dest_counter1.func());

  memoizer_move_dest = std::move(memoizer);

  EXPECT_EQ(memoizer_move_dest.value(memoizer_move_dest_counter2.func()),
            "aaa1");
  EXPECT_EQ(memoizer_counter1.invocation_count(), 1);
  EXPECT_EQ(memoizer_move_dest_counter1.invocation_count(), 1);
  VerifyWorksAfterBeingAssigned(memoizer);
}

TEST(ThreadSafeMemoizerTest, MoveAssignment_MoveToSelf_NoMemoizedValue) {
  CountingFunc memoizer_counter("aaa");
  ThreadSafeMemoizer<std::string> memoizer;
  auto& looks_like_another_memoizer = memoizer;
  ASSERT_EQ(&memoizer, &looks_like_another_memoizer);

  memoizer = std::move(looks_like_another_memoizer);

  VerifyWorksAfterBeingAssigned(memoizer);
}

TEST(ThreadSafeMemoizerTest, MoveAssignment_MoveToSelf_MemoizedValue) {
  CountingFunc memoizer_counter("aaa_%s");
  auto func = memoizer_counter.func();
  ThreadSafeMemoizer<std::string> memoizer;
  auto& looks_like_another_memoizer = memoizer;
  ASSERT_EQ(&memoizer, &looks_like_another_memoizer);
  memoizer.value(func);

  memoizer = std::move(looks_like_another_memoizer);

  VerifyWorksAfterBeingAssigned(memoizer);
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
  const auto num_threads = max_practical_parallel_threads_for_testing();
  CountDownLatch latch(num_threads);
  std::vector<std::thread> threads;
  for (auto i = num_threads; i > 0; --i) {
    threads.emplace_back([i, num_threads, &latch, &memoizer] {
      latch.arrive_and_wait();

      for (auto k = num_threads; k > 0; --k) {
        std::this_thread::yield();
      }

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
  // into this variable to avoid creating a happens-before relationship, which
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

void VerifyWorksAfterBeingAssigned(ThreadSafeMemoizer<std::string>& memoizer) {
  ThreadSafeMemoizer<std::string> other_memoizer;
  CountingFunc other_memoizer_counter("sx22pz64dn_%s");

  // Randomly select whether the original memoizer had a memoized value.
  const bool other_memoizer_has_memoized_value = GenerateRandomBool();
  if (other_memoizer_has_memoized_value) {
    other_memoizer.value(other_memoizer_counter.func());
  }

  // Randomly select copy-assignment or move-assignment.
  if (GenerateRandomBool()) {
    memoizer = other_memoizer;
  } else {
    memoizer = std::move(other_memoizer);
  }

  // Verify that the given `ThreadSafeMemoizer` behaves correctly after being
  // assigned.
  if (other_memoizer_has_memoized_value) {
    EXPECT_EQ(memoizer.value(other_memoizer_counter.func()), "sx22pz64dn_0");
    EXPECT_EQ(other_memoizer_counter.invocation_count(), 1);
  } else {
    CountingFunc temp_counter("mx3rfb8qqk");
    EXPECT_EQ(memoizer.value(temp_counter.func()), "mx3rfb8qqk");
    EXPECT_EQ(temp_counter.invocation_count(), 1);
    EXPECT_EQ(other_memoizer_counter.invocation_count(), 0);
  }
}

}  // namespace
