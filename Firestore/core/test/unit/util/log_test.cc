/*
 * Copyright 2017 Google LLC
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

#include "Firestore/core/src/util/log.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace util {

TEST(LogTest, SetAndGet) {
  LogLevel previous_level = kLogLevelError;
  if (LogIsLoggable(kLogLevelWarning)) previous_level = kLogLevelWarning;
  if (LogIsLoggable(kLogLevelNotice)) previous_level = kLogLevelNotice;
  if (LogIsLoggable(kLogLevelDebug)) previous_level = kLogLevelDebug;

  LogSetLevel(kLogLevelDebug);
  EXPECT_TRUE(LogIsDebugEnabled());

  EXPECT_TRUE(LogIsLoggable(kLogLevelDebug));
  EXPECT_TRUE(LogIsLoggable(kLogLevelNotice));
  EXPECT_TRUE(LogIsLoggable(kLogLevelWarning));
  EXPECT_TRUE(LogIsLoggable(kLogLevelError));

  LogSetLevel(kLogLevelWarning);
  EXPECT_FALSE(LogIsDebugEnabled());

  EXPECT_FALSE(LogIsLoggable(kLogLevelDebug));
  EXPECT_FALSE(LogIsLoggable(kLogLevelNotice));
  EXPECT_TRUE(LogIsLoggable(kLogLevelWarning));
  EXPECT_TRUE(LogIsLoggable(kLogLevelError));

  LogSetLevel(previous_level);
}

TEST(LogTest, LogAllKinds) {
  LOG_DEBUG("test debug logging %s", 1);
  LOG_WARN("test warning logging %s", 3);
  LOG_DEBUG("test va-args %s %s %s", "abc", std::string{"def"}, 123);
}

}  //  namespace util
}  //  namespace firestore
}  //  namespace firebase
