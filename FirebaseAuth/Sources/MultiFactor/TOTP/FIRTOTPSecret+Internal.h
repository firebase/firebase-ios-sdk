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

#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoStartMFATOTPEnrollmentRequestInfo.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoStartMFATOTPEnrollmentResponseInfo.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuth.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactorSession.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPSecret.h"

NS_ASSUME_NONNULL_BEGIN
/**
 @brief Internal header extending TOTPSecret class.
 */
@interface FIRTOTPSecret ()

/**
 @brief Shared secret key/seed used for enrolling in TOTP MFA and generating OTPs.
 */
@property(nonatomic, copy, readonly, nullable) NSString *secretKey;

/**
 @brief Hashing algorithm used.
 */
@property(nonatomic, copy, readonly, nullable) NSString *hashingAlgorithm;

/**
 @brief Length of the one-time passwords to be generated.
 */
@property(nonatomic, readonly) NSInteger codeLength;

/**
 @brief The interval (in seconds) when the OTP codes should change.
 */
@property(nonatomic, readonly) NSInteger codeIntervalSeconds;

/**
 @brief The timestamp by which TOTP enrollment should be completed. This can be used by callers to
 show a countdown of when to enter OTP code by.
 */
@property(nonatomic, copy, readonly, nullable) NSDate *enrollmentCompletionDeadline;

/**
 @brief Additional session information.
 */
@property(nonatomic, copy, readonly, nullable) NSString *sessionInfo;

/**
 @fn initWithSecretKey
 @brief Initializes an instance of FIRTOTPSecret.
 @param secretKey Shared secret key/seed used for enrolling in TOTP MFA and generating OTPs.
 @param hashingAlgorithm Hashing algorithm used.
 @param codeLength Length of the one-time passwords to be generated.
 @param codeIntervalSeconds The interval (in seconds) when the OTP codes should change.
 @param enrollmentCompletionDeadline The timestamp by which TOTP enrollment should be completed.
 This can be used by callers to show a countdown of when to enter OTP code by.
 @param sessionInfo Additional session information.
 */
- (instancetype)initWithSecretKey:(NSString *)secretKey
                 hashingAlgorithm:(NSString *)hashingAlgorithm
                       codeLength:(NSInteger)codeLength
              codeIntervalSeconds:(NSInteger)codeIntervalSeconds
     enrollmentCompletionDeadline:(NSDate *)enrollmentCompletionDeadline
                      sessionInfo:(NSString *)sessionInfo;
@end

NS_ASSUME_NONNULL_END

#endif
