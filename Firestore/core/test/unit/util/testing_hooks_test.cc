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

#include "Firestore/core/test/unit/testutil/async_testing.h"

#include "absl/types/optional.h"

#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

// A "friend" class of TestingHooks to call its private members.
class TestingHooksTestHelper {
 public:
  TestingHooksTestHelper() : testing_hooks_(new TestingHooks) {}
  std::shared_ptr<TestingHooks> testing_hooks_;
};

} //  namespace util
} //  namespace firestore
} //  namespace firebase

namespace {

using firebase::firestore::util::TestingHooks;
using firebase::firestore::util::TestingHooksTestHelper;
using firebase::firestore::testutil::AsyncTest;
using ExistenceFilterMismatchInfoAccumulator = firebase::firestore::testutil::AsyncAccumulator<TestingHooks::ExistenceFilterMismatchInfo>;

class TestingHooksTest : public ::testing::Test, public AsyncTest, public TestingHooksTestHelper {
};

TEST_F(TestingHooksTest, OnExistenceFilterMismatchCallbackShouldGetNotified) {
  auto accumulator = ExistenceFilterMismatchInfoAccumulator::NewInstance();
  testing_hooks_->OnExistenceFilterMismatch(accumulator->AsCallback());

  Async([testing_hooks = testing_hooks_]() { testing_hooks->NotifyOnExistenceFilterMismatch({123, 456}); });

  Await(accumulator->WaitForObject());
  ASSERT_FALSE(accumulator->IsEmpty());
  TestingHooks::ExistenceFilterMismatchInfo info = accumulator->Shift();
  EXPECT_EQ(info.localCacheCount, 123);
  EXPECT_EQ(info.existenceFilterCount, 456);
}

}  // namespace
