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

#import "FIRAuthCredential_Internal.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIROAuthCredential
    @brief Internal implementation of FIRAuthCredential for generic credentials.
 */
@interface FIROAuthCredential : FIRAuthCredential

/** @property IDToken
    @brief The ID Token associated with this credential.
 */
@property(nonatomic, readonly, nullable) NSString *IDToken;

/** @property accessToken
    @brief The access token associated with this credential.
 */
@property(nonatomic, readonly, nullable) NSString *accessToken;

/** @fn initWithProviderId:IDToken:accessToken:
    @brief Designated initializer.
    @param providerID The provider ID associated with the credential being created.
    @param IDToken  The ID Token associated with the credential being created.
    @param accessToken The access token associated with the credential being created.
 */
- (nullable instancetype)initWithProviderID:(NSString *)providerID
                                    IDToken:(nullable NSString*)IDToken
                                accessToken:(nullable NSString *)accessToken;

@end

NS_ASSUME_NONNULL_END
