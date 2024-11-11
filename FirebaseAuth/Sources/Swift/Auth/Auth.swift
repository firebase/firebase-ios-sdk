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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import FirebaseCore
import FirebaseCoreExtension
#if COCOAPODS
  @_implementationOnly import GoogleUtilities
#else
  @_implementationOnly import GoogleUtilities_AppDelegateSwizzler
  @_implementationOnly import GoogleUtilities_Environment
#endif

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
  import UIKit
#endif

// Export the deprecated Objective-C defined globals and typedefs.
#if SWIFT_PACKAGE
  @_exported import FirebaseAuthInternal
#endif // SWIFT_PACKAGE

#if os(iOS)
  @available(iOS 13.0, *)
  extension Auth: UISceneDelegate {
    open func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
      for urlContext in URLContexts {
        let _ = canHandle(urlContext.url)
      }
    }
  }

  @available(iOS 13.0, *)
  extension Auth: UIApplicationDelegate {
    open func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      setAPNSToken(deviceToken, type: .unknown)
    }

    open func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
      kAuthGlobalWorkQueue.sync {
        self.tokenManager.cancel(withError: error)
      }
    }

    open func application(_ application: UIApplication,
                          didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                          fetchCompletionHandler completionHandler:
                          @escaping (UIBackgroundFetchResult) -> Void) {
      _ = canHandleNotification(userInfo)
      completionHandler(UIBackgroundFetchResult.noData)
    }

    open func application(_ application: UIApplication,
                          open url: URL,
                          options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
      return canHandle(url)
    }
  }
#endif

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
extension Auth: AuthInterop {
  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  ///
  /// This method is not for public use. It is for Firebase clients of AuthInterop.
  @objc(getTokenForcingRefresh:withCallback:)
  public func getToken(forcingRefresh forceRefresh: Bool,
                       completion callback: @escaping (String?, Error?) -> Void) {
    kAuthGlobalWorkQueue.async { [weak self] in
      if let strongSelf = self {
        // Enable token auto-refresh if not already enabled.
        if !strongSelf.autoRefreshTokens {
          AuthLog.logInfo(code: "I-AUT000002", message: "Token auto-refresh enabled.")
          strongSelf.autoRefreshTokens = true
          strongSelf.scheduleAutoTokenRefresh()

          #if os(iOS) || os(tvOS) // TODO(ObjC): Is a similar mechanism needed on macOS?
            strongSelf.applicationDidBecomeActiveObserver =
              NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil, queue: nil
              ) { notification in
                if let strongSelf = self {
                  strongSelf.isAppInBackground = false
                  if !strongSelf.autoRefreshScheduled {
                    strongSelf.scheduleAutoTokenRefresh()
                  }
                }
              }
            strongSelf.applicationDidEnterBackgroundObserver =
              NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: nil
              ) { notification in
                if let strongSelf = self {
                  strongSelf.isAppInBackground = true
                }
              }
          #endif
        }
      }
      // Call back with 'nil' if there is no current user.
      guard let strongSelf = self, let currentUser = strongSelf._currentUser else {
        DispatchQueue.main.async {
          callback(nil, nil)
        }
        return
      }
      // Call back with current user token.
      currentUser
        .internalGetToken(forceRefresh: forceRefresh, backend: strongSelf.backend) { token, error in
          DispatchQueue.main.async {
            callback(token, error)
          }
        }
    }
  }

  /// Get the current Auth user's UID. Returns nil if there is no user signed in.
  ///
  /// This method is not for public use. It is for Firebase clients of AuthInterop.
  open func getUserID() -> String? {
    return _currentUser?.uid
  }
}

