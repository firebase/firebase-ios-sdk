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

#import "FIRVerifyAssertionRequest.h"

/** @var kVerifyAssertionEndpoint
    @brief The "verifyAssertion" endpoint.
 */
static NSString *const kVerifyAssertionEndpoint = @"verifyAssertion";

/** @var kProviderIDKey
    @brief The key for the "providerId" value in the request.
 */
static NSString *const kProviderIDKey = @"providerId";

/** @var kProviderIDTokenKey
    @brief The key for the "id_token" value in the request.
 */
static NSString *const kProviderIDTokenKey = @"id_token";

/** @var kProviderAccessTokenKey
    @brief The key for the "access_token" value in the request.
 */
static NSString *const kProviderAccessTokenKey = @"access_token";

/** @var kProviderOAuthTokenSecretKey
    @brief The key for the "oauth_token_secret" value in the request.
 */
static NSString *const kProviderOAuthTokenSecretKey = @"oauth_token_secret";

/** @var kIdentifierKey
    @brief The key for the "identifier" value in the request.
 */
static NSString *const kIdentifierKey = @"identifier";

/** @var kRequestURIKey
    @brief The key for the "requestUri" value in the request.
 */
static NSString *const kRequestURIKey = @"requestUri";

/** @var kPostBodyKey
    @brief The key for the "postBody" value in the request.
 */
static NSString *const kPostBodyKey = @"postBody";

/** @var kPendingIDTokenKey
    @brief The key for the "pendingIdToken" value in the request.
 */
static NSString *const kPendingIDTokenKey = @"pendingIdToken";

/** @var kAutoCreateKey
    @brief The key for the "autoCreate" value in the request.
 */
static NSString *const kAutoCreateKey = @"autoCreate";

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
static NSString *const kIDTokenKey = @"idToken";

/** @var kReturnSecureTokenKey
    @brief The key for the "returnSecureToken" value in the request.
 */
static NSString *const kReturnSecureTokenKey = @"returnSecureToken";

@implementation FIRVerifyAssertionRequest

- (nullable instancetype)initWithProviderID:(NSString *)providerID
                       requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kVerifyAssertionEndpoint
            requestConfiguration:requestConfiguration];
  if (self) {
    _providerID = providerID;
    _returnSecureToken = YES;
    _autoCreate = YES;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *_Nullable *_Nullable)error {
  NSURLComponents *components = [[NSURLComponents alloc] init];
  NSMutableArray<NSURLQueryItem *> *queryItems = [@[[NSURLQueryItem queryItemWithName:kProviderIDKey
                                                                                value:_providerID]]
                                                  mutableCopy];

  if (_providerIDToken) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:kProviderIDTokenKey
                                                      value:_providerIDToken]];
  }

  if (_providerAccessToken) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:kProviderAccessTokenKey
                                                      value:_providerAccessToken]];
  }

  if (!_providerIDToken && !_providerAccessToken) {
    [NSException raise:NSInvalidArgumentException
                format:@"Either IDToken or accessToken must be supplied."];
  }

  if (_providerOAuthTokenSecret) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:kProviderOAuthTokenSecretKey
                                                      value:_providerOAuthTokenSecret]];
  }

  if (_inputEmail) {
    [queryItems addObject:[NSURLQueryItem queryItemWithName:kIdentifierKey
                                                      value:_inputEmail]];
  }
  [components setQueryItems:queryItems];
  NSMutableDictionary *body = [@{
      kRequestURIKey : @"http://localhost", // Unused by server, but required
      kPostBodyKey : [components query]
      } mutableCopy];

  if (_pendingIDToken) {
    body[kPendingIDTokenKey] = _pendingIDToken;
  }
  if (_accessToken) {
    body[kIDTokenKey] = _accessToken;
  }
  if (_returnSecureToken) {
    body[kReturnSecureTokenKey] = @YES;
  }

  body[kAutoCreateKey] = @(_autoCreate);

  return body;
}

@end
