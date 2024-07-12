/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>

@class FIRMultiFactorSession;

NS_ASSUME_NONNULL_BEGIN

/** @typedef FIRMultiFactorSessionCallback
    @brief The callback that triggered when a developer calls `getSessionWithCompletion`.
        This type is available on iOS only.
    @param session The multi factor session returned, if any.
    @param error The error which occurred, if any.
*/
typedef void (^FIRMultiFactorSessionCallback)(FIRMultiFactorSession *_Nullable session,
                                              NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.")
        API_UNAVAILABLE(macos, tvos, watchos);

/**
   @brief The string identifier for using phone as a second factor.
        This constant is available on iOS only.
*/
extern NSString *const _Nonnull FIRPhoneMultiFactorID NS_SWIFT_NAME(PhoneMultiFactorID)
    API_UNAVAILABLE(macos, tvos, watchos);

/**
   @brief The string identifier for using TOTP as a second factor.
        This constant is available on iOS only.
*/
extern NSString *const _Nonnull FIRTOTPMultiFactorID NS_SWIFT_NAME(TOTPMultiFactorID)
    API_UNAVAILABLE(macos, tvos, watchos);

NS_ASSUME_NONNULL_END
