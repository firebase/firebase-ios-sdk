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

#import <Foundation/Foundation.h>

#import "FirebaseAuth/Sources/Backend/FIRAuthRPCRequest.h"
#import "FirebaseAuth/Sources/Backend/FIRIdentityToolkitRequest.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIRGetRecaptchaConfigRequest
    @brief Represents the parameters for the getRecaptchaConfig endpoint.
 */
@interface FIRGetRecaptchaConfigRequest : FIRIdentityToolkitRequest <FIRAuthRPCRequest>

/** @property clientType
    @brief The client type should always be "ios".
 */
@property(nonatomic, copy, nullable) NSString *clientType;

/** @property version
    @brief The version of the reCAPTCHA service should be always be "enterprise".
 */
@property(nonatomic, copy, nullable) NSString *version;

/** @fn initWithEndpoint:requestConfiguration:
    @brief Please use initWithClientType:version:requestConfiguration:
 */
- (nullable instancetype)initWithEndpoint:(NSString *)endpoint
                     requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration
    NS_UNAVAILABLE;

/** @fn initWithEmail:password:requestConfiguration:
    @brief Designated initializer.
    @param clientType The client type.
    @param version The version of the reCAPTCHA service.
    @param requestConfiguration The config.
 */
- (nullable instancetype)initWithClientType:(NSString *)clientType
                                    version:(NSString *)version
                       requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration
    NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
