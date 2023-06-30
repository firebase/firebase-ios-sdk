/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactorInfo.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactorSession.h"
#import "FirebaseAuth/Sources/User/FIRUser_Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 @brief Identifies the current session to enroll a second factor or to complete sign in when
 previously enrolled. It contains additional context on the existing user, notably the confirmation
 that the user passed the first factor challenge.
 */

@interface FIRMultiFactorSession ()
/**
 @brief The ID token for an enroll flow. This has to be retrieved after recent authentication.
 */
@property(nonatomic, readonly) NSString *IDToken;
/**
 @brief The pending credential after an enrolled second factor user signs in successfully with the
 first factor
 */
@property(nonatomic) NSString *MFAPendingCredential;
/**
 @brief Multi factor info for the current user.
 */
@property(nonatomic) FIRMultiFactorInfo *multiFactorInfo;
/**
 @brief Current user object
 */
@property(nonatomic) FIRUser *currentUser;

+ (FIRMultiFactorSession *)sessionForCurrentUser;

@end

NS_ASSUME_NONNULL_END

#endif
