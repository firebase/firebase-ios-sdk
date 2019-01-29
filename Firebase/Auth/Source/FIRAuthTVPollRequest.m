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

#import "FIRAuthTVPollRequest.h"

#import "FIRAuthTVCode.h"

@implementation FIRAuthTVPollRequest

- (instancetype)initWithClientID:(NSString *)clientID
                    clientSecret:(NSString *)clientSecret
                      deviceCode:(NSString *)deviceCode {
  if (self = [super init]) {
    self.clientID = clientID;
    self.clientSecret = clientSecret;
    self.deviceCode = deviceCode;
  }

  return self;
}

- (NSDictionary <NSString *, NSString *>*)generatedParameters {
  // TODO: Make these constant.
  return @{
           @"client_id": self.clientID,
           @"client_secret": self.clientSecret,
           @"code": self.deviceCode,
           @"grant_type": @"http://oauth.net/grant_type/device/1.0"
           };
}

@end
