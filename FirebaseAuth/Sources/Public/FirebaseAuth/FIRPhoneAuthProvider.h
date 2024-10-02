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

NS_ASSUME_NONNULL_BEGIN

/** @var FIRPhoneAuthProviderID
    @brief A string constant identifying the phone identity provider.
        This constant is available on iOS only.
 */
extern NSString *const FIRPhoneAuthProviderID NS_SWIFT_NAME(PhoneAuthProviderID)
    API_UNAVAILABLE(macos, tvos, watchos);

/** @var FIRPhoneAuthProviderID
    @brief A string constant identifying the phone sign-in method.
        This constant is available on iOS only.
 */
extern NSString *const _Nonnull FIRPhoneAuthSignInMethod NS_SWIFT_NAME(PhoneAuthSignInMethod)
    API_UNAVAILABLE(macos, tvos, watchos);

/** @typedef FIRVerificationResultCallback
    @brief The type of block invoked when a request to send a verification code has finished.
        This type is available on iOS only.

    @param verificationID On success, the verification ID provided, nil otherwise.
    @param error On error, the error that occurred, nil otherwise.
 */
typedef void (^FIRVerificationResultCallback)(NSString *_Nullable verificationID,
                                              NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.")
        API_UNAVAILABLE(macos, tvos, watchos);

NS_ASSUME_NONNULL_END
