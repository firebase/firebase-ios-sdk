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

#import <FirebaseCore/FIRLogger.h>
#import <Foundation/Foundation.h>

#include <string>

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace firebase {
namespace firestore {
namespace util {

namespace {

// Translates a C++ LogLevel to the equivalent Objective-C FIRLoggerLevel
FIRLoggerLevel ToFIRLoggerLevel(LogLevel level) {
  switch (level) {
    case kLogLevelVerbose:  // fall through
    case kLogLevelDebug:
      return FIRLoggerLevelDebug;
    case kLogLevelInfo:
      return FIRLoggerLevelInfo;
    case kLogLevelWarning:
      return FIRLoggerLevelWarning;
    case kLogLevelError:
      return FIRLoggerLevelError;
    default:
      // Unsupported log level. FIRSetLoggerLevel will deal with it.
      return static_cast<FIRLoggerLevel>(-1);
  }
}

}  // namespace

void LogSetLevel(LogLevel level) {
  FIRSetLoggerLevel(ToFIRLoggerLevel(level));
}

LogLevel LogGetLevel() {
  // We return the true log level. True log level is what the SDK used to
  // determine whether to log instead of what parameter is used in the last call
  // of LogSetLevel().
  if (FIRIsLoggableLevel(FIRLoggerLevelInfo, NO)) {
    if (FIRIsLoggableLevel(FIRLoggerLevelDebug, NO)) {
      // FIRLoggerLevelMax is actually kLogLevelDebug right now. We do not check
      // further.
      return kLogLevelDebug;
    } else {
      return kLogLevelInfo;
    }
  } else {
    if (FIRIsLoggableLevel(FIRLoggerLevelWarning, NO)) {
      return kLogLevelWarning;
    } else {
      return kLogLevelError;
    }
  }
}

void LogDebug(const char* format, ...) {
  va_list list;
  va_start(list, format);
  FIRLogBasic(FIRLoggerLevelDebug, kFIRLoggerFirestore, @"I-FST000001",
              WrapNSStringNoCopy(format), list);
  va_end(list);
}

void LogInfo(const char* format, ...) {
  va_list list;
  va_start(list, format);
  FIRLogBasic(FIRLoggerLevelInfo, kFIRLoggerFirestore, @"I-FST000001",
              WrapNSStringNoCopy(format), list);
  va_end(list);
}

void LogWarning(const char* format, ...) {
  va_list list;
  va_start(list, format);
  FIRLogBasic(FIRLoggerLevelWarning, kFIRLoggerFirestore, @"I-FST000001",
              WrapNSStringNoCopy(format), list);
  va_end(list);
}

void LogError(const char* format, ...) {
  va_list list;
  va_start(list, format);
  FIRLogBasic(FIRLoggerLevelError, kFIRLoggerFirestore, @"I-FST000001",
              WrapNSStringNoCopy(format), list);
  va_end(list);
}

void LogMessageV(LogLevel log_level, const char* format, va_list args) {
  FIRLogBasic(ToFIRLoggerLevel(log_level), kFIRLoggerFirestore, @"I-FST000001",
              WrapNSStringNoCopy(format), args);
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
