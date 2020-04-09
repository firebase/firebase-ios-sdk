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

#import "FIRFinalizeMFAEnrollmentRequest.h"

static NSString *const kFinalizeMFAEnrollmentEndPoint = @"accounts/mfaEnrollment:finalize";

@implementation FIRFinalizeMFAEnrollmentRequest

- (nullable instancetype)initWithIDToken:(NSString *)IDToken
                             MFAProvider:(NSString *)MFAProvider
                             displayName:(NSString *)displayName
                        verificationInfo:(FIRAuthProtoFinalizeMFAPhoneRequestInfo *)verificationInfo
                    requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kFinalizeMFAEnrollmentEndPoint
            requestConfiguration:requestConfiguration
             useIdentityPlatform:YES
                      useStaging:NO];
  if (self) {
    _IDToken = IDToken;
    _MFAProvider = MFAProvider;
    _displayName = displayName;
    _verificationInfo = verificationInfo;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  if (_IDToken) {
    postBody[@"idToken"] = _IDToken;
  }
  if (_MFAProvider) {
    postBody[@"mfaProvider"] = _MFAProvider;
  }
  if (_displayName) {
    postBody[@"displayName"] = _displayName;
  }
  if (_verificationInfo) {
    if ([_verificationInfo isKindOfClass:[FIRAuthProtoFinalizeMFAPhoneRequestInfo class]]) {
      postBody[@"phoneVerificationInfo"] = [_verificationInfo dictionary];
    }
  }
  return [postBody copy];
}

@end
