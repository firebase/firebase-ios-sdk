// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

@_implementationOnly import FirebaseCore
@_implementationOnly import FirebaseCoreExtension

// TODO: What should this be?
// extension NSNotification.Name {
//    /**
//        @brief The name of the `NSNotificationCenter` notification which is posted when the auth state
//            changes (for example, a new token has been produced, a user signs in or signs out). The
//            object parameter of the notification is the sender `Auth` instance.
//     */
//    public static let AuthStateDidChange: NSNotification.Name
// }

/** @class Auth
    @brief Manages authentication for Firebase apps.
    @remarks This class is thread-safe.
 */
@objc public class Auth: NSObject {
  /** @fn auth
   @brief Gets the auth object for the default Firebase app.
   @remarks The default Firebase app must have already been configured or an exception will be
   raised.
   */
  @objc public class func auth() -> Auth {
    guard let defaultApp = FirebaseApp.app() else {
      fatalError("The default FirebaseApp instance must be configured before the default Auth" +
        "instance can be initialized. One way to ensure this is to call " +
        "`FirebaseApp.configure()` in the App Delegate's " +
        "`application(_:didFinishLaunchingWithOptions:)` (or the `@main` struct's " +
        "initializer in SwiftUI).")
    }
    return auth(app: defaultApp)
  }

  /** @fn authWithApp:
   @brief Gets the auth object for a `FirebaseApp`.

   @param app The app for which to retrieve the associated `Auth` instance.
   @return The `Auth` instance associated with the given app.
   */
  @objc public class func auth(app: FirebaseApp) -> Auth {
    let provider = ComponentType<AuthProvider>.instance(for: AuthProvider.self,
                                                        in: app.container)
    return provider.auth()
  }

  /** @property app
   @brief Gets the `FirebaseApp` object that this auth object is connected to.
   */
  @objc public weak var app: FirebaseApp?

  /** @property currentUser
   @brief Synchronously gets the cached current user, or null if there is none.
   */
  @objc public var currentUser: User?

  /** @property languageCode
   @brief The current user language code. This property can be set to the app's current language by
   calling `useAppLanguage()`.

   @remarks The string used to set this property must be a language code that follows BCP 47.
   */
  @objc public var languageCode: String?

  /** @property settings
   @brief Contains settings related to the auth object.
   */
  @NSCopying @objc public var settings: AuthSettings?

  /** @property userAccessGroup
   @brief The current user access group that the Auth instance is using. Default is nil.
   */
  @objc public var userAccessGroup: String?

  /** @property shareAuthStateAcrossDevices
   @brief Contains shareAuthStateAcrossDevices setting related to the auth object.
   @remarks If userAccessGroup is not set, setting shareAuthStateAcrossDevices will
   have no effect. You should set shareAuthStateAcrossDevices to it's desired
   state and then set the userAccessGroup after.
   */
  @objc public var shareAuthStateAcrossDevices: Bool

  /** @property tenantID
   @brief The tenant ID of the auth instance. nil if none is available.
   */
  @objc public var tenantID: String?

