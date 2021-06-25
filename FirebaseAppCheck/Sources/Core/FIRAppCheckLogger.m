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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

FIRLoggerService kFIRLoggerAppCheck = @"[Firebase/AppCheck]";

NSString *const kFIRLoggerAppCheckMessageCodeUnknown = @"I-FAA001001";

// FIRAppCheck.m
NSString *const kFIRLoggerAppCheckMessageCodeProviderFactoryIsMissing = @"I-FAA002001";
NSString *const kFIRLoggerAppCheckMessageCodeProviderIsMissing = @"I-FAA002002";

// FIRAppCheckAPIService.m
NSString *const kFIRLoggerAppCheckMessageCodeUnexpectedHTTPCode = @"I-FAA003001";

// FIRAppCheckDebugProvider.m
NSString *const kFIRLoggerAppCheckMessageDebugProviderIncompleteFIROptions = @"I-FAA004001";
NSString *const kFIRLoggerAppCheckMessageDebugProviderFailedExchange = @"I-FAA004002";

// FIRAppCheckDebugProviderFactory.m
NSString *const kFIRLoggerAppCheckMessageCodeDebugToken = @"I-FAA005001";

// FIRDeviceCheckProvider.m
NSString *const kFIRLoggerAppCheckMessageDeviceCheckProviderIncompleteFIROptions = @"I-FAA006001";

// FIRAppAttestProvider.m
NSString *const kFIRLoggerAppCheckMessageCodeAppAttestNotSupported = @"I-FAA007001";
NSString *const kFIRLoggerAppCheckMessageCodeAttestationRejected = @"I-FAA007002";

#pragma mark - Log functions
void FIRAppCheckDebugLog(NSString *messageCode, NSString *message, ...) {
  va_list args_ptr;
  va_start(args_ptr, message);
  FIRLogBasic(FIRLoggerLevelDebug, kFIRLoggerAppCheck, messageCode, message, args_ptr);
  va_end(args_ptr);
}

NS_ASSUME_NONNULL_END
