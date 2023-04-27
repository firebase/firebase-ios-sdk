/*
 * Copyright 2023 Google LLC
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

#include "Firestore/core/src/util/testing_hooks.h"

#include "absl/types/optional.h"

#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <vector>
#include <utility>

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace {

using namespace std::chrono_literals;
using firebase::firestore::util::TestingHooks;

template <typename T>
class MessageAccumulator : public std::enable_shared_from_this<MessageAccumulator<T>> {
 public:
  static std::shared_ptr<MessageAccumulator> NewInstance() {
    return std::shared_ptr<MessageAccumulator>(new MessageAccumulator);
  }

  std::function<void(const T&)> MakeListener() {
    auto shared_this = this->shared_from_this();
    return [shared_this](const T& message) {
      shared_this->OnMessage(message);
    };
  }

  void OnMessage(T&& message) {
    std::lock_guard<std::mutex> lock(mutex_);
    messages_.push_back(std::move(message));
    condition_variable_.notify_all();
  }

  absl::optional<T> WaitForMessage() {
    std::unique_lock<std::mutex> lock(mutex_);
    condition_variable_.wait_for(lock, 1000ms, [&](){return !messages_.empty();});
    auto iter = messages_.begin();
    if (iter == messages_.end()) {
      return absl::nullopt;
    }
    T message = std::move(*iter);
    messages_.erase(iter);
    return std::move(message);
  }

 private:
  MessageAccumulator() = default;
  std::mutex mutex_;
  std::condition_variable condition_variable_;
  std::vector<T> messages_;
};

TEST(TestingHooks, OnExistenceFilterMismatchShouldCompleteSuccessfully) {
  TestingHooks::OnExistenceFilterMismatch([](const TestingHooks::ExistenceFilterMismatchInfo&) {});
}

TEST(TestingHooks, OnExistenceFilterMismatchRegisteredCallbackShouldGetNotified) {
  auto accumulator = MessageAccumulator<TestingHooks::ExistenceFilterMismatchInfo>::NewInstance();
  TestingHooks::OnExistenceFilterMismatch(accumulator->MakeListener());
  absl::optional<TestingHooks::ExistenceFilterMismatchInfo> message_optional = accumulator->WaitForMessage();
  ASSERT_TRUE(message_optional.has_value());
  TestingHooks::ExistenceFilterMismatchInfo message = std::move(message_optional).value();
}

}  // namespace
