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

#include "Firestore/core/test/unit/util/thread_safe_memoizer_testing.h"

#include <algorithm>
#include <array>
#include <thread>

#include "gtest/gtest.h"

namespace {

using firebase::firestore::testing::CountDownLatch;
using firebase::firestore::testing::CountingFunc;
using firebase::firestore::testing::max_practical_parallel_threads_for_testing;

TEST(ThreadSafeMemoizerTesting, CountingFuncDefaultConstructor) {
  CountingFunc counting_func;
  auto func = counting_func.func();
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), i_str);
  }
}

TEST(ThreadSafeMemoizerTesting,
     CountingFuncShouldReturnSameStringIfNoReplacements) {
  CountingFunc counting_func("tdjebqrtny");
  auto func = counting_func.func();
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    EXPECT_EQ(*func(), "tdjebqrtny");
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncHandlesPercentSAtStart) {
  CountingFunc counting_func("%scmgb5bsbj2");
  auto func = counting_func.func();
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), i_str + "cmgb5bsbj2");
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncHandlesPercentSAtEnd) {
  CountingFunc counting_func("nd3krmj2mn%s");
  auto func = counting_func.func();
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), "nd3krmj2mn" + i_str);
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncHandlesPercentSInMiddle) {
  CountingFunc counting_func("txxz4%sddrs5");
  auto func = counting_func.func();
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), "txxz4" + i_str + "ddrs5");
  }
}

TEST(ThreadSafeMemoizerTesting,
     CountingFuncHandlesMultiplePercentSReplacements) {
  CountingFunc counting_func("%scx%s3b%s5jazwf%s");
  auto func = counting_func.func();
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), i_str + "cx" + i_str + "3b" + i_str + "5jazwf" + i_str);
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncHandlesPercentCAtStart) {
  CountingFunc counting_func("%cwxxsz2qm2e");
  auto func = counting_func.func("7k4bek9pfx");
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    EXPECT_EQ(*func(), "7k4bek9pfxwxxsz2qm2e");
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncHandlesPercentCAtEnd) {
  CountingFunc counting_func("7432wt5hnw%c");
  auto func = counting_func.func("yzcjsrh5tp");
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    EXPECT_EQ(*func(), "7432wt5hnwyzcjsrh5tp");
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncHandlesPercentCInMiddle) {
  CountingFunc counting_func("wxxsz%c2qm2e");
  auto func = counting_func.func("gptebm6kh5");
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    EXPECT_EQ(*func(), "wxxszgptebm6kh52qm2e");
  }
}

TEST(ThreadSafeMemoizerTesting,
     CountingFuncHandlesMultiplePercentCReplacements) {
  CountingFunc counting_func("%cw7%c98%c8cg5mz%c");
  auto func = counting_func.func("ww3");
  for (int i = 0; i < 100; i++) {
    SCOPED_TRACE("iteration i=" + std::to_string(i));
    EXPECT_EQ(*func(), "ww3w7ww398ww38cg5mzww3");
  }
}

TEST(ThreadSafeMemoizerTesting,
     CountingFuncHandlesDifferingPercentCReplacements) {
  CountingFunc counting_func("5c8sc_%c_gr7vf");
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    auto func = counting_func.func("a" + i_str + "a");
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), "5c8sc_a" + i_str + "a_gr7vf");
  }
}

TEST(ThreadSafeMemoizerTesting,
     CountingFuncHandlesAlternatingPercentReplacements1) {
  CountingFunc counting_func("%s_%c_%s_%c_%s");
  auto func = counting_func.func("bbb");
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), i_str + "_bbb_" + i_str + "_bbb_" + i_str);
  }
}

