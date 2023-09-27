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

#include <chrono>  // NOLINT(build/c++11)
#include <future>  // NOLINT(build/c++11)
#include <memory>
#include <string>
#include <thread>  // NOLINT(build/c++11)

#include "Firestore/core/src/api/listener_registration.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/remote/bloom_filter.h"
#include "Firestore/core/src/util/defer.h"
#include "Firestore/core/test/unit/testutil/async_testing.h"

#include "absl/types/optional.h"

#include "gtest/gtest.h"

namespace {

using namespace std::chrono_literals;  // NOLINT(build/namespaces)

using firebase::firestore::api::ListenerRegistration;
using firebase::firestore::nanopb::ByteString;
using firebase::firestore::remote::BloomFilter;
using firebase::firestore::testutil::AsyncTest;
using firebase::firestore::util::Defer;
using firebase::firestore::util::TestingHooks;

using ExistenceFilterMismatchInfoAccumulator =
    firebase::firestore::testutil::AsyncAccumulator<
        TestingHooks::ExistenceFilterMismatchInfo>;

/**
 * Creates and returns a new `ExistenceFilterMismatchInfo` object populated
 * with sample values.
 *
 * Each invocation of this function with the same argument will return an
 * object populated with the same values as the previous invocation.
 *
 * @param seed The value to incorporate into the sample values populated in the
 * returned object; a different seed will produce different sample values.
 *
 * @return A new `ExistenceFilterMismatchInfo` object populated with sample
 * values based on the given `seed`. The object's `bloom_filter` member will
 * contain a `BloomFilterInfo` whose `bloom_filter` member will contain a
 * `BloomFilter`.
 */
TestingHooks::ExistenceFilterMismatchInfo SampleExistenceFilterMismatchInfo(
    int seed = 0) {
  int local_cache_count = 123 + seed;
  int existence_filter_count = 456 + seed;
  std::string project_id = "test_project_id" + std::to_string(seed);
  std::string database_id = "test_database_id" + std::to_string(seed);

  std::string bloom_filter_bytes = "sample_bytes" + std::to_string(seed);
  bool bloom_filter_applied = (seed % 2 == 0);
  int bloom_filter_hash_count = 42 + seed;
  int bloom_filter_bitmap_length = static_cast<int>(bloom_filter_bytes.size());
  int bloom_filter_padding = (seed % 8);

  return {local_cache_count, existence_filter_count, project_id, database_id,
          TestingHooks::BloomFilterInfo{
              bloom_filter_applied, bloom_filter_hash_count,
              bloom_filter_bitmap_length, bloom_filter_padding,
              BloomFilter(ByteString(bloom_filter_bytes), bloom_filter_padding,
                          bloom_filter_hash_count)}};
}

class TestingHooksTest : public ::testing::Test, public AsyncTest {
 public:
  void AssertAccumulatedObject(
      const std::shared_ptr<ExistenceFilterMismatchInfoAccumulator>&
          accumulator,
      const TestingHooks::ExistenceFilterMismatchInfo& expected) {
    Await(accumulator->WaitForObject());
    ASSERT_FALSE(accumulator->IsEmpty());

    TestingHooks::ExistenceFilterMismatchInfo info = accumulator->Shift();
    EXPECT_EQ(info.local_cache_count, expected.local_cache_count);
    EXPECT_EQ(info.existence_filter_count, expected.existence_filter_count);
    EXPECT_EQ(info.project_id, expected.project_id);
    EXPECT_EQ(info.database_id, expected.database_id);
    EXPECT_EQ(info.bloom_filter.has_value(), expected.bloom_filter.has_value());

    if (info.bloom_filter.has_value() && expected.bloom_filter.has_value()) {
      const TestingHooks::BloomFilterInfo& info_bloom_filter =
          info.bloom_filter.value();
      const TestingHooks::BloomFilterInfo& expected_bloom_filter =
          expected.bloom_filter.value();
      EXPECT_EQ(info_bloom_filter.applied, expected_bloom_filter.applied);
      EXPECT_EQ(info_bloom_filter.hash_count, expected_bloom_filter.hash_count);
      EXPECT_EQ(info_bloom_filter.bitmap_length,
                expected_bloom_filter.bitmap_length);
      EXPECT_EQ(info_bloom_filter.padding, expected_bloom_filter.padding);
      EXPECT_EQ(info_bloom_filter.bloom_filter.has_value(),
                expected_bloom_filter.bloom_filter.has_value());
      if (info_bloom_filter.bloom_filter.has_value() &&
          expected_bloom_filter.bloom_filter.has_value()) {
        EXPECT_EQ(info_bloom_filter.bloom_filter.value(),
                  expected_bloom_filter.bloom_filter.value());
      }
    }
  }

  std::future<void> NotifyOnExistenceFilterMismatchAsync(
      const TestingHooks::ExistenceFilterMismatchInfo& info) {
    return Async([info]() {
      TestingHooks::GetInstance().NotifyOnExistenceFilterMismatch(info);
    });
  }
};

TEST_F(TestingHooksTest, GetInstanceShouldAlwaysReturnTheSameObject) {
  TestingHooks& testing_hooks1 = TestingHooks::GetInstance();
  TestingHooks& testing_hooks2 = TestingHooks::GetInstance();
  EXPECT_EQ(&testing_hooks1, &testing_hooks2);
}

TEST_F(TestingHooksTest, OnExistenceFilterMismatchCallbackShouldGetNotified) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> listener_registration =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator->AsCallback());
  Defer unregister_listener([=] { listener_registration->Remove(); });

  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo());

  AssertAccumulatedObject(accumulator, SampleExistenceFilterMismatchInfo());
}

