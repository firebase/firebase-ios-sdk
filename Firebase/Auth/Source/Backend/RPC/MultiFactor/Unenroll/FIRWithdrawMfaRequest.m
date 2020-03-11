/*
 * Copyright 2019 Google
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

#import "FIRWithdrawMfaRequest.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kWithdrawMfaEndPoint = @"accounts/mfaEnrollment:withdraw";

@implementation FIRWithdrawMfaRequest

- (nullable instancetype)initWithIDToken:(NSString *)idToken
                         mfaEnrollmentID:(NSString *)mfaEnrollmentID
                    requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kWithdrawMfaEndPoint
            requestConfiguration:requestConfiguration
             useIdentityPlatform:YES
                      useStaging:NO];
  if (self) {
    _idToken = idToken;
    _mfaEnrollmentID = mfaEnrollmentID;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing  _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  if (_idToken) {
    postBody[@"idToken"] = _idToken;
  }
  if (_mfaEnrollmentID) {
    postBody[@"mfaEnrollmentId"] = _mfaEnrollmentID;
  }
  return [postBody copy];
}

@end

NS_ASSUME_NONNULL_END
