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

#include <cassert>
#include <functional>
#include <memory>
#include <random>
#include <sstream>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace firebase {
namespace firestore {
namespace testing {
namespace {

std::vector<std::string> SplitSeparators(const std::string& s) {
  std::vector<std::string> chunks;

  auto found = s.find('%');
  decltype(found) search_start = 0;
  decltype(found) substr_start = 0;
  while (found != std::string::npos && found < s.size() - 1) {
    const auto next_char = s[found + 1];
    if (next_char == 's' || next_char == 'c') {
      chunks.push_back(s.substr(substr_start, found - substr_start));
      chunks.push_back(s.substr(found, 2));
      search_start = found + 2;
      substr_start = search_start;
    } else {
      search_start = found + 1;
    }
    found = s.find('%', search_start);
  }
  chunks.push_back(s.substr(substr_start));

  return chunks;
}

}  // namespace

CountingFunc::CountingFunc(const std::string& format)
    : CountingFunc(SplitSeparators(format)) {
}

CountingFunc::CountingFunc(std::vector<std::string> chunks)
    : chunks_(std::move(chunks)) {
  assert(!chunks_.empty());
  // Explicitly store the initial value into count_ because initialization of
  // std::atomic is _not_ atomic.
  count_.store(0);
}

std::function<std::shared_ptr<std::string>()> CountingFunc::func(
    std::string cookie) {
  return [this, cookie = std::move(cookie)] {
    return std::make_shared<std::string>(Next(cookie));
  };
}

int CountingFunc::invocation_count() const {
  return count_.load(std::memory_order_acquire);
}

std::string CountingFunc::Next(const std::string& cookie) {
  const int id = count_.fetch_add(1, std::memory_order_acq_rel);
  std::ostringstream ss;
  for (const std::string& chunk : chunks_) {
    if (chunk == "%s") {
      ss << id;
    } else if (chunk == "%c" && cookie.size() > 0) {
      ss << cookie;
    } else {
      ss << chunk;
    }
  }
  return ss.str();
}

CountDownLatch::CountDownLatch(int count) {
  // Explicitly store the count into the atomic<int> because initialization is
  // NOT atomic.
  count_.store(count);
}

void CountDownLatch::arrive_and_wait() {
  count_.fetch_sub(1);
  while (count_.load() > 0) {
    std::this_thread::yield();
  }
}

decltype(std::thread::hardware_concurrency())
max_practical_parallel_threads_for_testing() {
  const auto hardware_concurrency = std::thread::hardware_concurrency();
  return hardware_concurrency != 0 ? hardware_concurrency : 4;
}

bool GenerateRandomBool() {
  std::random_device random_device;
  std::default_random_engine random_engine(random_device());
  const auto random_value = random_engine.operator()();
  return random_value % 2 == 0;
}

}  // namespace testing
}  // namespace firestore
}  // namespace firebase
