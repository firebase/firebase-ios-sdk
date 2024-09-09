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

/// Constants that specify the level of logging to perform in App Check Core.
typedef NS_ENUM(NSInteger, GACAppCheckLogLevel) {
  /// The debug log level; equivalent to `OS_LOG_TYPE_DEBUG`.
  GACAppCheckLogLevelDebug = 1,
  /// The informational log level; equivalent to `OS_LOG_TYPE_INFO`.
  GACAppCheckLogLevelInfo = 2,
  /// The warning log level; equivalent to `OS_LOG_TYPE_DEFAULT`.
  GACAppCheckLogLevelWarning = 3,
  /// The error log level; equivalent to `OS_LOG_TYPE_ERROR`.
  GACAppCheckLogLevelError = 4,
  /// The fault log level; equivalent to `OS_LOG_TYPE_FAULT`.
  GACAppCheckLogLevelFault = 5
} NS_SWIFT_NAME(AppCheckCoreLogLevel);

NS_SWIFT_NAME(AppCheckCoreLogger)
@interface GACAppCheckLogger : NSObject

/// The current logging level.
///
/// Messages with levels equal to or higher priority than `logLevel` will be printed, where
/// Fault > Error > Warning > Info > Debug.
@property(class, atomic, assign) GACAppCheckLogLevel logLevel;

- (instancetype)init NS_UNAVAILABLE;

@end
