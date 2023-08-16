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

#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/Enroll/FIRStartMFAEnrollmentRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/Phone/FIRAuthProtoStartMFAPhoneRequestInfo.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoStartMFATOTPEnrollmentRequestInfo.h"

static NSString *const kStartMFAEnrollmentEndPoint = @"accounts/mfaEnrollment:start";

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
static NSString *const kTenantIDKey = @"tenantId";

@implementation FIRStartMFAEnrollmentRequest

- (nullable instancetype)initWithIDToken:(NSString *)IDToken
                          enrollmentInfo:(FIRAuthProtoStartMFAPhoneRequestInfo *)phoneEnrollmentInfo
                    requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kStartMFAEnrollmentEndPoint
            requestConfiguration:requestConfiguration];
  self.useIdentityPlatform = YES;
  if (self) {
    _IDToken = IDToken;
    _phoneEnrollmentInfo = phoneEnrollmentInfo;
  }
  return self;
}

- (nullable instancetype)initWithIDToken:(NSString *)IDToken
                      TOTPEnrollmentInfo:
                          (FIRAuthProtoStartMFATOTPEnrollmentRequestInfo *)TOTPEnrollmentInfo
                    requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kStartMFAEnrollmentEndPoint
            requestConfiguration:requestConfiguration];
  self.useIdentityPlatform = YES;
  if (self) {
    _IDToken = IDToken;
    _TOTPEnrollmentInfo = TOTPEnrollmentInfo;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  if (_IDToken) {
    postBody[@"idToken"] = _IDToken;
  }
  if (_phoneEnrollmentInfo) {
    postBody[@"phoneEnrollmentInfo"] = [_phoneEnrollmentInfo dictionary];
  } else if (_TOTPEnrollmentInfo) {
    postBody[@"totpEnrollmentInfo"] = [_TOTPEnrollmentInfo dictionary];
  }
  if (self.tenantID) {
    postBody[kTenantIDKey] = self.tenantID;
  }
  return [postBody copy];
}

@end
