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

#include <numeric_limits>
#include <string>

#include "Firestore/core/src/firebase/firestore/util/string_format.h"

namespace firebase {
namespace firestore {
namespace util {

// Levels used when logging messages.
enum LogLevel {
  // Debug Log Level
  kLogLevelDebug,
  // Notice Log Level
  kLogLevelNotice,
  // Warning Log Level
  kLogLevelWarning,
  // Error Log Level
  kLogLevelError,
};

/**
 * Counts the number of valid format specifiers are present in format.
 * Instances of '%%' are skipped. Invalid format specifiers will cause this
 * function to return a negative number.
 */
constexpr int CountFormatSpecifiers(const char* format) {
  // TODO(c++17): Convert to a multi-line constexpr and get rid of the recursion
  // clang-format off
  return
      // We don't really expect nullptrs, but if we encounter one, consider it
      // to have 0 format specifiers.
      format == nullptr ? 0 :
      // If we're at the end of the string (or 1 char away) then there must not
      // be any more format specifiers. (NB: this does imply that a single % at
      // the end is considered acceptable... whereas it would not be anywhere
      // else.)
      format[0] == 0 || format[1] == 0 ? 0 :
      // If we're not looking at a percent, then skip this char and check the
      // rest of the string.
      format[0] != '%' ? CountFormatSpecifiers(format + 1) :
      // Found %%. Skip and check the rest of the string.
      format[1] == '%' ? CountFormatSpecifiers(format + 2) :
      // Found %s.
      format[1] == 's' ? 1 + CountFormatSpecifiers(format + 2) :
      // Found % followed by neither % nor s. Invalid. We'll signal this by
      // returning a very negative number.
      std::numeric_limits<int>::min();
  // clang-format on
}

#define _PARAM_CHECK(FMT, ...)                                              \
  do {                                                                      \
    namespace _util = firebase::firestore::util;                            \
    static_assert(_util::CountFormatSpecifiers(FMT) >= 0,                   \
                  "Invalid format specifier detected. "                     \
                  "Only '%%' and '%s' are recognized.");                    \
    static_assert(                                                          \
        _util::CountFormatSpecifiers(FMT) ==                                \
            std::tuple_size<decltype(std::make_tuple(__VA_ARGS__))>::value, \
        "Parameter count mismatch to format string.");                      \
  } while (0)

// Log a message if kLogLevelDebug is enabled. Arguments are not evaluated if
// logging is disabled.
//
// @param format A format string suitable for use with `util::StringFormat`
// @param ... C++ variadic arguments that match the format string. Not C
//     varargs.
#define LOG_DEBUG(FMT, ...)                                           \
  do {                                                                \
    namespace _util = firebase::firestore::util;                      \
    if (_util::LogIsLoggable(_util::kLogLevelDebug)) {                \
      _PARAM_CHECK(FMT, __VA_ARGS__);                                 \
      std::string _message = _util::StringFormat(FMT, ##__VA_ARGS__); \
      _util::LogMessage(_util::kLogLevelDebug, _message);             \
    }                                                                 \
  } while (0)

// Log a message if kLogLevelWarn is enabled (it is by default). Arguments are
// not evaluated if logging is disabled.
//
// @param format A format string suitable for use with `util::StringFormat`
// @param ... C++ variadic arguments that match the format string. Not C
//     varargs.
#define LOG_WARN(FMT, ...)                                            \
  do {                                                                \
    namespace _util = firebase::firestore::util;                      \
    if (_util::LogIsLoggable(_util::kLogLevelWarning)) {              \
      _PARAM_CHECK(FMT, __VA_ARGS__);                                 \
      std::string _message = _util::StringFormat(FMT, ##__VA_ARGS__); \
      _util::LogMessage(_util::kLogLevelWarning, _message);           \
    }                                                                 \
  } while (0)

// Log a message if kLogLevelError is enabled (it is by default). Arguments are
// not evaluated if logging is disabled.
//
// @param format A format string suitable for use with `util::StringFormat`
// @param ... C++ variadic arguments that match the format string. Not C
//     varargs.
#define LOG_ERROR(FMT, ...)                                           \
  do {                                                                \
    namespace _util = firebase::firestore::util;                      \
    if (_util::LogIsLoggable(_util::kLogLevelError)) {                \
      _PARAM_CHECK(FMT, __VA_ARGS__);                                 \
      std::string _message = _util::StringFormat(FMT, ##__VA_ARGS__); \
      _util::LogMessage(_util::kLogLevelError, _message);             \
    }                                                                 \
  } while (0)

// Tests to see if the given log level is loggable.
bool LogIsLoggable(LogLevel level);

// Is debug logging enabled?
inline bool LogIsDebugEnabled() {
  return LogIsLoggable(kLogLevelDebug);
}

// All messages at or above the specified log level value are displayed.
void LogSetLevel(LogLevel level);

// Log a message at the given level.
void LogMessage(LogLevel log_level, const std::string& message);

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_LOG_H_
