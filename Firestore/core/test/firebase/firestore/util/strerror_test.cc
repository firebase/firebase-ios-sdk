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

#include "Firestore/core/src/firebase/firestore/util/strerror.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(StrErrorTest, ValidErrorCode) {
  errno = EAGAIN;
  EXPECT_EQ(StrError(EINTR), strerror(EINTR));
  EXPECT_EQ(errno, EAGAIN);
}

TEST(StrErrorTest, InvalidErrorCode) {
  errno = EBUSY;
  EXPECT_EQ(StrError(-1), "Unknown error -1");
  EXPECT_EQ(errno, EBUSY);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
