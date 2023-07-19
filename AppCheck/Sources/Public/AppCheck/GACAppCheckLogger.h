/*
 * Copyright 2023 Google LLC
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

#import "GACAppCheckErrors.h"

/// The current logging level.
///
/// Messages with levels equal to or higher priority than `GACAppCheckLogLevel` will be printed,
/// where Fault > Error > Warning > Info > Debug.
///
/// Note: Declared as volatile to make getting and setting atomic.
FOUNDATION_EXPORT volatile NSInteger gGACAppCheckLogLevel;

/// Constants that specify the level of logging to perform in App Check Core.
typedef NS_ENUM(NSInteger, GACAppCheckLogLevel) {
  /// The fault log level; equivalent to `OS_LOG_TYPE_FAULT`.
  GACAppCheckLogLevelFault = 1,
  /// The error log level; equivalent to `OS_LOG_TYPE_ERROR`.
  GACAppCheckLogLevelError = 2,
  /// The warning log level; equivalent to `OS_LOG_TYPE_DEFAULT`.
  GACAppCheckLogLevelWarning = 3,
  /// The informational log level; equivalent to `OS_LOG_TYPE_INFO`.
  GACAppCheckLogLevelInfo = 4,
  /// The debug log level; equivalent to `OS_LOG_TYPE_DEBUG`.
  GACAppCheckLogLevelDebug = 5
} NS_SWIFT_NAME(AppCheckCoreLogLevel);
