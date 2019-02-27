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

/// The log levels used by internal logging.
typedef NS_ENUM(NSInteger, GULLoggerLevel) {
  /// Error level, matches ASL_LEVEL_ERR and is used for OS_LOG_TYPE_ERROR.
  GULLoggerLevelError = 3,

  /// Warning level, matches ASL_LEVEL_WARNING and is used for OS_LOG_TYPE_DEFAULT.
  GULLoggerLevelWarning = 4,

  /// Notice level, matches ASL_LEVEL_NOTICE and is used for OS_LOG_TYPE_DEFAULT.
  GULLoggerLevelNotice = 5,

  /// Info level, matches ASL_LEVEL_INFO and is used for OS_LOG_TYPE_INFO.
  GULLoggerLevelInfo = 6,

  /// Debug level, matches ASL_LEVEL_DEBUG  and is mapped to OS_LOG_TYPE_DEBUG.
  GULLoggerLevelDebug = 7,

  /// Minimum log level.
  GULLoggerLevelMin = GULLoggerLevelError,

  /// Maximum log level.
  GULLoggerLevelMax = GULLoggerLevelDebug
} NS_SWIFT_NAME(GoogleLoggerLevel);
