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

#include "Firestore/core/src/firebase/firestore/util/status.h"

#include "Firestore/core/test/firebase/firestore/util/status_test_util.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(Status, OK) {
  EXPECT_EQ(Status::OK().code(), FirestoreErrorCode::Ok);
  EXPECT_EQ(Status::OK().error_message(), "");
  EXPECT_OK(Status::OK());
  ASSERT_OK(Status::OK());
  STATUS_CHECK_OK(Status::OK());
  EXPECT_EQ(Status::OK(), Status());
  Status s;
  EXPECT_TRUE(s.ok());
}

TEST(DeathStatus, CheckOK) {
  Status status(FirestoreErrorCode::InvalidArgument, "Invalid");
  ASSERT_ANY_THROW(STATUS_CHECK_OK(status));
}

TEST(Status, Set) {
  Status status;
  status = Status(FirestoreErrorCode::Cancelled, "Error message");
  EXPECT_EQ(status.code(), FirestoreErrorCode::Cancelled);
  EXPECT_EQ(status.error_message(), "Error message");
}

TEST(Status, Copy) {
  Status a(FirestoreErrorCode::InvalidArgument, "Invalid");
  Status b(a);
  ASSERT_EQ(a.ToString(), b.ToString());
}

TEST(Status, Assign) {
  Status a(FirestoreErrorCode::InvalidArgument, "Invalid");
  Status b;
  b = a;
  ASSERT_EQ(a.ToString(), b.ToString());
}

TEST(Status, Update) {
  Status s;
  s.Update(Status::OK());
  ASSERT_TRUE(s.ok());
  Status a(FirestoreErrorCode::InvalidArgument, "Invalid");
  s.Update(a);
  ASSERT_EQ(s.ToString(), a.ToString());
  Status b(FirestoreErrorCode::Internal, "Internal");
  s.Update(b);
  ASSERT_EQ(s.ToString(), a.ToString());
  s.Update(Status::OK());
  ASSERT_EQ(s.ToString(), a.ToString());
  ASSERT_FALSE(s.ok());
}

TEST(Status, EqualsOK) {
  ASSERT_EQ(Status::OK(), Status());
}

TEST(Status, EqualsSame) {
  Status a(FirestoreErrorCode::InvalidArgument, "Invalid");
  Status b(FirestoreErrorCode::InvalidArgument, "Invalid");
  ASSERT_EQ(a, b);
}

TEST(Status, EqualsCopy) {
  const Status a(FirestoreErrorCode::InvalidArgument, "Invalid");
  const Status b = a;
  ASSERT_EQ(a, b);
}

TEST(Status, EqualsDifferentCode) {
  const Status a(FirestoreErrorCode::InvalidArgument, "message");
  const Status b(FirestoreErrorCode::Internal, "message");
  ASSERT_NE(a, b);
}

TEST(Status, EqualsDifferentMessage) {
  const Status a(FirestoreErrorCode::InvalidArgument, "message");
  const Status b(FirestoreErrorCode::InvalidArgument, "another");
  ASSERT_NE(a, b);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
