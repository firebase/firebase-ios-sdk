/*
 * Copyright 2019 Google
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
#import <AuthenticationServices/AuthenticationServices.h>
#import "FIRAuthCredential_Internal.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIRAppleAuthCredential
 @brief Internal implementation of FIRAuthCredential for Apple credentials.
 */
@interface FIRAppleAuthCredential : FIRAuthCredential <NSSecureCoding>

@property(nonatomic, readonly) NSString* user;

@property(nonatomic, readonly) NSString* identityToken;

@property(nonatomic, readonly) NSString* password;

/** @fn initWithAuthorizationCredential:
 @brief Designated initializer.
 @param appleIDCredential The Apple ID Credential.
 */
- (nullable instancetype)initWithAuthorizationCredential:(ASAuthorizationAppleIDCredential *)appleIDCredential NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(13.0));

/** @fn initWithPasswordCredential:
 @brief Designated initializer.
 @param passwordCredential The Apple ID Credential.
 */
- (nullable instancetype)initWithPasswordCredential:(ASPasswordCredential *)passwordCredential NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(12.0));

- (nullable instancetype)initWithUser:(NSString *)user identityToken:(NSData *)identityToken NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
