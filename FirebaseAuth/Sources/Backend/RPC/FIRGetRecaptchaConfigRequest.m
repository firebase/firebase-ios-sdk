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

#import "FirebaseAuth/Sources/Backend/RPC/FIRGetRecaptchaConfigRequest.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const kRecaptchaVersion = @"RECAPTCHA_ENTERPRISE";

/** @var kGetRecaptchaConfigEndpoint
    @brief The "getRecaptchaConfig" endpoint.
 */
static NSString *const kGetRecaptchaConfigEndpoint = @"recaptchaConfig";

/** @var kClientType
    @brief The key for the "clientType" value in the request.
 */
static NSString *const kClientTypeKey = @"clientType";

/** @var kVersionKey
    @brief The key for the "version" value in the request.
 */
static NSString *const kVersionKey = @"version";

/** @var kTenantIDKey
    @brief The key for the tenant id value in the request.
 */
static NSString *const kTenantIDKey = @"tenantId";

@implementation FIRGetRecaptchaConfigRequest

- (nullable instancetype)initWithRequestConfiguration:
    (nonnull FIRAuthRequestConfiguration *)requestConfiguration {
  requestConfiguration.HTTPMethod = @"GET";
  self = [super initWithEndpoint:kGetRecaptchaConfigEndpoint
            requestConfiguration:requestConfiguration];
  self.useIdentityPlatform = YES;
  return self;
}

- (BOOL)containsPostBody {
  return NO;
}

- (nullable NSString *)queryParams {
  NSMutableString *queryParams = [[NSMutableString alloc] init];
  [queryParams appendFormat:@"&%@=%@&%@=%@", kClientTypeKey, self.clientType, kVersionKey,
                            kRecaptchaVersion];
  if (self.tenantID) {
    [queryParams appendFormat:@"&%@=%@", kTenantIDKey, self.tenantID];
  }
  return queryParams;
}

- (nullable id)unencodedHTTPRequestBodyWithError:(NSError *_Nullable *_Nullable)error {
  return nil;
}

@end

NS_ASSUME_NONNULL_END
