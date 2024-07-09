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
      self.tokenManagerGet().cancel(withError: error)
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
  func getTokenInternal(forcingRefresh forceRefresh: Bool) {
    // Enable token auto-refresh if not already enabled.
    if !self.autoRefreshTokens {
      AuthLog.logInfo(code: "I-AUT000002", message: "Token auto-refresh enabled.")
      self.autoRefreshTokens = true
      self.scheduleAutoTokenRefresh()

#if os(iOS) || os(tvOS) // TODO(ObjC): Is a similar mechanism needed on macOS?
      self.applicationDidBecomeActiveObserver =
      NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil, queue: nil
      ) { notification in
        self.isAppInBackground = false
        if !self.autoRefreshScheduled {
          self.scheduleAutoTokenRefresh()
        }
      }
      self.applicationDidEnterBackgroundObserver =
      NotificationCenter.default.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil, queue: nil
      ) { notification in
        self.isAppInBackground = true
      }
#endif
    }
  }

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  /// TODO: Switch protocol and implementation to Swift when clients are all Swift.
  ///
  /// This method is not for public use. It is for Firebase clients of AuthInterop.
  @objc(getTokenForcingRefresh:withCallback:)
  public func getToken(forcingRefresh forceRefresh: Bool,
                       completion: @escaping (String?, Error?) -> Void) {
    Task {
      do {
        let token = try await authWorker.getToken(forcingRefresh: forceRefresh)
        await MainActor.run {
          completion(token, nil)
        }
      } catch {
        await MainActor.run {
          completion(nil, error)
        }
      }
    }
  }

  /// Get the current Auth user's UID. Returns nil if there is no user signed in.
  ///
  /// This method is not for public use. It is for Firebase clients of AuthInterop.
  open func getUserID() -> String? {
    return currentUser?.uid
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
  @objc public internal(set) var currentUser: User?

  /// The current user language code.
  ///
  /// This property can be set to the app's current language by
  /// calling `useAppLanguage()`.
  ///
  /// The string used to set this property must be a language code that follows BCP 47.
  @objc open var languageCode: String? {
    get {
      self.getLanguageCode()
    }
    set(val) {
      self.setLanguageCode(val)
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
    Task {
      do {
        let result = try await fetchSignInMethods(forEmail: email)
        await MainActor.run {
          completion?(result, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
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
    return try await authWorker.fetchSignInMethods(forEmail: email)
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
    Task {
      do {
        let result = try await signIn(withEmail: email, password: password)
        await MainActor.run {
          completion?(result, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
        }
      }
    }
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
  @discardableResult
  open func signIn(withEmail email: String, password: String) async throws -> AuthDataResult {
    let result = try await authWorker.signIn(withEmail: email, password: password)
    try await authWorker.updateCurrentUser(result.user, byForce: false, savingToDisk: true)
    return result
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
    Task {
      do {
        let result = try await signIn(withEmail: email, link: link)
        await MainActor.run {
          completion?(result, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
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
  open func signIn(withEmail email: String, link: String) async throws -> AuthDataResult {
    let result = try await authWorker.signIn(withEmail: email, link: link)
    try await authWorker.updateCurrentUser(result.user, byForce: false, savingToDisk: true)
    return result
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
      Task {
        do {
          let result = try await signIn(with: provider, uiDelegate: uiDelegate)
          await MainActor.run {
            completion?(result, nil)
          }
        } catch {
          await MainActor.run {
            completion?(nil, error)
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
    @available(tvOS, unavailable)
    @available(macOS, unavailable)
    @available(watchOS, unavailable)
    @discardableResult
    open func signIn(with provider: FederatedAuthProvider,
                     uiDelegate: AuthUIDelegate?) async throws -> AuthDataResult {
      let result = try await authWorker.signIn(with: provider, uiDelegate: uiDelegate)
      try await authWorker.updateCurrentUser(result.user, byForce: false, savingToDisk: true)
      return result
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
    Task {
      do {
        let result = try await signIn(with: credential)
        await MainActor.run {
          completion?(result, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
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
  @discardableResult
  open func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
    let result = try await authWorker.signIn(with: credential)
    try await authWorker.updateCurrentUser(result.user, byForce: false, savingToDisk: true)
    return result
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
    Task {
      do {
        let result = try await signInAnonymously()
        await MainActor.run {
          completion?(result, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
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
  @discardableResult
  @objc open func signInAnonymously() async throws -> AuthDataResult {
    let result = try await authWorker.signInAnonymously()
    try await authWorker.updateCurrentUser(result.user, byForce: false, savingToDisk: true)
    return result
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
    Task {
      do {
        let result = try await signIn(withCustomToken: token)
        await MainActor.run {
          completion?(result, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
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
  @discardableResult
  open func signIn(withCustomToken token: String) async throws -> AuthDataResult {
    let result = try await authWorker.signIn(withCustomToken: token)
    try await authWorker.updateCurrentUser(result.user, byForce: false, savingToDisk: true)
    return result
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
    Task {
      do {
        let result = try await createUser(withEmail: email, password: password)
        await MainActor.run {
          completion?(result, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
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
  /// - Returns: The `AuthDataResult` after the successful signin.
  @discardableResult
  open func createUser(withEmail email: String, password: String) async throws -> AuthDataResult {
    guard password.count > 0 else {
      throw AuthErrorUtils.weakPasswordError(serverResponseReason: "Missing password")
    }
    guard email.count > 0 else {
      throw AuthErrorUtils.missingEmailError(message: nil)
    }
    let result = try await authWorker.createUser(withEmail: email, password: password)
    try await authWorker.updateCurrentUser(result.user, byForce: false, savingToDisk: true)
    return result
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
    Task {
      do {
        try await confirmPasswordReset(withCode: code, newPassword: newPassword)
        await MainActor.run {
          completion(nil)
        }
      } catch {
        await MainActor.run {
          completion(error)
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
  open func confirmPasswordReset(withCode code: String, newPassword: String) async throws {
    try await authWorker.confirmPasswordReset(withCode: code, newPassword: newPassword)
  }

  /// Checks the validity of an out of band code.
  /// - Parameter code: The out of band code to check validity.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked
  /// asynchronously on the main thread in the future.
  @objc open func checkActionCode(_ code: String,
                                  completion: @escaping (ActionCodeInfo?, Error?) -> Void) {
    Task {
      do {
        let code = try await checkActionCode(code)
        await MainActor.run {
          completion(code, nil)
        }
      } catch {
        await MainActor.run {
          completion(nil, error)
        }
      }
    }
  }

  /// Checks the validity of an out of band code.
  /// - Parameter code: The out of band code to check validity.
  /// - Returns:  An `ActionCodeInfo`.
  open func checkActionCode(_ code: String) async throws -> ActionCodeInfo {
    return try await authWorker.checkActionCode(code)
  }

  /// Checks the validity of a verify password reset code.
  /// - Parameter code: The password reset code to be verified.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked asynchronously on the main thread in the future.
  @objc open func verifyPasswordResetCode(_ code: String,
                                          completion: @escaping (String?, Error?) -> Void) {
    Task {
      do {
        let email = try await verifyPasswordResetCode(code)
        await MainActor.run {
          completion(email, nil)
        }
      } catch {
        await MainActor.run {
          completion(nil, error)
        }
      }
    }
  }

  /// Checks the validity of a verify password reset code.
  /// - Parameter code: The password reset code to be verified.
  /// - Returns: An email.
  open func verifyPasswordResetCode(_ code: String) async throws -> String {
    return try await authWorker.verifyPasswordResetCode(code)
  }

  /// Applies out of band code.
  ///
  /// This method will not work for out of band codes which require an additional parameter,
  /// such as password reset code.
  /// - Parameter code: The out of band code to be applied.
  /// - Parameter completion: Optionally; a block which is invoked when the request finishes.
  /// Invoked asynchronously on the main thread in the future.
  @objc open func applyActionCode(_ code: String, completion: @escaping (Error?) -> Void) {
    Task {
      do {
        try await applyActionCode(code)
        await MainActor.run {
          completion(nil)
        }
      } catch {
        await MainActor.run {
          completion(error)
        }
      }
    }
  }

  /// Applies out of band code.
  ///
  /// This method will not work for out of band codes which require an additional parameter,
  /// such as password reset code.
  /// - Parameter code: The out of band code to be applied.
  open func applyActionCode(_ code: String) async throws {
    try await authWorker.applyActionCode(code)
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
    Task {
      do {
        try await sendPasswordReset(withEmail: email, actionCodeSettings: actionCodeSettings)
        await MainActor.run {
          completion?(nil)
        }
      } catch {
        await MainActor.run {
          completion?(error)
        }
      }
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
  open func sendPasswordReset(withEmail email: String,
                              actionCodeSettings: ActionCodeSettings? = nil) async throws {
    try await authWorker.sendPasswordReset(withEmail: email, actionCodeSettings: actionCodeSettings)
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
    Task {
      do {
        try await sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings)
        await MainActor.run {
          completion?(nil)
        }
      } catch {
        await MainActor.run {
          completion?(error)
        }
      }
    }
  }

  /// Sends a sign in with email link to provided email address.
  /// - Parameter email: The email address of the user.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  /// handling action codes.
  open func sendSignInLink(toEmail email: String,
                           actionCodeSettings: ActionCodeSettings) async throws {
    if !actionCodeSettings.handleCodeInApp {
      fatalError("The handleCodeInApp flag in ActionCodeSettings must be true for Email-link " +
        "Authentication.")
    }
    try await authWorker.sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings)
  }

  /// Signs out the current user.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeKeychainError` - Indicates an error occurred when accessing the
  /// keychain. The `NSLocalizedFailureReasonErrorKey` field in the `userInfo`
  /// dictionary will contain more information about the error encountered.
  @available(*, noasync, message: "Use the async version instead")
  @objc(signOut:) open func signOut() throws {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      try await authWorker.signOut()
      semaphore.signal()
    }
    semaphore.wait()
  }

  /// Signs out the current user.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeKeychainError` - Indicates an error occurred when accessing the
  /// keychain. The `NSLocalizedFailureReasonErrorKey` field in the `userInfo`
  /// dictionary will contain more information about the error encountered.
  open func signOut() async throws {
    try await authWorker.signOut()
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
        listener(auth, auth.currentUser)
      }
    }
    objc_sync_enter(Auth.self)
    listenerHandles.add(listener)
    objc_sync_exit(Auth.self)
    DispatchQueue.main.async {
      listener(self, self.currentUser)
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
    setLanguageCode(Locale.preferredLanguages.first)
  }

  /// Configures Firebase Auth to connect to an emulated host instead of the remote backend.
  @objc open func useEmulator(withHost host: String, port: Int) {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      await useEmulator(withHost: host, port: port)
      semaphore.signal()
    }
    semaphore.wait()
  }

  open func useEmulator(withHost host: String, port: Int) async {
    guard host.count > 0 else {
      fatalError("Cannot connect to empty host")
    }
    await authWorker.useEmulator(withHost: host, port: port)
  }

  /// Revoke the users token with authorization code.
  /// - Parameter completion: (Optional) the block invoked when the request to revoke the token is
  /// complete, or fails. Invoked asynchronously on the main thread in the future.
  @objc open func revokeToken(withAuthorizationCode authorizationCode: String,
                              completion: ((Error?) -> Void)? = nil) {
    Task {
      do {
        try await revokeToken(withAuthorizationCode: authorizationCode)
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

  /// Revoke the users token with authorization code.
  /// - Parameter completion: (Optional) the block invoked when the request to revoke the token is
  /// complete, or fails. Invoked asynchronously on the main thread in the future.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func revokeToken(withAuthorizationCode authorizationCode: String) async throws {
    if let currentUser {
      let idToken = try await currentUser.internalGetTokenAsync()
      let request = RevokeTokenRequest(withToken: authorizationCode,
                                      idToken: idToken,
                                      requestConfiguration: self.requestConfiguration)
      let _ = try await AuthBackend.call(with: request)
    }
  }

  /// Switch userAccessGroup and current user to the given accessGroup and the user stored in it.
  @objc open func useUserAccessGroup(_ accessGroup: String?) throws {
    // self.storedUserManager is initialized asynchronously. Make sure it is done.
    kAuthGlobalWorkQueue.sync {}
    return try internalUseUserAccessGroup(accessGroup)
  }

  func internalUseUserAccessGroup(_ accessGroup: String?) throws {
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

  /// Sets the `currentUser` on the receiver to the provided user object.
  /// - Parameters:
  ///   - user: The user object to be set as the current user of the calling Auth instance.
  ///   - completion: Optionally; a block invoked after the user of the calling Auth instance has
  ///             been updated or an error was encountered.
  @objc open func updateCurrentUser(_ user: User?, completion: ((Error?) -> Void)? = nil) {
    Task {
      guard let user else {
        await MainActor.run {
          completion?(AuthErrorUtils.nullUserError(message: nil))
        }
        return
      }
      do {
        try await updateCurrentUser(user)
        await MainActor.run {
          completion?(nil)
        }
      } catch {
        await MainActor.run {
          completion?(error)
        }
      }
    }
  }

  /// Sets the `currentUser` on the receiver to the provided user object.
  /// - Parameter user: The user object to be set as the current user of the calling Auth instance.
  /// - Parameter completion: Optionally; a block invoked after the user of the calling Auth
  /// instance has been updated or an error was encountered.
  open func updateCurrentUser(_ user: User) async throws {
    try await authWorker.updateCurrentUser(user)
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
      var data: Data?
      let semaphore = DispatchSemaphore(value: 0)
      Task {
        data = await tokenManagerGet().token?.data
        semaphore.signal()
      }
      semaphore.wait()
      return data
    }

  func tokenManagerInit(_ manager: AuthAPNSTokenManager) {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      await authWorker.tokenManagerInit(manager)
      semaphore.signal()
    }
    semaphore.wait()
  }

    func tokenManagerInit(_ manager: AuthAPNSTokenManager) async {
      await authWorker.tokenManagerInit(manager)
    }

  func tokenManagerGet() -> AuthAPNSTokenManager {
    var manager: AuthAPNSTokenManager!
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      manager = await tokenManagerGet()
      semaphore.signal()
    }
    semaphore.wait()
    return manager
  }

  func tokenManagerGet() async -> AuthAPNSTokenManager {
    return await authWorker.tokenManagerGet()
  }

    /// Sets the APNs token along with its type.
    ///
    /// This method is available on iOS only.
    ///
    /// If swizzling is disabled, the APNs Token must be set for phone number auth to work,
    /// by either setting calling this method or by setting the `APNSToken` property.
    @objc open func setAPNSToken(_ token: Data, type: AuthAPNSTokenType) {
      let semaphore = DispatchSemaphore(value: 0)
      Task {
        await authWorker.tokenManagerSet(token, type: type)
        semaphore.signal()
      }
      semaphore.wait()
    }

  /// Sets the APNs token along with its type.
  ///
  /// This method is available on iOS only.
  ///
  /// If swizzling is disabled, the APNs Token must be set for phone number auth to work,
  /// by either setting calling this method or by setting the `APNSToken` property.
  open func setAPNSToken(_ token: Data, type: AuthAPNSTokenType) async {
      await authWorker.tokenManagerSet(token, type: type)
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
    var result = false
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      result = await authWorker.canHandleNotification(userInfo)
      semaphore.signal()
    }
    semaphore.wait()
    return result
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
  @objc open func canHandleNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
      return await authWorker.canHandleNotification(userInfo)
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
      var result = false
      let semaphore = DispatchSemaphore(value: 0)
      Task {
        result = await authWorker.canHandle(url)
        semaphore.signal()
      }
      semaphore.wait()
      return result
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
  open func canHandle(_ url: URL) async -> Bool {
      return await authWorker.canHandle(url)
  }
  #endif

  /// The name of the `NSNotificationCenter` notification which is posted when the auth state
  /// changes (for example, a new token has been produced, a user signs in or signs out).
  ///
  /// The object parameter of the notification is the sender `Auth` instance.
  public static let authStateDidChangeNotification =
    NSNotification.Name(rawValue: "FIRAuthStateDidChangeNotification")

  // MARK: Internal methods

  init(app: FirebaseApp, keychainStorageProvider: AuthKeychainStorage = AuthKeychainStorageReal()) {
    Auth.setKeychainServiceNameForApp(app)
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
    authWorker = AuthWorker(requestConfiguration: requestConfiguration)
    super.init()
    requestConfiguration.auth = self

    Task {
      await authWorker.protectedDataInitialization(keychainStorageProvider)
    }
  }

  // TODO delete me

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

  // TODO: delete me
  func updateCurrentUser(_ user: User?, byForce force: Bool,
                         savingToDisk saveToDisk: Bool) throws {
    if user == currentUser {
      possiblyPostAuthStateChangeNotification()
    }
    if let user {
      if user.tenantID != nil || tenantID != nil, tenantID != user.tenantID {
        let error = AuthErrorUtils.tenantIDMismatchError()
        throw error
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
      currentUser = user
      possiblyPostAuthStateChangeNotification()
    }
    if let throwError {
      throw throwError
    }
  }

  #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func addProtectedDataDidBecomeAvailableObserver() {
      weak var weakSelf = self
      protectedDataDidBecomeAvailableObserver =
        NotificationCenter.default.addObserver(
          forName: UIApplication.protectedDataDidBecomeAvailableNotification,
          object: nil,
          queue: nil
        ) { notification in
          let strongSelf = weakSelf
          if let observer = strongSelf?.protectedDataDidBecomeAvailableObserver {
            NotificationCenter.default.removeObserver(
              observer,
              name: UIApplication.protectedDataDidBecomeAvailableNotification,
              object: nil
            )
          }
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

  func getUser() throws -> User? {
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
    if user != currentUser {
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
  /// @syncronized([FIRAuth class]) context.
  fileprivate static var gKeychainServiceNameForAppName: [String: String] = [:]

  /// Sets the keychain service name global data for the particular app.
  /// - Parameter app: The Firebase app to set keychain service name for.
  class func setKeychainServiceNameForApp(_ app: FirebaseApp) {
    objc_sync_enter(Auth.self)
    gKeychainServiceNameForAppName[app.name] = "firebase_auth_\(app.options.googleAppID)"
    objc_sync_exit(Auth.self)
  }

  /// Gets the keychain service name global data for the particular app by name.
  /// - Parameter appName: The name of the Firebase app to get keychain service name for.
  class func keychainServiceName(forAppName appName: String) -> String? {
    objc_sync_enter(Auth.self)
    defer { objc_sync_exit(Auth.self) }
    return gKeychainServiceNameForAppName[appName]
  }

  /// Deletes the keychain service name global data for the particular app by name.
  /// - Parameter appName: The name of the Firebase app to delete keychain service name for.
  class func deleteKeychainServiceNameForAppName(_ appName: String) {
    objc_sync_enter(Auth.self)
    gKeychainServiceNameForAppName.removeValue(forKey: appName)
    objc_sync_exit(Auth.self)
  }

  func signOutByForce(withUserID userID: String) throws {
    guard currentUser?.uid == userID else {
      return
    }
    try updateCurrentUser(nil, byForce: true, savingToDisk: true)
  }

  // MARK: Private methods

  /// Posts the auth state change notification if current user's token has been changed.
  func possiblyPostAuthStateChangeNotification() {
    let token = currentUser?.rawAccessToken()
    if lastNotifiedUserToken == token ||
      (token != nil && lastNotifiedUserToken == token) {
      return
    }
    lastNotifiedUserToken = token
    if autoRefreshTokens {
      // Shedule new refresh task after successful attempt.
      scheduleAutoTokenRefresh()
    }
    var internalNotificationParameters: [String: Any] = [:]
    if let app = app {
      internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationAppKey] = app
    }
    if let token, token.count > 0 {
      internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationTokenKey] = token
    }
    internalNotificationParameters[FIRAuthStateDidChangeInternalNotificationUIDKey] = currentUser?
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
  func scheduleAutoTokenRefresh() {
    let tokenExpirationInterval =
      (currentUser?.accessTokenExpirationDate()?.timeIntervalSinceNow ?? 0) - 5 * 60
    scheduleAutoTokenRefresh(withDelay: max(tokenExpirationInterval, 0), retry: false)
  }

  /// Schedules a task to automatically refresh tokens on the current user.
  /// - Parameter delay: The delay in seconds after which the token refresh task should be scheduled
  /// to be executed.
  /// - Parameter retry: Flag to determine whether the invocation is a retry attempt or not.
  func scheduleAutoTokenRefresh(withDelay delay: TimeInterval, retry: Bool) {
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
    autoRefreshScheduled = true
    Task {
      await authWorker.autoTokenRefresh(accessToken: accessToken, 
                                        retry: retry,
                                        delay: fastTokenRefreshForTest ? 0.1 : delay)
    }
  }

  func saveUser(_ user: User?) throws {
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

  private func getLanguageCode() -> String? {
    var code: String?
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      code = await authWorker.getLanguageCode()
      semaphore.signal()
    }
    semaphore.wait()
    return code
  }

  private func setLanguageCode(_ code: String?) {
    let semaphore = DispatchSemaphore(value: 0)
    Task {
      await authWorker.setLanguageCode(code)
      semaphore.signal()
    }
    semaphore.wait()
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

  // MARK: Internal properties

  /// Allow tests to swap in an alternate mainBundle.
  var mainBundleUrlTypes: [[String: Any]]!

  /// The configuration object comprising of parameters needed to make a request to Firebase
  ///   Auth's backend.
  var requestConfiguration: AuthRequestConfiguration

  let authWorker: AuthWorker

  var fastTokenRefreshForTest = false

  #if os(iOS)

    /// The manager for app credentials used by phone number auth.
    var appCredentialManager: AuthAppCredentialManager!

    /// The manager for remote notifications used by phone number auth.
    var notificationManager: AuthNotificationManager!

    /// An object that takes care of presenting URLs via the auth instance.
    var authURLPresenter: AuthWebViewControllerDelegate

  #endif // TARGET_OS_IOS

  // MARK: Private properties

  /// The stored user manager.
  var storedUserManager: AuthStoredUserManager!

  /// The Firebase app name.
  let firebaseAppName: String

  /// The keychain service.
  var keychainServices: AuthKeychainServices!

  /// The user access (ID) token used last time for posting auth state changed notification.
  var lastNotifiedUserToken: String?

  /// This flag denotes whether or not tokens should be automatically refreshed.
  /// Will only be set to `true` if the another Firebase service is included (additionally to
  ///  Firebase Auth).
  private var autoRefreshTokens = false

  /// Whether or not token auto-refresh is currently scheduled.
  var autoRefreshScheduled = false

  /// A flag that is set to YES if the app is put in the background and no when the app is
  ///    returned to the foreground.
  var isAppInBackground = false

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
  /// Mutations should occur within a @syncronized(self) context.
  private var listenerHandles: NSMutableArray = []
}
