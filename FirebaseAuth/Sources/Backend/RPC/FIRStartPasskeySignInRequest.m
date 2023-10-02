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

#import "FirebaseAuth/Sources/Backend/RPC/FIRStartPasskeySignInRequest.h"

NS_ASSUME_NONNULL_BEGIN

/**
 @var kStartPasskeySignInEndPoint
 @brief GCIP endpoint for startPasskeySignIn rpc
 */
static NSString *const kStartPasskeySignInEndPoint = @"accounts/passkeySignIn:start";

/**
 @var kTenantIDKey
 @brief The key for the tenant id value in the request.
 */
static NSString *const kTenantIDKey = @"tenantId";

@implementation FIRStartPasskeySignInRequest

- (nullable instancetype)initWithRequestConfiguration:
    (FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kStartPasskeySignInEndPoint
            requestConfiguration:requestConfiguration];

  if (self) {
    self.useIdentityPlatform = YES;
  }

  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  if (self.tenantID) {
    postBody[kTenantIDKey] = self.tenantID;
  }
  return [postBody copy];
}

@end

NS_ASSUME_NONNULL_END
