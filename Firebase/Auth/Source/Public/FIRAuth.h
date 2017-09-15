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

#import "FIRAuthErrors.h"
#import "FIRAuthSwiftNameSupport.h"

#if TARGET_OS_IOS
#import "FIRAuthAPNSTokenType.h"
#endif

@class FIRActionCodeSettings;
@class FIRApp;
@class FIRAuth;
@class FIRAuthCredential;
@class FIRAuthDataResult;
@class FIRUser;
@protocol FIRAuthStateListener;

NS_ASSUME_NONNULL_BEGIN

/** @typedef FIRAuthStateDidChangeListenerHandle
    @brief The type of handle returned by @c FIRAuth.addAuthStateDidChangeListener:.
 */
typedef id<NSObject> FIRAuthStateDidChangeListenerHandle
    FIR_SWIFT_NAME(AuthStateDidChangeListenerHandle);

/** @typedef FIRAuthStateDidChangeListenerBlock
    @brief The type of block which can be registered as a listener for auth state did change events.

    @param auth The FIRAuth object on which state changes occurred.
    @param user Optionally; the current signed in user, if any.
 */
typedef void(^FIRAuthStateDidChangeListenerBlock)(FIRAuth *auth, FIRUser *_Nullable user)
    FIR_SWIFT_NAME(AuthStateDidChangeListenerBlock);

/** @typedef FIRIDTokenDidChangeListenerHandle
    @brief The type of handle returned by @c FIRAuth.addIDTokenDidChangeListener:.
 */
typedef id<NSObject> FIRIDTokenDidChangeListenerHandle
    FIR_SWIFT_NAME(IDTokenDidChangeListenerHandle);

/** @typedef FIRIDTokenDidChangeListenerBlock
    @brief The type of block which can be registered as a listener for ID token did change events.

    @param auth The FIRAuth object on which ID token changes occurred.
    @param user Optionally; the current signed in user, if any.
 */
typedef void(^FIRIDTokenDidChangeListenerBlock)(FIRAuth *auth, FIRUser *_Nullable user)
    FIR_SWIFT_NAME(IDTokenDidChangeListenerBlock);

/** @typedef FIRAuthDataResultCallback
    @brief The type of block invoked when sign-in related events complete.

    @param authResult Optionally; Result of sign-in request containing both the user and
       the additional user info associated with the user.
    @param error Optionally; the error which occurred - or nil if the request was successful.
 */
typedef void (^FIRAuthDataResultCallback)(FIRAuthDataResult *_Nullable authResult,
                                          NSError *_Nullable error)
    FIR_SWIFT_NAME(AuthDataResultCallback);

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
/**
    @brief The name of the @c NSNotificationCenter notification which is posted when the auth state
        changes (for example, a new token has been produced, a user signs in or signs out). The
        object parameter of the notification is the sender @c FIRAuth instance.
 */
extern const NSNotificationName FIRAuthStateDidChangeNotification
    FIR_SWIFT_NAME(AuthStateDidChange);
#else
/**
    @brief The name of the @c NSNotificationCenter notification which is posted when the auth state
        changes (for example, a new token has been produced, a user signs in or signs out). The
        object parameter of the notification is the sender @c FIRAuth instance.
 */
extern NSString *const FIRAuthStateDidChangeNotification
    FIR_SWIFT_NAME(AuthStateDidChangeNotification);
#endif  // defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

/** @typedef FIRAuthResultCallback
    @brief The type of block invoked when sign-in related events complete.

    @param user Optionally; the signed in user, if any.
    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRAuthResultCallback)(FIRUser *_Nullable user, NSError *_Nullable error)
    FIR_SWIFT_NAME(AuthResultCallback);

/** @typedef FIRProviderQueryCallback
    @brief The type of block invoked when a list of identity providers for a given email address is
        requested.

    @param providers Optionally; a list of provider identifiers, if any.
        @see FIRGoogleAuthProviderID etc.
    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRProviderQueryCallback)(NSArray<NSString *> *_Nullable providers,
                                         NSError *_Nullable error)
    FIR_SWIFT_NAME(ProviderQueryCallback);

/** @typedef FIRSendPasswordResetCallback
    @brief The type of block invoked when sending a password reset email.

    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRSendPasswordResetCallback)(NSError *_Nullable error)
    FIR_SWIFT_NAME(SendPasswordResetCallback);

/** @typedef FIRConfirmPasswordResetCallback
    @brief The type of block invoked when performing a password reset.

    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRConfirmPasswordResetCallback)(NSError *_Nullable error)
    FIR_SWIFT_NAME(ConfirmPasswordResetCallback);

/** @typedef FIRVerifyPasswordResetCodeCallback
    @brief The type of block invoked when verifying that an out of band code should be used to
        perform password reset.

    @param email Optionally; the email address of the user for which the out of band code applies.
    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRVerifyPasswordResetCodeCallback)(NSString *_Nullable email,
                                                   NSError *_Nullable error)
    FIR_SWIFT_NAME(VerifyPasswordResetCodeCallback);

/** @typedef FIRApplyActionCodeCallback
    @brief The type of block invoked when applying an action code.

    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRApplyActionCodeCallback)(NSError *_Nullable error)
    FIR_SWIFT_NAME(ApplyActionCodeCallback);

/**
    @brief Keys used to retrieve operation data from a @c FIRActionCodeInfo object by the
        @c dataForKey method.
  */
