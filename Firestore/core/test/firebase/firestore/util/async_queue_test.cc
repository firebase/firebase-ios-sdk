/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/util/async_queue.h"

#include <chrono>
#include <future>
#include <string>

#include <gtest/gtest.h>

namespace firebase {
namespace firestore {
namespace util {

TEST(AsyncQueue, Foo) {
  AsyncQueue queue;
  std::packaged_task<void()> signal_finished{[] {}};
  std::string steps;

  queue.Enqueue([&] { steps += '1'; });
  queue.Enqueue([&] { steps += '2'; });
  queue.Enqueue([&] { steps += '3'; });
  auto handle = queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(1000), [&] {
      steps += "foo";
      });
  queue.EnqueueAfterDelay(AsyncQueue::Milliseconds(2000), [&] {
    steps += '4';
    signal_finished();
  });
  (void)handle;
  // handle.Cancel();

  // signal_finished.get_future().wait_for(std::chrono::seconds(1));
  signal_finished.get_future().wait();
  EXPECT_EQ(steps, "1234");
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
