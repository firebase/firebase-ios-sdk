/*
 * Copyright 2021 Google LLC
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

/// Firebase app check error domain.
FOUNDATION_EXTERN NSErrorDomain const GACAppCheckErrorDomain NS_SWIFT_NAME(AppCheckCoreErrorDomain);

typedef NS_ERROR_ENUM(GACAppCheckErrorDomain, GACAppCheckErrorCode){
    /// An unknown or non-actionable error.
    GACAppCheckErrorCodeUnknown = 0,

    /// A network connection error.
    GACAppCheckErrorCodeServerUnreachable = 1,

    /// Invalid configuration error. Currently, an exception is thrown but this error is reserved
    /// for future implementations of invalid configuration detection.
    GACAppCheckErrorCodeInvalidConfiguration = 2,

    /// System keychain access error. Ensure that the app has proper keychain access.
    GACAppCheckErrorCodeKeychain = 3,

    /// Selected app attestation provider is not supported on the current platform or OS version.
    GACAppCheckErrorCodeUnsupported = 4

} NS_SWIFT_NAME(AppCheckCoreErrorCode);

#pragma mark - Error Message Codes

typedef NS_ENUM(NSInteger, GACAppCheckMessageCode) {
  GACLoggerAppCheckMessageCodeUnknown = 1001,

  // App Check
  GACLoggerAppCheckMessageCodeProviderIsMissing = 2002,
  GACLoggerAppCheckMessageCodeUnexpectedHTTPCode = 3001,

  // Debug Provider
  GACLoggerAppCheckMessageLocalDebugToken = 4001,
  GACLoggerAppCheckMessageEnvironmentVariableDebugToken = 4002,
  GACLoggerAppCheckMessageDebugProviderFirebaseEnvironmentVariable = 4003,
  GACLoggerAppCheckMessageDebugProviderFailedExchange = 4004,

  // App Attest Provider
  GACLoggerAppCheckMessageCodeAppAttestNotSupported = 7001,
  GACLoggerAppCheckMessageCodeAttestationRejected = 7002
} NS_SWIFT_NAME(AppCheckCoreMessageCode);