typedef NS_ENUM(NSInteger, FIRActionDataKey) {
  /**
   * The email address to which the code was sent.
   * For FIRActionCodeOperationRecoverEmail, the new email address for the account.
   */
  FIRActionCodeEmailKey = 0,

  /** For FIRActionCodeOperationRecoverEmail, the current email address for the account. */
  FIRActionCodeFromEmailKey = 1
} FIR_SWIFT_NAME(ActionDataKey);

/** @class FIRActionCodeInfo
    @brief Manages information regarding action codes.
 */
FIR_SWIFT_NAME(ActionCodeInfo)
@interface FIRActionCodeInfo : NSObject

/**
    @brief Operations which can be performed with action codes.
  */
typedef NS_ENUM(NSInteger, FIRActionCodeOperation) {
    /** Action code for unknown operation. */
    FIRActionCodeOperationUnknown = 0,

    /** Action code for password reset operation. */
    FIRActionCodeOperationPasswordReset = 1,

    /** Action code for verify email operation. */
    FIRActionCodeOperationVerifyEmail = 2,

    /** Action code for recover email operation. */
    FIRActionCodeOperationRecoverEmail = 3,

} FIR_SWIFT_NAME(ActionCodeOperation);

/**
    @brief The operation being performed.
 */
@property(nonatomic, readonly) FIRActionCodeOperation operation;

/** @fn dataForKey:
    @brief The operation being performed.

    @param key The FIRActionDataKey value used to retrieve the operation data.

    @return The operation data pertaining to the provided action code key.
 */
- (NSString *)dataForKey:(FIRActionDataKey)key;

/** @fn init
    @brief please use initWithOperation: instead.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

/** @typedef FIRCheckActionCodeCallBack
    @brief The type of block invoked when performing a check action code operation.

    @param info Metadata corresponding to the action code.
    @param error Optionally; if an error occurs, this is the NSError object that describes the
        problem. Set to nil otherwise.
 */
typedef void (^FIRCheckActionCodeCallBack)(FIRActionCodeInfo *_Nullable info,
                                           NSError *_Nullable error)
    FIR_SWIFT_NAME(CheckActionCodeCallback);

/** @class FIRAuth
    @brief Manages authentication for Firebase apps.
    @remarks This class is thread-safe.
 */
FIR_SWIFT_NAME(Auth)
@interface FIRAuth : NSObject

/** @fn auth
    @brief Gets the auth object for the default Firebase app.
    @remarks The default Firebase app must have already been configured or an exception will be
        raised.
 */
+ (FIRAuth *)auth FIR_SWIFT_NAME(auth());

/** @fn authWithApp:
    @brief Gets the auth object for a @c FIRApp.

    @param app The FIRApp for which to retrieve the associated FIRAuth instance.
    @return The FIRAuth instance associated with the given FIRApp.
 */
+ (FIRAuth *)authWithApp:(FIRApp *)app FIR_SWIFT_NAME(auth(app:));

/** @property app
    @brief Gets the @c FIRApp object that this auth object is connected to.
 */
@property(nonatomic, weak, readonly, nullable) FIRApp *app;

/** @property currentUser
    @brief Synchronously gets the cached current user, or null if there is none.
 */
@property(nonatomic, strong, readonly, nullable) FIRUser *currentUser;

/** @proprty languageCode
    @brief The current user language code. This property can be set to the app's current language by
        calling @c useAppLanguage.

    @remarks The string used to set this property must be a language code that follows BCP 47.
 */
