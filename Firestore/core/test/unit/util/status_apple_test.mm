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

#include "Firestore/core/src/util/status.h"

#include <cerrno>

#include "Firestore/core/src/util/error_apple.h"
#include "Firestore/core/test/unit/testutil/status_testing.h"
#include "gmock/gmock.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

NSError* MakeNotFound() {
  return [NSError
      errorWithDomain:NSPOSIXErrorDomain
                 code:ENOENT
             userInfo:@{NSLocalizedDescriptionKey : @"Some file not found"}];
}

NSError* MakeCocoaNotFound() {
  return [NSError errorWithDomain:NSCocoaErrorDomain
                             code:NSFileNoSuchFileError
                         userInfo:@{
                           NSLocalizedDescriptionKey : @"Some file not found",
                           NSUnderlyingErrorKey : MakeNotFound()
                         }];
}

}  // namespace

TEST(Status, MapsPosixErrorCodes) {
  Status s = Status::FromNSError(MakeNotFound());
  EXPECT_EQ(Error::kErrorNotFound, s.code());

  s = Status::FromNSError(MakeCocoaNotFound());
  EXPECT_EQ(Error::kErrorNotFound, s.code());
}

TEST(Status, PreservesNSError) {
  NSError* expected = MakeCocoaNotFound();
  Status s = Status::FromNSError(expected);

  NSError* actual = s.ToNSError();
  EXPECT_TRUE([expected isEqual:actual]);
}

TEST(Status, CausedBy_Chain_NSError) {
  NSError* not_found_nserror = MakeNotFound();
  Status internal_error(Error::kErrorInternal, "Something broke");

  Status result = internal_error;
  result.CausedBy(Status::FromNSError(not_found_nserror));
  EXPECT_NE(internal_error, result);

  // Outer should prevail
  EXPECT_EQ(internal_error.code(), result.code());
  ASSERT_THAT(
      result.ToString(),
      testing::MatchesRegex(
          "Internal: Something broke: Some file not found \\(errno .*\\)"));

  NSError* error = result.ToNSError();
  EXPECT_EQ(internal_error.code(), error.code);
  EXPECT_EQ(FIRFirestoreErrorDomain, error.domain);

  NSError* cause = error.userInfo[NSUnderlyingErrorKey];
  EXPECT_TRUE([not_found_nserror isEqual:cause]);
}

#if !__clang_analyzer__
TEST(Status, MovedFromToNSError) {
  Status not_found(Error::kErrorNotFound, "Some file not found");
  Status unused = std::move(not_found);

  EXPECT_EQ(not_found.ToNSError().domain, FIRFirestoreErrorDomain);
  EXPECT_EQ(not_found.ToNSError().code, Error::kErrorInternal);
}
#endif  // !__clang_analyzer__

}  // namespace util
}  // namespace firestore
}  // namespace firebase
