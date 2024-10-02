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

NS_ASSUME_NONNULL_BEGIN

/**
    @brief The Firebase Auth error domain.
 */
extern NSString *const FIRAuthErrorDomain NS_SWIFT_NAME(AuthErrorDomain);

/**
    @brief The name of the key for the error short string of an error code.
 */
extern NSString *const FIRAuthErrorUserInfoNameKey NS_SWIFT_NAME(AuthErrorUserInfoNameKey);

/**
    @brief Errors with one of the following three codes:
          - `AuthErrorCodeAccountExistsWithDifferentCredential`
          - `AuthErrorCodeCredentialAlreadyInUse`
          - `AuthErrorCodeEmailAlreadyInUse`
        may contain an `NSError.userInfo` dictionary object which contains this key. The value
        associated with this key is an NSString of the email address of the account that already
        exists.
 */
extern NSString *const FIRAuthErrorUserInfoEmailKey NS_SWIFT_NAME(AuthErrorUserInfoEmailKey);

/**
    @brief The key used to read the updated Auth credential from the userInfo dictionary of the
        NSError object returned. This is the updated auth credential the developer should use for
        recovery if applicable.
 */
// clang-format off
// clang-format12 will merge lines and exceed 100 character limit.
extern NSString *const FIRAuthErrorUserInfoUpdatedCredentialKey
    NS_SWIFT_NAME(AuthErrorUserInfoUpdatedCredentialKey);

/**
    @brief The key used to read the MFA resolver from the userInfo dictionary of the NSError object
        returned when 2FA is required for sign-incompletion.
 */
extern NSString *const FIRAuthErrorUserInfoMultiFactorResolverKey
    NS_SWIFT_NAME(AuthErrorUserInfoMultiFactorResolverKey);
// clang-format on

NS_ASSUME_NONNULL_END
