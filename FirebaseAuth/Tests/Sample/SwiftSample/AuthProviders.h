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

#import <UIKit/UIKit.h>

@class FIRAuthCredential;

NS_ASSUME_NONNULL_BEGIN

/** @typedef AuthCredentialCallback
    @brief The type of block invoked when a @c FIRAuthCredential object is ready or an error has
        occurred.
    @param credential The auth credential if any.
    @param error The error which occurred, if any.
 */
typedef void (^AuthCredentialCallback)(FIRAuthCredential *_Nullable credential,
                                       NSError *_Nullable error);
/** @protocol AuthProvider
    @brief A common interface for auth providers to be used by the sample app.
 */
@protocol AuthProvider <NSObject>

/** @fn getAuthCredentialWithPresentingViewController:callback:
    @brief Gets a @c FIRAuthCredential instance for use with Firebase headless API by signing in.
    @param viewController The view controller to present the UI.
    @param callback A block which is invoked when the sign-in flow finishes. Invoked asynchronously
        on an unspecified thread in the future.
 */
- (void)getAuthCredentialWithPresentingViewController:(UIViewController *)viewController
                                             callback:(AuthCredentialCallback)callback;

/** @fn signOut
    @brief Logs out the current provider session, which invalidates any cached crendential.
 */
- (void)signOut;

@end

/** @class AuthProviders
    @brief Namespace for @c AuthProvider instances.
 */
@interface AuthProviders : NSObject

/** @fn google
    @brief Returns a Google auth provider.
 */
+ (id<AuthProvider>)google;

/** @fn facebook
    @brief Returns a Facebook auth provider.
 */
+ (id<AuthProvider>)facebook;

/** @fn init
    @brief This class is not supposed to be instantiated.
 */
- (nullable instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
