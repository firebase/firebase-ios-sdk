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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_LOG_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_LOG_H_

#include <cstdarg>

namespace firebase {
namespace firestore {
namespace util {

/// @brief Levels used when logging messages.
enum LogLevel {
  /// Verbose Log Level
  kLogLevelVerbose = 0,
  /// Debug Log Level
  kLogLevelDebug,
  /// Info Log Level
  kLogLevelInfo,
  /// Warning Log Level
  kLogLevelWarning,
  /// Error Log Level
  kLogLevelError,
};

// Common log methods.

// All messages at or above the specified log level value are displayed.
void LogSetLevel(LogLevel level);
// Get the currently set log level.
LogLevel LogGetLevel();
// Log a debug message to the system log.
void LogDebug(const char* format, ...);
// Log an info message to the system log.
void LogInfo(const char* format, ...);
// Log a warning to the system log.
void LogWarning(const char* format, ...);
// Log an error to the system log.
void LogError(const char* format, ...);
// Log a firebase message (implemented by the platform specific logger).
void LogMessageV(LogLevel log_level, const char* format, va_list args);
// Log a firebase message via LogMessageV().
void LogMessage(LogLevel log_level, const char* format, ...);

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_LOG_H_
