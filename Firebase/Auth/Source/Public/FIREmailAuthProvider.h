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

#import "FIRAuthSwiftNameSupport.h"

@class FIRAuthCredential;

NS_ASSUME_NONNULL_BEGIN

/**
    @brief A string constant identifying the email & password identity provider.
 */
extern NSString *const FIREmailAuthProviderID FIR_SWIFT_NAME(EmailAuthProviderID);

/**
    @brief please use @c FIREmailAuthProviderID instead.
 */
extern NSString *const FIREmailPasswordAuthProviderID __attribute__((deprecated));

/** @class FIREmailAuthProvider
    @brief A concrete implementation of @c FIRAuthProvider for Email & Password Sign In.
 */
FIR_SWIFT_NAME(EmailAuthProvider)
@interface FIREmailAuthProvider : NSObject

/** @typedef FIREmailPasswordAuthProvider
    @brief Please use @c FIREmailAuthProvider instead.
 */
typedef FIREmailAuthProvider FIREmailPasswordAuthProvider __attribute__((deprecated));


/** @fn credentialWithEmail:password:
    @brief Creates an @c FIRAuthCredential for an email & password sign in.

    @param email The user's email address.
    @param password The user's password.
    @return A FIRAuthCredential containing the email & password credential.
 */
+ (FIRAuthCredential *)credentialWithEmail:(NSString *)email password:(NSString *)password;

/** @fn init
    @brief This class is not meant to be initialized.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
