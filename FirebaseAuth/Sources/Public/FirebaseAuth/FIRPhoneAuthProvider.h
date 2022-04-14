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

@class FIRAuth;
@class FIRMultiFactorSession;
@class FIRPhoneAuthCredential;
@class FIRPhoneMultiFactorInfo;
@protocol FIRAuthUIDelegate;

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

/** @class FIRPhoneAuthProvider
    @brief A concrete implementation of `AuthProvider` for phone auth providers.
        This class is available on iOS only.
 */
NS_SWIFT_NAME(PhoneAuthProvider) API_UNAVAILABLE(macos, tvos, watchos)
    @interface FIRPhoneAuthProvider : NSObject

/** @fn provider
    @brief Returns an instance of `PhoneAuthProvider` for the default `Auth` object.
 */
+ (instancetype)provider NS_SWIFT_NAME(provider());

/** @fn providerWithAuth:
    @brief Returns an instance of `PhoneAuthProvider` for the provided `Auth` object.
    @param auth The auth object to associate with the phone auth provider instance.
 */
+ (instancetype)providerWithAuth:(FIRAuth *)auth NS_SWIFT_NAME(provider(auth:));

/** @fn verifyPhoneNumber:UIDelegate:completion:
    @brief Starts the phone number authentication flow by sending a verification code to the
        specified phone number.
    @param phoneNumber The phone number to be verified.
    @param UIDelegate An object used to present the SFSafariViewController. The object is retained
        by this method until the completion block is executed.
    @param completion The callback to be invoked when the verification flow is finished.
    @remarks Possible error codes:

        + `AuthErrorCodeCaptchaCheckFailed` - Indicates that the reCAPTCHA token obtained by
            the Firebase Auth is invalid or has expired.
        + `AuthErrorCodeQuotaExceeded` - Indicates that the phone verification quota for this
            project has been exceeded.
        + `AuthErrorCodeInvalidPhoneNumber` - Indicates that the phone number provided is
            invalid.
        + `AuthErrorCodeMissingPhoneNumber` - Indicates that a phone number was not provided.
 */
- (void)verifyPhoneNumber:(NSString *)phoneNumber
               UIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
               completion:(nullable void (^)(NSString *_Nullable verificationID,
                                             NSError *_Nullable error))completion;

/** @fn verifyPhoneNumber:UIDelegate:multiFactorSession:completion:
    @brief Verify ownership of the second factor phone number by the current user.
    @param phoneNumber The phone number to be verified.
    @param UIDelegate An object used to present the SFSafariViewController. The object is retained
        by this method until the completion block is executed.
    @param session A session to identify the MFA flow. For enrollment, this identifies the user
        trying to enroll. For sign-in, this identifies that the user already passed the first
        factor challenge.
    @param completion The callback to be invoked when the verification flow is finished.
*/
- (void)verifyPhoneNumber:(NSString *)phoneNumber
               UIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
       multiFactorSession:(nullable FIRMultiFactorSession *)session
               completion:(nullable void (^)(NSString *_Nullable verificationID,
                                             NSError *_Nullable error))completion;

/** @fn verifyPhoneNumberWithMultiFactorInfo:UIDelegate:multiFactorSession:completion:
    @brief Verify ownership of the second factor phone number by the current user.
    @param phoneMultiFactorInfo The phone multi factor whose number need to be verified.
    @param UIDelegate An object used to present the SFSafariViewController. The object is retained
        by this method until the completion block is executed.
    @param session A session to identify the MFA flow. For enrollment, this identifies the user
        trying to enroll. For sign-in, this identifies that the user already passed the first
        factor challenge.
    @param completion The callback to be invoked when the verification flow is finished.
*/
- (void)verifyPhoneNumberWithMultiFactorInfo:(FIRPhoneMultiFactorInfo *)phoneMultiFactorInfo
                                  UIDelegate:(nullable id<FIRAuthUIDelegate>)UIDelegate
                          multiFactorSession:(nullable FIRMultiFactorSession *)session
                                  completion:
                                      (nullable void (^)(NSString *_Nullable verificationID,
                                                         NSError *_Nullable error))completion;

/** @fn credentialWithVerificationID:verificationCode:
    @brief Creates an `AuthCredential` for the phone number provider identified by the
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
    @brief Please use the `provider()` or `provider(auth:)` methods to obtain an instance of
        `PhoneAuthProvider`.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
