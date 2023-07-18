/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAuth/Sources/Backend/RPC/Proto/FIRAuthProto.h"

NS_ASSUME_NONNULL_BEGIN

/**
 @brief FIRAuthProtoFinalizeMFATOTPSignInRequestInfo class.  This class is used to compose
 finalizeMFASignInRequest for TOTP case.
 */
@interface FIRAuthProtoFinalizeMFATOTPSignInRequestInfo : NSObject <FIRAuthProto>

/**
 @brief Multifactor enrollment ID.
 */
@property(nonatomic, strong, readonly, nullable) NSString *mfaEnrollmentID;

/**
 @brief Verification code.
 */
@property(nonatomic, strong, readonly, nullable) NSString *verificationCode;

/**
 @fn initWithMfaEnrollmentID:verificationCode
 @brief initialize function for FIRAuthProtoFinalizeMFATOTPSignInRequestInfo.
 @param mfaEnrollmentID Multifactor enrollment ID.
 @param verificationCode One time verification code.
 */
- (instancetype)initWithMfaEnrollmentID:(NSString *)mfaEnrollmentID
                       verificationCode:(NSString *)verificationCode;
@end

NS_ASSUME_NONNULL_END
