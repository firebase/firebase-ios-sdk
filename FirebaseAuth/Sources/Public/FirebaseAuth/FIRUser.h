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

#import <Foundation/Foundation.h>

@class FIRAuthTokenResult;
@class FIRPhoneAuthCredential;
@class FIRUserProfileChangeRequest;
@class FIRUserMetadata;
@protocol FIRAuthUIDelegate;

NS_ASSUME_NONNULL_BEGIN

/** @typedef FIRAuthTokenCallback
    @brief The type of block called when a token is ready for use.
    @see `User.getIDToken()`
    @see `User.idTokenForcingRefresh(_:)`

    @param token Optionally; an access token if the request was successful.
    @param error Optionally; the error which occurred - or nil if the request was successful.

    @remarks One of `token` or `error` will always be non-nil.
 */
typedef void (^FIRAuthTokenCallback)(NSString *_Nullable token, NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRAuthTokenResultCallback
    @brief The type of block called when a token is ready for use.
    @see `User.getIDToken()`
    @see `User.idTokenForcingRefresh(_:)`

    @param tokenResult Optionally; an object containing the raw access token string as well as other
        useful data pertaining to the token.
    @param error Optionally; the error which occurred - or nil if the request was successful.

    @remarks One of `token` or `error` will always be non-nil.
 */
typedef void (^FIRAuthTokenResultCallback)(FIRAuthTokenResult *_Nullable tokenResult,
                                           NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRUserProfileChangeCallback
    @brief The type of block called when a user profile change has finished.

    @param error Optionally; the error which occurred - or nil if the request was successful.
 */
typedef void (^FIRUserProfileChangeCallback)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRSendEmailVerificationCallback
    @brief The type of block called when a request to send an email verification has finished.

    @param error Optionally; the error which occurred - or nil if the request was successful.
 */
typedef void (^FIRSendEmailVerificationCallback)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

NS_ASSUME_NONNULL_END