@property (nonatomic, copy, nullable) NSString *languageCode;

#if TARGET_OS_IOS
/** @property APNSToken
    @brief The APNs token used for phone number authentication. The type of the token (production
        or sandbox) will be attempted to be automatcially detected.
    @remarks If swizzling is disabled, the APNs Token must be set for phone number auth to work,
        by either setting this property or by calling @c setAPNSToken:type:
 */
@property(nonatomic, strong, nullable) NSData *APNSToken;
#endif

/** @fn init
    @brief Please access auth instances using @c FIRAuth.auth and @c FIRAuth.authForApp:.
 */
- (instancetype)init NS_UNAVAILABLE;

/** @fn fetchProvidersForEmail:completion:
    @brief Fetches the list of IdPs that can be used for signing in with the provided email address.
        Useful for an "identifier-first" sign-in flow.

    @param email The email address for which to obtain a list of identity providers.
    @param completion Optionally; a block which is invoked when the list of providers for the
        specified email address is ready or an error was encountered. Invoked asynchronously on the
        main thread in the future.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeInvalidEmail - Indicates the email address is malformed.</li>
    </ul>

    @remarks See @c FIRAuthErrors for a list of error codes that are common to all API methods.
 */
- (void)fetchProvidersForEmail:(NSString *)email
                    completion:(nullable FIRProviderQueryCallback)completion;

/** @fn signInWithEmail:password:completion:
    @brief Signs in using an email address and password.

    @param email The user's email address.
    @param password The user's password.
    @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
        canceled. Invoked asynchronously on the main thread in the future.

    @remarks Possible error codes:

    <ul>
        <li>@c FIRAuthErrorCodeOperationNotAllowed - Indicates that email and password
            accounts are not enabled. Enable them in the Auth section of the
            Firebase console.
        </li>
        <li>@c FIRAuthErrorCodeUserDisabled - Indicates the user's account is disabled.
        </li>
        <li>@c FIRAuthErrorCodeWrongPassword - Indicates the user attempted
            sign in with an incorrect password.
        </li>
        <li>@c FIRAuthErrorCodeInvalidEmail - Indicates the email address is malformed.
        </li>
    </ul>

    @remarks See @c FIRAuthErrors for a list of error codes that are common to all API methods.
 */
- (void)signInWithEmail:(NSString *)email
               password:(NSString *)password
             completion:(nullable FIRAuthResultCallback)completion;

/** @fn signInWithCredential:completion:
    @brief Convenience method for @c signInAndRetrieveDataWithCredential:completion: This method
        doesn't return additional identity provider data.
 */
- (void)signInWithCredential:(FIRAuthCredential *)credential
                  completion:(nullable FIRAuthResultCallback)completion;

/** @fn signInAndRetrieveDataWithCredential:completion:
    @brief Asynchronously signs in to Firebase with the given 3rd-party credentials (e.g. a Facebook
        login Access Token, a Google ID Token/Access Token pair, etc.) and returns additional
        identity provider data.

    @param credential The credential supplied by the IdP.
    @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
        canceled. Invoked asynchronously on the main thread in the future.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeInvalidCredential - Indicates the supplied credential is invalid.
            This could happen if it has expired or it is malformed.
        </li>
        <li>@c FIRAuthErrorCodeOperationNotAllowed - Indicates that accounts
            with the identity provider represented by the credential are not enabled.
            Enable them in the Auth section of the Firebase console.
        </li>
        <li>@c FIRAuthErrorCodeAccountExistsWithDifferentCredential - Indicates the email asserted
            by the credential (e.g. the email in a Facebook access token) is already in use by an
            existing account, that cannot be authenticated with this sign-in method. Call
            fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
            the sign-in providers returned. This error will only be thrown if the "One account per
            email address" setting is enabled in the Firebase console, under Auth settings.
        </li>
        <li>@c FIRAuthErrorCodeUserDisabled - Indicates the user's account is disabled.
        </li>
        <li>@c FIRAuthErrorCodeWrongPassword - Indicates the user attempted sign in with an
            incorrect password, if credential is of the type EmailPasswordAuthCredential.
        </li>
        <li>@c FIRAuthErrorCodeInvalidEmail - Indicates the email address is malformed.
        </li>
        <li>@c FIRAuthErrorCodeMissingVerificationID - Indicates that the phone auth credential was
            created with an empty verification ID.
        </li>
        <li>@c FIRAuthErrorCodeMissingVerificationCode - Indicates that the phone auth credential
            was created with an empty verification code.
        </li>
        <li>@c FIRAuthErrorCodeInvalidVerificationCode - Indicates that the phone auth credential
            was created with an invalid verification Code.
        </li>
        <li>@c FIRAuthErrorCodeInvalidVerificationID - Indicates that the phone auth credential was
            created with an invalid verification ID.
        </li>
        <li>@c FIRAuthErrorCodeSessionExpired - Indicates that the SMS code has expired.
        </li>
    </ul>

    @remarks See @c FIRAuthErrors for a list of error codes that are common to all API methods.
 */