/// Manages authentication for Firebase apps.
///
/// This class is thread-safe.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRAuth) open class Auth: NSObject {
  /// Gets the auth object for the default Firebase app.
  ///
  /// The default Firebase app must have already been configured or an exception will be raised.
  @objc open class func auth() -> Auth {
    guard let defaultApp = FirebaseApp.app() else {
      fatalError("The default FirebaseApp instance must be configured before the default Auth " +
        "instance can be initialized. One way to ensure this is to call " +
        "`FirebaseApp.configure()` in the App Delegate's " +
        "`application(_:didFinishLaunchingWithOptions:)` (or the `@main` struct's " +
        "initializer in SwiftUI).")
    }
    return auth(app: defaultApp)
  }

  /// Gets the auth object for a `FirebaseApp`.
  /// - Parameter app: The app for which to retrieve the associated `Auth` instance.
  /// - Returns: The `Auth` instance associated with the given app.
  @objc open class func auth(app: FirebaseApp) -> Auth {
    return ComponentType<AuthInterop>.instance(for: AuthInterop.self, in: app.container) as! Auth
  }

  /// Gets the `FirebaseApp` object that this auth object is connected to.
  @objc public internal(set) weak var app: FirebaseApp?

  /// Synchronously gets the cached current user, or null if there is none.
  @objc public var currentUser: User? {
    kAuthGlobalWorkQueue.sync {
      _currentUser
    }
  }

  private var _currentUser: User?

  /// The current user language code.
  ///
  /// This property can be set to the app's current language by
  /// calling `useAppLanguage()`.
  ///
  /// The string used to set this property must be a language code that follows BCP 47.
  @objc open var languageCode: String? {
    get {
      kAuthGlobalWorkQueue.sync {
        requestConfiguration.languageCode
      }
    }
    set(val) {
      kAuthGlobalWorkQueue.sync {
        requestConfiguration.languageCode = val
      }
    }
  }

  /// Contains settings related to the auth object.
  @NSCopying @objc open var settings: AuthSettings?

  /// The current user access group that the Auth instance is using.
  ///
  /// Default is `nil`.
  @objc public internal(set) var userAccessGroup: String?

  /// Contains shareAuthStateAcrossDevices setting related to the auth object.
  ///
  /// If userAccessGroup is not set, setting shareAuthStateAcrossDevices will
  /// have no effect. You should set shareAuthStateAcrossDevices to its desired
  /// state and then set the userAccessGroup after.
  @objc open var shareAuthStateAcrossDevices: Bool = false

  /// The tenant ID of the auth instance. `nil` if none is available.
  @objc open var tenantID: String?

  /// The custom authentication domain used to handle all sign-in redirects.
  /// End-users will see
  /// this domain when signing in. This domain must be allowlisted in the Firebase Console.
  @objc open var customAuthDomain: String?

  /// Sets the `currentUser` on the receiver to the provided user object.
  /// - Parameters:
  ///   - user: The user object to be set as the current user of the calling Auth instance.
  ///   - completion: Optionally; a block invoked after the user of the calling Auth instance has
  ///             been updated or an error was encountered.
  @objc open func updateCurrentUser(_ user: User?, completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      guard let user else {
        let error = AuthErrorUtils.nullUserError(message: nil)
        Auth.wrapMainAsync(completion, error)
        return
      }
      let updateUserBlock: (User) -> Void = { user in
        do {
          try self.updateCurrentUser(user, byForce: true, savingToDisk: true)
          Auth.wrapMainAsync(completion, nil)
        } catch {
          Auth.wrapMainAsync(completion, error)
        }
      }
      if user.requestConfiguration.apiKey != self.requestConfiguration.apiKey {
        // If the API keys are different, then we need to confirm that the user belongs to the same
        // project before proceeding.
        user.requestConfiguration = self.requestConfiguration
        user.reload { error in
          if let error {
            Auth.wrapMainAsync(completion, error)
            return
          }
          updateUserBlock(user)
        }
      } else {
        updateUserBlock(user)
      }
    }
  }

  /// Sets the `currentUser` on the receiver to the provided user object.
  /// - Parameter user: The user object to be set as the current user of the calling Auth instance.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func updateCurrentUser(_ user: User) async throws {
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

  /// [Deprecated] Fetches the list of all sign-in methods previously used for the provided
  /// email address. This method returns an empty list when [Email Enumeration
  /// Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled, irrespective of the number of authentication methods available for the given
  /// email.
  ///
  /// Possible error codes: `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  ///
  /// - Parameter email: The email address for which to obtain a list of sign-in methods.
  /// - Parameter completion: Optionally; a block which is invoked when the list of sign in methods
  /// for the specified email address is ready or an error was encountered. Invoked asynchronously
  /// on the main thread in the future.
  #if !FIREBASE_CI
    @available(
      *,
      deprecated,
      message: "`fetchSignInMethods` is deprecated and will be removed in a future release. This method returns an empty list when Email Enumeration Protection is enabled."
    )
  #endif // !FIREBASE_CI
  @objc open func fetchSignInMethods(forEmail email: String,
                                     completion: (([String]?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let request = CreateAuthURIRequest(identifier: email,
                                         continueURI: "http://www.google.com/",
                                         requestConfiguration: self.requestConfiguration)
      Task {
        do {
          let response = try await self.backend.call(with: request)
          Auth.wrapMainAsync(callback: completion, withParam: response.signinMethods, error: nil)
        } catch {
          Auth.wrapMainAsync(callback: completion, withParam: nil, error: error)
        }
      }
    }
  }

  /// [Deprecated] Fetches the list of all sign-in methods previously used for the provided
  /// email address. This method returns an empty list when [Email Enumeration
  /// Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled, irrespective of the number of authentication methods available for the given
  /// email.
  ///
  /// Possible error codes: `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  ///
  /// - Parameter email: The email address for which to obtain a list of sign-in methods.
  /// - Returns: List of sign-in methods
  @available(
    *,
    deprecated,
    message: "`fetchSignInMethods` is deprecated and will be removed in a future release. This method returns an empty list when Email Enumeration Protection is enabled."
  )
  open func fetchSignInMethods(forEmail email: String) async throws -> [String] {
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

  /// Signs in using an email address and password.
  ///
  /// When [Email Enumeration
  /// Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled, this method fails with an error in case of an invalid
  /// email/password.
  ///
  /// Possible error codes:
  ///  * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
  /// accounts are not enabled. Enable them in the Auth section of the
  /// Firebase console.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted
  /// sign in with an incorrect password.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// - Parameter email: The user's email address.
  /// - Parameter password: The user's password.
  /// - Parameter completion: Optionally; a block which is invoked when the sign in flow finishes,
  /// or is canceled. Invoked asynchronously on the main thread in the future.
  @objc open func signIn(withEmail email: String,
                         password: String,
                         completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      Task {
        do {
          let authData = try await self.internalSignInAndRetrieveData(
            withEmail: email,
            password: password
          )
          decoratedCallback(authData, nil)
        } catch {
          decoratedCallback(nil, error)
        }
      }
    }
  }

  /// Signs in using an email address and password.
  ///
  /// When [Email Enumeration
  /// Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled, this method throws in case of an invalid email/password.
  ///
  /// Possible error codes:
  ///  * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
  /// accounts are not enabled. Enable them in the Auth section of the
  /// Firebase console.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted
  /// sign in with an incorrect password.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// - Parameter email: The user's email address.
  /// - Parameter password: The user's password.
  /// - Returns: The signed in user.
  func internalSignInUser(withEmail email: String,
                          password: String) async throws -> User {
    let request = VerifyPasswordRequest(email: email,
                                        password: password,
                                        requestConfiguration: requestConfiguration)
    if request.password.count == 0 {
      throw AuthErrorUtils.wrongPasswordError(message: nil)
    }
    #if os(iOS)
      let response = try await injectRecaptcha(request: request,
                                               action: AuthRecaptchaAction.signInWithPassword)
    #else
      let response = try await backend.call(with: request)
    #endif
    return try await completeSignIn(
      withAccessToken: response.idToken,
      accessTokenExpirationDate: response.approximateExpirationDate,
      refreshToken: response.refreshToken,
      anonymous: false
    )
  }

  /// Signs in using an email address and password.
  ///
  /// Possible error codes:
  ///  * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
  /// accounts are not enabled. Enable them in the Auth section of the
  /// Firebase console.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted
  /// sign in with an incorrect password.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// - Parameter email: The user's email address.
  /// - Parameter password: The user's password.
  ///  - Returns: The `AuthDataResult` after a successful signin.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  open func signIn(withEmail email: String, password: String) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.signIn(withEmail: email, password: password) { authData, error in
        if let authData {
          continuation.resume(returning: authData)
        } else {
          continuation.resume(throwing: error!)
        }
      }
    }
  }

  /// Signs in using an email address and email sign-in link.
  ///
  /// Possible error codes:
  ///  * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
  /// accounts are not enabled. Enable them in the Auth section of the
  /// Firebase console.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted
  /// sign in with an incorrect password.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// - Parameter email: The user's email address.
  /// - Parameter link: The email sign-in link.
  /// - Parameter completion: Optionally; a block which is invoked when the sign in flow finishes,
  /// or is canceled. Invoked asynchronously on the main thread in the future.
  @objc open func signIn(withEmail email: String,
                         link: String,
                         completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      let credential = EmailAuthCredential(withEmail: email, link: link)
      Task {
        do {
          let authData = try await self.internalSignInAndRetrieveData(withCredential: credential,
                                                                      isReauthentication: false)
          decoratedCallback(authData, nil)
        } catch {
          decoratedCallback(nil, error)
        }
      }
    }
  }

  /// Signs in using an email address and email sign-in link.
  /// Possible error codes:
  ///  * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
  /// accounts are not enabled. Enable them in the Auth section of the
  /// Firebase console.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted
  /// sign in with an incorrect password.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// - Parameter email: The user's email address.
  /// - Parameter link: The email sign-in link.
  ///  - Returns: The `AuthDataResult` after a successful signin.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func signIn(withEmail email: String, link: String) async throws -> AuthDataResult {
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

  #if os(iOS)
    /// Signs in using the provided auth provider instance.
    ///
    /// Possible error codes:
    ///  * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
    /// accounts are not enabled. Enable them in the Auth section of the
    /// Firebase console.
    /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
    /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted
    /// sign in with an incorrect password.
    /// * `AuthErrorCodeWebNetworkRequestFailed` - Indicates that a network request within a
    /// SFSafariViewController or WKWebView failed.
    /// * `AuthErrorCodeWebInternalError` - Indicates that an internal error occurred within a
    /// SFSafariViewController or WKWebView.
    /// * `AuthErrorCodeWebSignInUserInteractionFailure` - Indicates a general failure during
    /// a web sign-in flow.
    /// * `AuthErrorCodeWebContextAlreadyPresented` - Indicates that an attempt was made to
    /// present a new web context while one was already being presented.
    /// * `AuthErrorCodeWebContextCancelled` - Indicates that the URL presentation was
    /// cancelled prematurely by the user.
    /// *  `AuthErrorCodeAccountExistsWithDifferentCredential` - Indicates the email asserted
    /// by the credential (e.g. the email in a Facebook access token) is already in use by an
    /// existing account, that cannot be authenticated with this sign-in method. Call
    /// fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
    /// the sign-in providers returned. This error will only be thrown if the "One account per
    /// email address" setting is enabled in the Firebase console, under Auth settings.
    /// - Parameter provider: An instance of an auth provider used to initiate the sign-in flow.
    /// - Parameter uiDelegate: Optionally an instance of a class conforming to the AuthUIDelegate
    /// protocol, this is used for presenting the web context. If nil, a default AuthUIDelegate
    /// will be used.
    /// - Parameter completion: Optionally; a block which is invoked when the sign in flow finishes,
    /// or is canceled. Invoked asynchronously on the main thread in the future.
    @available(tvOS, unavailable)
    @available(macOS, unavailable)
    @available(watchOS, unavailable)
    @objc(signInWithProvider:UIDelegate:completion:)
    open func signIn(with provider: FederatedAuthProvider,
                     uiDelegate: AuthUIDelegate?,
                     completion: ((AuthDataResult?, Error?) -> Void)?) {
      kAuthGlobalWorkQueue.async {
        Task {
          let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
          do {
            let credential = try await provider.credential(with: uiDelegate)
            let authData = try await self.internalSignInAndRetrieveData(
              withCredential: credential,
              isReauthentication: false
            )
            decoratedCallback(authData, nil)
          } catch {
            decoratedCallback(nil, error)
          }
        }
      }
    }

    /// Signs in using the provided auth provider instance.
    ///
    /// Possible error codes:
    ///  * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password
    /// accounts are not enabled. Enable them in the Auth section of the
    /// Firebase console.
    /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
    /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted
    /// sign in with an incorrect password.
    /// * `AuthErrorCodeWebNetworkRequestFailed` - Indicates that a network request within a
    /// SFSafariViewController or WKWebView failed.
    /// * `AuthErrorCodeWebInternalError` - Indicates that an internal error occurred within a
    /// SFSafariViewController or WKWebView.
    /// * `AuthErrorCodeWebSignInUserInteractionFailure` - Indicates a general failure during
    /// a web sign-in flow.
    /// * `AuthErrorCodeWebContextAlreadyPresented` - Indicates that an attempt was made to
    /// present a new web context while one was already being presented.
    /// * `AuthErrorCodeWebContextCancelled` - Indicates that the URL presentation was
    /// cancelled prematurely by the user.
    /// *  `AuthErrorCodeAccountExistsWithDifferentCredential` - Indicates the email asserted
    /// by the credential (e.g. the email in a Facebook access token) is already in use by an
    /// existing account, that cannot be authenticated with this sign-in method. Call
    /// fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
    /// the sign-in providers returned. This error will only be thrown if the "One account per
    /// email address" setting is enabled in the Firebase console, under Auth settings.
    /// - Parameter provider: An instance of an auth provider used to initiate the sign-in flow.
    /// - Parameter uiDelegate: Optionally an instance of a class conforming to the AuthUIDelegate
    /// protocol, this is used for presenting the web context. If nil, a default AuthUIDelegate
    /// will be used.
    /// - Returns: The `AuthDataResult` after the successful signin.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    @available(tvOS, unavailable)
    @available(macOS, unavailable)
    @available(watchOS, unavailable)
    @discardableResult
    open func signIn(with provider: FederatedAuthProvider,
                     uiDelegate: AuthUIDelegate?) async throws -> AuthDataResult {
      return try await withCheckedThrowingContinuation { continuation in
        self.signIn(with: provider, uiDelegate: uiDelegate) { result, error in
          if let result {
            continuation.resume(returning: result)
          } else {
            continuation.resume(throwing: error!)
          }
        }
      }
    }
  #endif // iOS

  /// Asynchronously signs in to Firebase with the given 3rd-party credentials (e.g. a Facebook
  /// login Access Token, a Google ID Token/Access Token pair, etc.) and returns additional
  /// identity provider data.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
  /// This could happen if it has expired or it is malformed.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that accounts
  /// with the identity provider represented by the credential are not enabled.
  /// Enable them in the Auth section of the Firebase console.
  /// * `AuthErrorCodeAccountExistsWithDifferentCredential` - Indicates the email asserted
  /// by the credential (e.g. the email in a Facebook access token) is already in use by an
  /// existing account, that cannot be authenticated with this sign-in method. Call
  /// fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
  /// the sign-in providers returned. This error will only be thrown if the "One account per
  /// email address" setting is enabled in the Firebase console, under Auth settings.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted sign in with an
  /// incorrect password, if credential is of the type EmailPasswordAuthCredential.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// * `AuthErrorCodeMissingVerificationID` - Indicates that the phone auth credential was
  /// created with an empty verification ID.
  /// * `AuthErrorCodeMissingVerificationCode` - Indicates that the phone auth credential
  /// was created with an empty verification code.
  /// * `AuthErrorCodeInvalidVerificationCode` - Indicates that the phone auth credential
  /// was created with an invalid verification Code.
  /// * `AuthErrorCodeInvalidVerificationID` - Indicates that the phone auth credential was
  /// created with an invalid verification ID.
  /// * `AuthErrorCodeSessionExpired` - Indicates that the SMS code has expired.
  /// - Parameter credential: The credential supplied by the IdP.
  /// - Parameter completion: Optionally; a block which is invoked when the sign in flow finishes,
  /// or is canceled. Invoked asynchronously on the main thread in the future.
  @objc(signInWithCredential:completion:)
  open func signIn(with credential: AuthCredential,
                   completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      Task {
        do {
          let authData = try await self.internalSignInAndRetrieveData(withCredential: credential,
                                                                      isReauthentication: false)
          decoratedCallback(authData, nil)
        } catch {
          decoratedCallback(nil, error)
        }
      }
    }
  }

  /// Asynchronously signs in to Firebase with the given 3rd-party credentials (e.g. a Facebook
  /// login Access Token, a Google ID Token/Access Token pair, etc.) and returns additional
  /// identity provider data.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
  /// This could happen if it has expired or it is malformed.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that accounts
  /// with the identity provider represented by the credential are not enabled.
  /// Enable them in the Auth section of the Firebase console.
  /// * `AuthErrorCodeAccountExistsWithDifferentCredential` - Indicates the email asserted
  /// by the credential (e.g. the email in a Facebook access token) is already in use by an
  /// existing account, that cannot be authenticated with this sign-in method. Call
  /// fetchProvidersForEmail for this user’s email and then prompt them to sign in with any of
  /// the sign-in providers returned. This error will only be thrown if the "One account per
  /// email address" setting is enabled in the Firebase console, under Auth settings.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted sign in with an
  /// incorrect password, if credential is of the type EmailPasswordAuthCredential.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// * `AuthErrorCodeMissingVerificationID` - Indicates that the phone auth credential was
  /// created with an empty verification ID.
  /// * `AuthErrorCodeMissingVerificationCode` - Indicates that the phone auth credential
  /// was created with an empty verification code.
  /// * `AuthErrorCodeInvalidVerificationCode` - Indicates that the phone auth credential
  /// was created with an invalid verification Code.
  /// * `AuthErrorCodeInvalidVerificationID` - Indicates that the phone auth credential was
  /// created with an invalid verification ID.
  /// * `AuthErrorCodeSessionExpired` - Indicates that the SMS code has expired.
  /// - Parameter credential: The credential supplied by the IdP.
  /// - Returns: The `AuthDataResult` after the successful signin.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  open func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
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

  /// Asynchronously creates and becomes an anonymous user.
  ///
  /// If there is already an anonymous user signed in, that user will be returned instead.
  /// If there is any other existing user signed in, that user will be signed out.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that anonymous accounts are
  /// not enabled. Enable them in the Auth section of the Firebase console.
  /// - Parameter completion: Optionally; a block which is invoked when the sign in finishes, or is
  /// canceled. Invoked asynchronously on the main thread in the future.
  @objc open func signInAnonymously(completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      if let currentUser = self._currentUser, currentUser.isAnonymous {
        let result = AuthDataResult(withUser: currentUser, additionalUserInfo: nil)
        decoratedCallback(result, nil)
        return
      }
      let request = SignUpNewUserRequest(requestConfiguration: self.requestConfiguration)
      Task {
        do {
          let response = try await self.backend.call(with: request)
          let user = try await self.completeSignIn(
            withAccessToken: response.idToken,
            accessTokenExpirationDate: response.approximateExpirationDate,
            refreshToken: response.refreshToken,
            anonymous: true
          )
          // TODO: The ObjC implementation passed a nil providerID to the nonnull providerID
          let additionalUserInfo = AdditionalUserInfo(providerID: "",
                                                      profile: nil,
                                                      username: nil,
                                                      isNewUser: true)
          decoratedCallback(AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo),
                            nil)
        } catch {
          decoratedCallback(nil, error)
        }
      }
    }
  }

  /// Asynchronously creates and becomes an anonymous user.
  ///
  /// If there is already an anonymous user signed in, that user will be returned instead.
  /// If there is any other existing user signed in, that user will be signed out.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that anonymous accounts are
  /// not enabled. Enable them in the Auth section of the Firebase console.
  /// - Returns: The `AuthDataResult` after the successful signin.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  @objc open func signInAnonymously() async throws -> AuthDataResult {
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

  /// Asynchronously signs in to Firebase with the given Auth token.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidCustomToken` - Indicates a validation error with
  /// the custom token.
  /// * `AuthErrorCodeCustomTokenMismatch` - Indicates the service account and the API key
  /// belong to different projects.
  /// - Parameter token: A self-signed custom auth token.
  /// - Parameter completion: Optionally; a block which is invoked when the sign in finishes, or is
  ///    canceled. Invoked asynchronously on the main thread in the future.
  @objc open func signIn(withCustomToken token: String,
                         completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let decoratedCallback = self.signInFlowAuthDataResultCallback(byDecorating: completion)
      let request = VerifyCustomTokenRequest(token: token,
                                             requestConfiguration: self.requestConfiguration)
      Task {
        do {
          let response = try await self.backend.call(with: request)
          let user = try await self.completeSignIn(
            withAccessToken: response.idToken,
            accessTokenExpirationDate: response.approximateExpirationDate,
            refreshToken: response.refreshToken,
            anonymous: false
          )
          // TODO: The ObjC implementation passed a nil providerID to the nonnull providerID
          let additionalUserInfo = AdditionalUserInfo(providerID: "",
                                                      profile: nil,
                                                      username: nil,
                                                      isNewUser: response.isNewUser)
          decoratedCallback(AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo),
                            nil)
        } catch {
          decoratedCallback(nil, error)
        }
      }
    }
  }

  /// Asynchronously signs in to Firebase with the given Auth token.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidCustomToken` - Indicates a validation error with
  /// the custom token.
  /// * `AuthErrorCodeCustomTokenMismatch` - Indicates the service account and the API key
  /// belong to different projects.
  /// - Parameter token: A self-signed custom auth token.
  /// - Returns: The `AuthDataResult` after the successful signin.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  open func signIn(withCustomToken token: String) async throws -> AuthDataResult {
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

  /// Creates and, on success, signs in a user with the given email address and password.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// * `AuthErrorCodeEmailAlreadyInUse` - Indicates the email used to attempt sign up
  /// already exists. Call fetchProvidersForEmail to check which sign-in mechanisms the user
  /// used, and prompt the user to sign in with one of those.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password accounts
  /// are not enabled. Enable them in the Auth section of the Firebase console.
  /// * `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
  /// considered too weak. The NSLocalizedFailureReasonErrorKey field in the NSError.userInfo
  /// dictionary object will contain more detailed explanation that can be shown to the user.
  /// - Parameter email: The user's email address.
  /// - Parameter password: The user's desired password.
  /// - Parameter completion: Optionally; a block which is invoked when the sign up flow finishes,
  /// or is canceled. Invoked asynchronously on the main thread in the future.
  @objc open func createUser(withEmail email: String,
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
                                         idToken: nil,
                                         requestConfiguration: self.requestConfiguration)

      #if os(iOS)
        self.wrapInjectRecaptcha(request: request,
                                 action: AuthRecaptchaAction.signUpPassword) { response, error in
          if let error {
            DispatchQueue.main.async {
              decoratedCallback(nil, error)
            }
            return
          }
          self.internalCreateUserWithEmail(request: request, inResponse: response,
                                           decoratedCallback: decoratedCallback)
        }
      #else
        self.internalCreateUserWithEmail(request: request, decoratedCallback: decoratedCallback)
      #endif
    }
  }

  func internalCreateUserWithEmail(request: SignUpNewUserRequest,
                                   inResponse: SignUpNewUserResponse? = nil,
                                   decoratedCallback: @escaping (AuthDataResult?, Error?) -> Void) {
    Task {
      do {
        var response: SignUpNewUserResponse
        if let inResponse {
          response = inResponse
        } else {
          response = try await self.backend.call(with: request)
        }
        let user = try await self.completeSignIn(
          withAccessToken: response.idToken,
          accessTokenExpirationDate: response.approximateExpirationDate,
          refreshToken: response.refreshToken,
          anonymous: false
        )
        let additionalUserInfo = AdditionalUserInfo(providerID: EmailAuthProvider.id,
                                                    profile: nil,
                                                    username: nil,
                                                    isNewUser: true)
        decoratedCallback(AuthDataResult(withUser: user,
                                         additionalUserInfo: additionalUserInfo),
                          nil)
      } catch {
        decoratedCallback(nil, error)
      }
    }
  }

  /// Creates and, on success, signs in a user with the given email address and password.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// * `AuthErrorCodeEmailAlreadyInUse` - Indicates the email used to attempt sign up
  /// already exists. Call fetchProvidersForEmail to check which sign-in mechanisms the user
  /// used, and prompt the user to sign in with one of those.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that email and password accounts
  /// are not enabled. Enable them in the Auth section of the Firebase console.
  /// * `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
  /// considered too weak. The NSLocalizedFailureReasonErrorKey field in the NSError.userInfo
  /// dictionary object will contain more detailed explanation that can be shown to the user.
  /// - Parameter email: The user's email address.
  /// - Parameter password: The user's desired password.
  /// - Returns: The `AuthDataResult` after the successful signin.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  open func createUser(withEmail email: String, password: String) async throws -> AuthDataResult {
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

  /// Resets the password given a code sent to the user outside of the app and a new password
  /// for the user.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
  /// considered too weak.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates the administrator disabled sign
  /// in with the specified identity provider.
  /// * `AuthErrorCodeExpiredActionCode` - Indicates the OOB code is expired.
  /// * `AuthErrorCodeInvalidActionCode` - Indicates the OOB code is invalid.
  /// - Parameter code: The reset code.
  ///  - Parameter newPassword: The new password.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked asynchronously on the main thread in the future.
  @objc open func confirmPasswordReset(withCode code: String, newPassword: String,
                                       completion: @escaping (Error?) -> Void) {
    kAuthGlobalWorkQueue.async {
      let request = ResetPasswordRequest(oobCode: code,
                                         newPassword: newPassword,
                                         requestConfiguration: self.requestConfiguration)
      self.wrapAsyncRPCTask(request, completion)
    }
  }

  /// Resets the password given a code sent to the user outside of the app and a new password
  /// for the user.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
  /// considered too weak.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates the administrator disabled sign
  /// in with the specified identity provider.
  /// * `AuthErrorCodeExpiredActionCode` - Indicates the OOB code is expired.
  /// * `AuthErrorCodeInvalidActionCode` - Indicates the OOB code is invalid.
  /// - Parameter code: The reset code.
  ///  - Parameter newPassword: The new password.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func confirmPasswordReset(withCode code: String, newPassword: String) async throws {
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

  /// Checks the validity of an out of band code.
  /// - Parameter code: The out of band code to check validity.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked
  /// asynchronously on the main thread in the future.
  @objc open func checkActionCode(_ code: String,
                                  completion: @escaping (ActionCodeInfo?, Error?) -> Void) {
    kAuthGlobalWorkQueue.async {
      let request = ResetPasswordRequest(oobCode: code,
                                         newPassword: nil,
                                         requestConfiguration: self.requestConfiguration)
      Task {
        do {
          let response = try await self.backend.call(with: request)

          let operation = ActionCodeInfo.actionCodeOperation(forRequestType: response.requestType)
          guard let email = response.email else {
            fatalError("Internal Auth Error: Failed to get a ResetPasswordResponse")
          }
          let actionCodeInfo = ActionCodeInfo(withOperation: operation,
                                              email: email,
                                              newEmail: response.verifiedEmail)
          Auth.wrapMainAsync(callback: completion, withParam: actionCodeInfo, error: nil)
        } catch {
          Auth.wrapMainAsync(callback: completion, withParam: nil, error: error)
        }
      }
    }
  }

  /// Checks the validity of an out of band code.
  /// - Parameter code: The out of band code to check validity.
  /// - Returns:  An `ActionCodeInfo`.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func checkActionCode(_ code: String) async throws -> ActionCodeInfo {
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

  /// Checks the validity of a verify password reset code.
  /// - Parameter code: The password reset code to be verified.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked asynchronously on the main thread in the future.
  @objc open func verifyPasswordResetCode(_ code: String,
                                          completion: @escaping (String?, Error?) -> Void) {
    checkActionCode(code) { info, error in
      if let error {
        completion(nil, error)
        return
      }
      completion(info?.email, nil)
    }
  }

  /// Checks the validity of a verify password reset code.
  /// - Parameter code: The password reset code to be verified.
  /// - Returns: An email.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func verifyPasswordResetCode(_ code: String) async throws -> String {
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

  /// Applies out of band code.
  ///
  /// This method will not work for out of band codes which require an additional parameter,
  /// such as password reset code.
  /// - Parameter code: The out of band code to be applied.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked asynchronously on the main thread in the future.
  @objc open func applyActionCode(_ code: String, completion: @escaping (Error?) -> Void) {
    kAuthGlobalWorkQueue.async {
      let request = SetAccountInfoRequest(requestConfiguration: self.requestConfiguration)
      request.oobCode = code
      self.wrapAsyncRPCTask(request, completion)
    }
  }

  /// Applies out of band code.
  ///
  /// This method will not work for out of band codes which require an additional parameter,
  /// such as password reset code.
  /// - Parameter code: The out of band code to be applied.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func applyActionCode(_ code: String) async throws {
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

  /// Initiates a password reset for the given email address.
  ///
  /// This method does not throw an
  /// error when there's no user account with the given email address and [Email Enumeration
  /// Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
  /// sent in the request.
  /// * `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
  /// the console for this action.
  /// * `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
  /// sending update email.
  /// - Parameter email: The email address of the user.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked
  /// asynchronously on the main thread in the future.
  @objc open func sendPasswordReset(withEmail email: String,
                                    completion: ((Error?) -> Void)? = nil) {
    sendPasswordReset(withEmail: email, actionCodeSettings: nil, completion: completion)
  }

  /// Initiates a password reset for the given email address and `ActionCodeSettings` object.
  ///
  /// This method does not throw an
  /// error when there's no user account with the given email address and [Email Enumeration
  /// Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
  /// sent in the request.
  /// * `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
  /// the console for this action.
  /// * `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
  /// sending update email.
  /// * `AuthErrorCodeMissingIosBundleID` - Indicates that the iOS bundle ID is missing when
  /// `handleCodeInApp` is set to true.
  /// * `AuthErrorCodeMissingAndroidPackageName` - Indicates that the android package name
  /// is missing when the `androidInstallApp` flag is set to true.
  /// * `AuthErrorCodeUnauthorizedDomain` - Indicates that the domain specified in the
  /// continue URL is not allowlisted in the Firebase console.
  /// * `AuthErrorCodeInvalidContinueURI` - Indicates that the domain specified in the
  /// continue URL is not valid.
  /// - Parameter email: The email address of the user.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  /// handling action codes.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked asynchronously on the main thread in the future.
  @objc open func sendPasswordReset(withEmail email: String,
                                    actionCodeSettings: ActionCodeSettings?,
                                    completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      let request = GetOOBConfirmationCodeRequest.passwordResetRequest(
        email: email,
        actionCodeSettings: actionCodeSettings,
        requestConfiguration: self.requestConfiguration
      )
      #if os(iOS)
        self.wrapInjectRecaptcha(request: request,
                                 action: AuthRecaptchaAction.getOobCode) { result, error in
          if let completion {
            DispatchQueue.main.async {
              completion(error)
            }
          }
        }
      #else
        self.wrapAsyncRPCTask(request, completion)
      #endif
    }
  }

  /// Initiates a password reset for the given email address and `ActionCodeSettings` object.
  ///
  /// This method does not throw an
  /// error when there's no user account with the given email address and [Email Enumeration
  /// Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
  /// sent in the request.
  /// * `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
  /// the console for this action.
  /// * `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
  /// sending update email.
  /// * `AuthErrorCodeMissingIosBundleID` - Indicates that the iOS bundle ID is missing when
  /// `handleCodeInApp` is set to true.
  /// * `AuthErrorCodeMissingAndroidPackageName` - Indicates that the android package name
  /// is missing when the `androidInstallApp` flag is set to true.
  /// * `AuthErrorCodeUnauthorizedDomain` - Indicates that the domain specified in the
  /// continue URL is not allowlisted in the Firebase console.
  /// * `AuthErrorCodeInvalidContinueURI` - Indicates that the domain specified in the
  /// continue URL is not valid.
  /// - Parameter email: The email address of the user.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  /// handling action codes.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func sendPasswordReset(withEmail email: String,
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

  /// Sends a sign in with email link to provided email address.
  /// - Parameter email: The email address of the user.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  /// handling action codes.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked asynchronously on the main thread in the future.
  @objc open func sendSignInLink(toEmail email: String,
                                 actionCodeSettings: ActionCodeSettings,
                                 completion: ((Error?) -> Void)? = nil) {
    if !actionCodeSettings.handleCodeInApp {
      fatalError("The handleCodeInApp flag in ActionCodeSettings must be true for Email-link " +
        "Authentication.")
    }
    kAuthGlobalWorkQueue.async {
      let request = GetOOBConfirmationCodeRequest.signInWithEmailLinkRequest(
        email,
        actionCodeSettings: actionCodeSettings,
        requestConfiguration: self.requestConfiguration
      )
      #if os(iOS)
        self.wrapInjectRecaptcha(request: request,
                                 action: AuthRecaptchaAction.getOobCode) { result, error in
          if let completion {
            DispatchQueue.main.async {
              completion(error)
            }
          }
        }
      #else
        self.wrapAsyncRPCTask(request, completion)
      #endif
    }
  }

  /// Sends a sign in with email link to provided email address.
  /// - Parameter email: The email address of the user.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  /// handling action codes.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func sendSignInLink(toEmail email: String,
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

  /// Signs out the current user.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeKeychainError` - Indicates an error occurred when accessing the
  /// keychain. The `NSLocalizedFailureReasonErrorKey` field in the `userInfo`
  /// dictionary will contain more information about the error encountered.
  @objc(signOut:) open func signOut() throws {
    try kAuthGlobalWorkQueue.sync {
      guard self._currentUser != nil else {
        return
      }
      return try self.updateCurrentUser(nil, byForce: false, savingToDisk: true)
    }
  }

  /// Checks if link is an email sign-in link.
  /// - Parameter link: The email sign-in link.
  /// - Returns: `true` when the link passed matches the expected format of an email sign-in link.
  @objc open func isSignIn(withEmailLink link: String) -> Bool {
    guard link.count > 0 else {
      return false
    }
    let queryItems = getQueryItems(link)
    if let _ = queryItems["oobCode"],
       let mode = queryItems["mode"],
       mode == "signIn" {
      return true
    }
    return false
  }

  #if os(iOS) && !targetEnvironment(macCatalyst)

    /// Initializes reCAPTCHA using the settings configured for the project or tenant.
    ///
    /// If you change the tenant ID of the `Auth` instance, the configuration will be
    /// reloaded.
    @objc(initializeRecaptchaConfigWithCompletion:)
    open func initializeRecaptchaConfig(completion: ((Error?) -> Void)?) {
      Task {
        do {
          try await initializeRecaptchaConfig()
          if let completion {
            completion(nil)
          }
        } catch {
          if let completion {
            completion(error)
          }
        }
      }
    }

    /// Initializes reCAPTCHA using the settings configured for the project or tenant.
    ///
    /// If you change the tenant ID of the `Auth` instance, the configuration will be
    /// reloaded.
    open func initializeRecaptchaConfig() async throws {
      // Trigger recaptcha verification flow to initialize the recaptcha client and
      // config. Recaptcha token will be returned.
      let verifier = AuthRecaptchaVerifier.shared(auth: self)
      _ = try await verifier.verify(forceRefresh: true, action: AuthRecaptchaAction.defaultAction)
    }
  #endif

  /// Registers a block as an "auth state did change" listener.
  ///
  /// To be invoked when:
  /// * The block is registered as a listener,
  /// * A user with a different UID from the current user has signed in, or
  /// * The current user has signed out.
  ///
  /// The block is invoked immediately after adding it according to its standard invocation
  /// semantics, asynchronously on the main thread. Users should pay special attention to
  /// making sure the block does not inadvertently retain objects which should not be retained by
  /// the long-lived block. The block itself will be retained by `Auth` until it is
  /// unregistered or until the `Auth` instance is otherwise deallocated.
  /// - Parameter listener: The block to be invoked. The block is always invoked asynchronously on
  /// the main thread, even for it's initial invocation after having been added as a listener.
  /// - Returns: A handle useful for manually unregistering the block as a listener.
  @objc(addAuthStateDidChangeListener:)
  open func addStateDidChangeListener(_ listener: @escaping (Auth, User?) -> Void)
    -> NSObjectProtocol {
    var firstInvocation = true
    var previousUserID: String?
    return addIDTokenDidChangeListener { auth, user in
      let shouldCallListener = firstInvocation || previousUserID != user?.uid
      firstInvocation = false
      previousUserID = user?.uid
      if shouldCallListener {
        listener(auth, user)
      }
    }
  }

  /// Unregisters a block as an "auth state did change" listener.
  /// - Parameter listenerHandle: The handle for the listener.
  @objc(removeAuthStateDidChangeListener:)
  open func removeStateDidChangeListener(_ listenerHandle: NSObjectProtocol) {
    NotificationCenter.default.removeObserver(listenerHandle)
    objc_sync_enter(Auth.self)
    defer { objc_sync_exit(Auth.self) }
    listenerHandles.remove(listenerHandle)
  }

  /// Registers a block as an "ID token did change" listener.
  ///
  /// To be invoked when:
  /// * The block is registered as a listener,
  /// * A user with a different UID from the current user has signed in,
  /// * The ID token of the current user has been refreshed, or
  /// * The current user has signed out.
  ///
  /// The block is invoked immediately after adding it according to its standard invocation
  /// semantics, asynchronously on the main thread. Users should pay special attention to
  /// making sure the block does not inadvertently retain objects which should not be retained by
  /// the long-lived block. The block itself will be retained by `Auth` until it is
  /// unregistered or until the `Auth` instance is otherwise deallocated.
  /// - Parameter listener: The block to be invoked. The block is always invoked asynchronously on
  /// the main thread, even for it's initial invocation after having been added as a listener.
  /// - Returns: A handle useful for manually unregistering the block as a listener.
  @objc open func addIDTokenDidChangeListener(_ listener: @escaping (Auth, User?) -> Void)
    -> NSObjectProtocol {
    let handle = NotificationCenter.default.addObserver(
      forName: Auth.authStateDidChangeNotification,
      object: self,
      queue: OperationQueue.main
    ) { notification in
      if let auth = notification.object as? Auth {
        listener(auth, auth._currentUser)
      }
    }
    objc_sync_enter(Auth.self)
    listenerHandles.add(listener)
    objc_sync_exit(Auth.self)
    DispatchQueue.main.async {
      listener(self, self._currentUser)
    }
    return handle
  }

  /// Unregisters a block as an "ID token did change" listener.
  /// - Parameter listenerHandle: The handle for the listener.
  @objc open func removeIDTokenDidChangeListener(_ listenerHandle: NSObjectProtocol) {
    NotificationCenter.default.removeObserver(listenerHandle)
    objc_sync_enter(Auth.self)
    listenerHandles.remove(listenerHandle)
    objc_sync_exit(Auth.self)
  }

  /// Sets `languageCode` to the app's current language.
  @objc open func useAppLanguage() {
    kAuthGlobalWorkQueue.sync {
      self.requestConfiguration.languageCode = Locale.preferredLanguages.first
    }
  }

  /// Configures Firebase Auth to connect to an emulated host instead of the remote backend.
  @objc open func useEmulator(withHost host: String, port: Int) {
    guard host.count > 0 else {
      fatalError("Cannot connect to empty host")
    }
    // If host is an IPv6 address, it should be formatted with surrounding brackets.
    let formattedHost = host.contains(":") ? "[\(host)]" : host
    kAuthGlobalWorkQueue.sync {
      self.requestConfiguration.emulatorHostAndPort = "\(formattedHost):\(port)"
      #if os(iOS)
        self.settings?.appVerificationDisabledForTesting = true
      #endif
    }
  }

  /// Revoke the users token with authorization code.
  /// - Parameter authorizationCode: The authorization code used to perform the revocation.
  /// - Parameter completion: (Optional) the block invoked when the request to revoke the token is
  /// complete, or fails. Invoked asynchronously on the main thread in the future.
  @objc open func revokeToken(withAuthorizationCode authorizationCode: String,
                              completion: ((Error?) -> Void)? = nil) {
    _currentUser?.internalGetToken(backend: backend) { idToken, error in
      if let error {
        Auth.wrapMainAsync(completion, error)
        return
      }
      guard let idToken else {
        fatalError("Internal Auth Error: Both idToken and error are nil")
      }
      let request = RevokeTokenRequest(withToken: authorizationCode,
                                       idToken: idToken,
                                       requestConfiguration: self.requestConfiguration)
      self.wrapAsyncRPCTask(request, completion)
    }
  }

  /// Revoke the users token with authorization code.
  /// - Parameter authorizationCode: The authorization code used to perform the revocation.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func revokeToken(withAuthorizationCode authorizationCode: String) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.revokeToken(withAuthorizationCode: authorizationCode) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /// Switch userAccessGroup and current user to the given accessGroup and the user stored in it.
  @objc open func useUserAccessGroup(_ accessGroup: String?) throws {
    // self.storedUserManager is initialized asynchronously. Make sure it is done.
    kAuthGlobalWorkQueue.sync {}
    return try internalUseUserAccessGroup(accessGroup)
  }

  private func internalUseUserAccessGroup(_ accessGroup: String?) throws {
    storedUserManager.setStoredUserAccessGroup(accessGroup: accessGroup)
    let user = try getStoredUser(forAccessGroup: accessGroup)
    try updateCurrentUser(user, byForce: false, savingToDisk: false)
    if userAccessGroup == nil, accessGroup != nil {
      let userKey = "\(firebaseAppName)\(kUserKey)"
      try keychainServices.removeData(forKey: userKey)
    }
    userAccessGroup = accessGroup
    lastNotifiedUserToken = user?.rawAccessToken()
  }

  /// Get the stored user in the given accessGroup.
  ///
  ///  This API is not supported on tvOS when `shareAuthStateAcrossDevices` is set to `true`.
  /// and will return `nil`.
  /// Please refer to https://github.com/firebase/firebase-ios-sdk/issues/8878 for details.
  @available(swift 1000.0) // Objective-C only API
  @objc(getStoredUserForAccessGroup:error:)
  open func __getStoredUser(forAccessGroup accessGroup: String?,
                            error outError: NSErrorPointer) -> User? {
    do {
      return try getStoredUser(forAccessGroup: accessGroup)
    } catch {
      outError?.pointee = error as NSError
      return nil
    }
  }

  /// Get the stored user in the given accessGroup.
  ///
  ///  This API is not supported on tvOS when `shareAuthStateAcrossDevices` is set to `true`.
  /// and will return `nil`.
  ///
  /// Please refer to https://github.com/firebase/firebase-ios-sdk/issues/8878 for details.
  open func getStoredUser(forAccessGroup accessGroup: String?) throws -> User? {
    var user: User?
    if let accessGroup {
      #if os(tvOS)
        if shareAuthStateAcrossDevices {
          AuthLog.logError(code: "I-AUT000001",
                           message: "Getting a stored user for a given access group is not supported " +
                             "on tvOS when `shareAuthStateAcrossDevices` is set to `true` (#8878)." +
                             "This case will return `nil`.")
          return nil
        }
      #endif
      guard let apiKey = app?.options.apiKey else {
        fatalError("Internal Auth Error: missing apiKey")
      }
      user = try storedUserManager.getStoredUser(
        accessGroup: accessGroup,
        shareAuthStateAcrossDevices: shareAuthStateAcrossDevices,
        projectIdentifier: apiKey
      )
    } else {
      let userKey = "\(firebaseAppName)\(kUserKey)"
      if let encodedUserData = try keychainServices.data(forKey: userKey) {
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: encodedUserData)
        user = unarchiver.decodeObject(of: User.self, forKey: userKey)
      }
    }
    user?.auth = self
    return user
  }

  #if os(iOS)
    /// The APNs token used for phone number authentication.
    ///
    /// The type of the token (production or sandbox) will be automatically
    /// detected based on your provisioning profile.
    ///
    /// This property is available on iOS only.
    ///
    /// If swizzling is disabled, the APNs Token must be set for phone number auth to work,
    /// by either setting this property or by calling `setAPNSToken(_:type:)`.
    @objc(APNSToken) open var apnsToken: Data? {
      kAuthGlobalWorkQueue.sync {
        self.tokenManager.token?.data
      }
    }

    /// Sets the APNs token along with its type.
    ///
    /// This method is available on iOS only.
    ///
    /// If swizzling is disabled, the APNs Token must be set for phone number auth to work,
    /// by either setting calling this method or by setting the `APNSToken` property.
    @objc open func setAPNSToken(_ token: Data, type: AuthAPNSTokenType) {
      kAuthGlobalWorkQueue.sync {
        self.tokenManager.token = AuthAPNSToken(withData: token, type: type)
      }
    }

    /// Whether the specific remote notification is handled by `Auth` .
    ///
    /// This method is available on iOS only.
    ///
    /// If swizzling is disabled, related remote notifications must be forwarded to this method
    /// for phone number auth to work.
    /// - Parameter userInfo: A dictionary that contains information related to the
    /// notification in question.
    /// - Returns: Whether or the notification is handled. A return value of `true` means the
    /// notification is for Firebase Auth so the caller should ignore the notification from further
    /// processing, and `false` means the notification is for the app (or another library) so
    /// the caller should continue handling this notification as usual.
    @objc open func canHandleNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
      kAuthGlobalWorkQueue.sync {
        self.notificationManager.canHandle(notification: userInfo)
      }
    }

    /// Whether the specific URL is handled by `Auth` .
    ///
    /// This method is available on iOS only.
    ///
    /// If swizzling is disabled, URLs received by the application delegate must be forwarded
    /// to this method for phone number auth to work.
    /// - Parameter url: The URL received by the application delegate from any of the openURL
    /// method.
    /// - Returns: Whether or the URL is handled. `true` means the URL is for Firebase Auth
    /// so the caller should ignore the URL from further processing, and `false` means the
    /// the URL is for the app (or another library) so the caller should continue handling
    /// this URL as usual.
    @objc(canHandleURL:) open func canHandle(_ url: URL) -> Bool {
      kAuthGlobalWorkQueue.sync {
        guard let authURLPresenter = self.authURLPresenter as? AuthURLPresenter else {
          return false
        }
        return authURLPresenter.canHandle(url: url)
      }
    }
  #endif

  /// The name of the `NSNotificationCenter` notification which is posted when the auth state
  /// changes (for example, a new token has been produced, a user signs in or signs out).
  ///
  /// The object parameter of the notification is the sender `Auth` instance.
  public static let authStateDidChangeNotification =
    NSNotification.Name(rawValue: "FIRAuthStateDidChangeNotification")

  // MARK: Internal methods

  init(app: FirebaseApp,
       keychainStorageProvider: AuthKeychainStorage = AuthKeychainStorageReal(),
       backend: AuthBackend = .init(rpcIssuer: AuthBackendRPCIssuer()),
       authDispatcher: AuthDispatcher = .init()) {
    self.app = app
    mainBundleUrlTypes = Bundle.main
      .object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]

    let appCheck = ComponentType<AppCheckInterop>.instance(for: AppCheckInterop.self,
                                                           in: app.container)
    guard let apiKey = app.options.apiKey else {
      fatalError("Missing apiKey for Auth initialization")
    }

    firebaseAppName = app.name

    #if os(iOS)
      authURLPresenter = AuthURLPresenter()
      settings = AuthSettings()
      GULAppDelegateSwizzler.proxyOriginalDelegateIncludingAPNSMethods()
      GULSceneDelegateSwizzler.proxyOriginalSceneDelegate()
    #endif
    requestConfiguration = AuthRequestConfiguration(apiKey: apiKey,
                                                    appID: app.options.googleAppID,
                                                    auth: nil,
                                                    heartbeatLogger: app.heartbeatLogger,
                                                    appCheck: appCheck)
    self.backend = backend
    self.authDispatcher = authDispatcher

    let keychainServiceName = Auth.keychainServiceName(for: app)
    keychainServices = AuthKeychainServices(service: keychainServiceName,
                                            storage: keychainStorageProvider)
    storedUserManager = AuthStoredUserManager(
      serviceName: keychainServiceName,
      keychainServices: keychainServices
    )

    super.init()
    requestConfiguration.auth = self

    protectedDataInitialization()
  }

  private func protectedDataInitialization() {
    // Continue with the rest of initialization in the work thread.
    kAuthGlobalWorkQueue.async { [weak self] in
      // Load current user from Keychain.
      guard let self else {
        return
      }

      do {
        if let storedUserAccessGroup = self.storedUserManager.getStoredUserAccessGroup() {
          try self.internalUseUserAccessGroup(storedUserAccessGroup)
        } else {
          let user = try self.getUser()
          if let user {
            self.tenantID = user.tenantID
          }
          try self.updateCurrentUser(user, byForce: false, savingToDisk: false)
          if let user {
            self.lastNotifiedUserToken = user.rawAccessToken()
          }
        }
      } catch {
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
          if (error as NSError).code == AuthErrorCode.keychainError.rawValue {
            // If there's a keychain error, assume it is due to the keychain being accessed
            // before the device is unlocked as a result of prewarming, and listen for the
            // UIApplicationProtectedDataDidBecomeAvailable notification.
            self.addProtectedDataDidBecomeAvailableObserver()
          }
        #endif
        AuthLog.logError(code: "I-AUT000001",
                         message: "Error loading saved user when starting up: \(error)")
      }

      #if os(iOS)
        if GULAppEnvironmentUtil.isAppExtension() {
          // iOS App extensions should not call [UIApplication sharedApplication], even if
          // UIApplication responds to it.
          return
        }

        // Using reflection here to avoid build errors in extensions.
        let sel = NSSelectorFromString("sharedApplication")
        guard UIApplication.responds(to: sel),
              let rawApplication = UIApplication.perform(sel),
              let application = rawApplication.takeUnretainedValue() as? UIApplication else {
          return
        }

        // Initialize for phone number auth.
        self.tokenManager = AuthAPNSTokenManager(withApplication: application)
        self.appCredentialManager = AuthAppCredentialManager(withKeychain: self.keychainServices)
        self.notificationManager = AuthNotificationManager(
          withApplication: application,
          appCredentialManager: self.appCredentialManager
        )

        GULAppDelegateSwizzler.registerAppDelegateInterceptor(self)
        GULSceneDelegateSwizzler.registerSceneDelegateInterceptor(self)
      #endif
    }
  }

  #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    private func addProtectedDataDidBecomeAvailableObserver() {
      protectedDataDidBecomeAvailableObserver =
        NotificationCenter.default.addObserver(
          forName: UIApplication.protectedDataDidBecomeAvailableNotification,
          object: nil,
          queue: nil
        ) { [weak self] notification in
          guard let self else { return }
          if let observer = self.protectedDataDidBecomeAvailableObserver {
            NotificationCenter.default.removeObserver(
              observer,
              name: UIApplication.protectedDataDidBecomeAvailableNotification,
              object: nil
            )
          }
          self.protectedDataInitialization()
        }
    }
  #endif

  deinit {
    let defaultCenter = NotificationCenter.default
    while listenerHandles.count > 0 {
      let handleToRemove = listenerHandles.lastObject
      defaultCenter.removeObserver(handleToRemove as Any)
      listenerHandles.removeLastObject()
    }

    #if os(iOS)
      defaultCenter.removeObserver(applicationDidBecomeActiveObserver as Any,
                                   name: UIApplication.didBecomeActiveNotification,
                                   object: nil)
      defaultCenter.removeObserver(applicationDidEnterBackgroundObserver as Any,
                                   name: UIApplication.didEnterBackgroundNotification,
                                   object: nil)
    #endif
  }

  private func getUser() throws -> User? {
    var user: User?
    if let userAccessGroup {
      guard let apiKey = app?.options.apiKey else {
        fatalError("Internal Auth Error: missing apiKey")
      }
      user = try storedUserManager.getStoredUser(
        accessGroup: userAccessGroup,
        shareAuthStateAcrossDevices: shareAuthStateAcrossDevices,
        projectIdentifier: apiKey
      )
    } else {
      let userKey = "\(firebaseAppName)\(kUserKey)"
      guard let encodedUserData = try keychainServices.data(forKey: userKey) else {
        return nil
      }
      let unarchiver = try NSKeyedUnarchiver(forReadingFrom: encodedUserData)
      user = unarchiver.decodeObject(of: User.self, forKey: userKey)
    }
    user?.auth = self
    return user
  }

  /// Gets the keychain service name global data for the particular app by name.
  /// - Parameter appName: The name of the Firebase app to get keychain service name for.
  class func keychainServiceForAppID(_ appID: String) -> String {
    return "firebase_auth_\(appID)"
  }

  func updateKeychain(withUser user: User?) -> Error? {
    if user != _currentUser {
      // No-op if the user is no longer signed in. This is not considered an error as we don't check
      // whether the user is still current on other callbacks of user operations either.
      return nil
    }
    do {
      try saveUser(user)
      possiblyPostAuthStateChangeNotification()
    } catch {
      return error
    }
    return nil
  }

  /// A map from Firebase app name to keychain service names.
  ///
  /// This map is needed for looking up the keychain service name after the FirebaseApp instance
  /// is deleted, to remove the associated keychain item. Accessing should occur within a
  /// @synchronized([FIRAuth class]) context.
  fileprivate static var gKeychainServiceNameForAppName: [String: String] = [:]

  /// Gets the keychain service name global data for the particular app by
  /// name, creating an entry for one if it does not exist.
  /// - Parameter app: The Firebase app to get the keychain service name for.
  /// - Returns: The keychain service name for the given app.
  static func keychainServiceName(for app: FirebaseApp) -> String {
    objc_sync_enter(Auth.self)
    defer { objc_sync_exit(Auth.self) }
    let appName = app.name
    if let serviceName = gKeychainServiceNameForAppName[appName] {
      return serviceName
    } else {
      let serviceName = "firebase_auth_\(app.options.googleAppID)"
      gKeychainServiceNameForAppName[appName] = serviceName
      return serviceName
    }
  }

  /// Deletes the keychain service name global data for the particular app by name.
  /// - Parameter appName: The name of the Firebase app to delete keychain service name for.
  /// - Returns: The deleted keychain service name, if any.
  static func deleteKeychainServiceNameForAppName(_ appName: String) -> String? {
    objc_sync_enter(Auth.self)
    defer { objc_sync_exit(Auth.self) }
    guard let serviceName = gKeychainServiceNameForAppName[appName] else {
      return nil
    }
    gKeychainServiceNameForAppName.removeValue(forKey: appName)
    return serviceName
  }

  func signOutByForce(withUserID userID: String) throws {
    guard _currentUser?.uid == userID else {
      return
    }
    try updateCurrentUser(nil, byForce: true, savingToDisk: true)
  }

  // MARK: Private methods

  /// Posts the auth state change notification if current user's token has been changed.
  private func possiblyPostAuthStateChangeNotification() {
    let token = _currentUser?.rawAccessToken()
    if lastNotifiedUserToken == token ||
      (token != nil && lastNotifiedUserToken == token) {
      return
    }
    lastNotifiedUserToken = token
    if autoRefreshTokens {
      // Schedule new refresh task after successful attempt.
      scheduleAutoTokenRefresh()
    }
    var internalNotificationParameters: [String: Any] = [:]
    if let app = app {
      internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationAppKey] = app
    }
    if let token, token.count > 0 {
      internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationTokenKey] = token
    }
    internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationUIDKey] = _currentUser?
      .uid
    let notifications = NotificationCenter.default
    DispatchQueue.main.async {
      notifications.post(name: NSNotification.Name.FIRAuthStateDidChangeInternal,
                         object: self,
                         userInfo: internalNotificationParameters)
      notifications.post(name: Auth.authStateDidChangeNotification, object: self)
    }
  }

  /// Schedules a task to automatically refresh tokens on the current user. The0 token refresh
  /// is scheduled 5 minutes before the  scheduled expiration time.
  ///
  /// If the token expires in less than 5 minutes, schedule the token refresh immediately.
  private func scheduleAutoTokenRefresh() {
    let tokenExpirationInterval =
      (_currentUser?.accessTokenExpirationDate()?.timeIntervalSinceNow ?? 0) - 5 * 60
    scheduleAutoTokenRefresh(withDelay: max(tokenExpirationInterval, 0), retry: false)
  }

  /// Schedules a task to automatically refresh tokens on the current user.
  /// - Parameter delay: The delay in seconds after which the token refresh task should be scheduled
  /// to be executed.
  /// - Parameter retry: Flag to determine whether the invocation is a retry attempt or not.
  private func scheduleAutoTokenRefresh(withDelay delay: TimeInterval, retry: Bool) {
    guard let accessToken = _currentUser?.rawAccessToken() else {
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
    autoRefreshScheduled = true
    weak var weakSelf = self
    authDispatcher.dispatch(afterDelay: delay, queue: kAuthGlobalWorkQueue) {
      guard let strongSelf = weakSelf else {
        return
      }
      guard strongSelf._currentUser?.rawAccessToken() == accessToken else {
        // Another auto refresh must have been scheduled, so keep _autoRefreshScheduled unchanged.
        return
      }
      strongSelf.autoRefreshScheduled = false
      if strongSelf.isAppInBackground {
        return
      }
      let uid = strongSelf._currentUser?.uid
      strongSelf._currentUser?
        .internalGetToken(forceRefresh: true, backend: strongSelf.backend) { token, error in
          if strongSelf._currentUser?.uid != uid {
            return
          }
          if error != nil {
            // Kicks off exponential back off logic to retry failed attempt. Starts with one minute
            // delay (60 seconds) if this is the first failed attempt.
            let rescheduleDelay = retry ? min(delay * 2, 16 * 60) : 60
            strongSelf.scheduleAutoTokenRefresh(withDelay: rescheduleDelay, retry: true)
          }
        }
    }
  }

  /// Update the current user; initializing the user's internal properties correctly, and
  /// optionally saving the user to disk.
  ///
  /// This method is called during: sign in and sign out events, as well as during class
  /// initialization time. The only time the saveToDisk parameter should be set to NO is during
  /// class initialization time because the user was just read from disk.
  /// - Parameter user: The user to use as the current user (including nil, which is passed at sign
  /// out time.)
  /// - Parameter saveToDisk: Indicates the method should persist the user data to disk.
  func updateCurrentUser(_ user: User?, byForce force: Bool,
                         savingToDisk saveToDisk: Bool) throws {
    if user == _currentUser {
      possiblyPostAuthStateChangeNotification()
    }
    if let user {
      if user.tenantID != nil || tenantID != nil, tenantID != user.tenantID {
        throw AuthErrorUtils.tenantIDMismatchError()
      }
    }
    var throwError: Error?
    if saveToDisk {
      do {
        try saveUser(user)
      } catch {
        throwError = error
      }
    }
    if throwError == nil || force {
      _currentUser = user
      possiblyPostAuthStateChangeNotification()
    }
    if let throwError {
      throw throwError
    }
  }

  private func saveUser(_ user: User?) throws {
    if let userAccessGroup {
      guard let apiKey = app?.options.apiKey else {
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
          shareAuthStateAcrossDevices: shareAuthStateAcrossDevices,
          projectIdentifier: apiKey
        )
      }
    } else {
      let userKey = "\(firebaseAppName)\(kUserKey)"
      if let user {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        archiver.encode(user, forKey: userKey)
        archiver.finishEncoding()
        let archiveData = archiver.encodedData
        // Save the user object's encoded value.
        try keychainServices.setData(archiveData as Data, forKey: userKey)
      } else {
        try keychainServices.removeData(forKey: userKey)
      }
    }
  }

  /// Completes a sign-in flow once we have access and refresh tokens for the user.
  /// - Parameter accessToken: The STS access token.
  /// - Parameter accessTokenExpirationDate: The approximate expiration date of the access token.
  /// - Parameter refreshToken: The STS refresh token.
  /// - Parameter anonymous: Whether or not the user is anonymous.
  @discardableResult
  func completeSignIn(withAccessToken accessToken: String?,
                      accessTokenExpirationDate: Date?,
                      refreshToken: String?,
                      anonymous: Bool) async throws -> User {
    return try await User.retrieveUser(withAuth: self,
                                       accessToken: accessToken,
                                       accessTokenExpirationDate: accessTokenExpirationDate,
                                       refreshToken: refreshToken,
                                       anonymous: anonymous)
  }

  /// Signs in using an email address and password.
  ///
  /// This is the internal counterpart of this method, which uses a callback that does not
  /// update the current user.
  /// - Parameter email: The user's email address.
  /// - Parameter password: The user's password.
  private func internalSignInAndRetrieveData(withEmail email: String,
                                             password: String) async throws -> AuthDataResult {
    let credential = EmailAuthCredential(withEmail: email, password: password)
    return try await internalSignInAndRetrieveData(withCredential: credential,
                                                   isReauthentication: false)
  }

  func internalSignInAndRetrieveData(withCredential credential: AuthCredential,
                                     isReauthentication: Bool) async throws
    -> AuthDataResult {
    if let emailCredential = credential as? EmailAuthCredential {
      // Special case for email/password credentials
      switch emailCredential.emailType {
      case let .link(link):
        // Email link sign in
        return try await internalSignInAndRetrieveData(withEmail: emailCredential.email, link: link)
      case let .password(password):
        // Email password sign in
        let user = try await internalSignInUser(
          withEmail: emailCredential.email,
          password: password
        )
        let additionalUserInfo = AdditionalUserInfo(providerID: EmailAuthProvider.id,
                                                    profile: nil,
                                                    username: nil,
                                                    isNewUser: false)
        return AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
      }
    }
    #if !os(watchOS)
      if let gameCenterCredential = credential as? GameCenterAuthCredential {
        return try await signInAndRetrieveData(withGameCenterCredential: gameCenterCredential)
      }
    #endif
    #if os(iOS)
      if let phoneCredential = credential as? PhoneAuthCredential {
        // Special case for phone auth credentials
        let operation = isReauthentication ? AuthOperationType.reauth :
          AuthOperationType.signUpOrSignIn
        let response = try await signIn(withPhoneCredential: phoneCredential,
                                        operation: operation)
        let user = try await completeSignIn(withAccessToken: response.idToken,
                                            accessTokenExpirationDate: response
                                              .approximateExpirationDate,
                                            refreshToken: response.refreshToken,
                                            anonymous: false)

        let additionalUserInfo = AdditionalUserInfo(providerID: PhoneAuthProvider.id,
                                                    profile: nil,
                                                    username: nil,
                                                    isNewUser: response.isNewUser)
        return AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
      }
    #endif

    let request = VerifyAssertionRequest(providerID: credential.provider,
                                         requestConfiguration: requestConfiguration)
    request.autoCreate = !isReauthentication
    credential.prepare(request)
    let response = try await backend.call(with: request)
    if response.needConfirmation {
      let email = response.email
      let credential = OAuthCredential(withVerifyAssertionResponse: response)
      throw AuthErrorUtils.accountExistsWithDifferentCredentialError(
        email: email,
        updatedCredential: credential
      )
    }
    guard let providerID = response.providerID, providerID.count > 0 else {
      throw AuthErrorUtils.unexpectedResponse(deserializedResponse: response)
    }
    let user = try await completeSignIn(withAccessToken: response.idToken,
                                        accessTokenExpirationDate: response
                                          .approximateExpirationDate,
                                        refreshToken: response.refreshToken,
                                        anonymous: false)
    let additionalUserInfo = AdditionalUserInfo(providerID: providerID,
                                                profile: response.profile,
                                                username: response.username,
                                                isNewUser: response.isNewUser)
    let updatedOAuthCredential = OAuthCredential(withVerifyAssertionResponse: response)
    return AuthDataResult(withUser: user,
                          additionalUserInfo: additionalUserInfo,
                          credential: updatedOAuthCredential)
  }

  #if os(iOS)
    /// Signs in using a phone credential.
    /// - Parameter credential: The Phone Auth credential used to sign in.
    /// - Parameter operation: The type of operation for which this sign-in attempt is initiated.
    private func signIn(withPhoneCredential credential: PhoneAuthCredential,
                        operation: AuthOperationType) async throws -> VerifyPhoneNumberResponse {
      switch credential.credentialKind {
      case let .phoneNumber(phoneNumber, temporaryProof):
        let request = VerifyPhoneNumberRequest(temporaryProof: temporaryProof,
                                               phoneNumber: phoneNumber,
                                               operation: operation,
                                               requestConfiguration: requestConfiguration)
        return try await backend.call(with: request)
      case let .verification(verificationID, code):
        guard verificationID.count > 0 else {
          throw AuthErrorUtils.missingVerificationIDError(message: nil)
        }
        guard code.count > 0 else {
          throw AuthErrorUtils.missingVerificationCodeError(message: nil)
        }
        let request = VerifyPhoneNumberRequest(verificationID: verificationID,
                                               verificationCode: code,
                                               operation: operation,
                                               requestConfiguration: requestConfiguration)
        return try await backend.call(with: request)
      }
    }
  #endif

  #if !os(watchOS)
    /// Signs in using a game center credential.
    /// - Parameter credential: The Game Center Auth Credential used to sign in.
    private func signInAndRetrieveData(withGameCenterCredential credential: GameCenterAuthCredential) async throws
      -> AuthDataResult {
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
      let response = try await backend.call(with: request)
      let user = try await completeSignIn(withAccessToken: response.idToken,
                                          accessTokenExpirationDate: response
                                            .approximateExpirationDate,
                                          refreshToken: response.refreshToken,
                                          anonymous: false)
      let additionalUserInfo = AdditionalUserInfo(providerID: GameCenterAuthProvider.id,
                                                  profile: nil,
                                                  username: nil,
                                                  isNewUser: response.isNewUser)
      return AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
    }

  #endif

  /// Signs in using an email and email sign-in link.
  /// - Parameter email: The user's email address.
  /// - Parameter link: The email sign-in link.
  private func internalSignInAndRetrieveData(withEmail email: String,
                                             link: String) async throws -> AuthDataResult {
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
    let response = try await backend.call(with: request)
    let user = try await completeSignIn(withAccessToken: response.idToken,
                                        accessTokenExpirationDate: response
                                          .approximateExpirationDate,
                                        refreshToken: response.refreshToken,
                                        anonymous: false)

    let additionalUserInfo = AdditionalUserInfo(providerID: EmailAuthProvider.id,
                                                profile: nil,
                                                username: nil,
                                                isNewUser: response.isNewUser)
    return AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
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

  /// Creates a AuthDataResultCallback block which wraps another AuthDataResultCallback;
  ///    trying to update the current user before forwarding it's invocations along to a subject
  /// block.
  ///
  ///    Typically invoked as part of the complete sign-in flow. For any other uses please
  /// consider alternative ways of updating the current user.
  /// - Parameter callback: Called when the user has been updated or when an error has occurred.
  /// Invoked asynchronously on the main thread in the future.
  /// - Returns: Returns a block that updates the current user.
  func signInFlowAuthDataResultCallback(byDecorating callback:
    ((AuthDataResult?, Error?) -> Void)?) -> (AuthDataResult?, Error?) -> Void {
    let authDataCallback: (((AuthDataResult?, Error?) -> Void)?, AuthDataResult?, Error?) -> Void =
      { callback, result, error in
        Auth.wrapMainAsync(callback: callback, withParam: result, error: error)
      }
    return { authResult, error in
      if let error {
        authDataCallback(callback, nil, error)
        return
      }
      do {
        try self.updateCurrentUser(authResult?.user, byForce: false, savingToDisk: true)
      } catch {
        authDataCallback(callback, nil, error)
        return
      }
      authDataCallback(callback, authResult, nil)
    }
  }

  private func wrapAsyncRPCTask(_ request: any AuthRPCRequest, _ callback: ((Error?) -> Void)?) {
    Task {
      do {
        let _ = try await self.backend.call(with: request)
        Auth.wrapMainAsync(callback, nil)
      } catch {
        Auth.wrapMainAsync(callback, error)
      }
    }
  }

  class func wrapMainAsync(_ callback: ((Error?) -> Void)?, _ error: Error?) {
    if let callback {
      DispatchQueue.main.async {
        callback(error)
      }
    }
  }

  class func wrapMainAsync<T: Any>(callback: ((T?, Error?) -> Void)?,
                                   withParam param: T?,
                                   error: Error?) -> Void {
    if let callback {
      DispatchQueue.main.async {
        callback(param, error)
      }
    }
  }

  #if os(iOS)
    private func wrapInjectRecaptcha<T: AuthRPCRequest>(request: T,
                                                        action: AuthRecaptchaAction,
                                                        _ callback: @escaping (
                                                          (T.Response?, Error?) -> Void
                                                        )) {
      Task {
        do {
          let response = try await injectRecaptcha(request: request, action: action)
          callback(response, nil)
        } catch {
          callback(nil, error)
        }
      }
    }

    func injectRecaptcha<T: AuthRPCRequest>(request: T,
                                            action: AuthRecaptchaAction) async throws -> T
      .Response {
      let recaptchaVerifier = AuthRecaptchaVerifier.shared(auth: self)
      if recaptchaVerifier.enablementStatus(forProvider: AuthRecaptchaProvider.password) != .off {
        try await recaptchaVerifier.injectRecaptchaFields(request: request,
                                                          provider: AuthRecaptchaProvider.password,
                                                          action: action)
      } else {
        do {
          return try await backend.call(with: request)
        } catch {
          let nsError = error as NSError
          if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
             nsError.code == AuthErrorCode.internalError.rawValue,
             let messages = underlyingError
             .userInfo[AuthErrorUtils.userInfoDeserializedResponseKey] as? [String: AnyHashable],
             let message = messages["message"] as? String,
             message.hasPrefix("MISSING_RECAPTCHA_TOKEN") {
            try await recaptchaVerifier.injectRecaptchaFields(
              request: request,
              provider: AuthRecaptchaProvider.password,
              action: action
            )
          } else {
            throw error
          }
        }
      }
      return try await backend.call(with: request)
    }
  #endif

  // MARK: Internal properties

  /// Allow tests to swap in an alternate mainBundle, including ObjC unit tests via CocoaPods.
  #if FIREBASE_CI
    @objc public var mainBundleUrlTypes: [[String: Any]]!
  #else
    var mainBundleUrlTypes: [[String: Any]]!
  #endif

  /// The configuration object comprising of parameters needed to make a request to Firebase
  ///   Auth's backend.
  var requestConfiguration: AuthRequestConfiguration

  let backend: AuthBackend

  #if os(iOS)

    /// The manager for APNs tokens used by phone number auth.
    var tokenManager: AuthAPNSTokenManager!

    /// The manager for app credentials used by phone number auth.
    var appCredentialManager: AuthAppCredentialManager!

    /// The manager for remote notifications used by phone number auth.
    var notificationManager: AuthNotificationManager!

    /// An object that takes care of presenting URLs via the auth instance.
    var authURLPresenter: AuthWebViewControllerDelegate

  #endif // TARGET_OS_IOS

  // MARK: Private properties

  /// The stored user manager.
  private let storedUserManager: AuthStoredUserManager

  /// The Firebase app name.
  private let firebaseAppName: String

  private let authDispatcher: AuthDispatcher

  /// The keychain service.
  private let keychainServices: AuthKeychainServices

  /// The user access (ID) token used last time for posting auth state changed notification.
  private var lastNotifiedUserToken: String?

  /// This flag denotes whether or not tokens should be automatically refreshed.
  /// Will only be set to `true` if the another Firebase service is included (additionally to
  ///  Firebase Auth).
  private var autoRefreshTokens = false

  /// Whether or not token auto-refresh is currently scheduled.
  private var autoRefreshScheduled = false

  /// A flag that is set to YES if the app is put in the background and no when the app is
  ///    returned to the foreground.
  private var isAppInBackground = false

  /// An opaque object to act as the observer for UIApplicationDidBecomeActiveNotification.
  private var applicationDidBecomeActiveObserver: NSObjectProtocol?

  /// An opaque object to act as the observer for
  ///    UIApplicationDidEnterBackgroundNotification.
  private var applicationDidEnterBackgroundObserver: NSObjectProtocol?

  /// An opaque object to act as the observer for
  /// UIApplicationProtectedDataDidBecomeAvailable.
  private var protectedDataDidBecomeAvailableObserver: NSObjectProtocol?

  /// Key of user stored in the keychain. Prefixed with a Firebase app name.
  private let kUserKey = "_firebase_user"

  /// Handles returned from `NSNotificationCenter` for blocks which are "auth state did
  /// change" notification listeners.
  ///
  /// Mutations should occur within a @synchronized(self) context.
  private var listenerHandles: NSMutableArray = []
}
