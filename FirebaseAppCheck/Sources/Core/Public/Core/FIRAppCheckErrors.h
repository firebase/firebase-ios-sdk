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
FOUNDATION_EXTERN NSErrorDomain const FIRAppCheckErrorDomain NS_SWIFT_NAME(AppCheckErrorDomain);

typedef NS_ERROR_ENUM(FIRAppCheckErrorDomain, FIRAppCheckErrorCode){
    /// An unknown or non-actionable error.
    FIRAppCheckErrorCodeUnknown = 0,

    /// A network connection error.
    FIRAppCheckErrorCodeServerUnreachable = 1,

    /// Invalid configuration error. Currently, an exception is thrown but this error is reserved
    /// for future implementations of invalid configuration detection.
    FIRAppCheckErrorCodeInvalidConfiguration = 2,

    /// System keychain access error. Ensure that the app has proper keychain access.
    FIRAppCheckErrorCodeKeychain = 3,

    /// Selected app attestation provider is not supported on the current platform or OS version.
    FIRAppCheckErrorCodeUnsupported = 4

} NS_SWIFT_NAME(AppCheckErrorCode);