- (void)signInAndRetrieveDataWithCredential:(FIRAuthCredential *)credential
                                 completion:(nullable FIRAuthDataResultCallback)completion;

/** @fn signInAnonymouslyWithCompletion:
    @brief Asynchronously creates and becomes an anonymous user.
    @param completion Optionally; a block which is invoked when the sign in finishes, or is
        canceled. Invoked asynchronously on the main thread in the future.

    @remarks If there is already an anonymous user signed in, that user will be returned instead.
        If there is any other existing user signed in, that user will be signed out.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeOperationNotAllowed - Indicates that anonymous accounts are
            not enabled. Enable them in the Auth section of the Firebase console.
        </li>
    </ul>

    @remarks See @c FIRAuthErrors for a list of error codes that are common to all API methods.
 */
- (void)signInAnonymouslyWithCompletion:(nullable FIRAuthResultCallback)completion;

/** @fn signInWithCustomToken:completion:
    @brief Asynchronously signs in to Firebase with the given Auth token.

    @param token A self-signed custom auth token.
    @param completion Optionally; a block which is invoked when the sign in finishes, or is
        canceled. Invoked asynchronously on the main thread in the future.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeInvalidCustomToken - Indicates a validation error with
            the custom token.
        </li>
        <li>@c FIRAuthErrorCodeCustomTokenMismatch - Indicates the service account and the API key
            belong to different projects.
        </li>
    </ul>

    @remarks See @c FIRAuthErrors for a list of error codes that are common to all API methods.
 */
- (void)signInWithCustomToken:(NSString *)token
                   completion:(nullable FIRAuthResultCallback)completion;

/** @fn createUserWithEmail:password:completion:
    @brief Creates and, on success, signs in a user with the given email address and password.

    @param email The user's email address.
    @param password The user's desired password.
    @param completion Optionally; a block which is invoked when the sign up flow finishes, or is
        canceled. Invoked asynchronously on the main thread in the future.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeInvalidEmail - Indicates the email address is malformed.
        </li>
        <li>@c FIRAuthErrorCodeEmailAlreadyInUse - Indicates the email used to attempt sign up
            already exists. Call fetchProvidersForEmail to check which sign-in mechanisms the user
            used, and prompt the user to sign in with one of those.
        </li>
        <li>@c FIRAuthErrorCodeOperationNotAllowed - Indicates that email and password accounts
            are not enabled. Enable them in the Auth section of the Firebase console.
        </li>
        <li>@c FIRAuthErrorCodeWeakPassword - Indicates an attempt to set a password that is
            considered too weak. The NSLocalizedFailureReasonErrorKey field in the NSError.userInfo
            dictionary object will contain more detailed explanation that can be shown to the user.
        </li>
    </ul>

    @remarks See @c FIRAuthErrors for a list of error codes that are common to all API methods.
 */
- (void)createUserWithEmail:(NSString *)email
                   password:(NSString *)password
                 completion:(nullable FIRAuthResultCallback)completion;

/** @fn confirmPasswordResetWithCode:newPassword:completion:
    @brief Resets the password given a code sent to the user outside of the app and a new password
      for the user.

    @param newPassword The new password.
    @param completion Optionally; a block which is invoked when the request finishes. Invoked
        asynchronously on the main thread in the future.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeWeakPassword - Indicates an attempt to set a password that is
            considered too weak.
        </li>
        <li>@c FIRAuthErrorCodeOperationNotAllowed - Indicates the administrator disabled sign
            in with the specified identity provider.
        </li>
        <li>@c FIRAuthErrorCodeExpiredActionCode - Indicates the OOB code is expired.
        </li>
        <li>@c FIRAuthErrorCodeInvalidActionCode - Indicates the OOB code is invalid.
        </li>
   </ul>

    @remarks See @c FIRAuthErrors for a list of error codes that are common to all API methods.
 */