  /** @fn updateCurrentUser:completion:
   @brief Sets the `currentUser` on the receiver to the provided user object.
   @param user The user object to be set as the current user of the calling Auth instance.
   @param completion Optionally; a block invoked after the user of the calling Auth instance has
   been updated or an error was encountered.
   */
  @objc public func updateCurrentUser(_ user: User?, completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      guard let user else {
        if let completion {
          DispatchQueue.main.async {
            completion(AuthErrorUtils.nullUserError(message: nil))
          }
        }
        return
      }
      let updateUserBlock: (User) -> Void = { user in
        do {
          try self.updateCurrentUser(user: user, byForce: true, savingToDisk: true)
          if let completion {
            DispatchQueue.main.async {
              completion(nil)
            }
          }
        } catch {
          if let completion {
            DispatchQueue.main.async {
              completion(error)
            }
          }
        }
      }
      if user.requestConfiguration.apiKey != self.requestConfiguration.apiKey {
        // If the API keys are different, then we need to confirm that the user belongs to the same
        // project before proceeding.
        user.requestConfiguration = self.requestConfiguration
        user.reload { error in
          if let error {
            if let completion {
              DispatchQueue.main.async {
                completion(error)
              }
            }
            return
          }
          updateUserBlock(user)
        }
      } else {
        updateUserBlock(user)
      }
    }
  }

  /** @fn updateCurrentUser:completion:
   @brief Sets the `currentUser` on the receiver to the provided user object.
   @param user The user object to be set as the current user of the calling Auth instance.
   @param completion Optionally; a block invoked after the user of the calling Auth instance has
   been updated or an error was encountered.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func updateCurrentUser(_ user: User) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.updateCurrentUser(user) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /** @fn fetchSignInMethodsForEmail:completion:
   @brief Fetches the list of all sign-in methods previously used for the provided email address.

   @param email The email address for which to obtain a list of sign-in methods.
   @param completion Optionally; a block which is invoked when the list of sign in methods for the
   specified email address is ready or an error was encountered. Invoked asynchronously on the
   main thread in the future.

   @remarks Possible error codes:

   + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.

   @remarks See @c AuthErrors for a list of error codes that are common to all API methods.
   */
  @objc public func fetchSignInMethods(forEmail email: String,
                                       completion: (([String]?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let request = CreateAuthURIRequest(identifier: email,
                                         continueURI: "http:www.google.com",
                                         requestConfiguration: self.requestConfiguration)
      AuthBackend.post(withRequest: request) { response, error in
        if let completion {
          DispatchQueue.main.async {
            completion((response as? CreateAuthURIResponse)?.signinMethods, error)
          }
        }
      }
    }
  }

  /** @fn fetchSignInMethodsForEmail:completion:
   @brief Fetches the list of all sign-in methods previously used for the provided email address.

   @param email The email address for which to obtain a list of sign-in methods.
   @param completion Optionally; a block which is invoked when the list of sign in methods for the
   specified email address is ready or an error was encountered. Invoked asynchronously on the
   main thread in the future.

   @remarks Possible error codes:

   + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.

   @remarks See @c AuthErrors for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func fetchSignInMethods(forEmail email: String) async throws -> [String] {
    return try await withCheckedThrowingContinuation { continuation in
      self.fetchSignInMethods(forEmail: email) { methods, error in
        if let methods {
          continuation.resume(returning: methods)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn signInWithEmail:password:completion:
   @brief Signs in using an email address and password.

   @param email The user's email address.
   @param password The user's password.
   @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks Possible error codes:

   + `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
   accounts are not enabled. Enable them in the Auth section of the
   Firebase console.
   + `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
   + `AuthErrorCodeWrongPassword` - Indicates the user attempted
   sign in with an incorrect password.
   + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.

   @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc public func signIn(withEmail email: String,
                           password: String,
                           callback: @escaping ((User?, Error?) -> Void)) {
    let request = VerifyPasswordRequest(email: email,
                                        password: password,
                                        requestConfiguration: requestConfiguration)
    if request.password.count == 0 {
      callback(nil, AuthErrorUtils.wrongPasswordError(message: nil))
      return
    }
    AuthBackend.post(withRequest: request) { rawResponse, error in
      if let error {
        callback(nil, error)
        return
      }
      guard let response = rawResponse as? VerifyPasswordResponse else {
        fatalError("Internal Auth Error: null response from VerifyPasswordRequest")
      }
      self.completeSignIn(withAccessToken: response.idToken,
                          accessTokenExpirationDate: response.approximateExpirationDate,
                          refreshToken: response.refreshToken,
                          anonymous: false,
                          callback: callback)
    }
  }

  /** @fn signInWithEmail:password:completion:
   @brief Signs in using an email address and password.

   @param email The user's email address.
   @param password The user's password.
   @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks Possible error codes:

   + `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
   accounts are not enabled. Enable them in the Auth section of the
   Firebase console.
   + `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
   + `AuthErrorCodeWrongPassword` - Indicates the user attempted
   sign in with an incorrect password.
   + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.

   @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func signIn(withEmail email: String, password: String) async throws -> User {
    return try await withCheckedThrowingContinuation { continuation in
      self.signIn(withEmail: email, password: password) { user, error in
        if let user {
          continuation.resume(returning: user)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn signInWithEmail:link:completion:
   @brief Signs in using an email address and email sign-in link.

   @param email The user's email address.
   @param link The email sign-in link.
   @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks Possible error codes:

   + `AuthErrorCodeOperationNotAllowed` - Indicates that email and email sign-in link
   accounts are not enabled. Enable them in the Auth section of the
   Firebase console.
   + `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
   + `AuthErrorCodeInvalidEmail` - Indicates the email address is invalid.

   @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc public func signIn(withEmail email: String,
                           link: String,
                           completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      let credential = EmailAuthCredential(withEmail: email, link: link)
      self.internalSignInAndRetrieveData(withCredential: credential,
                                         isReauthentication: false,
                                         callback: decoratedCallback)
    }
  }

  /** @fn signInWithEmail:link:completion:
   @brief Signs in using an email address and email sign-in link.

   @param email The user's email address.
   @param link The email sign-in link.
   @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks Possible error codes:

   + `AuthErrorCodeOperationNotAllowed` - Indicates that email and email sign-in link
   accounts are not enabled. Enable them in the Auth section of the
   Firebase console.
   + `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
   + `AuthErrorCodeInvalidEmail` - Indicates the email address is invalid.

   @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func signIn(withEmail email: String, link: String) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.signIn(withEmail: email, link: link) { result, error in
        if let result {
          continuation.resume(returning: result)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn signInWithProvider:UIDelegate:completion:
   @brief Signs in using the provided auth provider instance.
   This method is available on iOS, macOS Catalyst, and tvOS only.

   @param provider An instance of an auth provider used to initiate the sign-in flow.
   @param UIDelegate Optionally an instance of a class conforming to the AuthUIDelegate
   protocol, this is used for presenting the web context. If nil, a default AuthUIDelegate
   will be used.
   @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks Possible error codes:
   <ul>
   <li>@c AuthErrorCodeOperationNotAllowed - Indicates that email and password
   accounts are not enabled. Enable them in the Auth section of the
   Firebase console.
   </li>
   <li>@c AuthErrorCodeUserDisabled - Indicates the user's account is disabled.
   </li>
   <li>@c AuthErrorCodeWebNetworkRequestFailed - Indicates that a network request within a
   SFSafariViewController or WKWebView failed.
   </li>
   <li>@c AuthErrorCodeWebInternalError - Indicates that an internal error occurred within a
   SFSafariViewController or WKWebView.
   </li>
   <li>@c AuthErrorCodeWebSignInUserInteractionFailure - Indicates a general failure during
   a web sign-in flow.
   </li>
   <li>@c AuthErrorCodeWebContextAlreadyPresented - Indicates that an attempt was made to
   present a new web context while one was already being presented.
   </li>
   <li>@c AuthErrorCodeWebContextCancelled - Indicates that the URL presentation was
   cancelled prematurely by the user.
   </li>
   <li>@c AuthErrorCodeAccountExistsWithDifferentCredential - Indicates the email asserted
   by the credential (e.g. the email in a Facebook access token) is already in use by an
   existing account, that cannot be authenticated with this sign-in method. Call
   fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
   the sign-in providers returned. This error will only be thrown if the "One account per
   email address" setting is enabled in the Firebase console, under Auth settings.
   </li>
   </ul>

   @remarks See @c AuthErrors for a list of error codes that are common to all API methods.
   */

  @objc(signInWithProvider:UIDelegate:completion:)
  public func signIn(withProvider provider: FederatedAuthProvider,
                     uiDelegate: AuthUIDelegate,
                     completion: ((AuthDataResult?, Error?) -> Void)?) {
    #if os(iOS)
      kAuthGlobalWorkQueue.async {
        let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
        provider.getCredentialWith(uiDelegate) { rawCredential, error in
          if let error {
            decoratedCallback(nil, error)
            return
          }
          guard let credential = rawCredential else {
            fatalError("Internal Auth Error: Failed to get a AuthCredential")
          }
          self.internalSignInAndRetrieveData(withCredential: credential,
                                             isReauthentication: false,
                                             callback: decoratedCallback)
        }
      }
    #endif
  }

  /** @fn signInWithCredential:completion:
   @brief Asynchronously signs in to Firebase with the given 3rd-party credentials (e.g. a Facebook
   login Access Token, a Google ID Token/Access Token pair, etc.) and returns additional
   identity provider data.

   @param credential The credential supplied by the IdP.
   @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks Possible error codes:

   + `AuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
   This could happen if it has expired or it is malformed.
   + `AuthErrorCodeOperationNotAllowed` - Indicates that accounts
   with the identity provider represented by the credential are not enabled.
   Enable them in the Auth section of the Firebase console.
   + `AuthErrorCodeAccountExistsWithDifferentCredential` - Indicates the email asserted
   by the credential (e.g. the email in a Facebook access token) is already in use by an
   existing account, that cannot be authenticated with this sign-in method. Call
   fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
   the sign-in providers returned. This error will only be thrown if the "One account per
   email address" setting is enabled in the Firebase console, under Auth settings.
   + `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
   + `AuthErrorCodeWrongPassword` - Indicates the user attempted sign in with an
   incorrect password, if credential is of the type EmailPasswordAuthCredential.
   + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
   + `AuthErrorCodeMissingVerificationID` - Indicates that the phone auth credential was
   created with an empty verification ID.
   + `AuthErrorCodeMissingVerificationCode` - Indicates that the phone auth credential
   was created with an empty verification code.
   + `AuthErrorCodeInvalidVerificationCode` - Indicates that the phone auth credential
   was created with an invalid verification Code.
   + `AuthErrorCodeInvalidVerificationID` - Indicates that the phone auth credential was
   created with an invalid verification ID.
   + `AuthErrorCodeSessionExpired` - Indicates that the SMS code has expired.

   @remarks See `AuthErrors` for a list of error codes that are common to all API methods
   */
  @objc public func signIn(with credential: AuthCredential,
                           completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      self.internalSignInAndRetrieveData(withCredential: credential,
                                         isReauthentication: false,
                                         callback: decoratedCallback)
    }
  }

  /** @fn signInWithCredential:completion:
   @brief Asynchronously signs in to Firebase with the given 3rd-party credentials (e.g. a Facebook
   login Access Token, a Google ID Token/Access Token pair, etc.) and returns additional
   identity provider data.

   @param credential The credential supplied by the IdP.
   @param completion Optionally; a block which is invoked when the sign in flow finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks Possible error codes:

   + `AuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
   This could happen if it has expired or it is malformed.
   + `AuthErrorCodeOperationNotAllowed` - Indicates that accounts
   with the identity provider represented by the credential are not enabled.
   Enable them in the Auth section of the Firebase console.
   + `AuthErrorCodeAccountExistsWithDifferentCredential` - Indicates the email asserted
   by the credential (e.g. the email in a Facebook access token) is already in use by an
   existing account, that cannot be authenticated with this sign-in method. Call
   fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
   the sign-in providers returned. This error will only be thrown if the "One account per
   email address" setting is enabled in the Firebase console, under Auth settings.
   + `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
   + `AuthErrorCodeWrongPassword` - Indicates the user attempted sign in with an
   incorrect password, if credential is of the type EmailPasswordAuthCredential.
   + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
   + `AuthErrorCodeMissingVerificationID` - Indicates that the phone auth credential was
   created with an empty verification ID.
   + `AuthErrorCodeMissingVerificationCode` - Indicates that the phone auth credential
   was created with an empty verification code.
   + `AuthErrorCodeInvalidVerificationCode` - Indicates that the phone auth credential
   was created with an invalid verification Code.
   + `AuthErrorCodeInvalidVerificationID` - Indicates that the phone auth credential was
   created with an invalid verification ID.
   + `AuthErrorCodeSessionExpired` - Indicates that the SMS code has expired.

   @remarks See `AuthErrors` for a list of error codes that are common to all API methods
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.signIn(with: credential) { result, error in
        if let result {
          continuation.resume(returning: result)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn signInAnonymouslyWithCompletion:
   @brief Asynchronously creates and becomes an anonymous user.
   @param completion Optionally; a block which is invoked when the sign in finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks If there is already an anonymous user signed in, that user will be returned instead.
   If there is any other existing user signed in, that user will be signed out.

   @remarks Possible error codes:

   + `AuthErrorCodeOperationNotAllowed` - Indicates that anonymous accounts are
   not enabled. Enable them in the Auth section of the Firebase console.

   @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc public func signInAnonymously(completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      if let currentUser = self.currentUser, currentUser.isAnonymous {
        let result = AuthDataResult(withUser: currentUser, additionalUserInfo: nil)
        decoratedCallback(result, nil)
      }
      let request = SignUpNewUserRequest(requestConfiguration: self.requestConfiguration)
      AuthBackend.post(withRequest: request) { rawResponse, error in
        if let error {
          decoratedCallback(nil, error)
          return
        }
        guard let response = rawResponse as? SignUpNewUserResponse else {
          fatalError("Internal Auth Error: Failed to get a SignUpNewUserResponse")
        }
        self.completeSignIn(withAccessToken: response.idToken,
                            accessTokenExpirationDate: response.approximateExpirationDate,
                            refreshToken: response.refreshToken,
                            anonymous: true) { user, error in
          if let error {
            decoratedCallback(nil, error)
            return
          }
          if let user {
            let additionalUserInfo = AdditionalUserInfo(providerID: nil,
                                                        profile: nil,
                                                        username: nil,
                                                        isNewUser: true)
            decoratedCallback(AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo),
                              nil)
          } else {
            decoratedCallback(nil, nil)
          }
        }
      }
    }
  }

  /** @fn signInAnonymouslyWithCompletion:
   @brief Asynchronously creates and becomes an anonymous user.
   @param completion Optionally; a block which is invoked when the sign in finishes, or is
   canceled. Invoked asynchronously on the main thread in the future.

   @remarks If there is already an anonymous user signed in, that user will be returned instead.
   If there is any other existing user signed in, that user will be signed out.

   @remarks Possible error codes:

   + `AuthErrorCodeOperationNotAllowed` - Indicates that anonymous accounts are
   not enabled. Enable them in the Auth section of the Firebase console.

   @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc public func signInAnonymously() async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.signInAnonymously { result, error in
        if let result {
          continuation.resume(returning: result)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn signInWithCustomToken:completion:
      @brief Asynchronously signs in to Firebase with the given Auth token.

      @param token A self-signed custom auth token.
      @param completion Optionally; a block which is invoked when the sign in finishes, or is
          canceled. Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidCustomToken` - Indicates a validation error with
              the custom token.
          + `AuthErrorCodeCustomTokenMismatch` - Indicates the service account and the API key
              belong to different projects.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc public func signIn(withCustomToken token: String,
                           completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      let request = VerifyCustomTokenRequest(token: token,
                                             requestConfiguration: self.requestConfiguration)
      AuthBackend.post(withRequest: request) { rawResponse, error in
        if let error {
          decoratedCallback(nil, error)
          return
        }
        guard let response = rawResponse as? VerifyCustomTokenResponse else {
          fatalError("Internal Auth Error: Failed to get a VerifyCustomTokenResponse")
        }
        self.completeSignIn(withAccessToken: response.idToken,
                            accessTokenExpirationDate: response.approximateExpirationDate,
                            refreshToken: response.refreshToken,
                            anonymous: true) { user, error in
          if let error {
            decoratedCallback(nil, error)
            return
          }
          if let user {
            let additionalUserInfo = AdditionalUserInfo(providerID: nil,
                                                        profile: nil,
                                                        username: nil,
                                                        isNewUser: response.isNewUser)
            decoratedCallback(AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo),
                              nil)
          } else {
            decoratedCallback(nil, nil)
          }
        }
      }
    }
  }

  /** @fn signInWithCustomToken:completion:
      @brief Asynchronously signs in to Firebase with the given Auth token.

      @param token A self-signed custom auth token.
      @param completion Optionally; a block which is invoked when the sign in finishes, or is
          canceled. Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidCustomToken` - Indicates a validation error with
              the custom token.
          + `AuthErrorCodeCustomTokenMismatch` - Indicates the service account and the API key
              belong to different projects.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func signIn(withCustomToken token: String) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.signIn(withCustomToken: token) { result, error in
        if let result {
          continuation.resume(returning: result)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn createUserWithEmail:password:completion:
      @brief Creates and, on success, signs in a user with the given email address and password.

      @param email The user's email address.
      @param password The user's desired password.
      @param completion Optionally; a block which is invoked when the sign up flow finishes, or is
          canceled. Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
          + `AuthErrorCodeEmailAlreadyInUse` - Indicates the email used to attempt sign up
              already exists. Call fetchProvidersForEmail to check which sign-in mechanisms the user
              used, and prompt the user to sign in with one of those.
          + `AuthErrorCodeOperationNotAllowed` - Indicates that email and password accounts
              are not enabled. Enable them in the Auth section of the Firebase console.
          + `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
              considered too weak. The NSLocalizedFailureReasonErrorKey field in the NSError.userInfo
              dictionary object will contain more detailed explanation that can be shown to the user.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc public func createUser(withEmail email: String,
                               password: String,
                               completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    guard password.count > 0 else {
      if let completion {
        completion(nil, AuthErrorUtils.weakPasswordError(serverResponseReason: "Missing password"))
      }
      return
    }
    guard email.count > 0 else {
      if let completion {
        completion(nil, AuthErrorUtils.missingEmailError(message: nil))
      }
      return
    }
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      let request = SignUpNewUserRequest(email: email,
                                         password: password,
                                         displayName: nil,
                                             requestConfiguration: self.requestConfiguration)
      AuthBackend.post(withRequest: request) { rawResponse, error in
        if let error {
          decoratedCallback(nil, error)
          return
        }
        guard let response = rawResponse as? SignUpNewUserResponse else {
          fatalError("Internal Auth Error: Failed to get a SignUpNewUserResponse")
        }
        self.completeSignIn(withAccessToken: response.idToken,
                            accessTokenExpirationDate: response.approximateExpirationDate,
                            refreshToken: response.refreshToken,
                            anonymous: true) { user, error in
          if let error {
            decoratedCallback(nil, error)
            return
          }
          if let user {
            let additionalUserInfo = AdditionalUserInfo(providerID: EmailAuthProvider.id,
                                                        profile: nil,
                                                        username: nil,
                                                        isNewUser: true)
            decoratedCallback(AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo),
                              nil)
          } else {
            decoratedCallback(nil, nil)
          }
        }
      }
    }
  }

  /** @fn createUserWithEmail:password:completion:
      @brief Creates and, on success, signs in a user with the given email address and password.

      @param email The user's email address.
      @param password The user's desired password.
      @param completion Optionally; a block which is invoked when the sign up flow finishes, or is
          canceled. Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
          + `AuthErrorCodeEmailAlreadyInUse` - Indicates the email used to attempt sign up
              already exists. Call fetchProvidersForEmail to check which sign-in mechanisms the user
              used, and prompt the user to sign in with one of those.
          + `AuthErrorCodeOperationNotAllowed` - Indicates that email and password accounts
              are not enabled. Enable them in the Auth section of the Firebase console.
          + `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
              considered too weak. The NSLocalizedFailureReasonErrorKey field in the NSError.userInfo
              dictionary object will contain more detailed explanation that can be shown to the user.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func createUser(withEmail email: String, password: String) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.createUser(withEmail: email, password: password) { result, error in
        if let result {
          continuation.resume(returning: result)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn confirmPasswordResetWithCode:newPassword:completion:
      @brief Resets the password given a code sent to the user outside of the app and a new password
        for the user.

      @param newPassword The new password.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
              considered too weak.
          + `AuthErrorCodeOperationNotAllowed` - Indicates the administrator disabled sign
              in with the specified identity provider.
          + `AuthErrorCodeExpiredActionCode` - Indicates the OOB code is expired.
          + `AuthErrorCodeInvalidActionCode` - Indicates the OOB code is invalid.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc public func confirmPasswordReset(withCode code: String, newPassword: String,
                                         completion: @escaping (Error?) -> Void) {
    kAuthGlobalWorkQueue.async {
      let request = ResetPasswordRequest(oobCode: code,
                                         newPassword: newPassword,
                                         requestConfiguration: self.requestConfiguration)
      AuthBackend.post(withRequest: request) { _, error in
        DispatchQueue.main.async {
          if let error {
            completion(error)
            return
          }
          completion(nil)
        }
      }
    }
  }

  /** @fn confirmPasswordResetWithCode:newPassword:completion:
      @brief Resets the password given a code sent to the user outside of the app and a new password
        for the user.

      @param newPassword The new password.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
              considered too weak.
          + `AuthErrorCodeOperationNotAllowed` - Indicates the administrator disabled sign
              in with the specified identity provider.
          + `AuthErrorCodeExpiredActionCode` - Indicates the OOB code is expired.
          + `AuthErrorCodeInvalidActionCode` - Indicates the OOB code is invalid.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func confirmPasswordReset(withCode code: String, newPassword: String) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.confirmPasswordReset(withCode: code, newPassword: newPassword) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /** @fn checkActionCode:completion:
      @brief Checks the validity of an out of band code.

      @param code The out of band code to check validity.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.
   */
  @objc public func checkActionCode(_ code: String,
                                    completion: @escaping (ActionCodeInfo?, Error?) -> Void) {
    kAuthGlobalWorkQueue.async {
      let request = ResetPasswordRequest(oobCode: code,
                                         newPassword: nil,
                                         requestConfiguration: self.requestConfiguration)
      AuthBackend.post(withRequest: request) { rawResponse, error in
        DispatchQueue.main.async {
          if let error {
            completion(nil, error)
            return
          }
          guard let response = rawResponse as? ResetPasswordResponse,
          let email = response.email else {
            fatalError("Internal Auth Error: Failed to get a ResetPasswordResponse")
          }
          let operation = ActionCodeInfo.actionCodeOperation(forRequestType: response.requestType)
          let actionCodeInfo = ActionCodeInfo(withOperation: operation,
                                              email: email,
                                              newEmail: response.verifiedEmail)
          DispatchQueue.main.async {
            completion(actionCodeInfo, nil)
          }
        }
      }
    }
  }

  /** @fn checkActionCode:completion:
      @brief Checks the validity of an out of band code.

      @param code The out of band code to check validity.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func checkActionCode(_ code: String) async throws -> ActionCodeInfo {
    return try await withCheckedThrowingContinuation { continuation in
      self.checkActionCode(code) { info, error in
        if let info {
          continuation.resume(returning: info)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn verifyPasswordResetCode:completion:
      @brief Checks the validity of a verify password reset code.

      @param code The password reset code to be verified.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.
   */
  @objc public func verifyPasswordResetCode(_ code: String,
                                            completion: @escaping (String?, Error?) -> Void) {
    self.checkActionCode(code) { info, error in
      if let error {
        completion(nil, error)
        return
      }
      completion(info?.email, nil)
    }
  }

  /** @fn verifyPasswordResetCode:completion:
      @brief Checks the validity of a verify password reset code.

      @param code The password reset code to be verified.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc public func verifyPasswordResetCode(_ code: String) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      self.verifyPasswordResetCode(code) { code, error in
        if let code {
          continuation.resume(returning: code)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /** @fn applyActionCode:completion:
      @brief Applies out of band code.

      @param code The out of band code to be applied.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.

      @remarks This method will not work for out of band codes which require an additional parameter,
          such as password reset code.
   */
  @objc public func applyActionCode(_ code: String, completion: @escaping (Error?) -> Void) {
    kAuthGlobalWorkQueue.async {
      let request = SetAccountInfoRequest(requestConfiguration: self.requestConfiguration)
      request.oobCode = code
      AuthBackend.post(withRequest: request) { rawResponse, error in
        DispatchQueue.main.async {
          completion(error)
        }
      }
    }
  }

  /** @fn applyActionCode:completion:
      @brief Applies out of band code.

      @param code The out of band code to be applied.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.

      @remarks This method will not work for out of band codes which require an additional parameter,
          such as password reset code.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func applyActionCode(_ code: String) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.applyActionCode(code) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /** @fn sendPasswordResetWithEmail:completion:
      @brief Initiates a password reset for the given email address.

      @param email The email address of the user.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
              sent in the request.
          + `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
              the console for this action.
          + `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
              sending update email.

   */
  @objc public func sendPasswordReset(withEmail email: String,
                                      completion: ((Error?) -> Void)? = nil) {
    sendPasswordReset(withEmail: email, actionCodeSettings: nil, completion: completion)
  }

  /** @fn sendPasswordResetWithEmail:actionCodeSetting:completion:
      @brief Initiates a password reset for the given email address and `ActionCodeSettings` object.

      @param email The email address of the user.
      @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
          handling action codes.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
              sent in the request.
          + `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
              the console for this action.
          + `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
              sending update email.
          + `AuthErrorCodeMissingIosBundleID` - Indicates that the iOS bundle ID is missing when
              `handleCodeInApp` is set to true.
          + `AuthErrorCodeMissingAndroidPackageName` - Indicates that the android package name
              is missing when the `androidInstallApp` flag is set to true.
          + `AuthErrorCodeUnauthorizedDomain` - Indicates that the domain specified in the
              continue URL is not allowlisted in the Firebase console.
          + `AuthErrorCodeInvalidContinueURI` - Indicates that the domain specified in the
              continue URL is not valid.

   */
  @objc public func sendPasswordReset(withEmail email: String,
                                      actionCodeSettings: ActionCodeSettings?,
                                      completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let request = GetOOBConfirmationCodeRequest.passwordResetRequest(
        email: email,
        actionCodeSettings: actionCodeSettings,
        requestConfiguration: self.requestConfiguration)
      AuthBackend.post(withRequest: request) { response, error in
        if let completion {
          DispatchQueue.main.async {
            completion(error)
          }
        }
      }
    }
  }

  /** @fn sendPasswordResetWithEmail:actionCodeSetting:completion:
      @brief Initiates a password reset for the given email address and `ActionCodeSettings` object.

      @param email The email address of the user.
      @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
          handling action codes.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
              sent in the request.
          + `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
              the console for this action.
          + `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
              sending update email.
          + `AuthErrorCodeMissingIosBundleID` - Indicates that the iOS bundle ID is missing when
              `handleCodeInApp` is set to true.
          + `AuthErrorCodeMissingAndroidPackageName` - Indicates that the android package name
              is missing when the `androidInstallApp` flag is set to true.
          + `AuthErrorCodeUnauthorizedDomain` - Indicates that the domain specified in the
              continue URL is not allowlisted in the Firebase console.
          + `AuthErrorCodeInvalidContinueURI` - Indicates that the domain specified in the
              continue URL is not valid.

   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func sendPasswordReset(withEmail email: String,
                                actionCodeSettings: ActionCodeSettings? = nil) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.sendPasswordReset(withEmail: email, actionCodeSettings: actionCodeSettings) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /** @fn sendSignInLinkToEmail:actionCodeSettings:completion:
      @brief Sends a sign in with email link to provided email address.

      @param email The email address of the user.
      @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
          handling action codes.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.
   */
  @objc public func sendSignInLink(toEmail email: String,
                                   actionCodeSettings: ActionCodeSettings,
                                   completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let request = GetOOBConfirmationCodeRequest.signInWithEmailLinkRequest(
        email,
        actionCodeSettings: actionCodeSettings,
        requestConfiguration: self.requestConfiguration)
      AuthBackend.post(withRequest: request) { response, error in
        if let completion {
          DispatchQueue.main.async {
            completion(error)
          }
        }
      }
    }
  }

  /** @fn sendSignInLinkToEmail:actionCodeSettings:completion:
      @brief Sends a sign in with email link to provided email address.

      @param email The email address of the user.
      @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
          handling action codes.
      @param completion Optionally; a block which is invoked when the request finishes. Invoked
          asynchronously on the main thread in the future.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func sendSignInLink(toEmail email: String,
                             actionCodeSettings: ActionCodeSettings) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /** @fn signOut:
      @brief Signs out the current user.

      @param error Optionally; if an error occurs, upon return contains an NSError object that
          describes the problem; is nil otherwise.
      @return @YES when the sign out request was successful. @NO otherwise.

      @remarks Possible error codes:

          + `AuthErrorCodeKeychainError` - Indicates an error occurred when accessing the
              keychain. The `NSLocalizedFailureReasonErrorKey` field in the `userInfo`
              dictionary will contain more information about the error encountered.

   */
  @objc public func signOut() throws {
    try kAuthGlobalWorkQueue.sync {
      guard self.currentUser != nil else {
        return
      }
      return try self.updateCurrentUser(user: nil, byForce: false, savingToDisk: true)
    }
  }

  /** @fn isSignInWithEmailLink
      @brief Checks if link is an email sign-in link.

      @param link The email sign-in link.
      @return Returns true when the link passed matches the expected format of an email sign-in link.
   */
  @objc public func isSignIn(withEmailLink link: String) -> Bool {
    guard link.count > 0 else {
      return false
    }
    let queryItems = getQueryItems(link)
    if let _ = queryItems["oobCode"],
       let mode = queryItems["signIn"],
       mode == "signIn" {
      return true
    }
    return false
  }

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
          the long-lived block. The block itself will be retained by `Auth` until it is
          unregistered or until the `Auth` instance is otherwise deallocated.

      @return A handle useful for manually unregistering the block as a listener.
   */
  @objc(addAuthStateDidChangeListener:)
  public func addStateDidChangeListener(_ listener: @escaping (Auth, User?) -> Void)
  -> AuthStateDidChangeListenerHandle {
    var firstInvocation = true
    var previousUserID: String? = nil
    return addIDTokenDidChangeListener() { auth, user in
      let shouldCallListener = firstInvocation || previousUserID != user?.uid
      firstInvocation = false
      previousUserID = user?.uid
      if shouldCallListener {
        listener(auth, user)
      }
    }
  }

  /** @fn removeAuthStateDidChangeListener:
      @brief Unregisters a block as an "auth state did change" listener.

      @param listenerHandle The handle for the listener.
   */
  @objc(removeAuthStateDidChangeListener:)
  public func removeStateDidChangeListener(_ listenerHandle: AuthStateDidChangeListenerHandle) {
    NotificationCenter.default.removeObserver(listenerHandle)
    //TODO
    @synchronized(self) {
      [_listenerHandles removeObject:listenerHandle];
    }
  }

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
          the long-lived block. The block itself will be retained by `Auth` until it is
          unregistered or until the `Auth` instance is otherwise deallocated.

      @return A handle useful for manually unregistering the block as a listener.
   */
  @objc public func addIDTokenDidChangeListener(_ listener: @escaping (Auth, User?) -> Void)
  -> IDTokenDidChangeListenerHandle {

  }

  /** @fn removeIDTokenDidChangeListener:
      @brief Unregisters a block as an "ID token did change" listener.

      @param listenerHandle The handle for the listener.
   */
  @objc public func removeIDTokenDidChangeListener(_ listenerHandle: IDTokenDidChangeListenerHandle) {

  }

  /** @fn useAppLanguage
      @brief Sets `languageCode` to the app's current language.
   */
  @objc public func useAppLanguage() {

  }

  /** @fn useEmulatorWithHost:port
      @brief Configures Firebase Auth to connect to an emulated host instead of the remote backend.
   */
  @objc public func useEmulator(withHost host: String, port: Int) {

  }

  /** @fn revokeTokenWithAuthorizationCode:Completion
      @brief Revoke the users token with authorization code.
      @param completion (Optional) the block invoked when the request to revoke the token is
          complete, or fails. Invoked asynchronously on the main thread in the future.
   */
  @objc public func revokeToken(withAuthorizationCode authorizationCode: String,
                                completion: ((Error?) -> Void)? = nil) {

  }

  /** @fn revokeTokenWithAuthorizationCode:Completion
      @brief Revoke the users token with authorization code.
      @param completion (Optional) the block invoked when the request to revoke the token is
          complete, or fails. Invoked asynchronously on the main thread in the future.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
 public func revokeToken(withAuthorizationCode authorizationCode: String) async throws {

  }

  /** @fn useUserAccessGroup:error:
      @brief Switch userAccessGroup and current user to the given accessGroup and the user stored in
          it.
   */
  @objc public func useUserAccessGroup(_ accessGroup: String?) throws {}


