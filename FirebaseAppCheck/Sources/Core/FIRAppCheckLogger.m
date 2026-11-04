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

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

FIRLoggerService kFIRLoggerAppCheck = @"[FirebaseAppCheck]";

// FIRAppCheck.m
NSString *const kFIRLoggerAppCheckMessageCodeProviderFactoryIsMissing = @"I-FAA002001";
NSString *const kFIRLoggerAppCheckMessageCodeProviderIsMissing = @"I-FAA002002";

// FIRAppCheckDebugProvider.m
NSString *const kFIRLoggerAppCheckMessageDebugProviderIncompleteFIROptions = @"I-FAA004001";
NSString *const kFIRLoggerAppCheckMessageCodeDebugTokenExchangeFailed = @"I-FAA004002";
NSString *const kFIRLoggerAppCheckMessageCodeDebugTokenSource = @"I-FAA004003";
NSString *const kFIRLoggerAppCheckMessageCodeDebugTokenRejected = @"I-FAA004004";

// FIRAppCheckDebugProviderFactory.m
NSString *const kFIRLoggerAppCheckMessageCodeDebugToken = @"I-FAA005001";

// FIRDeviceCheckProvider.m
NSString *const kFIRLoggerAppCheckMessageDeviceCheckProviderIncompleteFIROptions = @"I-FAA006001";

// FIRRecaptchaProvider.m
NSString *const kFIRLoggerAppCheckMessageRecaptchaProviderIncompleteFIROptions = @"I-FAA007001";
NSString *const kFIRLoggerAppCheckMessageRecaptchaProviderMissingSiteKey = @"I-FAA007002";
NSString *const kFIRLoggerAppCheckMessageRecaptchaProviderMissingRecaptchaEnterpriseSDK =
    @"I-FAA007003";

// FIRDefaultProviderFactory.m
NSString *const kFIRLoggerAppCheckMessageCodeDeviceCheckProviderUnavailable = @"I-FAA008002";

#pragma mark - Log functions

void FIRAppCheckDebugLog(NSString *messageCode, NSString *message, ...) {
  va_list args_ptr;
  va_start(args_ptr, message);
  FIRLogBasic(FIRLoggerLevelDebug, kFIRLoggerAppCheck, messageCode, message, args_ptr);
  va_end(args_ptr);
}

void FIRAppCheckLogDebugTokenSource(NSString *source) {
  FIRLogNotice(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeDebugTokenSource,
               @"Debug token loaded from %@.", source);
}

void FIRAppCheckLogDebugTokenRejected(NSString *_Nullable projectID,
                                      NSString *_Nullable googleAppID) {
  FIRLogWarning(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeDebugTokenRejected,
                @"The App Check debug token was rejected by the server (HTTP 403). If the token "
                @"is not registered with your project, run 'firebase "
                @"appcheck:debugtokens:create --project %@ --app %@ --force' to provision a new "
                @"token. A 403 response can also mean that the Firebase App Check API is disabled "
                @"or that the API key is restricted.",
                projectID ?: @"<project-id>", googleAppID ?: @"<app-id>");
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
