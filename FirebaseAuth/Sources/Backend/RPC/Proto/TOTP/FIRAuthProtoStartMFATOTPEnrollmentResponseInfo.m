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

#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoStartMFATOTPEnrollmentResponseInfo.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAuthProtoStartMFATOTPEnrollmentResponseInfo

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
  self = [super init];
  if (self) {
    _sharedSecretKey = [dictionary[@"sharedSecretKey"] copy];
    _verificationCodeLength = [dictionary[@"verificationCodeLength"] integerValue];
    _hashingAlgorithm = [dictionary[@"hashingAlgorithm"] copy];
    _periodSec = [dictionary[@"periodSec"] integerValue];
    _sessionInfo = [dictionary[@"sessionInfo"] copy];
    _finalizeEnrollmentTime =
        [dictionary[@"finalizeEnrollmentTime"] isKindOfClass:[NSString class]]
            ? [NSDate
                  dateWithTimeIntervalSinceNow:[dictionary[@"finalizeEnrollmentTime"] doubleValue]]
            : nil;
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
