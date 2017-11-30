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

@class FIRAuthCredential;

NS_ASSUME_NONNULL_BEGIN

/** @class FIROAuthProvider
    @brief A concrete implementation of @c FIRAuthProvider for generic OAuth Providers.
 */
NS_SWIFT_NAME(OAuthProvider)
@interface FIROAuthProvider : NSObject

/** @fn credentialWithProviderID:IDToken:accessToken:
    @brief Creates an @c FIRAuthCredential for that OAuth 2 provider identified by providerID, ID
        token and access token.

    @param providerID The provider ID associated with the Auth credential being created.
    @param IDToken The IDToken associated with the Auth credential being created.
    @param accessToken The accessstoken associated with the Auth credential be created, if
        available.
    @return A FIRAuthCredential for the specified provider ID, ID token and access token.
 */
+ (FIRAuthCredential *)credentialWithProviderID:(NSString *)providerID
                                        IDToken:(NSString *)IDToken
                                    accessToken:(nullable NSString *)accessToken;


/** @fn credentialWithProviderID:accessToken:
    @brief Creates an @c FIRAuthCredential for that OAuth 2 provider identified by providerID using
      an ID token.

    @param providerID The provider ID associated with the Auth credential being created.
    @param accessToken The accessstoken associated with the Auth credential be created
    @return A FIRAuthCredential.
 */
+ (FIRAuthCredential *)credentialWithProviderID:(NSString *)providerID
                                    accessToken:(NSString *)accessToken;

/** @fn init
    @brief This class is not meant to be initialized.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
