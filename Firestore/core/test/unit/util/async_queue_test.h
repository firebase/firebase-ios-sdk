/*
 * Copyright 2018 Google LLC
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

#ifndef FIRESTORE_CORE_TEST_UNIT_UTIL_ASYNC_QUEUE_TEST_H_
#define FIRESTORE_CORE_TEST_UNIT_UTIL_ASYNC_QUEUE_TEST_H_

#include "Firestore/core/src/util/async_queue.h"

#include <memory>

#include "Firestore/core/test/unit/testutil/async_testing.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

using FactoryFunc = std::unique_ptr<Executor> (*)();

class AsyncQueueTest : public ::testing::TestWithParam<FactoryFunc>,
                       public testutil::AsyncTest {
 public:
  // `GetParam()` must return a factory function.
  AsyncQueueTest() : queue{AsyncQueue::Create(GetParam()())} {
  }

  std::shared_ptr<AsyncQueue> queue;
};

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_TEST_UNIT_UTIL_ASYNC_QUEUE_TEST_H_
