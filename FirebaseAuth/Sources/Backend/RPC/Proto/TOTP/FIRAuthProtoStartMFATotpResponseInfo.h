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

@interface FIRAuthProtoStartMFATotpResponseInfo : NSObject <FIRAuthProto>

/**
 @property sharedSecretKey
 @brief A base 32 encoded string that represents the shared TOTP secret.
 */
@property(nonatomic, copy, readonly, nullable) NSString *sharedSecretKey;

/**
 @property verificationCodeLength
 @brief The length of the verification code that needs to be generated.
 */
@property(nonatomic, readonly) NSInteger verificationCodeLength;

/**
 @property hashingAlgorithm
 @brief hashing algorithm used to generate the verification code.
 */
@property(nonatomic, copy, readonly, nullable) NSString *hashingAlgorithm;

/**
 @property periodSec
 @brief Duration in seconds at which the verification code will change.
 */
@property(nonatomic, readonly) NSInteger periodSec;

/**
 @property sessionInfo
 @brief An encoded string that represents the enrollment session.
 */
@property(nonatomic, copy, readonly, nullable) NSString *sessionInfo;

/**
 @property finalizeEnrollmentTime
 @briefThe time by which the enrollment must finish.
 */
@property(nonatomic, strong, readonly, nullable) NSDate *finalizeEnrollmentTime;

@end

NS_ASSUME_NONNULL_END
