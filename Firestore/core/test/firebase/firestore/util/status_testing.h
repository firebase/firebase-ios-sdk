/*
 * Copyright 2015, 2018 Google
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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_STATUS_TESTING_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_STATUS_TESTING_H_

#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * Checks the status. Don't use directly; use one of the relevant macros
 * instead. eg:
 *
 *   Status good_status = ...;
 *   ASSERT_OK(good_status);
 */
inline testing::AssertionResult Equal(Status expected, Status actual) {
  if (expected != actual) {
    return testing::AssertionFailure()
           << "Status should have been " << expected.ToString()
           << ", but instead contained " << actual.ToString();
  }
  return testing::AssertionSuccess();
}

/**
 * Checks the status. Don't use directly; use one of the relevant macros
 * instead. eg:
 *
 *   Status good_status = ...;
 *   ASSERT_OK(good_status);
 *
 *   Status bad_status = ...;
 *   EXPECT_NOT_OK(bad_status);
 */
inline testing::AssertionResult StatusOk(const Status& status) {
  return Equal(Status::OK(), status);
}

template <typename T>
testing::AssertionResult StatusOk(const StatusOr<T>& status) {
  return StatusOk(status.status());
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

// Macros for testing the results of functions that return util::Status.
#define ASSERT_OK(status) \
  ASSERT_TRUE(firebase::firestore::util::StatusOk(status))
#define EXPECT_OK(status) \
  EXPECT_TRUE(firebase::firestore::util::StatusOk(status))

// EXPECT_NOT_OK/ASSERT_NOT_OK have fairly limited utility since they don't
// provide much value (when they fail, they would just print the OK status
// which conveys no more information than EXPECT_FALSE(status.ok());
// If you want to check for particular errors, a better alternative is:
// EXPECT_EQ(..expected Error..., status.code());
#define ASSERT_NOT_OK(status) \
  ASSERT_FALSE(firebase::firestore::util::StatusOk(status))
#define EXPECT_NOT_OK(status) \
  EXPECT_FALSE(firebase::firestore::util::StatusOk(status))

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_STATUS_TESTING_H_