TEST(ThreadSafeMemoizerTesting,
     CountingFuncHandlesAlternatingPercentReplacements2) {
  CountingFunc counting_func("%c_%s_%c_%s_%c");
  auto func = counting_func.func("bbb");
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), "bbb_" + i_str + "_bbb_" + i_str + "_bbb");
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncHandlesInvalidPercents) {
  CountingFunc counting_func("%%s %% %x %cs %");
  auto func = counting_func.func("zzz");
  for (int i = 0; i < 100; i++) {
    const std::string i_str = std::to_string(i);
    SCOPED_TRACE("iteration i=" + i_str);
    EXPECT_EQ(*func(), "%" + i_str + " %% %x zzzs %");
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncFunctionsUseSameCounter) {
  CountingFunc counting_func("3gswsz9hyd_%s");
  const std::vector<decltype(counting_func.func())> funcs{
      counting_func.func(), counting_func.func(), counting_func.func(),
      counting_func.func(), counting_func.func()};
  int next_id = 0;
  for (int i = 0; i < 100; i++) {
    for (decltype(funcs.size()) j = 0; j < funcs.size(); j++) {
      SCOPED_TRACE("iteration i=" + std::to_string(i) +
                   " j=" + std::to_string(j));
      EXPECT_EQ(*funcs[j](), "3gswsz9hyd_" + std::to_string(next_id++));
    }
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncThreadSafety) {
  CountingFunc counting_func("ejrxk3g6tb_%s");
  std::vector<std::thread> threads;
  std::array<std::array<std::string, 100>, 20> strings;
  CountDownLatch latch(strings.size());
  for (decltype(strings.size()) i = 0; i < strings.size(); i++) {
    threads.emplace_back([&, i] {
      auto func = counting_func.func();
      auto& results = strings[i];
      latch.arrive_and_wait();
      for (decltype(results.size()) j = 0; j < results.size(); j++) {
        results[j] = *func();
      }
    });
  }

  for (auto& thread : threads) {
    thread.join();
  }

  std::vector<std::string> actual_strings;
  for (const auto& thread_strings : strings) {
    actual_strings.insert(actual_strings.end(), thread_strings.begin(),
                          thread_strings.end());
  }

  std::vector<std::string> expected_strings;
  for (decltype(actual_strings.size()) i = 0; i < actual_strings.size(); i++) {
    expected_strings.push_back("ejrxk3g6tb_" + std::to_string(i));
  }

  std::sort(actual_strings.begin(), actual_strings.end());
  std::sort(expected_strings.begin(), expected_strings.end());
  ASSERT_EQ(actual_strings, expected_strings);
}

TEST(ThreadSafeMemoizerTesting, CountingFuncInvocationCountOnNewInstance) {
  CountingFunc counting_func;
  EXPECT_EQ(counting_func.invocation_count(), 0);
}

TEST(ThreadSafeMemoizerTesting, CountingFuncInvocationCountIncrementsBy1) {
  CountingFunc counting_func;
  auto func = counting_func.func();
  for (int i = 0; i < 100; i++) {
    EXPECT_EQ(counting_func.invocation_count(), i);
    func();
    EXPECT_EQ(counting_func.invocation_count(), i + 1);
  }
}

TEST(ThreadSafeMemoizerTesting,
     CountingFuncInvocationCountIncrementedByEachFunc) {
  CountingFunc counting_func;
  for (int i = 0; i < 100; i++) {
    auto func = counting_func.func();
    EXPECT_EQ(counting_func.invocation_count(), i);
    func();
    EXPECT_EQ(counting_func.invocation_count(), i + 1);
  }
}

TEST(ThreadSafeMemoizerTesting, CountingFuncInvocationCountThreadSafe) {
  CountingFunc counting_func;
  const int num_threads = max_practical_parallel_threads_for_testing();
  std::vector<std::thread> threads;
  CountDownLatch latch(num_threads);
  for (auto i = num_threads; i > 0; i--) {
    threads.emplace_back([&, i] {
      auto func = counting_func.func();
      latch.arrive_and_wait();
      auto last_count = counting_func.invocation_count();
      for (int j = 0; j < 100; j++) {
        SCOPED_TRACE("Thread i=" + std::to_string(i) +
                     " j=" + std::to_string(j));
        func();
        auto new_count = counting_func.invocation_count();
        EXPECT_GT(new_count, last_count);
        last_count = new_count;
      }
    });
  }

  for (auto& thread : threads) {
    thread.join();
  }

  EXPECT_EQ(counting_func.invocation_count(), num_threads * 100);
}

}  // namespace
