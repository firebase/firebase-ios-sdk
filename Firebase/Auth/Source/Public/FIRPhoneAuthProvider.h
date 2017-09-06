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

#import "FIRAuthSwiftNameSupport.h"

@class FIRAuth;
@class FIRPhoneAuthCredential;
@protocol FIRAuthUIDelegate;

NS_ASSUME_NONNULL_BEGIN

/** @var FIRPhoneAuthProviderID
    @brief A string constant identifying the phone identity provider.
 */
extern NSString *const FIRPhoneAuthProviderID FIR_SWIFT_NAME(PhoneAuthProviderID);

/** @typedef FIRVerificationResultCallback
    @brief The type of block invoked when a request to send a verification code has finished.

    @param verificationID On success, the verification ID provided, nil otherwise.
    @param error On error, the error that occured, nil otherwise.
 */
typedef void (^FIRVerificationResultCallback)(NSString *_Nullable verificationID,
                                              NSError *_Nullable error)
    FIR_SWIFT_NAME(VerificationResultCallback);

/** @class FIRPhoneAuthProvider
    @brief A concrete implementation of @c FIRAuthProvider for phone auth providers.
 */
FIR_SWIFT_NAME(PhoneAuthProvider)
@interface FIRPhoneAuthProvider : NSObject

/** @fn provider
    @brief Returns an instance of @c FIRPhoneAuthProvider for the default @c FIRAuth object.
 */
+ (instancetype)provider FIR_SWIFT_NAME(provider());

/** @fn providerWithAuth:
    @brief Returns an instance of @c FIRPhoneAuthProvider for the provided @c FIRAuth object.

    @param auth The auth object to associate with the phone auth provider instance.
 */
+ (instancetype)providerWithAuth:(FIRAuth *)auth FIR_SWIFT_NAME(provider(auth:));

/** @fn verifyPhoneNumber:completion:
    @brief Please use @c verifyPhoneNumber:UIDelegate:completion: instead.

    @param phoneNumber The phone number to be verified.
    @param completion The callback to be invoked when the verification flow is finished.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeAppNotVerified - Indicates that Firebase could not retrieve the
            silent push notification and therefore could not verify your app.</li>
        <li>@c FIRAuthErrorCodeInvalidAppCredential - Indicates that The APNs device token provided
            is either incorrect or does not match the private certificate uploaded to the Firebase
            Console.</li>
        <li>@c FIRAuthErrorCodeQuotaExceeded - Indicates that the phone verification quota for this
            project has been exceeded.</li>
        <li>@c FIRAuthErrorCodeInvalidPhoneNumber - Indicates that the phone number provided is
            invalid.</li>
        <li>@c FIRAuthErrorCodeMissingPhoneNumber - Indicates that a phone number was not provided.
        </li>
        <li>@c FIRAuthErrorCodeMissingAppToken - Indicates that the APNs device token could not be
            obtained. The app may not have set up remote notification correctly, or may fail to
            forward the APNs device token to FIRAuth if app delegate swizzling is disabled.
        </li>
    </ul>
 */
- (void)verifyPhoneNumber:(NSString *)phoneNumber
               completion:(nullable FIRVerificationResultCallback)completion
    __attribute__((deprecated));

/** @fn verifyPhoneNumber:UIDelegate:completion:
    @brief Starts the phone number authentication flow by sending a verifcation code to the
        specified phone number.
    @param phoneNumber The phone number to be verified.
    @param UIDelegate An object used to present the SFSafariViewController. The object is retained
        by this method until the completion block is executed.
    @param completion The callback to be invoked when the verification flow is finished.
    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeCaptchaCheckFailed - Indicates that the reCAPTCHA token obtained by
            the Firebase Auth is invalid or has expired.</li>
        <li>@c FIRAuthErrorCodeQuotaExceeded - Indicates that the phone verification quota for this
            project has been exceeded.</li>
        <li>@c FIRAuthErrorCodeInvalidPhoneNumber - Indicates that the phone number provided is
            invalid.</li>
        <li>@c FIRAuthErrorCodeMissingPhoneNumber - Indicates that a phone number was not provided.
        </li>
    </ul>
 */
- (void)verifyPhoneNumber:(NSString *)phoneNumber
               UIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
               completion:(nullable FIRVerificationResultCallback)completion;

/** @fn credentialWithVerificationID:verificationCode:
    @brief Creates an @c FIRAuthCredential for the phone number provider identified by the
        verification ID and verification code.

    @param verificationID The verification ID obtained from invoking
        verifyPhoneNumber:completion:
    @param verificationCode The verification code obtained from the user.
    @return The corresponding phone auth credential for the verification ID and verification code
        provided.
 */
- (FIRPhoneAuthCredential *)credentialWithVerificationID:(NSString *)verificationID
                                        verificationCode:(NSString *)verificationCode;

/** @fn init
    @brief Please use the @c provider or @c providerWithAuth: methods to obtain an instance of
        @c FIRPhoneAuthProvider.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
