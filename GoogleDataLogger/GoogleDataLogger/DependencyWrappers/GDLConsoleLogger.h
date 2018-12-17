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

#import "GULLogger.h"

/** The console logger prefix. */
static GULLoggerService kGDLConsoleLogger = @"[GoogleDataLogger]";

/** A list of message codes to print in the logger that help to correspond printed messages with
 * code locations.
 *
 * Prefixes:
 * - MCW => MessageCodeWarning
 */
typedef NS_ENUM(NSInteger, GDLMessageCode) {

  /** For warning messages concerning transform: not being implemented by a log transformer. */
  GDLMCWTransformerDoesntImplementTransform = 1,

  /** For warning messages concerning protoBytes: not being implemented by a log extension. */
  GDLMCWExtensionMissingBytesImpl = 2
};

/** */
FOUNDATION_EXTERN NSString *GDLMessageCodeEnumToString(GDLMessageCode code);

/** Logs the warningMessage string to the console at the warning level.
 *
 * @param warningMessageFormat The format string to log to the console.
 */
FOUNDATION_EXTERN void GDLLogWarning(GDLMessageCode messageCode,
                                     NSString *warningMessageFormat,
                                     ...) NS_FORMAT_FUNCTION(2, 3);

// A define to wrap GULLogWarning with slightly more convenient usage.
#define GDLLogWarning(MESSAGE_CODE, MESSAGE_FORMAT, ...)                                          \
  GULLogWarning(kGDLConsoleLogger, YES, GDLMessageCodeEnumToString(MESSAGE_CODE), MESSAGE_FORMAT, \
                __VA_ARGS__);
