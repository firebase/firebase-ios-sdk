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

#import <Foundation/Foundation.h>

#import "FirebaseAuth/Sources/Backend/FIRAuthRPCRequest.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIRSecureTokenRequest
    @brief Represents the parameters for the token endpoint.
 */
@interface FIRSecureTokenRequest : NSObject <FIRAuthRPCRequest>

/** @property refreshToken
    @brief The client's refresh token.
 */
@property(nonatomic, copy, readonly, nullable) NSString *refreshToken;

/** @property APIKey
    @brief The client's API Key.
 */
@property(nonatomic, copy, readonly) NSString *APIKey;

/** @fn refreshRequestWithRefreshToken:requestConfiguration:
    @brief Creates a refresh request with the given refresh token.
    @param refreshToken The refresh token.
    @param requestConfiguration An object containing configurations to be added to the request.
    @return A refresh request.
 */
+ (FIRSecureTokenRequest *)refreshRequestWithRefreshToken:(NSString *)refreshToken
                                     requestConfiguration:
                                         (FIRAuthRequestConfiguration *)requestConfiguration;

/** @fn init
    @brief Please use initWithRefreshToken:requestConfiguration:
 */
- (instancetype)init NS_UNAVAILABLE;

/** @fn initWithRefreshToken:requestConfiguration:
    @brief Designated initializer.
    @param refreshToken The client's refresh token (for refresh requests.)
    @param requestConfiguration An object containing configurations to be added to the request.
 */
- (nullable instancetype)initWithRefreshToken:(NSString *)refreshToken
                         requestConfiguration:(FIRAuthRequestConfiguration *)requestConfiguration
    NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
