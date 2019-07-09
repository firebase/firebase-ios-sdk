/*
 * Copyright 2019 Google
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

#import "FIRInstallationsHTTPError.h"
#import "FIRInstallationsErrorUtil.h"

@implementation FIRInstallationsHTTPError

- (instancetype)initWithHTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                                data:(nullable NSData *)data {
  NSDictionary *userInfo = [FIRInstallationsHTTPError userInfoWithHTTPResponse:HTTPResponse
                                                                          data:data];
  self = [super
      initWithDomain:kFirebaseInstallationsErrorDomain
                code:[FIRInstallationsHTTPError errorCodeWithHTTPCode:HTTPResponse.statusCode]
            userInfo:userInfo];
  if (self) {
    _HTTPResponse = HTTPResponse;
    _data = data;
  }
  return self;
}

+ (FIRInstallationsErrorCode)errorCodeWithHTTPCode:(NSInteger)HTTPCode {
  return FIRInstallationsErrorCodeUnknown;
}

+ (NSDictionary *)userInfoWithHTTPResponse:(NSHTTPURLResponse *)URLResponse
                                      data:(nullable NSData *)data {
  return @{};
}

@end