TEST_F(
    TestingHooksTest,
    // NOLINTNEXTLINE(whitespace/line_length)
    OnExistenceFilterMismatchCallbackShouldGetNotifiedWithAbsentExistenceFilterInfo) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> listener_registration =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator->AsCallback());
  Defer unregister_listener([=] { listener_registration->Remove(); });
  TestingHooks::ExistenceFilterMismatchInfo existence_filter_mismatch_info =
      SampleExistenceFilterMismatchInfo();
  existence_filter_mismatch_info.bloom_filter = absl::nullopt;

  NotifyOnExistenceFilterMismatchAsync(existence_filter_mismatch_info);

  AssertAccumulatedObject(accumulator, existence_filter_mismatch_info);
}

TEST_F(
    TestingHooksTest,
    // NOLINTNEXTLINE(whitespace/line_length)
    OnExistenceFilterMismatchCallbackShouldGetNotifiedWithAbsentExistenceFilter) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> listener_registration =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator->AsCallback());
  Defer unregister_listener([=] { listener_registration->Remove(); });
  TestingHooks::ExistenceFilterMismatchInfo existence_filter_mismatch_info =
      SampleExistenceFilterMismatchInfo();
  existence_filter_mismatch_info.bloom_filter->bloom_filter = absl::nullopt;

  NotifyOnExistenceFilterMismatchAsync(existence_filter_mismatch_info);

  AssertAccumulatedObject(accumulator, existence_filter_mismatch_info);
}

TEST_F(TestingHooksTest,
       OnExistenceFilterMismatchCallbackShouldGetNotifiedMultipleTimes) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> listener_registration =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator->AsCallback());
  Defer unregister_listener([=] { listener_registration->Remove(); });

  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo(0));
  AssertAccumulatedObject(accumulator, SampleExistenceFilterMismatchInfo(0));
  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo(1));
  AssertAccumulatedObject(accumulator, SampleExistenceFilterMismatchInfo(1));
  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo(2));
  AssertAccumulatedObject(accumulator, SampleExistenceFilterMismatchInfo(2));
}

TEST_F(TestingHooksTest,
       OnExistenceFilterMismatchAllCallbacksShouldGetNotified) {
  auto accumulator1 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  auto accumulator2 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> listener_registration1 =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator1->AsCallback());
  Defer unregister_listener1([=] { listener_registration1->Remove(); });
  std::shared_ptr<ListenerRegistration> listener_registration2 =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator2->AsCallback());
  Defer unregister_listener2([=] { listener_registration2->Remove(); });

  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo());

  AssertAccumulatedObject(accumulator1, SampleExistenceFilterMismatchInfo());
  AssertAccumulatedObject(accumulator2, SampleExistenceFilterMismatchInfo());
}

TEST_F(TestingHooksTest,
       OnExistenceFilterMismatchCallbackShouldGetNotifiedOncePerRegistration) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> listener_registration1 =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator->AsCallback());
  Defer unregister_listener1([=] { listener_registration1->Remove(); });
  std::shared_ptr<ListenerRegistration> listener_registration2 =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator->AsCallback());
  Defer unregister_listener2([=] { listener_registration1->Remove(); });

  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo());

  AssertAccumulatedObject(accumulator, SampleExistenceFilterMismatchInfo());
  AssertAccumulatedObject(accumulator, SampleExistenceFilterMismatchInfo());
  std::this_thread::sleep_for(250ms);
  EXPECT_TRUE(accumulator->IsEmpty());
}

TEST_F(TestingHooksTest,
       OnExistenceFilterMismatchShouldNotBeNotifiedAfterRemove) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> registration =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator->AsCallback());
  registration->Remove();

  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo());

  std::this_thread::sleep_for(250ms);
  EXPECT_TRUE(accumulator->IsEmpty());
}

TEST_F(TestingHooksTest, OnExistenceFilterMismatchRemoveShouldOnlyRemoveOne) {
  auto accumulator1 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  auto accumulator2 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  auto accumulator3 = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> listener_registration1 =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator1->AsCallback());
  Defer unregister_listener1([=] { listener_registration1->Remove(); });
  std::shared_ptr<ListenerRegistration> listener_registration2 =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator2->AsCallback());
  Defer unregister_listener2([=] { listener_registration1->Remove(); });
  std::shared_ptr<ListenerRegistration> listener_registration3 =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator3->AsCallback());
  Defer unregister_listener3([=] { listener_registration3->Remove(); });

  listener_registration2->Remove();

  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo());

  AssertAccumulatedObject(accumulator1, SampleExistenceFilterMismatchInfo());
  AssertAccumulatedObject(accumulator3, SampleExistenceFilterMismatchInfo());
  std::this_thread::sleep_for(250ms);
  EXPECT_TRUE(accumulator2->IsEmpty());
}

TEST_F(TestingHooksTest, OnExistenceFilterMismatchMultipleRemovesHaveNoEffect) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  std::shared_ptr<ListenerRegistration> listener_registration =
      TestingHooks::GetInstance().OnExistenceFilterMismatch(
          accumulator->AsCallback());
  Defer unregister_listener([=] { listener_registration->Remove(); });
  listener_registration->Remove();
  listener_registration->Remove();
  listener_registration->Remove();

  NotifyOnExistenceFilterMismatchAsync(SampleExistenceFilterMismatchInfo());

  std::this_thread::sleep_for(250ms);
  EXPECT_TRUE(accumulator->IsEmpty());
}

}  // namespace
