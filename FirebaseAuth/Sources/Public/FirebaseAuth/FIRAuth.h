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

#import <AvailabilityMacros.h>
#import <Foundation/Foundation.h>

@class FIRActionCodeSettings;
@class FIRApp;
@class FIRAuth;
@class FIRAuthCredential;
@class FIRAuthDataResult;
@class FIRAuthSettings;
@class FIRUser;
@protocol FIRAuthUIDelegate;
@protocol FIRFederatedAuthProvider;

NS_ASSUME_NONNULL_BEGIN

/** @typedef FIRUserUpdateCallback
    @brief The type of block invoked when a request to update the current user is completed.
 */
typedef void (^FIRUserUpdateCallback)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRAuthStateDidChangeListenerHandle
    @brief The type of handle returned by `Auth.addAuthStateDidChangeListener(_:)`.
 */
// clang-format off
// clang-format12 merges the next two lines.
typedef id<NSObject> FIRAuthStateDidChangeListenerHandle
    NS_SWIFT_NAME(AuthStateDidChangeListenerHandle);
// clang-format on

/** @typedef FIRAuthStateDidChangeListenerBlock
    @brief The type of block which can be registered as a listener for auth state did change events.

    @param auth The Auth object on which state changes occurred.
    @param user Optionally; the current signed in user, if any.
 */
typedef void (^FIRAuthStateDidChangeListenerBlock)(FIRAuth *auth, FIRUser *_Nullable user)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRIDTokenDidChangeListenerHandle
    @brief The type of handle returned by `Auth.addIDTokenDidChangeListener(_:)`.
 */
// clang-format off
// clang-format12 merges the next two lines.
typedef id<NSObject> FIRIDTokenDidChangeListenerHandle
    NS_SWIFT_NAME(IDTokenDidChangeListenerHandle);
// clang-format on

/** @typedef FIRIDTokenDidChangeListenerBlock
    @brief The type of block which can be registered as a listener for ID token did change events.

    @param auth The Auth object on which ID token changes occurred.
    @param user Optionally; the current signed in user, if any.
 */
typedef void (^FIRIDTokenDidChangeListenerBlock)(FIRAuth *auth, FIRUser *_Nullable user)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRAuthDataResultCallback
    @brief The type of block invoked when sign-in related events complete.

    @param authResult Optionally; Result of sign-in request containing both the user and
       the additional user info associated with the user.
    @param error Optionally; the error which occurred - or nil if the request was successful.
 */
typedef void (^FIRAuthDataResultCallback)(FIRAuthDataResult *_Nullable authResult,
                                          NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");
/**
    @brief The name of the `NSNotificationCenter` notification which is posted when the auth state
        changes (for example, a new token has been produced, a user signs in or signs out). The
        object parameter of the notification is the sender `Auth` instance.
 */
extern const NSNotificationName FIRAuthStateDidChangeNotification NS_SWIFT_NAME(AuthStateDidChange);

/** @typedef FIRAuthResultCallback
    @brief The type of block invoked when sign-in related events complete.

    @param user Optionally; the signed in user, if any.
    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRAuthResultCallback)(FIRUser *_Nullable user, NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRProviderQueryCallback
    @brief The type of block invoked when a list of identity providers for a given email address is
        requested.

    @param providers Optionally; a list of provider identifiers, if any.
        @see GoogleAuthProviderID etc.
    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRProviderQueryCallback)(NSArray<NSString *> *_Nullable providers,
                                         NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRSignInMethodQueryCallback
    @brief The type of block invoked when a list of sign-in methods for a given email address is
        requested.
 */
typedef void (^FIRSignInMethodQueryCallback)(NSArray<NSString *> *_Nullable, NSError *_Nullable)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRSendPasswordResetCallback
    @brief The type of block invoked when sending a password reset email.

    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRSendPasswordResetCallback)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRSendSignInLinkToEmailCallback
    @brief The type of block invoked when sending an email sign-in link email.
 */
typedef void (^FIRSendSignInLinkToEmailCallback)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRConfirmPasswordResetCallback
    @brief The type of block invoked when performing a password reset.

    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRConfirmPasswordResetCallback)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRVerifyPasswordResetCodeCallback
    @brief The type of block invoked when verifying that an out of band code should be used to
        perform password reset.

    @param email Optionally; the email address of the user for which the out of band code applies.
    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRVerifyPasswordResetCodeCallback)(NSString *_Nullable email,
                                                   NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

/** @typedef FIRApplyActionCodeCallback
    @brief The type of block invoked when applying an action code.

    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRApplyActionCodeCallback)(NSError *_Nullable error)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

typedef void (^FIRAuthVoidErrorCallback)(NSError *_Nullable)
    NS_SWIFT_UNAVAILABLE("Use Swift's closure syntax instead.");

NS_ASSUME_NONNULL_END
