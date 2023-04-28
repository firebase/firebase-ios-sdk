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

#include <chrono>
#include <future>
#include <memory>
#include <thread>

#include "Firestore/core/src/api/listener_registration.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

// A "friend" class of TestingHooks to call its private members.
class TestingHooksTestHelper {
 public:
  TestingHooksTestHelper() : testing_hooks_(new TestingHooks) {
  }
  std::shared_ptr<TestingHooks> testing_hooks_;
};

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase

namespace {

using namespace std::chrono_literals;
using firebase::firestore::api::ListenerRegistration;
using firebase::firestore::testutil::AsyncTest;
using firebase::firestore::util::TestingHooks;
using firebase::firestore::util::TestingHooksTestHelper;
using ExistenceFilterMismatchInfoAccumulator =
    firebase::firestore::testutil::AsyncAccumulator<
        TestingHooks::ExistenceFilterMismatchInfo>;

class TestingHooksTest : public ::testing::Test,
                         public AsyncTest,
                         public TestingHooksTestHelper {
 public:
  void AssertAccumulatedObject(
      const std::shared_ptr<ExistenceFilterMismatchInfoAccumulator>&
          accumulator,
      TestingHooks::ExistenceFilterMismatchInfo expected) {
    Await(accumulator->WaitForObject());
    ASSERT_FALSE(accumulator->IsEmpty());
    TestingHooks::ExistenceFilterMismatchInfo info = accumulator->Shift();
    EXPECT_EQ(info.localCacheCount, expected.localCacheCount);
    EXPECT_EQ(info.existenceFilterCount, expected.existenceFilterCount);
  }

  std::future<void> NotifyOnExistenceFilterMismatchAsync(
      TestingHooks::ExistenceFilterMismatchInfo info) {
    return Async([info, testing_hooks = testing_hooks_]() {
      testing_hooks->NotifyOnExistenceFilterMismatch(info);
    });
  }
};

TEST_F(TestingHooksTest, OnExistenceFilterMismatchCallbackShouldGetNotified) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  testing_hooks_->OnExistenceFilterMismatch(accumulator->AsCallback());

  NotifyOnExistenceFilterMismatchAsync({123, 456});

  AssertAccumulatedObject(accumulator, {123, 456});
}

TEST_F(TestingHooksTest,
       OnExistenceFilterMismatchCallbackShouldGetNotifiedMultipleTimes) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  testing_hooks_->OnExistenceFilterMismatch(accumulator->AsCallback());

  NotifyOnExistenceFilterMismatchAsync({111, 222});
  AssertAccumulatedObject(accumulator, {111, 222});
  NotifyOnExistenceFilterMismatchAsync({333, 444});
  AssertAccumulatedObject(accumulator, {333, 444});
  NotifyOnExistenceFilterMismatchAsync({555, 666});
  AssertAccumulatedObject(accumulator, {555, 666});
}

TEST_F(TestingHooksTest,
       OnExistenceFilterMismatchAllCallbacksShouldGetNotified) {
  auto accumulator1 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  auto accumulator2 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  testing_hooks_->OnExistenceFilterMismatch(accumulator1->AsCallback());
  testing_hooks_->OnExistenceFilterMismatch(accumulator2->AsCallback());

  NotifyOnExistenceFilterMismatchAsync({123, 456});

  AssertAccumulatedObject(accumulator1, {123, 456});
  AssertAccumulatedObject(accumulator2, {123, 456});
}

TEST_F(TestingHooksTest,
       OnExistenceFilterMismatchShouldNotBeNotifiedAfterRemove) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> registration =
      testing_hooks_->OnExistenceFilterMismatch(accumulator->AsCallback());
  registration->Remove();

  NotifyOnExistenceFilterMismatchAsync({123, 456});

  std::this_thread::sleep_for(250ms);
  EXPECT_TRUE(accumulator->IsEmpty());
}

TEST_F(TestingHooksTest, OnExistenceFilterMismatchRemoveShouldOnlyRemoveOne) {
  auto accumulator1 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  auto accumulator2 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  auto accumulator3 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  testing_hooks_->OnExistenceFilterMismatch(accumulator1->AsCallback());
  std::shared_ptr<ListenerRegistration> registration2 =
      testing_hooks_->OnExistenceFilterMismatch(accumulator2->AsCallback());
  testing_hooks_->OnExistenceFilterMismatch(accumulator3->AsCallback());
  registration2->Remove();

  NotifyOnExistenceFilterMismatchAsync({123, 456});

  AssertAccumulatedObject(accumulator1, {123, 456});
  AssertAccumulatedObject(accumulator3, {123, 456});
  std::this_thread::sleep_for(250ms);
  EXPECT_TRUE(accumulator2->IsEmpty());
}

TEST_F(TestingHooksTest, OnExistenceFilterMismatchMultipleRemovesHaveNoEffect) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> registration =
      testing_hooks_->OnExistenceFilterMismatch(accumulator->AsCallback());
  registration->Remove();
  registration->Remove();
  registration->Remove();

  NotifyOnExistenceFilterMismatchAsync({123, 456});

  std::this_thread::sleep_for(250ms);
  EXPECT_TRUE(accumulator->IsEmpty());
}

}  // namespace