- (void)confirmPasswordResetWithCode:(NSString *)code
                         newPassword:(NSString *)newPassword
                          completion:(FIRConfirmPasswordResetCallback)completion;

/** @fn checkActionCode:completion:
    @brief Checks the validity of an out of band code.

    @param code The out of band code to check validity.
    @param completion Optionally; a block which is invoked when the request finishes. Invoked
        asynchronously on the main thread in the future.
 */
- (void)checkActionCode:(NSString *)code completion:(FIRCheckActionCodeCallBack)completion;

/** @fn verifyPasswordResetCode:completion:
    @brief Checks the validity of a verify password reset code.

    @param code The password reset code to be verified.
    @param completion Optionally; a block which is invoked when the request finishes. Invoked
        asynchronously on the main thread in the future.
 */
- (void)verifyPasswordResetCode:(NSString *)code
                     completion:(FIRVerifyPasswordResetCodeCallback)completion;

/** @fn applyActionCode:completion:
    @brief Applies out of band code.

    @param code The out of band code to be applied.
    @param completion Optionally; a block which is invoked when the request finishes. Invoked
        asynchronously on the main thread in the future.

    @remarks This method will not work for out of band codes which require an additional parameter,
        such as password reset code.
 */
- (void)applyActionCode:(NSString *)code
             completion:(FIRApplyActionCodeCallback)completion;

/** @fn sendPasswordResetWithEmail:completion:
    @brief Initiates a password reset for the given email address.

    @param email The email address of the user.
    @param completion Optionally; a block which is invoked when the request finishes. Invoked
        asynchronously on the main thread in the future.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeInvalidRecipientEmail - Indicates an invalid recipient email was
            sent in the request.
        </li>
        <li>@c FIRAuthErrorCodeInvalidSender - Indicates an invalid sender email is set in
            the console for this action.
        </li>
        <li>@c FIRAuthErrorCodeInvalidMessagePayload - Indicates an invalid email template for
            sending update email.
        </li>
    </ul>
 */
- (void)sendPasswordResetWithEmail:(NSString *)email
                        completion:(nullable FIRSendPasswordResetCallback)completion;

/** @fn sendPasswordResetWithEmail:actionCodeSetting:completion:
    @brief Initiates a password reset for the given email address and @FIRActionCodeSettings object.

    @param email The email address of the user.
    @param actionCodeSettings An @c FIRActionCodeSettings object containing settings related to
        handling action codes.
    @param completion Optionally; a block which is invoked when the request finishes. Invoked
        asynchronously on the main thread in the future.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeInvalidRecipientEmail - Indicates an invalid recipient email was
            sent in the request.
        </li>
        <li>@c FIRAuthErrorCodeInvalidSender - Indicates an invalid sender email is set in
            the console for this action.
        </li>
        <li>@c FIRAuthErrorCodeInvalidMessagePayload - Indicates an invalid email template for
            sending update email.
        </li>
        <li>@c FIRAuthErrorCodeMissingIosBundleID - Indicates that the iOS bundle ID is missing when
            @c handleCodeInApp is set to YES.
        </li>
        <li>@c FIRAuthErrorCodeMissingAndroidPackageName - Indicates that the android package name
            is missing when the @c androidInstallApp flag is set to true.
        </li>
        <li>@c FIRAuthErrorCodeUnauthorizedDomain - Indicates that the domain specified in the
            continue URL is not whitelisted in the Firebase console.
        </li>
        <li>@c FIRAuthErrorCodeInvalidContinueURI - Indicates that the domain specified in the
            continue URI is not valid.
        </li>
    </ul>
 */
 - (void)sendPasswordResetWithEmail:(NSString *)email
                 actionCodeSettings:(FIRActionCodeSettings *)actionCodeSettings
                         completion:(nullable FIRSendPasswordResetCallback)completion;

/** @fn signOut:
    @brief Signs out the current user.

    @param error Optionally; if an error occurs, upon return contains an NSError object that
        describes the problem; is nil otherwise.
    @return @YES when the sign out request was successful. @NO otherwise.

    @remarks Possible error codes:
    <ul>
        <li>@c FIRAuthErrorCodeKeychainError - Indicates an error occurred when accessing the
            keychain. The @c NSLocalizedFailureReasonErrorKey field in the @c NSError.userInfo
            dictionary will contain more information about the error encountered.
        </li>
    </ul>

 */
