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

#include <atomic>
#include <cstdio>
#include <string>

#include "Firestore/core/src/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace util {
namespace {

std::atomic<LogLevel> g_log_level(kLogLevelNotice);

}  // namespace

void LogSetLevel(LogLevel level) {
  g_log_level = level;
}

bool LogIsLoggable(LogLevel level) {
  return level >= g_log_level;
}

void LogMessage(LogLevel log_level, const std::string& message) {
  if (log_level < g_log_level) {
    return;
  }

  const char* level_word;

  switch (log_level) {
    case kLogLevelDebug:
      level_word = "DEBUG";
      break;
    case kLogLevelWarning:
      level_word = "WARNING";
      break;
    case kLogLevelError:
      level_word = "ERROR";
      break;
    case kLogLevelNotice:
      level_word = "INFO";
      break;
    default:
      UNREACHABLE();
      break;
  }

  printf("%s: %s\n", level_word, message.c_str());
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
