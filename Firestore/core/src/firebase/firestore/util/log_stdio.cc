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

#include <cstdio>
#include <string>

namespace firebase {
namespace firestore {
namespace util {

LogLevel g_log_level = kLogLevelInfo;

void LogSetLevel(LogLevel level) {
  g_log_level = level;
}

LogLevel LogGetLevel() {
  return g_log_level;
}

void LogDebug(const char* format, ...) {
  va_list list;
  va_start(list, format);
  LogMessageV(kLogLevelDebug, format, list);
  va_end(list);
}

void LogInfo(const char* format, ...) {
  va_list list;
  va_start(list, format);
  LogMessageV(kLogLevelInfo, format, list);
  va_end(list);
}

void LogWarning(const char* format, ...) {
  va_list list;
  va_start(list, format);
  LogMessageV(kLogLevelWarning, format, list);
  va_end(list);
}

void LogError(const char* format, ...) {
  va_list list;
  va_start(list, format);
  LogMessageV(kLogLevelError, format, list);
  va_end(list);
}

void LogMessageV(LogLevel log_level, const char* format, va_list args) {
  if (log_level < g_log_level) {
    return;
  }
  switch (log_level) {
    case kLogLevelVerbose:
      printf("VERBOSE: ");
      break;
    case kLogLevelDebug:
      printf("DEBUG: ");
      break;
    case kLogLevelInfo:
      break;
    case kLogLevelWarning:
      printf("WARNING: ");
      break;
    case kLogLevelError:
      printf("ERROR: ");
      break;
  }
  vprintf(format, args);
  printf("\n");
}

void LogMessage(LogLevel log_level, const char* format, ...) {
  va_list list;
  va_start(list, format);
  LogMessageV(log_level, format, list);
  va_end(list);
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
