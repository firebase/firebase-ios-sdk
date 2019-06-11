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

@class FIRAuthCredential;

NS_ASSUME_NONNULL_BEGIN

/**
 @brief A string constant identifying the Apple identity provider.
 */
extern NSString *const FIRAppleAuthProviderID NS_SWIFT_NAME(AppleAuthProviderID);

/**
 @brief A string constant identifying the Apple sign-in method.
 */
extern NSString *const _Nonnull FIRAppleAuthSignInMethod NS_SWIFT_NAME(AppleAuthSignInMethod);


/** @class FIRAppleAuthProvider
 @brief Utility class for constructing Apple credentials.
 */
NS_SWIFT_NAME(AppleAuthProvider)
@interface FIRAppleAuthProvider : NSObject

/** @fn credentialWithAppleIDCredential:
 @brief Creates an `FIRAuthCredential` for a Apple sign in.
 @param credential The Apple OAuth access token.
 @return A FIRAuthCredential containing the Apple credential.
 */
+ (FIRAuthCredential *)credentialWithAppleIDCredential:(ASAuthorizationAppleIDCredential *)credential API_AVAILABLE(ios(13.0));

/** @fn credentialWithPasswordCredential:
 @brief Creates an `FIRAuthCredential` for a Apple sign in with password.
 @param credential The Apple OAuth access token.
 @return A FIRAuthCredential containing the Apple credential.
 */
+ (FIRAuthCredential *)credentialWithPasswordCredential: (ASPasswordCredential *)credential API_AVAILABLE(ios(12.0));

/** @fn init
 @brief This class is not meant to be initialized.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
