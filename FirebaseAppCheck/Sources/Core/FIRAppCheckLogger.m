/*
 * Copyright 2020 Google LLC
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

#import "Core/FIRAppCheckLogger.h"

#import "../FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

FIRLoggerService kFIRLoggerAppCheck = @"[FirebaseAppCheck]";

// FIRAppCheck.m
NSString *const kFIRLoggerAppCheckMessageCodeProviderFactoryIsMissing = @"I-FAA002001";
NSString *const kFIRLoggerAppCheckMessageCodeProviderIsMissing = @"I-FAA002002";

// FIRAppCheckDebugProvider.m
NSString *const kFIRLoggerAppCheckMessageDebugProviderIncompleteFIROptions = @"I-FAA004001";

// FIRAppCheckDebugProviderFactory.m
NSString *const kFIRLoggerAppCheckMessageCodeDebugToken = @"I-FAA005001";

// FIRDeviceCheckProvider.m
NSString *const kFIRLoggerAppCheckMessageDeviceCheckProviderIncompleteFIROptions = @"I-FAA006001";

#pragma mark - Log functions

void FIRAppCheckDebugLog(NSString *messageCode, NSString *message, ...) {
  va_list args_ptr;
  va_start(args_ptr, message);
  FIRLogBasic(FIRLoggerLevelDebug, kFIRLoggerAppCheck, messageCode, message, args_ptr);
  va_end(args_ptr);
}

#pragma mark - Helper functions

GACAppCheckLogLevel FIRGetGACAppCheckLogLevel(void) {
  FIRLoggerLevel loggerLevel = FIRGetLoggerLevel();
  switch (loggerLevel) {
    case FIRLoggerLevelError:
      return GACAppCheckLogLevelError;
    case FIRLoggerLevelWarning:
    case FIRLoggerLevelNotice:
      return GACAppCheckLogLevelWarning;
    case FIRLoggerLevelInfo:
      return GACAppCheckLogLevelInfo;
    case FIRLoggerLevelDebug:
      return GACAppCheckLogLevelDebug;
  }
}

NS_ASSUME_NONNULL_END
