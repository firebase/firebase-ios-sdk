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

@class FIRAppCheckHTTPError;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSErrorDomain const kFIRAppCheckErrorDomain NS_SWIFT_NAME(AppCheckErrorDomain);

void FIRAppCheckSetErrorToPointer(NSError *error, NSError **pointer);

@interface FIRAppCheckErrorUtil : NSObject

// Internal errors.

+ (NSError *)cachedTokenNotFound;
+ (NSError *)cachedTokenExpired;

+ (FIRAppCheckHTTPError *)APIErrorWithHTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                                              data:(nullable NSData *)data;

+ (NSError *)APIErrorWithNetworkError:(NSError *)networkError;

+ (NSError *)appCheckTokenResponseErrorWithMissingField:(NSString *)fieldName;

+ (NSError *)appAttestAttestationResponseErrorWithMissingField:(NSString *)fieldName;

+ (NSError *)JSONSerializationError:(NSError *)error;

+ (NSError *)errorWithFailureReason:(NSString *)failureReason;

+ (NSError *)unsupportedAttestationProvider:(NSString *)providerName;

+ (NSError *)appAttestKeyIDNotFound;

@end

typedef NS_ERROR_ENUM(kFIRAppCheckErrorDomain, FIRAppCheckErrorCode){
    /// An unknown or non-actionable error.
    FIRAppCheckErrorCodeUnknown = 0,

    /// A network connection error.
    FIRAppCheckErrorCodeServerUnreachable = 1,

    /// Invalid configuration error.
    FIRAppCheckErrorCodeInvalidConfiguration = 2,

    /// System keychain access error.
    FIRAppCheckErrorCodeKeychain = 3,

    /// Selected app attestation provider is not supported on the current platform or OS version.
    FIRAppCheckErrorCodeUnsupported = 4} NS_SWIFT_NAME(AppCheckErrorCode);

NS_ASSUME_NONNULL_END
