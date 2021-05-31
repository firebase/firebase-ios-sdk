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

#import <Foundation/Foundation.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

extern FIRLoggerService kFIRLoggerAppCheck;

FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageCodeUnknown;

// FIRAppCheck.m
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageCodeProviderFactoryIsMissing;
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageCodeProviderIsMissing;

// FIRAppCheckAPIService.m
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageCodeUnexpectedHTTPCode;

// FIRAppCheckDebugProvider.m
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageDebugProviderIncompleteFIROptions;
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageDebugProviderFailedExchange;

// FIRAppCheckDebugProviderFactory.m
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageCodeDebugToken;

// FIRDeviceCheckProvider.m
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageDeviceCheckProviderIncompleteFIROptions;

// FIRAppAttestProvider.m
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageCodeAppAttestNotSupported;
FOUNDATION_EXPORT NSString *const kFIRLoggerAppCheckMessageCodeAttestationRejected;

void FIRAppCheckDebugLog(NSString *messageCode, NSString *message, ...);
