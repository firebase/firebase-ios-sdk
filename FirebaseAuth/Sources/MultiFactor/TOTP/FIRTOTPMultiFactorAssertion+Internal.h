/*
 * Copyright 2023 Google LLC
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

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPMultiFactorAssertion.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPSecret.h"

NS_ASSUME_NONNULL_BEGIN
/**
 @brief The subclass of base class MultiFactorAssertion, used to assert ownership of a TOTP
 (Time-based One Time Password). second factor.
 This class is available on iOS only.
 */
@interface FIRTOTPMultiFactorAssertion ()

/**
 @brief secret TOTPSecret
 */
@property(nonatomic, copy, readonly, nonnull) FIRTOTPSecret *secret;

/**
 @brief one time password string
 */
@property(nonatomic, copy, readonly, nonnull) NSString *oneTimePassword;

/**
 @brief the enrollment ID
 */
@property(nonatomic, copy, readonly, nonnull) NSString *enrollmentID;

/**
 @fn initWithSecret
 @brief initializing function
 @param secret TOTPSecret
 @param oneTimePassword one time password string
 */
- (instancetype)initWithSecret:(FIRTOTPSecret *)secret oneTimePassword:(NSString *)oneTimePassword;

/**
 @fn initWithEnrollmentID:oneTimePassword
 @brief initializing function
 @param enrollmentID enrollment ID
 @param oneTimePassword one time password string
 */
- (instancetype)initWithEnrollmentID:(NSString *)enrollmentID
                     oneTimePassword:(NSString *)oneTimePassword;

@end

NS_ASSUME_NONNULL_END

#endif
