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

#ifndef FIRESTORE_CORE_TEST_UNIT_TESTUTIL_STATUS_TESTING_H_
#define FIRESTORE_CORE_TEST_UNIT_TESTUTIL_STATUS_TESTING_H_

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/util/status_fwd.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace testutil {

/**
 * Checks the status. Don't use directly; use one of the relevant macros
 * instead. eg:
 *
 *   Status good_status = ...;
 *   ASSERT_OK(good_status);
 */
testing::AssertionResult Equal(const util::Status& expected,
                               const util::Status& actual);

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
testing::AssertionResult StatusOk(const util::Status& status);

template <typename T>
testing::AssertionResult StatusOk(const util::StatusOr<T>& status) {
  return StatusOk(status.status());
}

MATCHER(IsOk, negation ? "not ok" : "ok") {
  if (arg.ok()) return true;

  *result_listener << "actual status was " << arg;
  return false;
}

MATCHER(IsNotFound, negation ? "actually found" : "is not found") {
  if (arg.code() == Error::kErrorNotFound) return true;

  *result_listener << "actual status was " << arg;
  return false;
}

MATCHER(IsPermissionDenied,
        negation ? "not permission denied" : "permission denied") {
  if (arg.code() == Error::kErrorPermissionDenied) return true;

  *result_listener << "actual status was " << arg;
  return false;
}

MATCHER(IsUnimplemented, negation ? "actually implemented" : "unimplemented") {
  if (arg.code() == Error::kErrorUnimplemented) return true;

  *result_listener << "actual status was " << arg;
  return false;
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase

// Macros for testing the results of functions that return util::Status.
#define ASSERT_OK(status) \
  ASSERT_TRUE(firebase::firestore::testutil::StatusOk(status))
#define EXPECT_OK(status) \
  EXPECT_TRUE(firebase::firestore::testutil::StatusOk(status))

// EXPECT_NOT_OK/ASSERT_NOT_OK have fairly limited utility since they don't
// provide much value (when they fail, they would just print the OK status
// which conveys no more information than EXPECT_FALSE(status.ok());
// If you want to check for particular errors, a better alternative is:
// EXPECT_EQ(..expected Error..., status.code());
#define ASSERT_NOT_OK(status) \
  ASSERT_FALSE(firebase::firestore::testutil::StatusOk(status))
#define EXPECT_NOT_OK(status) \
  EXPECT_FALSE(firebase::firestore::testutil::StatusOk(status))

#endif  // FIRESTORE_CORE_TEST_UNIT_TESTUTIL_STATUS_TESTING_H_
