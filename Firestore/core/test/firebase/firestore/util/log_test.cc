/*
 * Copyright 2017 Google
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

#include "Firestore/core/src/firebase/firestore/util/log.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

// When running against the log_apple.mm implementation (backed by FIRLogger)
// this test can fail if debug_mode gets persisted in the user defaults. Check
// for defaults getting in your way with
//
//   defaults read firebase_firestore_util_log_apple_test
//
// You can fix it with:
//
//   defaults write firebase_firestore_util_log_apple_test
//       /google/firebase/debug_mode NO
TEST(Log, SetAndGet) {
  LogSetLevel(kLogLevelVerbose);

  LogSetLevel(kLogLevelDebug);
  EXPECT_EQ(kLogLevelDebug, LogGetLevel());

  LogSetLevel(kLogLevelInfo);
  EXPECT_EQ(kLogLevelInfo, LogGetLevel());

  LogSetLevel(kLogLevelWarning);
  EXPECT_EQ(kLogLevelWarning, LogGetLevel());

  LogSetLevel(kLogLevelError);
  EXPECT_EQ(kLogLevelError, LogGetLevel());
}

TEST(Log, LogAllKinds) {
  LogDebug("test debug logging %d", 1);
  LogInfo("test info logging %d", 2);
  LogWarning("test warning logging %d", 3);
  LogError("test error logging %d", 4);
  LogMessage(kLogLevelError, "test va-args %s %c %d", "abc", ':', 123);
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
