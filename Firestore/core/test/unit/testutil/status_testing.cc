/*
 * Copyright 2019 Google
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

#include "Firestore/core/test/unit/testutil/status_testing.h"

#include "Firestore/core/src/util/status.h"

namespace firebase {
namespace firestore {
namespace testutil {

using util::Status;

/**
 * Checks the status. Don't use directly; use one of the relevant macros
 * instead. eg:
 *
 *   Status good_status = ...;
 *   ASSERT_OK(good_status);
 */
testing::AssertionResult Equal(const Status& expected, const Status& actual) {
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
testing::AssertionResult StatusOk(const Status& status) {
  return Equal(Status::OK(), status);
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
