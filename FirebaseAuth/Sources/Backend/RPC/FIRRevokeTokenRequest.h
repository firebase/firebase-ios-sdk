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

#import "FirebaseAuth/Sources/Backend/FIRAuthRPCRequest.h"
#import "FirebaseAuth/Sources/Backend/FIRIdentityToolkitRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRRevokeTokenRequest : FIRIdentityToolkitRequest <FIRAuthRPCRequest>

/** @property appToken
    @brief The APNS device token.
 */
@property(nonatomic, copy, nullable) NSString *token;

/** @property accessToken
    @brief The STS Access Token of the authenticated user.
 */
@property(nonatomic, copy, nullable) NSString *idToken;

/** @fn initWithEndpoint:requestConfiguration:
    @brief Please use initWithToken:requestConfiguration: instead.
 */
- (nullable instancetype)initWithEndpoint:(NSString *)endpoint
                     requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration
    NS_UNAVAILABLE;

/** @fn initWithAppToken:isSandbox:requestConfiguration:
    @brief Designated initializer.
    @param token The token to be revoked.
    @param idToken The id token associated with the current user.
    @param requestConfiguration An object containing configurations to be added to the request.
 */
- (nullable instancetype)initWithToken:(NSString *)token
                               idToken:(NSString *)idToken
                  requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration
    NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
