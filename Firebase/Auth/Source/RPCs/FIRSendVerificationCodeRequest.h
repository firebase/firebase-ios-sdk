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

#import "FIRIdentityToolkitRequest.h"

#import "FIRAuthRPCRequest.h"
#import "FIRIdentityToolkitRequest.h"

@class FIRAuthAppCredential;

NS_ASSUME_NONNULL_BEGIN

@interface FIRSendVerificationCodeRequest : FIRIdentityToolkitRequest <FIRAuthRPCRequest>

/** @property phoneNumber
    @brief The phone number to which the verification code should be sent.
 */
@property(nonatomic, strong, readonly) NSString *phoneNumber;

/** @property appCredential
    @brief The credential to prove the identity of the app in order to send the verification code.
 */
@property(nonatomic, strong, readonly) FIRAuthAppCredential *appCredential;

/** @fn initWithEndpoint:APIKey:
    @brief Please use initWithPhoneNumber:APIKey:
 */
- (nullable instancetype)initWithEndpoint:(NSString *)endpoint
                                   APIKey:(NSString *)APIKey NS_UNAVAILABLE;

/** @fn initWithPhoneNumber:APIKey:
    @brief Designated initializer.
    @param phoneNumber The phone number to which the verification code is to be sent.
    @param appCredential The credential that proves the identity of the app.
    @param APIKey The client's API Key.
 */
- (nullable instancetype)initWithPhoneNumber:(NSString *)phoneNumber
                               appCredential:(FIRAuthAppCredential *)appCredential
                                      APIKey:(NSString *)APIKey NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
