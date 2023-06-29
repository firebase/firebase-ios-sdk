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
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoFinalizeMFATOTPSignInRequestInfo.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAuthProtoFinalizeMFATOTPSignInRequestInfo

- (instancetype)initWithMfaEnrollmentID:(nonnull NSString *)mfaEnrollmentID
                       verificationCode:(NSString *)verificationCode {
  self = [super init];
  if (self) {
    _mfaEnrollmentID = mfaEnrollmentID;
    _verificationCode = verificationCode;
  }
  return self;
}

- (NSDictionary *)dictionary {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  if (_verificationCode) {
    dict[@"verificationCode"] = _verificationCode;
  }
  return [dict copy];
}

@end

NS_ASSUME_NONNULL_END
