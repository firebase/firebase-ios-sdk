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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The log levels used by internal logging.
typedef NS_ENUM(NSInteger, GULLoggerLevel) {
  /// Error level, corresponding to `OS_LOG_TYPE_ERROR`.
  GULLoggerLevelError = 3,  // For backwards compatibility, the enum value matches `ASL_LEVEL_ERR`.

  /// Warning level, corresponding to `OS_LOG_TYPE_DEFAULT`.
  ///
  /// > Note: Since OSLog doesn't have a WARNING type, this is equivalent to `GULLoggerLevelNotice`.
  GULLoggerLevelWarning = 4,  // For backwards compatibility, the value matches `ASL_LEVEL_WARNING`.

  /// Notice level, corresponding to `OS_LOG_TYPE_DEFAULT`.
  GULLoggerLevelNotice = 5,  // For backwards compatibility, the value matches `ASL_LEVEL_NOTICE`.

  /// Info level, corresponding to `OS_LOG_TYPE_INFO`.
  GULLoggerLevelInfo = 6,  // For backwards compatibility, the enum value matches `ASL_LEVEL_INFO`.

  /// Debug level, corresponding to `OS_LOG_TYPE_DEBUG`.
  GULLoggerLevelDebug = 7,  // For backwards compatibility, the value matches `ASL_LEVEL_DEBUG`.

  /// The minimum (most severe) supported logging level.
  GULLoggerLevelMin = GULLoggerLevelError,

  /// The maximum (least severe) supported logging level.
  GULLoggerLevelMax = GULLoggerLevelDebug
} NS_SWIFT_NAME(GoogleLoggerLevel);

NS_ASSUME_NONNULL_END
