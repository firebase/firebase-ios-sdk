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

#import "FIRFinalizeMFASignInRequest.h"

static NSString *const kFinalizeMFASignInEndPoint = @"accounts/mfaSignIn:finalize";

@implementation FIRFinalizeMFASignInRequest

- (nullable instancetype)initWithMFAProvider:(NSString *)MFAProvider
                        MFAPendingCredential:(NSString *)MFAPendingCredential
                            verificationInfo:(FIRAuthProtoFinalizeMFAPhoneRequestInfo *)verificationInfo
                        requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kFinalizeMFASignInEndPoint
            requestConfiguration:requestConfiguration
             useIdentityPlatform:YES
                      useStaging:NO];
  if (self) {
    _MFAProvider = MFAProvider;
    _MFAPendingCredential = MFAPendingCredential;
    _verificationInfo = verificationInfo;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing  _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  if (_MFAProvider) {
    postBody[@"mfaProvider"] = _MFAProvider;
  }
  if (_MFAPendingCredential) {
    postBody[@"mfaPendingCredential"] = _MFAPendingCredential;
  }
  if (_verificationInfo) {
    if ([_verificationInfo isKindOfClass:[FIRAuthProtoFinalizeMFAPhoneRequestInfo class]]) {
      postBody[@"phoneVerificationInfo"] = [_verificationInfo dictionary];
    }
  }
  return [postBody copy];
}

@end
