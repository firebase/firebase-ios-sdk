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

#import "FIRCoreSwiftNameSupport.h"

/**
 * The log levels used by internal logging.
 */
typedef NS_ENUM(NSInteger, FIRLoggerLevel) {
  FIRLoggerLevelError = 3 /*ASL_LEVEL_ERR*/,
  FIRLoggerLevelWarning = 4 /*ASL_LEVEL_WARNING*/,
  FIRLoggerLevelNotice = 5 /*ASL_LEVEL_NOTICE*/,
  FIRLoggerLevelInfo = 6 /*ASL_LEVEL_INFO*/,
  FIRLoggerLevelDebug = 7 /*ASL_LEVEL_DEBUG*/,
  FIRLoggerLevelMin = FIRLoggerLevelError,
  FIRLoggerLevelMax = FIRLoggerLevelDebug
} FIR_SWIFT_NAME(FirebaseLoggerLevel);
