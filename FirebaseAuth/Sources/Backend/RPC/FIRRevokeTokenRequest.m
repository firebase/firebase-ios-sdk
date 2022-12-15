/*
 * Copyright 2022 Google LLC
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
static NSString *const kRevokeTokenEndpoint =
    @"revokeToken";  // TODO: Double check the endpoint when backend is ready

/** @var kAppTokenKey
    @brief The key for the appToken request paramenter.
 */
static NSString *const kTokenKey = @"token";

/** @var kIDTokenKey
    @brief The key for the "idToken" value in the request. This is actually the STS Access Token,
        despite it's confusing (backwards compatiable) parameter name.
 */
static NSString *const kIDTokenKey = @"idToken";

@implementation FIRRevokeTokenRequest

- (nullable instancetype)initWitToken:(NSString *)token
                              idToken:(NSString *)idToken
                 requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super initWithEndpoint:kRevokeTokenEndpoint requestConfiguration:requestConfiguration];
  if (self) {
    _token = token;
    _idToken = idToken;
  }
  return self;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *__autoreleasing _Nullable *)error {
  NSMutableDictionary *postBody = [NSMutableDictionary dictionary];
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
