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

#ifndef FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_STATUS_TEST_UTIL_H_
#define FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_STATUS_TEST_UTIL_H_

#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

inline testing::AssertionResult Equal(Status expected, Status actual) {
  if (expected != actual) {
    return testing::AssertionFailure()
           << "Should have seen status " << expected.ToString() << " but got "
           << actual.ToString();
  }

  return testing::AssertionSuccess();
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

// Macros for testing the results of functions that return util::Status.
#define EXPECT_OK(statement)                      \
  EXPECT_TRUE(::firebase::firestore::util::Equal( \
      ::firebase::firestore::util::Status::OK(), (statement)));
#define ASSERT_OK(statement)                      \
  ASSERT_TRUE(::firebase::firestore::util::Equal( \
      ::firebase::firestore::util::Status::OK(), (statement)));

// There are no EXPECT_NOT_OK/ASSERT_NOT_OK macros since they would not
// provide much value (when they fail, they would just print the OK status
// which conveys no more information than EXPECT_FALSE(status.ok());
// If you want to check for particular errors, a better alternative is:
// EXPECT_EQ(..expected FirestoreErrorCode..., status.code());

#endif  // FIRESTORE_CORE_TEST_FIREBASE_FIRESTORE_UTIL_STATUS_TEST_UTIL_H_
