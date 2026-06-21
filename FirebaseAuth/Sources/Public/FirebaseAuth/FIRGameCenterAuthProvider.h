/*
 * Copyright 2018 Google
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

/**
    @brief A string constant identifying the Game Center identity provider.
 */
extern NSString *const FIRGameCenterAuthProviderID NS_SWIFT_NAME(GameCenterAuthProviderID);

/**
    @brief A string constant identifying the Game Center sign-in method.
 */
extern NSString *const _Nonnull FIRGameCenterAuthSignInMethod NS_SWIFT_NAME(
    GameCenterAuthSignInMethod);

/** @typedef FIRGameCenterCredentialCallback
    @brief The type of block invoked when the Game Center credential code has finished.
    @param credential On success, the credential will be provided, nil otherwise.
    @param error On error, the error that occurred, nil otherwise.
 */
typedef void (^FIRGameCenterCredentialCallback)(FIRAuthCredential *_Nullable credential,
                                                NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

NS_ASSUME_NONNULL_END