- (BOOL)signOut:(NSError *_Nullable *_Nullable)error;

/** @fn addAuthStateDidChangeListener:
    @brief Registers a block as an "auth state did change" listener. To be invoked when:

      + The block is registered as a listener,
      + A user with a different UID from the current user has signed in, or
      + The current user has signed out.

    @param listener The block to be invoked. The block is always invoked asynchronously on the main
        thread, even for it's initial invocation after having been added as a listener.

    @remarks The block is invoked immediately after adding it according to it's standard invocation
        semantics, asynchronously on the main thread. Users should pay special attention to
        making sure the block does not inadvertently retain objects which should not be retained by
        the long-lived block. The block itself will be retained by @c FIRAuth until it is
        unregistered or until the @c FIRAuth instance is otherwise deallocated.

    @return A handle useful for manually unregistering the block as a listener.
 */
- (FIRAuthStateDidChangeListenerHandle)addAuthStateDidChangeListener:
    (FIRAuthStateDidChangeListenerBlock)listener;

/** @fn removeAuthStateDidChangeListener:
    @brief Unregisters a block as an "auth state did change" listener.

    @param listenerHandle The handle for the listener.
 */
- (void)removeAuthStateDidChangeListener:(FIRAuthStateDidChangeListenerHandle)listenerHandle;

/** @fn addIDTokenDidChangeListener:
    @brief Registers a block as an "ID token did change" listener. To be invoked when:

      + The block is registered as a listener,
      + A user with a different UID from the current user has signed in,
      + The ID token of the current user has been refreshed, or
      + The current user has signed out.

    @param listener The block to be invoked. The block is always invoked asynchronously on the main
        thread, even for it's initial invocation after having been added as a listener.

    @remarks The block is invoked immediately after adding it according to it's standard invocation
        semantics, asynchronously on the main thread. Users should pay special attention to
        making sure the block does not inadvertently retain objects which should not be retained by
        the long-lived block. The block itself will be retained by @c FIRAuth until it is
        unregistered or until the @c FIRAuth instance is otherwise deallocated.

    @return A handle useful for manually unregistering the block as a listener.
 */
- (FIRIDTokenDidChangeListenerHandle)addIDTokenDidChangeListener:
    (FIRIDTokenDidChangeListenerBlock)listener;

/** @fn removeIDTokenDidChangeListener:
    @brief Unregisters a block as an "ID token did change" listener.

    @param listenerHandle The handle for the listener.
 */
- (void)removeIDTokenDidChangeListener:(FIRIDTokenDidChangeListenerHandle)listenerHandle;

/** @fn useAppLanguage
    @brief Sets @c languageCode to the app's current language.
 */
- (void)useAppLanguage;

#if TARGET_OS_IOS

/** @fn canHandleURL:
    @brief Whether the specific URL is handled by @c FIRAuth .
    @param URL The URL received by the application delegate from any of the openURL method.
    @return Whether or the URL is handled. YES means the URL is for Firebase Auth
        so the caller should ignore the URL from further processing, and NO means the
        the URL is for the app (or another libaray) so the caller should continue handling
        this URL as usual.
    @remarks If swizzling is disabled, URLs received by the application delegate must be forwarded
        to this method for phone number auth to work.
 */
- (BOOL)canHandleURL:(nonnull NSURL *)URL;

/** @fn setAPNSToken:type:
    @brief Sets the APNs token along with its type.
    @remarks If swizzling is disabled, the APNs Token must be set for phone number auth to work,
        by either setting calling this method or by setting the @c APNSToken property.
 */
- (void)setAPNSToken:(NSData *)token type:(FIRAuthAPNSTokenType)type;

/** @fn canHandleNotification:
    @brief Whether the specific remote notification is handled by @c FIRAuth .
    @param userInfo A dictionary that contains information related to the
        notification in question.
    @return Whether or the notification is handled. YES means the notification is for Firebase Auth
        so the caller should ignore the notification from further processing, and NO means the
        the notification is for the app (or another libaray) so the caller should continue handling
        this notification as usual.
    @remarks If swizzling is disabled, related remote notifications must be forwarded to this method
        for phone number auth to work.
 */
- (BOOL)canHandleNotification:(NSDictionary *)userInfo;

#endif  // TARGET_OS_IOS

@end

NS_ASSUME_NONNULL_END
