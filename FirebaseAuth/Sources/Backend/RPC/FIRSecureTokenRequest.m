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

#import "FirebaseAuth/Sources/Backend/RPC/FIRSecureTokenRequest.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthRequestConfiguration.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kFIRSecureTokenServiceGetTokenURLFormat
    @brief The format of the secure token service URLs. Requires string format substitution with
        the client's API Key.
 */
static NSString *const kFIRSecureTokenServiceGetTokenURLFormat = @"https://%@/v1/token?key=%@";

/** @var kFIREmulatorURLFormat
    @brief The format of the emulated secure token service URLs. Requires string format substitution
   with the emulator host, the gAPIHost, and the client's API Key.
 */
static NSString *const kFIREmulatorURLFormat = @"http://%@/%@/v1/token?key=%@";

/** @var kFIRSecureTokenServiceGrantTypeRefreshToken
    @brief The string value of the @c FIRSecureTokenRequestGrantTypeRefreshToken request type.
 */
static NSString *const kFIRSecureTokenServiceGrantTypeRefreshToken = @"refresh_token";

/** @var kGrantTypeKey
    @brief The key for the "grantType" parameter in the request.
 */
static NSString *const kGrantTypeKey = @"grantType";

/** @var kRefreshTokenKey
    @brief The key for the "refreshToken" parameter in the request.
 */
static NSString *const kRefreshTokenKey = @"refreshToken";

/** @var gAPIHost
 @brief Host for server API calls.
 */
static NSString *gAPIHost = @"securetoken.googleapis.com";

@implementation FIRSecureTokenRequest {
  /** @var _requestConfiguration
      @brief Contains configuration relevant to the request.
   */
  FIRAuthRequestConfiguration *_requestConfiguration;
}

+ (FIRSecureTokenRequest *)refreshRequestWithRefreshToken:(NSString *)refreshToken
                                     requestConfiguration:
                                         (FIRAuthRequestConfiguration *)requestConfiguration {
  return [[self alloc] initWithRefreshToken:refreshToken requestConfiguration:requestConfiguration];
}

- (nullable instancetype)initWithRefreshToken:(NSString *)refreshToken
                         requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration {
  self = [super init];
  if (self) {
    _refreshToken = [refreshToken copy];
    _APIKey = [requestConfiguration.APIKey copy];
    _requestConfiguration = requestConfiguration;
  }
  return self;
}

- (FIRAuthRequestConfiguration *)requestConfiguration {
  return _requestConfiguration;
}

- (NSURL *)requestURL {
  NSString *URLString;

  NSString *emulatorHostAndPort = _requestConfiguration.emulatorHostAndPort;
  if (emulatorHostAndPort) {
    URLString =
        [NSString stringWithFormat:kFIREmulatorURLFormat, emulatorHostAndPort, gAPIHost, _APIKey];
  } else {
    URLString =
        [NSString stringWithFormat:kFIRSecureTokenServiceGetTokenURLFormat, gAPIHost, _APIKey];
  }
  NSURL *URL = [NSURL URLWithString:URLString];
  return URL;
}

- (BOOL)containsPostBody {
  return YES;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *_Nullable *_Nullable)error {
  NSMutableDictionary *postBody = [@{
    kGrantTypeKey : kFIRSecureTokenServiceGrantTypeRefreshToken,
    kRefreshTokenKey : _refreshToken
  } mutableCopy];
  return [postBody copy];
}

#pragma mark - Internal API for development

+ (NSString *)host {
  return gAPIHost;
}

+ (void)setHost:(NSString *)host {
  gAPIHost = host;
}

@end

NS_ASSUME_NONNULL_END
