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

#import <GoogleUtilities/GULLoggerLevel.h>

/**
 * The log levels used by internal logging.
 */
typedef NS_ENUM(NSInteger, FIRLoggerLevel) {
  /** Error level, matches ASL_LEVEL_ERR. */
  FIRLoggerLevelError = GULLoggerLevelError,
  /** Warning level, matches ASL_LEVEL_WARNING. */
  FIRLoggerLevelWarning = GULLoggerLevelWarning,
  /** Notice level, matches ASL_LEVEL_NOTICE. */
  FIRLoggerLevelNotice = GULLoggerLevelNotice,
  /** Info level, matches ASL_LEVEL_NOTICE. */
  FIRLoggerLevelInfo = GULLoggerLevelInfo,
  /** Debug level, matches ASL_LEVEL_DEBUG. */
  FIRLoggerLevelDebug = GULLoggerLevelDebug,
  /** Minimum log level. */
  FIRLoggerLevelMin = FIRLoggerLevelError,
  /** Maximum log level. */
  FIRLoggerLevelMax = FIRLoggerLevelDebug
} NS_SWIFT_NAME(FirebaseLoggerLevel);
