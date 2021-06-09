/*
 * Copyright 2021 Google
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

#import "FirebaseAuth/Sources/Backend/RPC/Proto/Otp/FIRAuthProtoFinalizeMFAOtpRequestInfo.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAuthProtoFinalizeMFAOtpRequestInfo

- (instancetype)initWithMFAEnrollmentID:(NSString *)MFAEnrollmentID
                   verificationCode:(NSString *)verificationCode {
  self = [super init];
  if (self) {
    _MFAEnrollmentID = MFAEnrollmentID;
    _code = verificationCode;
  }
  return self;
}

- (NSDictionary *)dictionary {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  if (_MFAEnrollmentID) {
    dict[@"mfaEnrollmentId"] = _MFAEnrollmentID;
  }
  if (_code) {
    dict[@"code"] = _code;
  }
  return [dict copy];
}

@end

NS_ASSUME_NONNULL_END
