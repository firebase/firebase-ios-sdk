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

#import "FIRAuthTVCode.h"

NSString * const kFIRAuthTVDeviceCodeKey = @"device_code";
NSString * const kFIRAuthTVUserCodeKey = @"user_code";
NSString * const kFIRAuthTVVerificationURLKey = @"verification_url";
NSString * const kFIRAuthTVExpiresInKey = @"expires_in";
NSString * const kFIRAuthTVPollingIntervalKey = @"interval";

@implementation FIRAuthTVCode

- (instancetype) initWithDictionary:(NSDictionary <NSString *, NSString *> *)dictionary {
  if (self = [self init]) {
    self.deviceCode = dictionary[kFIRAuthTVDeviceCodeKey];
    self.userCode = dictionary[kFIRAuthTVUserCodeKey];
    self.verificationURL = [NSURL URLWithString:dictionary[kFIRAuthTVVerificationURLKey]];
    self.secondsToExpire = [dictionary[kFIRAuthTVExpiresInKey] integerValue];
    self.pollingInterval = [dictionary[kFIRAuthTVPollingIntervalKey] integerValue];
  }

  return self;
}

@end
