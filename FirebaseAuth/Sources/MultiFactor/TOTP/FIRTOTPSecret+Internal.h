/*
 * Copyright 2023 Google
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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPSecret.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactorSession.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoStartMFATOTPEnrollmentResponseInfo.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoStartMFATOTPEnrollmentRequestInfo.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuth.h"


NS_ASSUME_NONNULL_BEGIN

@interface FIRTOTPSecret ()

@property(nonatomic, copy, readonly, nullable) NSString *secretKey;
@property(nonatomic, copy, readonly, nullable) NSString *hashingAlgorithm;
@property(nonatomic, readonly) NSInteger codeLength;
@property(nonatomic, readonly) NSInteger codeIntervalSeconds;
@property(nonatomic, copy, readonly, nullable) NSDate *enrollmentCompletionDeadline;
@property(nonatomic, copy, readonly, nullable) NSString *sessionInfo;

- (instancetype)initWithSecretKey:(NSString *)secretKey
									hashingAlgorithm:(NSString *)hashingAlgorithm
												codeLength:(NSInteger)codeLength
								codeIntervalSeconds:(NSInteger)codeIntervalSeconds
		 enrollmentCompletionDeadline:(NSDate *)enrollmentCompletionDeadline
											sessionInfo:(NSString *)sessionInfo;

@end

NS_ASSUME_NONNULL_END

#endif
