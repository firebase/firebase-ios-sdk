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

#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorAssertion+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/TOTP/FIRTOTPMultiFactorAssertion+Internal.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPMultiFactorAssertion.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPSecret.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const _Nonnull FIRTOTPMultiFactorID;

@implementation FIRTOTPMultiFactorAssertion

- (instancetype)init {
  self = [super init];
  if (self) {
    _factorID = FIRTOTPMultiFactorID;
  }
  return self;
}

- (instancetype)initWithSecret:(FIRTOTPSecret *)secret oneTimePassword:(NSString *)oneTimePassword {
  self = [super init];
  if (self) {
    _factorID = FIRTOTPMultiFactorID;
    _secret = secret;
    _oneTimePassword = oneTimePassword;
  }
  return self;
}

- (instancetype)initWithEnrollmentID:(NSString *)enrollmentID
                     oneTimePassword:(NSString *)oneTimePassword {
  self = [super init];
  if (self) {
    _factorID = FIRTOTPMultiFactorID;
    _enrollmentID = enrollmentID;
    _oneTimePassword = oneTimePassword;
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
#endif
