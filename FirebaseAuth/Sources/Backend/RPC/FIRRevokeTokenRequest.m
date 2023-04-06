/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAuth/Sources/Backend/RPC/FIRRevokeTokenRequest.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kRevokeTokenEndpoint
    @brief The endpoint for the revokeToken request.
 */
static NSString *const kRevokeTokenEndpoint = @"accounts:revokeToken";

/** @var kProviderIDKey
    @brief The key for the provider that issued the token to revoke.
 */
static NSString *const kProviderIDKey = @"providerId";

/** @var kTokenTypeKey
    @brief The key for the type of the token to revoke.
 */
static NSString *const kTokenTypeKey = @"tokenType";

/** @var kTokenKey
    @brief The key for the token to be revoked.
 */
static NSString *const kTokenKey = @"token";

/** @var kIDTokenKey
    @brief The key for the ID Token associated with this credential.
 */
static NSString *const kIDTokenKey = @"idToken";

typedef NS_ENUM(NSInteger, FIRTokenType) {
  /** Indicates that the token type is unspecified.
   */
  FIRTokenTypeUnspecified = 0,

  /** Indicates that the token type is refresh token.
   */
  FIRTokenTypeRefreshToken = 1,

  /** Indicates that the token type is access token.
   */
  FIRTokenTypeAccessToken = 2,

  /** Indicates that the token type is authorization code.
   */
  FIRTokenTypeAuthorizationCode = 3,
};

@implementation FIRRevokeTokenRequest

- (nullable instancetype)initWithToken:(NSString *)token
                               idToken:(NSString *)idToken
                  requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kRevokeTokenEndpoint
            requestConfiguration:requestConfiguration
             useIdentityPlatform:YES
                      useStaging:NO];
  if (self) {
    // Apple and authorization code are the only provider and token type we support for now.
    // Generalize this initializer to accept other providers and token types once supported.
    _providerID = @"apple.com";
    _tokenType = FIRTokenTypeAuthorizationCode;
    _token = token;
    _idToken = idToken;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
  if (_providerID) {
    postBody[kProviderIDKey] = _providerID;
  }
  if (_tokenType) {
    postBody[kTokenTypeKey] = [NSNumber numberWithInteger:_tokenType].stringValue;
  }
  if (_token) {
    postBody[kTokenKey] = _token;
  }
  if (_idToken) {
    postBody[kIDTokenKey] = _idToken;
  }
  return [postBody copy];
}

@end

NS_ASSUME_NONNULL_END
