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

#import "FIRAuthRPCRequest.h"
#import "FIRIdentityToolkitRequest.h"

NS_ASSUME_NONNULL_BEGIN

/** @enum FIRGetOOBConfirmationCodeRequestType
    @brief Types of OOB Confirmation Code requests.
 */
typedef NS_ENUM(NSInteger, FIRGetOOBConfirmationCodeRequestType) {
  /** @var FIRGetOOBConfirmationCodeRequestTypePasswordReset
      @brief Requests a password reset code.
   */
  FIRGetOOBConfirmationCodeRequestTypePasswordReset,

  /** @var FIRGetOOBConfirmationCodeRequestTypeVerifyEmail
      @brief Requests an email verification code.
   */
  FIRGetOOBConfirmationCodeRequestTypeVerifyEmail,
};

/** @enum FIRGetOOBConfirmationCodeRequest
    @brief Represents the parameters for the getOOBConfirmationCode endpoint.
 */
@interface FIRGetOOBConfirmationCodeRequest : FIRIdentityToolkitRequest <FIRAuthRPCRequest>

/** @property requestType
    @brief The types of OOB Confirmation Code to request.
 */
@property(nonatomic, assign, readonly) FIRGetOOBConfirmationCodeRequestType requestType;

/** @property email
    @brief The email of the user.
    @remarks For password reset.
 */
@property(nonatomic, copy, nullable, readonly) NSString *email;

/** @property accessToken
    @brief The STS Access Token of the authenticated user.
    @remarks For email change.
 */
@property(nonatomic, copy, nullable, readonly) NSString *accessToken;

/** @fn passwordResetRequestWithEmail:APIKey:
    @brief Creates a password reset request.
    @param email The user's email address.
    @param APIKey The client's API Key.
    @return A password reset request.
 */
+ (nullable FIRGetOOBConfirmationCodeRequest *)passwordResetRequestWithEmail:(NSString *)email
                                                                      APIKey:(NSString *)APIKey;

/** @fn verifyEmailRequestWithAccessToken:APIKey:
    @brief Creates a password reset request.
    @param accessToken The user's STS Access Token.
    @param APIKey The client's API Key.
    @return A password reset request.
 */
+ (nullable FIRGetOOBConfirmationCodeRequest *)
    verifyEmailRequestWithAccessToken:(NSString *)accessToken APIKey:(NSString *)APIKey;

/** @fn init
    @brief Please use a factory method.
 */
- (nullable instancetype)initWithEndpoint:(NSString *)endpoint
                                   APIKey:(NSString *)APIKey NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
