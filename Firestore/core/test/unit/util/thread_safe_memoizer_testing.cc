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

#include <atomic>
#include <cassert>
#include <functional>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace firebase {
namespace firestore {
namespace testing {

namespace {

std::vector<std::string> Split(const std::string& s, const std::string& sep) {
  std::vector<std::string> chunks;
  auto index = s.find(sep);
  decltype(index) start = 0;
  while (index != std::string::npos) {
    chunks.push_back(s.substr(start, index - start));
    start = index + sep.size();
    index = s.find(sep, start);
  }
  chunks.push_back(s.substr(start));
  return chunks;
}

}  // namespace

CountingFunc::CountingFunc(const std::string& format)
    : CountingFunc(Split(format, "%s")) {
}

CountingFunc::CountingFunc(std::vector<std::string> chunks)
    : chunks_(std::move(chunks)) {
  assert(!chunks_.empty());
  // Explicitly store the initial value into count_ because initialization of
  // std::atomic is _not_ atomic.
  count_.store(0);
}

std::function<std::shared_ptr<std::string>()> CountingFunc::func() {
  return [&] { return std::make_shared<std::string>(Next()); };
}

int CountingFunc::invocation_count() const {
  return count_.load();
}

std::string CountingFunc::Next() {
  const int id = count_.fetch_add(1, std::memory_order_acq_rel);
  std::ostringstream ss;
  int index = 0;
  for (const std::string& chunk : chunks_) {
    if (index > 0) {
      ss << id;
    }
    index++;
    ss << chunk;
  }
  return ss.str();
}

}  // namespace testing
}  // namespace firestore
}  // namespace firebase