// TODO: objc implementation?

  /** @fn getStoredUserForAccessGroup:error:
      @brief Get the stored user in the given accessGroup.
      @note This API is not supported on tvOS when `shareAuthStateAcrossDevices` is set to `true`.
          This case will return `nil`.
          Please refer to https://github.com/firebase/firebase-ios-sdk/issues/8878 for details.
   */
  public func getStoredUser(forAccessGroup accessGroup: String?) throws -> User? {}

  // TODO: Need to manage breaking change for
  // const NSNotificationName FIRAuthStateDidChangeNotification = @"FIRAuthStateDidChangeNotification";
  // Move to FIRApp with other Auth notifications?
  public let authStateDidChangeNotification =
    NSNotification.Name(rawValue: "FIRAuthStateDidChangeNotification")

  // MARK: Internal methods

  init(withApp app: FirebaseApp) {
    self.app = app
    mainBundleUrlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
  }

  func updateKeychain(withUser user: User?) -> Error? {
    if user != currentUser {
      // No-op if the user is no longer signed in. This is not considered an error as we don't check
      // whether the user is still current on other callbacks of user operations either.
      return nil
    }
    do {
      try saveUser(user)
      self.possiblyPostAuthStateChangeNotification()
    } catch {
      return error
    }
    return nil
  }

  // MARK: Private methods

  /** @fn possiblyPostAuthStateChangeNotification
      @brief Posts the auth state change notificaton if current user's token has been changed.
   */
  private func possiblyPostAuthStateChangeNotification() {
    let token = self.currentUser?.rawAccessToken()
    if self.lastNotifiedUserToken == token ||
      (token != nil && self.lastNotifiedUserToken == token) {
      return
    }
    lastNotifiedUserToken = token
    if autoRefreshTokens {
      // Shedule new refresh task after successful attempt.
      self.scheduleAutoTokenRefresh()
    }
    var internalNotificationParameters: [String: Any] = [:]
    if let app = self.app {
      internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationAppKey] = app
    }
    if let token, token.count > 0 {
      internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationTokenKey] = token
    }
    internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationUIDKey] = currentUser?
      .uid
    let notifications = NotificationCenter()
    DispatchQueue.main.async {
      notifications.post(name: NSNotification.Name.FIRAuthStateDidChangeInternal,
                         object: self,
                         userInfo: internalNotificationParameters)
      notifications.post(name: self.authStateDidChangeNotification, object: self)
    }
  }

  /** @fn scheduleAutoTokenRefreshWithDelay:
      @brief Schedules a task to automatically refresh tokens on the current user. The0 token refresh
          is scheduled 5 minutes before the  scheduled expiration time.
      @remarks If the token expires in less than 5 minutes, schedule the token refresh immediately.
   */
  private func scheduleAutoTokenRefresh() {
    let tokenExpirationInterval =
      (currentUser?.accessTokenExpirationDate()?.timeIntervalSinceNow ?? 0) - 5 * 60
    self.scheduleAutoTokenRefresh(withDelay: max(tokenExpirationInterval, 0), retry: false)
  }

  /** @fn scheduleAutoTokenRefreshWithDelay:
      @brief Schedules a task to automatically refresh tokens on the current user.
      @param delay The delay in seconds after which the token refresh task should be scheduled to be
          executed.
      @param retry Flag to determine whether the invocation is a retry attempt or not.
   */
  private func scheduleAutoTokenRefresh(withDelay delay: TimeInterval, retry: Bool) {
    guard let accessToken = currentUser?.rawAccessToken() else {
      return
    }
    let intDelay = Int(ceil(delay))
    if retry {
      AuthLog.logInfo(code: "I-AUT000003", message: "Token auto-refresh re-scheduled in " +
        "\(intDelay / 60):\(intDelay % 60) " +
        "because of error on previous refresh attempt.")
    } else {
      AuthLog.logInfo(code: "I-AUT000004", message: "Token auto-refresh scheduled in " +
        "\(intDelay / 60):\(intDelay % 60) " +
        "for the new token.")
    }
    self.autoRefreshScheduled = true
    weak var weakSelf = self
    AuthDispatcher.shared.dispatch(afterDelay: delay, queue: kAuthGlobalWorkQueue) {
      guard let strongSelf = weakSelf else {
        return
      }
      guard strongSelf.currentUser?.rawAccessToken() == accessToken else {
        // Another auto refresh must have been scheduled, so keep
        // _autoRefreshScheduled unchanged.
        return
      }
      strongSelf.autoRefreshScheduled = false
      if strongSelf.isAppInBackground {
        return
      }
      let uid = strongSelf.currentUser?.uid
      strongSelf.currentUser?.internalGetToken(forceRefresh: true) { token, error in
        if strongSelf.currentUser?.uid == uid {
          return
        }
        if let error {
          // Kicks off exponential back off logic to retry failed attempt. Starts with one minute delay
          // (60 seconds) if this is the first failed attempt.
          let rescheduleDelay = retry ? min(delay * 2, 16 * 60) : 60
          strongSelf.scheduleAutoTokenRefresh(withDelay: rescheduleDelay, retry: true)
        }
      }
    }
  }

  /** @fn updateCurrentUser:byForce:savingToDisk:error:
      @brief Update the current user; initializing the user's internal properties correctly, and
          optionally saving the user to disk.
      @remarks This method is called during: sign in and sign out events, as well as during class
          initialization time. The only time the saveToDisk parameter should be set to NO is during
          class initialization time because the user was just read from disk.
      @param user The user to use as the current user (including nil, which is passed at sign out
          time.)
      @param saveToDisk Indicates the method should persist the user data to disk.
   */
  private func updateCurrentUser(user: User?, byForce force: Bool,
                                 savingToDisk saveToDisk: Bool) throws {
    if user == self.currentUser {
      self.possiblyPostAuthStateChangeNotification()
    }
    if let user {
      if user.tenantID != nil || self.tenantID != nil, self.tenantID != user.tenantID {
        let error = AuthErrorUtils.tenantIDMismatchError()
        throw error
      }
    }
    var throwError: Error?
    if saveToDisk {
      do {
        try self.saveUser(user)
      } catch {
        throwError = error
      }
    }
    if throwError == nil || force {
      currentUser = user
      self.possiblyPostAuthStateChangeNotification()
    }
    if let throwError {
      throw throwError
    }
  }

  private func saveUser(_ user: User?) throws {
    if let userAccessGroup {
      guard let apiKey = self.app?.options.apiKey else {
        fatalError("Internal Auth Error: Missing apiKey in saveUser")
      }
      if let user {
        try storedUserManager.setStoredUser(user: user,
                                            accessGroup: userAccessGroup,
                                            shareAuthStateAcrossDevices: shareAuthStateAcrossDevices,
                                            projectIdentifier: apiKey)
      } else {
        try storedUserManager.removeStoredUser(
          accessGroup: userAccessGroup,
          shareAuthStateAcrossDevices: self.shareAuthStateAcrossDevices,
          projectIdentifier: apiKey
        )
      }
    } else {
      let userKey = "\(firebaseAppName)_firebase_user"
      if let user {
        #if os(watchOS)
          let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        #else
          // Encode the user object.
          let archiveData = NSMutableData()
          let archiver = NSKeyedArchiver(forWritingWith: archiveData)
        #endif
        archiver.encode(user, forKey: userKey)
        archiver.finishEncoding()
        #if os(watchOS)
          let archiveData = archiver.encodedData
        #endif
        // Save the user object's encoded value.
        try keychainServices.setData(archiveData as Data, forKey: userKey)
      } else {
        try keychainServices.removeData(forKey: userKey)
      }
    }
  }

  /** @fn completeSignInWithTokenService:callback:
      @brief Completes a sign-in flow once we have access and refresh tokens for the user.
      @param accessToken The STS access token.
      @param accessTokenExpirationDate The approximate expiration date of the access token.
      @param refreshToken The STS refresh token.
      @param anonymous Whether or not the user is anonymous.
      @param callback Called when the user has been signed in or when an error occurred. Invoked
          asynchronously on the global auth work queue in the future.
   */
  private func completeSignIn(withAccessToken accessToken: String?,
                              accessTokenExpirationDate: Date?,
                              refreshToken: String?,
                              anonymous: Bool,
                              callback: @escaping ((User?, Error?) -> Void)) {
    User.retrieveUser(withAuth: self,
                      accessToken: accessToken,
                      accessTokenExpirationDate: accessTokenExpirationDate,
                      refreshToken: refreshToken,
                      anonymous: anonymous,
                      callback: callback)
  }

  /** @fn internalSignInAndRetrieveDataWithEmail:password:callback:
      @brief Signs in using an email address and password.
      @param email The user's email address.
      @param password The user's password.
      @param completion A block which is invoked when the sign in finishes (or is cancelled.) Invoked
          asynchronously on the global auth work queue in the future.
      @remarks This is the internal counterpart of this method, which uses a callback that does not
          update the current user.
   */
  private func internalSignInAndRetrieveData(withEmail email: String, password: String,
                                             completion: ((AuthDataResult?, Error?) -> Void)?) {
    let credential = EmailAuthCredential(withEmail: email, password: password)
    self.internalSignInAndRetrieveData(withCredential: credential,
                                       isReauthentication: false,
                                       callback: completion)
  }

  private func internalSignInAndRetrieveData(withCredential credential: AuthCredential,
                                             isReauthentication: Bool,
                                             callback: ((AuthDataResult?, Error?) -> Void)?) {
    if let emailCredential = credential as? EmailAuthCredential {
      // Special case for email/password credentials
      switch emailCredential.emailType {
      case let .link(link):
        // Email link sign in
        self.internalSignInAndRetrieveData(withEmail: emailCredential.email,
                                           link: link,
                                           callback: callback)
      case let .password(password):
        // Email password sign in
        let completeEmailSignIn: (User?, Error?) -> Void = { user, error in
          if let callback {
            if let error {
              callback(nil, error)
              return
            }
            guard let user else {
              // TODO: This matches ObjC code but seems wrong.
              callback(nil, nil)
              return
            }
            let additionalUserInfo = AdditionalUserInfo(providerID: EmailAuthProvider.id,
                                                        profile: nil,
                                                        username: nil,
                                                        isNewUser: false)
            let result = AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
            callback(result, nil)
          }
        }
        self.signIn(withEmail: emailCredential.email,
                    password: password,
                    callback: completeEmailSignIn)
      }
      return
    }
    if let gameCenterCredential = credential as? GameCenterAuthCredential {
      self.signInAndRetrieveData(withGameCenterCredential: gameCenterCredential,
                                 callback: callback)
      return
    }
    #if os(iOS)
      if let phoneCredential = credential as? PhoneAuthCredential {
        // Special case for phone auth credentials
        let operation = isReauthentication ? AuthOperationType.reauth : AuthOperationType
          .signUpOrSignIn
        self
          .signIn(withPhoneCredential: phoneCredential,
                  operation: operation) { rawResponse, error in
            if let callback {
              if let error {
                callback(nil, error)
                return
              }
              guard let response = rawResponse as? VerifyPhoneNumberResponse else {
                fatalError("Internal Auth Error: Failed to get a VerifyPhoneNumberResponse")
              }
              self.completeSignIn(withAccessToken: response.idToken,
                                  accessTokenExpirationDate: response.approximateExpirationDate,
                                  refreshToken: response.refreshToken,
                                  anonymous: false) { user, error in
                if let error {
                  callback(nil, error)
                  return
                }
                if let user {
                  let additionalUserInfo = AdditionalUserInfo(providerID: PhoneAuthProvider.id,
                                                              profile: nil,
                                                              username: nil,
                                                              isNewUser: response.isNewUser)
                  let result = AuthDataResult(
                    withUser: user,
                    additionalUserInfo: additionalUserInfo
                  )
                  callback(result, nil)
                } else {
                  callback(nil, nil)
                }
              }
            }
          }
        return
      }
    #endif

    let request = VerifyAssertionRequest(providerID: credential.provider,
                                         requestConfiguration: requestConfiguration)
    request.autoCreate = !isReauthentication
    credential.prepare(request)
    AuthBackend.post(withRequest: request) { rawResponse, error in
      if let error {
        if let callback {
          callback(nil, error)
        }
        return
      }
      guard let response = rawResponse as? VerifyAssertionResponse else {
        fatalError("Internal Auth Error: Failed to get a VerifyAssertionResponse")
      }
      if response.needConfirmation {
        if let callback {
          let email = response.email
          let credential = OAuthCredential(withVerifyAssertionResponse: response)
          callback(nil, AuthErrorUtils.accountExistsWithDifferentCredentialError(
            email: email,
            updatedCredential: credential
          ))
        }
        return
      }
      guard let providerID = response.providerID, providerID.count > 0 else {
        if let callback {
          callback(nil, AuthErrorUtils.unexpectedResponse(deserializedResponse: response))
        }
        return
      }
      self.completeSignIn(withAccessToken: response.idToken,
                          accessTokenExpirationDate: response.approximateExpirationDate,
                          refreshToken: response.refreshToken,
                          anonymous: false) { user, error in
        if let callback {
          if let error {
            callback(nil, error)
            return
          }
          if let user {
            let additionalUserInfo = AdditionalUserInfo.userInfo(verifyAssertionResponse: response)
            let updatedOAuthCredential = OAuthCredential(withVerifyAssertionResponse: response)
            let result = AuthDataResult(withUser: user,
                                        additionalUserInfo: additionalUserInfo,
                                        credential: updatedOAuthCredential)
            callback(result, error)
          } else {
            callback(nil, nil)
          }
        }
      }
    }
  }

  #if os(iOS)
    /** @fn signInWithPhoneCredential:callback:
        @brief Signs in using a phone credential.
        @param credential The Phone Auth credential used to sign in.
        @param operation The type of operation for which this sign-in attempt is initiated.
        @param callback A block which is invoked when the sign in finishes (or is cancelled.) Invoked
            asynchronously on the global auth work queue in the future.
     */
    private func signIn(withPhoneCredential credential: PhoneAuthCredential,
                        operation: AuthOperationType,
                        callback: @escaping (AuthRPCResponse?, Error?) -> Void) {
      if let temporaryProof = credential.temporaryProof, temporaryProof.count > 0,
         let phoneNumber = credential.phoneNumber, phoneNumber.count > 0 {
        let request = VerifyPhoneNumberRequest(temporaryProof: temporaryProof,
                                               phoneNumber: phoneNumber,
                                               operation: operation,
                                               requestConfiguration: requestConfiguration)
        AuthBackend.post(withRequest: request, callback: callback)
        return
      }
      guard let verificationID = credential.verificationID, verificationID.count > 0 else {
        callback(nil, AuthErrorUtils.missingVerificationIDError(message: nil))
        return
      }
      guard let verificationCode = credential.verificationCode, verificationCode.count > 0 else {
        callback(nil, AuthErrorUtils.missingVerificationCodeError(message: nil))
        return
      }
      let request = VerifyPhoneNumberRequest(verificationID: verificationID,
                                             verificationCode: verificationCode,
                                             operation: operation,
                                             requestConfiguration: requestConfiguration)
      AuthBackend.post(withRequest: request, callback: callback)
    }
  #endif

  /** @fn signInAndRetrieveDataWithGameCenterCredential:callback:
      @brief Signs in using a game center credential.
      @param credential The Game Center Auth Credential used to sign in.
      @param callback A block which is invoked when the sign in finished (or is cancelled). Invoked
          asynchronously on the global auth work queue in the future.
   */
  private func signInAndRetrieveData(withGameCenterCredential credential: GameCenterAuthCredential,
                                     callback: ((AuthDataResult?, Error?) -> Void)?) {
    guard let publicKeyURL = credential.publicKeyURL,
          let signature = credential.signature,
          let salt = credential.salt else {
      fatalError(
        "Internal Auth Error: Game Center credential missing publicKeyURL, signature, or salt"
      )
    }
    let request = SignInWithGameCenterRequest(playerID: credential.playerID,
                                              teamPlayerID: credential.teamPlayerID,
                                              gamePlayerID: credential.gamePlayerID,
                                              publicKeyURL: publicKeyURL,
                                              signature: signature,
                                              salt: salt,
                                              timestamp: credential.timestamp,
                                              displayName: credential.displayName,
                                              requestConfiguration: requestConfiguration)
    AuthBackend.post(withRequest: request) { rawResponse, error in
      if let error {
        if let callback {
          callback(nil, error)
        }
        return
      }
      guard let response = rawResponse as? SignInWithGameCenterResponse else {
        fatalError("Internal Auth Error: Failed to get a SignInWithGameCenterResponse")
      }
      self.completeSignIn(withAccessToken: response.idToken,
                          accessTokenExpirationDate: response.approximateExpirationDate,
                          refreshToken: response.refreshToken,
                          anonymous: false) { user, error in
        if let callback {
          if let error {
            callback(nil, error)
            return
          }
          if let user {
            let additionalUserInfo = AdditionalUserInfo(providerID: GameCenterAuthProvider.id,
                                                        profile: nil,
                                                        username: nil,
                                                        isNewUser: response.isNewUser)
            let result = AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
            callback(result, nil)
          } else {
            callback(nil, nil)
          }
        }
      }
    }
  }

  /** @fn internalSignInAndRetrieveDataWithEmail:link:completion:
      @brief Signs in using an email and email sign-in link.
      @param email The user's email address.
      @param link The email sign-in link.
      @param callback A block which is invoked when the sign in finishes (or is cancelled.) Invoked
          asynchronously on the global auth work queue in the future.
   */
  private func internalSignInAndRetrieveData(withEmail email: String,
                                             link: String,
                                             callback: ((AuthDataResult?, Error?) -> Void)?) {
    guard isSignIn(withEmailLink: link) else {
      fatalError("The link provided is not valid for email/link sign-in. Please check the link by " +
        "calling isSignIn(withEmailLink:) on the Auth instance before attempting to use it " +
        "for email/link sign-in.")
    }
    let queryItems = getQueryItems(link)
    guard let actionCode = queryItems["oobCode"] else {
      fatalError("Missing oobCode in link URL")
    }
    let request = EmailLinkSignInRequest(email: email,
                                         oobCode: actionCode,
                                         requestConfiguration: requestConfiguration)
    AuthBackend.post(withRequest: request) { rawResponse, error in
      if let error {
        if let callback {
          callback(nil, error)
        }
        return
      }
      guard let response = rawResponse as? EmailLinkSignInResponse else {
        fatalError("Internal Auth Error: Failed to get a EmailLinkSignInResponse")
      }
      self.completeSignIn(withAccessToken: response.idToken,
                          accessTokenExpirationDate: response.approximateExpirationDate,
                          refreshToken: response.refreshToken,
                          anonymous: false) { user, error in
        if let callback {
          if let error {
            callback(nil, error)
            return
          }
          if let user {
            let additionalUserInfo = AdditionalUserInfo(providerID: EmailAuthProvider.id,
                                                        profile: nil,
                                                        username: nil,
                                                        isNewUser: response.isNewUser)
            let result = AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
            callback(result, nil)
          } else {
            callback(nil, nil)
          }
        }
      }
    }
  }

  private func getQueryItems(_ link: String) -> [String: String] {
    var queryItems = AuthWebUtils.parseURL(link)
    if queryItems.count == 0 {
      let urlComponents = URLComponents(string: link)
      if let query = urlComponents?.query {
        queryItems = AuthWebUtils.parseURL(query)
      }
    }
    return queryItems
  }

  /** @fn signInFlowAuthDataResultCallbackByDecoratingCallback:
       @brief Creates a FIRAuthDataResultCallback block which wraps another FIRAuthDataResultCallback;
           trying to update the current user before forwarding it's invocations along to a subject
           block.
       @param callback Called when the user has been updated or when an error has occurred. Invoked
           asynchronously on the main thread in the future.
       @return Returns a block that updates the current user.
       @remarks Typically invoked as part of the complete sign-in flow. For any other uses please
           consider alternative ways of updating the current user.
   */
  private func signInFlowAuthDataResultCallback(byDecorating callback:
    ((AuthDataResult?, Error?) -> Void)?) -> (AuthDataResult?, Error?) -> Void {
    let authDataCallback: (((AuthDataResult?, Error?) -> Void)?, AuthDataResult?, Error?) -> Void =
      { callback, result, error in
        if let callback {
          DispatchQueue.main.async {
            callback(result, error)
          }
        }
      }
    return { authResult, error in
      if let error {
        authDataCallback(callback, nil, error)
        return
      }
      do {
        try self.updateCurrentUser(user: authResult?.user, byForce: false, savingToDisk: true)
      } catch {
        authDataCallback(callback, nil, error)
        return
      }
      authDataCallback(callback, authResult, nil)
    }
  }

  // MARK: Internal properties

  /** @property mainBundle
      @brief Allow tests to swap in an alternate mainBundle.
   */
  internal var mainBundleUrlTypes: [[String: Any]]?

  /** @property requestConfiguration
      @brief The configuration object comprising of paramters needed to make a request to Firebase
          Auth's backend.
   */
  internal let requestConfiguration: AuthRequestConfiguration

  #if os(iOS)

    /** @property tokenManager
        @brief The manager for APNs tokens used by phone number auth.
     */
    internal let tokenManager: AuthAPNSTokenManager

    /** @property appCredentailManager
        @brief The manager for app credentials used by phone number auth.
     */
    internal let appCredentialManager: AuthAppCredentialManager

    /** @property notificationManager
        @brief The manager for remote notifications used by phone number auth.
     */
    internal let notificationManager: AuthNotificationManager

  #endif // TARGET_OS_IOS

  /** @property authURLPresenter
      @brief An object that takes care of presenting URLs via the auth instance.
   */
  internal let authURLPresenter: AuthURLPresenter

  // MARK: Private properties

  /** @property storedUserManager
      @brief The stored user manager.
   */
  private var storedUserManager: AuthStoredUserManager

  /** @var _firebaseAppName
      @brief The Firebase app name.
   */
  private let firebaseAppName: String

  /** @var _keychainServices
      @brief The keychain service.
   */
  private var keychainServices: AuthKeychainServices

  /** @var _lastNotifiedUserToken
      @brief The user access (ID) token used last time for posting auth state changed notification.
   */
  private var lastNotifiedUserToken: String?

  /** @var _autoRefreshTokens
      @brief This flag denotes whether or not tokens should be automatically refreshed.
      @remarks Will only be set to @YES if the another Firebase service is included (additionally to
        Firebase Auth).
   */
  private var autoRefreshTokens = false

  /** @var _autoRefreshScheduled
      @brief Whether or not token auto-refresh is currently scheduled.
   */
  private var autoRefreshScheduled = false

  /** @var _isAppInBackground
      @brief A flag that is set to YES if the app is put in the background and no when the app is
          returned to the foreground.
   */
  private var isAppInBackground = false
}
