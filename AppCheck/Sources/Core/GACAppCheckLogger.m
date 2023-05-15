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

#import "AppCheck/Sources/Core/GACAppCheckLogger.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Log Message Codes

NSString *const kFIRLoggerAppCheckMessageCodeUnknown = @"I-FAA001001";

// GACAppCheck.m
NSString *const kFIRLoggerAppCheckMessageCodeProviderIsMissing = @"I-FAA002002";

// GACAppCheckAPIService.m
NSString *const kFIRLoggerAppCheckMessageCodeUnexpectedHTTPCode = @"I-FAA003001";

// GACAppCheckDebugProvider.m
NSString *const kFIRLoggerAppCheckMessageDebugProviderIncompleteFIROptions = @"I-FAA004001";
NSString *const kFIRLoggerAppCheckMessageDebugProviderFailedExchange = @"I-FAA004002";

// GACDeviceCheckProvider.m
NSString *const kFIRLoggerAppCheckMessageDeviceCheckProviderIncompleteFIROptions = @"I-FAA006001";

// GACAppAttestProvider.m
NSString *const kFIRLoggerAppCheckMessageCodeAppAttestNotSupported = @"I-FAA007001";
NSString *const kFIRLoggerAppCheckMessageCodeAttestationRejected = @"I-FAA007002";

#pragma mark - Logging Functions

/**
 * Generates the logging functions using macros.
 *
 * Calling GACLogError(@"Firebase", @"I-GAC000001", @"Configure %@ failed.", @"blah") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Error> [Firebase/AppCheck][I-GAC000001] Configure blah
 * failed. Calling GACLogDebug(@"GoogleSignIn", @"I-GAC000002", @"Configure succeed.") shows:
 * yyyy-mm-dd hh:mm:ss.SSS sender[PID] <Debug> [GoogleSignIn/AppCheck][I-COR000002] Configure
 * succeed.
 */
#define GAC_LOGGING_FUNCTION(level)                                                  \
  void GACLog##level(NSString *messageCode, NSString *format, ...) {                 \
    va_list args_ptr;                                                                \
    va_start(args_ptr, format);                                                      \
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args_ptr]; \
    va_end(args_ptr);                                                                \
    NSLog(@"<" #level "> [AppCheck][%@] %@", messageCode, message);                  \
  }

GAC_LOGGING_FUNCTION(Error)
GAC_LOGGING_FUNCTION(Warning)
GAC_LOGGING_FUNCTION(Notice)
GAC_LOGGING_FUNCTION(Info)
GAC_LOGGING_FUNCTION(Debug)

#undef GAC_LOGGING_FUNCTION

NS_ASSUME_NONNULL_END
