/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAuth/Sources/Backend/RPC/FIRStartPasskeyEnrollmentRequest.h"

NS_ASSUME_NONNULL_BEGIN

/**
 @var kStartPasskeyEnrollmentEndPoint
 @brief GCIP endpoint for startPasskeyEnrollment rpc
 */
static NSString *const kStartPasskeyEnrollmentEndPoint = @"accounts/passkeyEnrollment:start";

/**
 @var kTenantIDKey
 @brief The key for the tenant id value in the request.
 */
static NSString *const kTenantIDKey = @"tenantId";

/**
 @var kIDToken
 @brief The key for idToken value in the request.
 */
static NSString *const kIDToken = @"idToken";

@implementation FIRStartPasskeyEnrollmentRequest

- (nullable instancetype)initWithIDToken:(NSString *)IDToken
                    requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kStartPasskeyEnrollmentEndPoint
            requestConfiguration:requestConfiguration
             useIdentityPlatform:YES
                      useStaging:NO];
  if (self) {
    _IDToken = IDToken;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  if (_IDToken) {
    postBody[kIDToken] = _IDToken;
  }
  if (self.tenantID) {
    postBody[kTenantIDKey] = self.tenantID;
  }
  return [postBody copy];
}

@end

NS_ASSUME_NONNULL_END
