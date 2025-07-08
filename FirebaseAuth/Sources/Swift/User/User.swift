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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
extension User: NSSecureCoding {}

/// Represents a user.
///
/// Firebase Auth does not attempt to validate users
/// when loading them from the keychain. Invalidated users (such as those
/// whose passwords have been changed on another client) are automatically
/// logged out when an auth-dependent operation is attempted or when the
/// ID token is automatically refreshed.
///
/// This class is thread-safe.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRUser) open class User: NSObject, UserInfo {
  /// Indicates the user represents an anonymous user.
  @objc public internal(set) var isAnonymous: Bool

  /// Indicates the user represents an anonymous user.
  @objc open func anonymous() -> Bool { return isAnonymous }

  /// Indicates the email address associated with this user has been verified.
  @objc public private(set) var isEmailVerified: Bool

  /// Indicates the email address associated with this user has been verified.
  @objc open func emailVerified() -> Bool { return isEmailVerified }

  /// Profile data for each identity provider, if any.
  ///
  /// This data is cached on sign-in and updated when linking or unlinking.
  @objc open var providerData: [UserInfo] {
    return Array(providerDataRaw.values)
  }

  var providerDataRaw: [String: UserInfoImpl]

  /// The backend service for the given instance.
  private(set) var backend: AuthBackend

  /// Metadata associated with the Firebase user in question.
  @objc public private(set) var metadata: UserMetadata

  /// The tenant ID of the current user. `nil` if none is available.
  @objc public private(set) var tenantID: String?

  #if os(iOS)
    /// Multi factor object associated with the user.
    ///
    /// This property is available on iOS only.
    @objc public private(set) var multiFactor: MultiFactor
  #endif

  /// [Deprecated] Updates the email address for the user.
  ///
  /// On success, the cached user profile data is updated. Returns an error when
  /// [Email Enumeration Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled.
  ///
  ///  May fail if there is already an account with this email address that was created using
  /// email and password authentication.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
  ///   sent in the request.
  /// *  `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
  ///    the console for this action.
  /// *  `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
  ///   sending update email.
  /// *  `AuthErrorCodeEmailAlreadyInUse` - Indicates the email is already in use by another
  ///    account.
  /// *  `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// *  `AuthErrorCodeRequiresRecentLogin` - Updating a user’s email is a security
  ///  sensitive operation that requires a recent login from the user. This error indicates
  ///  the user has not signed in recently enough. To resolve, reauthenticate the user by
  ///  calling `reauthenticate(with:)`.
  /// - Parameter email: The email address for the user.
  /// - Parameter completion: Optionally; the block invoked when the user profile change has
  /// finished.
  #if !FIREBASE_CI
    @available(
      *,
      deprecated,
      message: "`updateEmail` is deprecated and will be removed in a future release. Use sendEmailVerification(beforeUpdatingEmail:) instead."
    )
  #endif // !FIREBASE_CI
  @objc(updateEmail:completion:)
  open func updateEmail(to email: String, completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.updateEmail(email: email, password: nil) { error in
        User.callInMainThreadWithError(callback: completion, error: error)
      }
    }
  }

  /// [Deprecated] Updates the email address for the user.
  ///
  /// On success, the cached user profile data is updated. Throws when
  /// [Email Enumeration Protection](https://cloud.google.com/identity-platform/docs/admin/email-enumeration-protection)
  /// is enabled.
  ///
  /// May fail if there is already an account with this email address that was created using
  /// email and password authentication.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
  ///   sent in the request.
  /// *  `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
  ///    the console for this action.
  /// *  `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
  ///   sending update email.
  /// *  `AuthErrorCodeEmailAlreadyInUse` - Indicates the email is already in use by another
  ///    account.
  /// *  `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// *  `AuthErrorCodeRequiresRecentLogin` - Updating a user’s email is a security
  ///  sensitive operation that requires a recent login from the user. This error indicates
  ///  the user has not signed in recently enough. To resolve, reauthenticate the user by
  ///  calling `reauthenticate(with:)`.
  /// - Parameter email: The email address for the user.
  #if !FIREBASE_CI
    @available(
      *,
      deprecated,
      message: "`updateEmail` is deprecated and will be removed in a future release. Use sendEmailVerification(beforeUpdatingEmail:) instead."
    )
  #endif // !FIREBASE_CI
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func updateEmail(to email: String) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.updateEmail(to: email) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /// Updates the password for the user. On success, the cached user profile data is updated.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates the administrator disabled
  ///        sign in with the specified identity provider.
  /// * `AuthErrorCodeRequiresRecentLogin` - Updating a user’s password is a security
  ///        sensitive operation that requires a recent login from the user. This error indicates
  ///        the user has not signed in recently enough. To resolve, reauthenticate the user by
  ///        calling `reauthenticate(with:)`.
  /// * `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
  /// considered too weak. The `NSLocalizedFailureReasonErrorKey` field in the `userInfo`
  /// dictionary object will contain more detailed explanation that can be shown to the user.
  /// - Parameter password: The new password for the user.
  /// - Parameter completion: Optionally; the block invoked when the user profile change has
  /// finished.
  @objc(updatePassword:completion:)
  open func updatePassword(to password: String, completion: ((Error?) -> Void)? = nil) {
    guard password.count > 0 else {
      if let completion {
        completion(AuthErrorUtils.weakPasswordError(serverResponseReason: "Missing Password"))
      }
      return
    }
    kAuthGlobalWorkQueue.async {
      self.updateEmail(email: nil, password: password) { error in
        User.callInMainThreadWithError(callback: completion, error: error)
      }
    }
  }

  /// Updates the password for the user. On success, the cached user profile data is updated.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates the administrator disabled
  ///        sign in with the specified identity provider.
  /// * `AuthErrorCodeRequiresRecentLogin` - Updating a user’s password is a security
  ///        sensitive operation that requires a recent login from the user. This error indicates
  ///        the user has not signed in recently enough. To resolve, reauthenticate the user by
  ///        calling `reauthenticate(with:)`.
  /// * `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
  /// considered too weak. The `NSLocalizedFailureReasonErrorKey` field in the `userInfo`
  /// dictionary object will contain more detailed explanation that can be shown to the user.
  /// - Parameter password: The new password for the user.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func updatePassword(to password: String) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.updatePassword(to: password) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  #if os(iOS)
    /// Updates the phone number for the user. On success, the cached user profile data is updated.
    ///
    /// Invoked asynchronously on the main thread in the future.
    ///
    /// This method is available on iOS only.
    ///
    /// Possible error codes:
    /// * `AuthErrorCodeRequiresRecentLogin` - Updating a user’s phone number is a security
    ///    sensitive operation that requires a recent login from the user. This error indicates
    ///    the user has not signed in recently enough. To resolve, reauthenticate the user by
    ///    calling `reauthenticate(with:)`.
    /// - Parameter credential: The new phone number credential corresponding to the
    /// phone number to be added to the Firebase account, if a phone number is already linked to the
    /// account this new phone number will replace it.
    /// - Parameter completion: Optionally; the block invoked when the user profile change has
    /// finished.
    @objc(updatePhoneNumberCredential:completion:)
    open func updatePhoneNumber(_ credential: PhoneAuthCredential,
                                completion: ((Error?) -> Void)? = nil) {
      kAuthGlobalWorkQueue.async {
        self.internalUpdateOrLinkPhoneNumber(credential: credential,
                                             isLinkOperation: false) { error in
          User.callInMainThreadWithError(callback: completion, error: error)
        }
      }
    }

    /// Updates the phone number for the user. On success, the cached user profile data is updated.
    ///
    /// Invoked asynchronously on the main thread in the future.
    ///
    /// This method is available on iOS only.
    ///
    /// Possible error codes:
    /// * `AuthErrorCodeRequiresRecentLogin` - Updating a user’s phone number is a security
    ///    sensitive operation that requires a recent login from the user. This error indicates
    ///    the user has not signed in recently enough. To resolve, reauthenticate the user by
    ///     calling `reauthenticate(with:)`.
    /// - Parameter credential: The new phone number credential corresponding to the
    /// phone number to be added to the Firebase account, if a phone number is already linked to the
    /// account this new phone number will replace it.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    open func updatePhoneNumber(_ credential: PhoneAuthCredential) async throws {
      return try await withCheckedThrowingContinuation { continuation in
        self.updatePhoneNumber(credential) { error in
          if let error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        }
      }
    }
  #endif

  /// Creates an object which may be used to change the user's profile data.
  ///
  ///  Set the properties of the returned object, then call
  ///  `UserProfileChangeRequest.commitChanges()` to perform the updates atomically.
  /// - Returns: An object which may be used to change the user's profile data atomically.
  @objc(profileChangeRequest)
  open func createProfileChangeRequest() -> UserProfileChangeRequest {
    var result: UserProfileChangeRequest!
    kAuthGlobalWorkQueue.sync {
      result = UserProfileChangeRequest(self)
    }
    return result
  }

  /// A refresh token; useful for obtaining new access tokens independently.
  ///
  ///  This property should only be used for advanced scenarios, and is not typically needed.
  @objc open var refreshToken: String? {
    var result: String?
    kAuthGlobalWorkQueue.sync {
      result = self.tokenService.refreshToken
    }
    return result
  }

  /// Reloads the user's profile data from the server.
  ///
  /// May fail with an `AuthErrorCodeRequiresRecentLogin` error code. In this case
  /// you should call `reauthenticate(with:)` before re-invoking
  /// `updateEmail(to:)`.
  /// - Parameter completion: Optionally; the block invoked when the reload has finished. Invoked
  ///   asynchronously on the main thread in the future.
  @objc open func reload(completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.getAccountInfoRefreshingCache { user, error in
        User.callInMainThreadWithError(callback: completion, error: error)
      }
    }
  }

  /// Reloads the user's profile data from the server.
  ///
  /// May fail with an `AuthErrorCodeRequiresRecentLogin` error code. In this case
  /// you should call `reauthenticate(with:)` before re-invoking
  /// `updateEmail(to:)`.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func reload() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.reload { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /// Renews the user's authentication tokens by validating a fresh set of credentials supplied
  /// by the user  and returns additional identity provider data.
  ///
  /// If the user associated with the supplied credential is different from the current user,
  /// or if the validation of the supplied credentials fails; an error is returned and the current
  /// user remains signed in.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
  ///    This could happen if it has expired or it is malformed.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that accounts with the
  ///    identity provider represented by the credential are not enabled. Enable them in the
  ///    Auth section of the Firebase console.
  /// *  `AuthErrorCodeEmailAlreadyInUse` -  Indicates the email asserted by the credential
  ///    (e.g. the email in a Facebook access token) is already in use by an existing account,
  ///    that cannot be authenticated with this method. This error will only be thrown if the
  ///   "One account per email address" setting is enabled in the Firebase console, under Auth
  ///   settings. Please note that the error code raised in this specific situation may not be
  ///    the same on Web and Android.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted reauthentication with
  ///    an incorrect password, if credential is of the type `EmailPasswordAuthCredential`.
  /// * `AuthErrorCodeUserMismatch` -  Indicates that an attempt was made to
  ///    reauthenticate with a user which is not the current user.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// - Parameter credential: A user-supplied credential, which will be validated by the server.
  /// This can be a successful third-party identity provider sign-in, or an email address and
  /// password.
  /// - Parameter completion: Optionally; the block invoked when the re-authentication operation has
  /// finished. Invoked asynchronously on the main thread in the future.
  @objc(reauthenticateWithCredential:completion:)
  open func reauthenticate(with credential: AuthCredential,
                           completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      Task {
        do {
          let authResult = try await self.auth?.internalSignInAndRetrieveData(
            withCredential: credential,
            isReauthentication: true
          )
          guard let user = authResult?.user,
                user.uid == self.auth?.getUserID() else {
            User.callInMainThreadWithAuthDataResultAndError(
              callback: completion,
              result: authResult,
              error: AuthErrorUtils.userMismatchError()
            )
            return
          }
          // Successful reauthenticate
          do {
            try await self.userProfileUpdate.setTokenService(user: self,
                                                             tokenService: user.tokenService)
            User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                            result: authResult,
                                                            error: nil)
          } catch {
            User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                            result: authResult,
                                                            error: error)
          }
        } catch {
          // If "user not found" error returned by backend,
          // translate to user mismatch error which is more
          // accurate.
          var reportError: Error = error
          if (error as NSError).code == AuthErrorCode.userNotFound.rawValue {
            reportError = AuthErrorUtils.userMismatchError()
          }
          User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                          result: nil,
                                                          error: reportError)
        }
      }
    }
  }

  /// Renews the user's authentication tokens by validating a fresh set of credentials supplied
  /// by the user  and returns additional identity provider data.
  ///
  /// If the user associated with the supplied credential is different from the current user,
  /// or if the validation of the supplied credentials fails; an error is returned and the current
  /// user remains signed in.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
  ///    This could happen if it has expired or it is malformed.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that accounts with the
  ///    identity provider represented by the credential are not enabled. Enable them in the
  ///    Auth section of the Firebase console.
  /// *  `AuthErrorCodeEmailAlreadyInUse` -  Indicates the email asserted by the credential
  ///    (e.g. the email in a Facebook access token) is already in use by an existing account,
  ///    that cannot be authenticated with this method. This error will only be thrown if the
  ///   "One account per email address" setting is enabled in the Firebase console, under Auth
  ///   settings. Please note that the error code raised in this specific situation may not be
  ///    the same on Web and Android.
  /// * `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
  /// * `AuthErrorCodeWrongPassword` - Indicates the user attempted reauthentication with
  ///    an incorrect password, if credential is of the type `EmailPasswordAuthCredential`.
  /// * `AuthErrorCodeUserMismatch` -  Indicates that an attempt was made to
  ///    reauthenticate with a user which is not the current user.
  /// * `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
  /// - Parameter credential: A user-supplied credential, which will be validated by the server.
  /// This can be a successful third-party identity provider sign-in, or an email address and
  /// password.
  /// - Returns: The `AuthDataResult` after the reauthentication.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  open func reauthenticate(with credential: AuthCredential) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.reauthenticate(with: credential) { result, error in
        if let result {
          continuation.resume(returning: result)
        } else if let error {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  #if os(iOS)
    /// Renews the user's authentication using the provided auth provider instance.
    ///
    /// This method is available on iOS only.
    /// - Parameter provider: An instance of an auth provider used to initiate the reauthenticate
    /// flow.
    /// - Parameter uiDelegate: Optionally an instance of a class conforming to the `AuthUIDelegate`
    ///    protocol, used for presenting the web context. If nil, a default `AuthUIDelegate`
    ///    will be used.
    /// - Parameter completion: Optionally; a block which is invoked when the reauthenticate flow
    /// finishes, or is canceled. Invoked asynchronously on the main thread in the future.
    @objc(reauthenticateWithProvider:UIDelegate:completion:)
    open func reauthenticate(with provider: FederatedAuthProvider,
                             uiDelegate: AuthUIDelegate?,
                             completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
      kAuthGlobalWorkQueue.async {
        Task {
          do {
            let credential = try await provider.credential(with: uiDelegate)
            self.reauthenticate(with: credential, completion: completion)
          } catch {
            if let completion {
              completion(nil, error)
            }
          }
        }
      }
    }

    /// Renews the user's authentication using the provided auth provider instance.
    ///
    /// This method is available on iOS only.
    /// - Parameter provider: An instance of an auth provider used to initiate the reauthenticate
    /// flow.
    /// - Parameter uiDelegate: Optionally an instance of a class conforming to the `AuthUIDelegate`
    ///    protocol, used for presenting the web context. If nil, a default `AuthUIDelegate`
    ///    will be used.
    /// - Returns: The `AuthDataResult` after the reauthentication.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    @discardableResult
    open func reauthenticate(with provider: FederatedAuthProvider,
                             uiDelegate: AuthUIDelegate?) async throws -> AuthDataResult {
      return try await withCheckedThrowingContinuation { continuation in
        self.reauthenticate(with: provider, uiDelegate: uiDelegate) { result, error in
          if let result {
            continuation.resume(returning: result)
          } else if let error {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  #endif

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  /// - Parameter completion: Optionally; the block invoked when the token is available. Invoked
  ///    asynchronously on the main thread in the future.
  @objc(getIDTokenWithCompletion:)
  open func getIDToken(completion: ((String?, Error?) -> Void)?) {
    // |getIDTokenForcingRefresh:completion:| is also a public API so there is no need to dispatch to
    // global work queue here.
    getIDTokenForcingRefresh(false, completion: completion)
  }

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  ///
  /// The authentication token will be refreshed (by making a network request) if it has
  /// expired, or if `forceRefresh` is `true`.
  /// - Parameter forceRefresh: Forces a token refresh. Useful if the token becomes invalid for some
  /// reason other than an expiration.
  /// - Parameter completion: Optionally; the block invoked when the token is available. Invoked
  ///    asynchronously on the main thread in the future.
  @objc(getIDTokenForcingRefresh:completion:)
  open func getIDTokenForcingRefresh(_ forceRefresh: Bool,
                                     completion: ((String?, Error?) -> Void)?) {
    getIDTokenResult(forcingRefresh: forceRefresh) { tokenResult, error in
      if let completion {
        DispatchQueue.main.async {
          completion(tokenResult?.token, error)
        }
      }
    }
  }

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  ///
  /// The authentication token will be refreshed (by making a network request) if it has
  /// expired, or if `forceRefresh` is `true`.
  /// - Parameter forceRefresh: Forces a token refresh. Useful if the token becomes invalid for some
  /// reason other than an expiration.
  /// - Returns: The Firebase authentication token.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func getIDToken(forcingRefresh forceRefresh: Bool = false) async throws -> String {
    return try await withCheckedThrowingContinuation { continuation in
      self.getIDTokenForcingRefresh(forceRefresh) { tokenResult, error in
        if let tokenResult {
          continuation.resume(returning: tokenResult)
        } else if let error {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// API included for compatibility with a mis-named Firebase 10 API.
  /// Use `getIDToken(forcingRefresh forceRefresh: Bool = false)` instead.
  open func idTokenForcingRefresh(_ forceRefresh: Bool) async throws -> String {
    return try await getIDToken(forcingRefresh: forceRefresh)
  }

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  /// - Parameter completion: Optionally; the block invoked when the token is available. Invoked
  ///    asynchronously on the main thread in the future.
  @objc(getIDTokenResultWithCompletion:)
  open func getIDTokenResult(completion: ((AuthTokenResult?, Error?) -> Void)?) {
    getIDTokenResult(forcingRefresh: false) { tokenResult, error in
      if let completion {
        DispatchQueue.main.async {
          completion(tokenResult, error)
        }
      }
    }
  }

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  ///
  /// The authentication token will be refreshed (by making a network request) if it has
  /// expired, or if `forcingRefresh` is `true`.
  /// - Parameter forcingRefresh: Forces a token refresh. Useful if the token becomes invalid for
  /// some
  /// reason other than an expiration.
  /// - Parameter completion: Optionally; the block invoked when the token is available. Invoked
  /// asynchronously on the main thread in the future.
  @objc(getIDTokenResultForcingRefresh:completion:)
  open func getIDTokenResult(forcingRefresh: Bool,
                             completion: ((AuthTokenResult?, Error?) -> Void)?) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken(forceRefresh: forcingRefresh, backend: self.backend) { token, error in
        var tokenResult: AuthTokenResult?
        if let token {
          do {
            tokenResult = try AuthTokenResult.tokenResult(token: token)
            AuthLog.logDebug(code: "I-AUT000017", message: "Actual token expiration date: " +
              "\(String(describing: tokenResult?.expirationDate))," +
              "current date: \(Date())")
            if let completion {
              DispatchQueue.main.async {
                completion(tokenResult, error)
              }
            }
            return
          } catch {
            if let completion {
              DispatchQueue.main.async {
                completion(tokenResult, error)
              }
            }
            return
          }
        }
        if let completion {
          DispatchQueue.main.async {
            completion(nil, error)
          }
        }
      }
    }
  }

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  ///
  /// The authentication token will be refreshed (by making a network request) if it has
  /// expired, or if `forceRefresh` is `true`.
  /// - Parameter forceRefresh: Forces a token refresh. Useful if the token becomes invalid for some
  /// reason other than an expiration.
  /// - Returns: The Firebase authentication token.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func getIDTokenResult(forcingRefresh forceRefresh: Bool = false) async throws
    -> AuthTokenResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.getIDTokenResult(forcingRefresh: forceRefresh) { tokenResult, error in
        if let tokenResult {
          continuation.resume(returning: tokenResult)
        } else if let error {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /// Associates a user account from a third-party identity provider with this user and
  ///    returns additional identity provider data.
  ///
  ///    Invoked asynchronously on the main thread in the future.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeProviderAlreadyLinked` - Indicates an attempt to link a provider of a
  ///    type already linked to this account.
  /// * `AuthErrorCodeCredentialAlreadyInUse` - Indicates an attempt to link with a
  ///    credential that has already been linked with a different Firebase account.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that accounts with the identity
  ///    provider represented by the credential are not enabled. Enable them in the Auth section
  ///    of the Firebase console.
  ///
  /// This method may also return error codes associated with `updateEmail(to:)` and
  /// `updatePassword(to:)` on `User`.
  /// - Parameter credential: The credential for the identity provider.
  /// - Parameter completion: Optionally; the block invoked when the unlinking is complete, or
  /// fails.
  @objc(linkWithCredential:completion:)
  open func link(with credential: AuthCredential,
                 completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      if self.providerDataRaw[credential.provider] != nil {
        User.callInMainThreadWithAuthDataResultAndError(
          callback: completion,
          result: nil,
          error: AuthErrorUtils.providerAlreadyLinkedError()
        )
        return
      }
      if let emailCredential = credential as? EmailAuthCredential {
        self.link(withEmailCredential: emailCredential, completion: completion)
        return
      }
      #if !os(watchOS)
        if let gameCenterCredential = credential as? GameCenterAuthCredential {
          self.link(withGameCenterCredential: gameCenterCredential, completion: completion)
          return
        }
      #endif
      #if os(iOS)
        if let phoneCredential = credential as? PhoneAuthCredential {
          self.link(withPhoneCredential: phoneCredential, completion: completion)
          return
        }
      #endif

      Task {
        do {
          let authDataResult = try await self.userProfileUpdate.link(user: self, with: credential)
          await MainActor.run {
            completion?(authDataResult, nil)
          }
        } catch {
          await MainActor.run {
            completion?(nil, error)
          }
        }
      }
    }
  }

  /// Associates a user account from a third-party identity provider with this user and
  /// returns additional identity provider data.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeProviderAlreadyLinked` - Indicates an attempt to link a provider of a
  ///    type already linked to this account.
  /// * `AuthErrorCodeCredentialAlreadyInUse` - Indicates an attempt to link with a
  ///    credential that has already been linked with a different Firebase account.
  /// * `AuthErrorCodeOperationNotAllowed` - Indicates that accounts with the identity
  ///    provider represented by the credential are not enabled. Enable them in the Auth section
  ///    of the Firebase console.
  ///
  /// This method may also return error codes associated with `updateEmail(to:)` and
  /// `updatePassword(to:)` on `User`.
  /// - Parameter credential: The credential for the identity provider.
  /// - Returns: An `AuthDataResult`.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  open func link(with credential: AuthCredential) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation { continuation in
      self.link(with: credential) { result, error in
        if let result {
          continuation.resume(returning: result)
        } else if let error {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  #if os(iOS)
    /// Link the user with the provided auth provider instance.
    ///
    /// This method is available on iOSonly.
    /// - Parameter provider: An instance of an auth provider used to initiate the link flow.
    /// - Parameter uiDelegate: Optionally an instance of a class conforming to the `AuthUIDelegate`
    /// protocol used for presenting the web context. If nil, a default `AuthUIDelegate` will be
    /// used.
    /// - Parameter completion: Optionally; a block which is invoked when the link flow finishes, or
    ///    is canceled. Invoked asynchronously on the main thread in the future.
    @objc(linkWithProvider:UIDelegate:completion:)
    open func link(with provider: FederatedAuthProvider,
                   uiDelegate: AuthUIDelegate?,
                   completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
      kAuthGlobalWorkQueue.async {
        Task {
          do {
            let credential = try await provider.credential(with: uiDelegate)
            self.link(with: credential, completion: completion)
          } catch {
            if let completion {
              completion(nil, error)
            }
          }
        }
      }
    }

    /// Link the user with the provided auth provider instance.
    ///
    /// This method is available on iOSonly.
    /// - Parameter provider: An instance of an auth provider used to initiate the link flow.
    /// - Parameter uiDelegate: Optionally an instance of a class conforming to the `AuthUIDelegate`
    /// protocol used for presenting the web context. If nil, a default `AuthUIDelegate`
    ///    will be used.
    /// - Returns: An AuthDataResult.
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    @discardableResult
    open func link(with provider: FederatedAuthProvider,
                   uiDelegate: AuthUIDelegate?) async throws -> AuthDataResult {
      return try await withCheckedThrowingContinuation { continuation in
        self.link(with: provider, uiDelegate: uiDelegate) { result, error in
          if let result {
            continuation.resume(returning: result)
          } else if let error {
            continuation.resume(throwing: error)
          }
        }
      }
    }
  #endif

  /// Disassociates a user account from a third-party identity provider with this user.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeNoSuchProvider` - Indicates an attempt to unlink a provider
  ///    that is not linked to the account.
  /// * `AuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
  ///    operation that requires a recent login from the user. This error indicates the user
  ///    has not signed in recently enough. To resolve, reauthenticate the user by calling
  ///    `reauthenticate(with:)`.
  /// - Parameter provider: The provider ID of the provider to unlink.
  /// - Parameter completion: Optionally; the block invoked when the unlinking is complete, or
  /// fails.
  @objc open func unlink(fromProvider provider: String,
                         completion: ((User?, Error?) -> Void)? = nil) {
    Task {
      do {
        let user = try await unlink(fromProvider: provider)
        await MainActor.run {
          completion?(user, nil)
        }
      } catch {
        await MainActor.run {
          completion?(nil, error)
        }
      }
    }
  }

  /// Disassociates a user account from a third-party identity provider with this user.
  ///
  /// Invoked asynchronously on the main thread in the future.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeNoSuchProvider` - Indicates an attempt to unlink a provider
  ///    that is not linked to the account.
  /// * `AuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
  ///    operation that requires a recent login from the user. This error indicates the user
  ///    has not signed in recently enough. To resolve, reauthenticate the user by calling
  ///    `reauthenticate(with:)`.
  /// - Parameter provider: The provider ID of the provider to unlink.
  /// - Returns: The user.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func unlink(fromProvider provider: String) async throws -> User {
    return try await userProfileUpdate.unlink(user: self, fromProvider: provider)
  }

  /// Initiates email verification for the user.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
  ///    sent in the request.
  /// * `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
  ///    the console for this action.
  /// * `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
  ///    sending update email.
  /// * `AuthErrorCodeUserNotFound` - Indicates the user account was not found.
  /// - Parameter completion: Optionally; the block invoked when the request to send an email
  /// verification is complete, or fails. Invoked asynchronously on the main thread in the future.
  @objc(sendEmailVerificationWithCompletion:)
  open func __sendEmailVerification(withCompletion completion: ((Error?) -> Void)?) {
    sendEmailVerification(completion: completion)
  }

  /// Initiates email verification for the user.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
  ///    sent in the request.
  /// * `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
  ///    the console for this action.
  /// * `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
  ///    sending update email.
  /// * `AuthErrorCodeUserNotFound` - Indicates the user account was not found.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  /// handling action codes.
  /// - Parameter completion: Optionally; the block invoked when the request to send an email
  /// verification is complete, or fails. Invoked asynchronously on the main thread in the future.
  @objc(sendEmailVerificationWithActionCodeSettings:completion:)
  open func sendEmailVerification(with actionCodeSettings: ActionCodeSettings? = nil,
                                  completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken(backend: self.backend) { accessToken, error in
        if let error {
          User.callInMainThreadWithError(callback: completion, error: error)
          return
        }
        guard let accessToken else {
          fatalError("Internal Error: Both error and accessToken are nil.")
        }
        guard let requestConfiguration = self.auth?.requestConfiguration else {
          fatalError("Internal Error: Unexpected nil requestConfiguration.")
        }
        let request = GetOOBConfirmationCodeRequest.verifyEmailRequest(
          accessToken: accessToken,
          actionCodeSettings: actionCodeSettings,
          requestConfiguration: requestConfiguration
        )
        Task {
          do {
            let _ = try await self.backend.call(with: request)
            User.callInMainThreadWithError(callback: completion, error: nil)
          } catch {
            self.signOutIfTokenIsInvalid(withError: error)
            User.callInMainThreadWithError(callback: completion, error: error)
          }
        }
      }
    }
  }

  /// Initiates email verification for the user.
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
  ///    sent in the request.
  /// * `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
  ///    the console for this action.
  /// * `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
  ///    sending update email.
  /// * `AuthErrorCodeUserNotFound` - Indicates the user account was not found.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  /// handling action codes. The default value is `nil`.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func sendEmailVerification(with actionCodeSettings: ActionCodeSettings? = nil) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.sendEmailVerification(with: actionCodeSettings) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /// Deletes the user account (also signs out the user, if this was the current user).
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
  ///  operation that requires a recent login from the user. This error indicates the user
  /// has not signed in recently enough. To resolve, reauthenticate the user by calling
  /// `reauthenticate(with:)`.
  /// - Parameter completion: Optionally; the block invoked when the request to delete the account
  /// is complete, or fails. Invoked asynchronously on the main thread in the future.
  @objc open func delete(completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken(backend: self.backend) { accessToken, error in
        if let error {
          User.callInMainThreadWithError(callback: completion, error: error)
          return
        }
        guard let accessToken else {
          fatalError("Auth Internal Error: Both error and accessToken are nil.")
        }
        guard let requestConfiguration = self.auth?.requestConfiguration else {
          fatalError("Auth Internal Error: Unexpected nil requestConfiguration.")
        }
        let request = DeleteAccountRequest(localID: self.uid, accessToken: accessToken,
                                           requestConfiguration: requestConfiguration)
        Task {
          do {
            let _ = try await self.backend.call(with: request)
            try self.auth?.signOutByForce(withUserID: self.uid)
            User.callInMainThreadWithError(callback: completion, error: nil)
          } catch {
            User.callInMainThreadWithError(callback: completion, error: error)
          }
        }
      }
    }
  }

  /// Deletes the user account (also signs out the user, if this was the current user).
  ///
  /// Possible error codes:
  /// * `AuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
  ///  operation that requires a recent login from the user. This error indicates the user
  /// has not signed in recently enough. To resolve, reauthenticate the user by calling
  /// `reauthenticate(with:)`.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func delete() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.delete { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  /// Send an email to verify the ownership of the account then update to the new email.
  /// - Parameter email: The email to be updated to.
  /// - Parameter completion: Optionally; the block invoked when the request to send the
  /// verification email is complete, or fails.
  @objc(sendEmailVerificationBeforeUpdatingEmail:completion:)
  open func __sendEmailVerificationBeforeUpdating(email: String, completion: ((Error?) -> Void)?) {
    sendEmailVerification(beforeUpdatingEmail: email, completion: completion)
  }

  /// Send an email to verify the ownership of the account then update to the new email.
  /// - Parameter email: The email to be updated to.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  ///    handling action codes.
  /// - Parameter completion: Optionally; the block invoked when the request to send the
  /// verification email is complete, or fails.
  @objc open func sendEmailVerification(beforeUpdatingEmail email: String,
                                        actionCodeSettings: ActionCodeSettings? = nil,
                                        completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken(backend: self.backend) { accessToken, error in
        if let error {
          User.callInMainThreadWithError(callback: completion, error: error)
          return
        }
        guard let accessToken else {
          fatalError("Internal Error: Both error and accessToken are nil.")
        }
        guard let requestConfiguration = self.auth?.requestConfiguration else {
          fatalError("Internal Error: Unexpected nil requestConfiguration.")
        }
        let request = GetOOBConfirmationCodeRequest.verifyBeforeUpdateEmail(
          accessToken: accessToken,
          newEmail: email,
          actionCodeSettings: actionCodeSettings,
          requestConfiguration: requestConfiguration
        )
        Task {
          do {
            let _ = try await self.backend.call(with: request)
            User.callInMainThreadWithError(callback: completion, error: nil)
          } catch {
            User.callInMainThreadWithError(callback: completion, error: error)
          }
        }
      }
    }
  }

  /// Send an email to verify the ownership of the account then update to the new email.
  /// - Parameter newEmail: The email to be updated to.
  /// - Parameter actionCodeSettings: An `ActionCodeSettings` object containing settings related to
  ///    handling action codes.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  open func sendEmailVerification(beforeUpdatingEmail newEmail: String,
                                  actionCodeSettings: ActionCodeSettings? = nil) async throws {
    return try await withCheckedThrowingContinuation { continuation in
      self.sendEmailVerification(beforeUpdatingEmail: newEmail,
                                 actionCodeSettings: actionCodeSettings) { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  // MARK: Internal implementations below

  func rawAccessToken() -> String {
    return tokenService.accessToken
  }

  func accessTokenExpirationDate() -> Date? {
    return tokenService.accessTokenExpirationDate
  }

  init(withTokenService tokenService: SecureTokenService, backend: AuthBackend) {
    self.backend = backend
    providerDataRaw = [:]
    userProfileUpdate = UserProfileUpdate()
    self.tokenService = tokenService
    isAnonymous = false
    isEmailVerified = false
    metadata = UserMetadata(withCreationDate: nil, lastSignInDate: nil)
    tenantID = nil
    #if os(iOS)
      multiFactor = MultiFactor(withMFAEnrollments: [])
    #endif
    uid = ""
    hasEmailPasswordCredential = false
    requestConfiguration = AuthRequestConfiguration(apiKey: "", appID: "")
  }

  class func retrieveUser(withAuth auth: Auth,
                          accessToken: String?,
                          accessTokenExpirationDate: Date?,
                          refreshToken: String?,
                          anonymous: Bool) async throws -> User {
    guard let accessToken = accessToken,
          let refreshToken = refreshToken else {
      throw AuthErrorUtils
        .invalidUserTokenError(message: "Invalid user token: accessToken or refreshToken is nil")
    }
    let tokenService = SecureTokenService(withRequestConfiguration: auth.requestConfiguration,
                                          accessToken: accessToken,
                                          accessTokenExpirationDate: accessTokenExpirationDate,
                                          refreshToken: refreshToken)
    let user = User(withTokenService: tokenService, backend: auth.backend)
    user.auth = auth
    user.tenantID = auth.tenantID
    user.requestConfiguration = auth.requestConfiguration
    let accessToken2 = try await user.internalGetTokenAsync(backend: user.backend)
    let getAccountInfoRequest = GetAccountInfoRequest(
      accessToken: accessToken2,
      requestConfiguration: user.requestConfiguration
    )
    let response = try await auth.backend.call(with: getAccountInfoRequest)
    user.isAnonymous = anonymous
    user.update(withGetAccountInfoResponse: response)
    return user
  }

  @objc open var providerID: String {
    return "Firebase"
  }

  /// The provider's user ID for the user.
  @objc open var uid: String

  /// The name of the user.
  @objc open var displayName: String?

  /// The URL of the user's profile photo.
  @objc open var photoURL: URL?

  /// The user's email address.
  @objc open var email: String?

  /// A phone number associated with the user.
  ///
  /// This property is only available for users authenticated via phone number auth.
  @objc open var phoneNumber: String?

  /// Whether or not the user can be authenticated by using Firebase email and password.
  var hasEmailPasswordCredential: Bool

  /// Used to serialize the update profile calls.
  private let userProfileUpdate: UserProfileUpdate

  /// A strong reference to a requestConfiguration instance associated with this user instance.
  var requestConfiguration: AuthRequestConfiguration

  /// A secure token service associated with this user. For performing token exchanges and
  ///   refreshing access tokens.
  var tokenService: SecureTokenService

  private weak var _auth: Auth?

  /// A weak reference to an `Auth` instance associated with this instance.
  weak var auth: Auth? {
    set {
      guard let newValue else {
        fatalError("Firebase Auth Internal Error: Set user's auth property with non-nil instance.")
      }
      _auth = newValue
      requestConfiguration = newValue.requestConfiguration
      tokenService.requestConfiguration = requestConfiguration
      backend = newValue.backend
    }
    get { return _auth }
  }

  // MARK: Private functions

  private func updateEmail(email: String?,
                           password: String?,
                           callback: @escaping (Error?) -> Void) {
    let hadEmailPasswordCredential = hasEmailPasswordCredential
    executeUserUpdateWithChanges(changeBlock: { user, request in
      if let email {
        request.email = email
      }
      if let password {
        request.password = password
      }
    }) { error in
      if let error {
        callback(error)
        return
      }
      if let email {
        self.email = email
      }
      if self.email != nil {
        if !hadEmailPasswordCredential {
          // The list of providers need to be updated for the newly added email-password provider.
          Task {
            do {
              let accessToken = try await self.internalGetTokenAsync(backend: self.backend)
              if let requestConfiguration = self.auth?.requestConfiguration {
                let getAccountInfoRequest = GetAccountInfoRequest(accessToken: accessToken,
                                                                  requestConfiguration: requestConfiguration)
                do {
                  let accountInfoResponse = try await self.backend.call(with: getAccountInfoRequest)
                  if let users = accountInfoResponse.users {
                    for userAccountInfo in users {
                      // Set the account to non-anonymous if there are any providers, even if
                      // they're not email/password ones.
                      if let providerUsers = userAccountInfo.providerUserInfo {
                        if providerUsers.count > 0 {
                          self.isAnonymous = false
                          for providerUserInfo in providerUsers {
                            if providerUserInfo.providerID == EmailAuthProvider.id {
                              self.hasEmailPasswordCredential = true
                              break
                            }
                          }
                        }
                      }
                    }
                  }
                  self.update(withGetAccountInfoResponse: accountInfoResponse)
                  if let error = self.updateKeychain() {
                    callback(error)
                    return
                  }
                  callback(nil)
                } catch {
                  self.signOutIfTokenIsInvalid(withError: error)
                  callback(error)
                }
              }
            } catch {
              callback(error)
            }
          }
          return
        }
      }
      if let error = self.updateKeychain() {
        callback(error)
        return
      }
      callback(nil)
    }
  }

  /// Performs a setAccountInfo request by mutating the results of a getAccountInfo response,
  /// atomically in regards to other calls to this method.
  /// - Parameter changeBlock: A block responsible for mutating a template `SetAccountInfoRequest`
  /// - Parameter callback: A block to invoke when the change is complete. Invoked asynchronously on
  /// the auth global work queue in the future.
  func executeUserUpdateWithChanges(changeBlock: @escaping (GetAccountInfoResponse.User,
                                                            SetAccountInfoRequest) -> Void,
                                    callback: @escaping (Error?) -> Void) {
    Task {
      do {
        try await userProfileUpdate.executeUserUpdateWithChanges(user: self,
                                                                 changeBlock: changeBlock)
        await MainActor.run {
          callback(nil)
        }
      } catch {
        await MainActor.run {
          callback(error)
        }
      }
    }
  }

  /// Gets the users' account data from the server, updating our local values.
  /// - Parameter callback: Invoked when the request to getAccountInfo has completed, or when an
  /// error has been detected. Invoked asynchronously on the auth global work queue in the future.
  func getAccountInfoRefreshingCache(callback: @escaping (GetAccountInfoResponse.User?,
                                                          Error?) -> Void) {
    Task {
      do {
        let responseUser = try await userProfileUpdate.getAccountInfoRefreshingCache(self)
        await MainActor.run {
          callback(responseUser, nil)
        }
      } catch {
        await MainActor.run {
          callback(nil, error)
        }
      }
    }
  }

  func update(withGetAccountInfoResponse response: GetAccountInfoResponse) {
    guard let user = response.users?.first else {
      // Silent fallthrough in ObjC code.
      AuthLog.logWarning(code: "I-AUT000016", message: "Missing user in GetAccountInfoResponse")
      return
    }
    uid = user.localID ?? ""
    email = user.email
    isEmailVerified = user.emailVerified
    displayName = user.displayName
    photoURL = user.photoURL
    phoneNumber = user.phoneNumber
    hasEmailPasswordCredential = user.passwordHash != nil && user.passwordHash!.count > 0
    metadata = UserMetadata(withCreationDate: user.creationDate,
                            lastSignInDate: user.lastLoginDate)
    var providerData: [String: UserInfoImpl] = [:]
    if let providerUserInfos = user.providerUserInfo {
      for providerUserInfo in providerUserInfos {
        let userInfo = UserInfoImpl.userInfo(
          withGetAccountInfoResponseProviderUserInfo: providerUserInfo
        )
        if let providerID = providerUserInfo.providerID {
          providerData[providerID] = userInfo
        }
      }
    }
    providerDataRaw = providerData
    #if os(iOS)
      if let enrollments = user.mfaEnrollments {
        multiFactor = MultiFactor(withMFAEnrollments: enrollments)
      }
      multiFactor.user = self
    #endif
  }

  #if os(iOS)
    /// Updates the phone number for the user. On success, the cached user profile data is updated.
    ///
    /// Invoked asynchronously on the global work queue in the future.
    /// - Parameter credential: The new phone number credential corresponding to the phone
    /// number to be added to the Firebase account. If a phone number is already linked to the
    /// account, this new phone number will replace it.
    /// - Parameter isLinkOperation: Boolean value indicating whether or not this is a link
    /// operation.
    /// - Parameter completion: Optionally; the block invoked when the user profile change has
    /// finished.
    private func internalUpdateOrLinkPhoneNumber(credential: PhoneAuthCredential,
                                                 isLinkOperation: Bool,
                                                 completion: @escaping (Error?) -> Void) {
      internalGetToken(backend: backend) { accessToken, error in
        if let error {
          completion(error)
          return
        }
        guard let accessToken = accessToken else {
          fatalError("Auth Internal Error: Both accessToken and error are nil")
        }
        guard let configuration = self.auth?.requestConfiguration else {
          fatalError("Auth Internal Error: nil value for VerifyPhoneNumberRequest initializer")
        }
        switch credential.credentialKind {
        case .phoneNumber: fatalError("Internal Error: Missing verificationCode")
        case let .verification(verificationID, code):
          let operation = isLinkOperation ? AuthOperationType.link : AuthOperationType.update
          let request = VerifyPhoneNumberRequest(verificationID: verificationID,
                                                 verificationCode: code,
                                                 operation: operation,
                                                 requestConfiguration: configuration)
          request.accessToken = accessToken
          Task {
            do {
              let verifyResponse = try await self.backend.call(with: request)
              guard let idToken = verifyResponse.idToken,
                    let refreshToken = verifyResponse.refreshToken else {
                fatalError("Internal Auth Error: missing token in internalUpdateOrLinkPhoneNumber")
              }
              // Update the new token and refresh user info again.
              self.tokenService = SecureTokenService(
                withRequestConfiguration: configuration,
                accessToken: idToken,
                accessTokenExpirationDate: verifyResponse.approximateExpirationDate,
                refreshToken: refreshToken
              )
              // Get account info to update cached user info.
              self.getAccountInfoRefreshingCache { user, error in
                if let error {
                  self.signOutIfTokenIsInvalid(withError: error)
                  completion(error)
                  return
                }
                self.isAnonymous = false
                if let error = self.updateKeychain() {
                  completion(error)
                  return
                }
                completion(nil)
              }
            } catch {
              self.signOutIfTokenIsInvalid(withError: error)
              completion(error)
            }
          }
        }
      }
    }
  #endif

  private func link(withEmail email: String,
                    password: String,
                    authResult: AuthDataResult,
                    _ completion: ((AuthDataResult?, Error?) -> Void)?) {
    internalGetToken(backend: backend) { accessToken, error in
      guard let requestConfiguration = self.auth?.requestConfiguration else {
        fatalError("Internal auth error: missing auth on User")
      }
      let request = SignUpNewUserRequest(email: email,
                                         password: password,
                                         displayName: nil,
                                         idToken: accessToken,
                                         requestConfiguration: requestConfiguration)
      Task {
        do {
          #if os(iOS)
            guard let auth = self.auth else {
              fatalError("Internal Auth error: missing auth instance on user")
            }
            let response = try await auth.injectRecaptcha(request: request,
                                                          action: AuthRecaptchaAction
                                                            .signUpPassword)
          #else
            let response = try await self.backend.call(with: request)
          #endif
          guard let refreshToken = response.refreshToken,
                let idToken = response.idToken else {
            fatalError("Internal auth error: Invalid SignUpNewUserResponse")
          }
          // Update the new token and refresh user info again.
          try await self.updateTokenAndRefreshUser(
            idToken: idToken,
            refreshToken: refreshToken,
            expirationDate: response.approximateExpirationDate,
            requestConfiguration: requestConfiguration
          )
          User.callInMainThreadWithAuthDataResultAndError(
            callback: completion,
            result: AuthDataResult(withUser: self, additionalUserInfo: nil),
            error: nil
          )
        } catch {
          self.signOutIfTokenIsInvalid(withError: error)
          User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                          result: nil, error: error)
        }
      }
    }
  }

  private func link(withEmailCredential emailCredential: EmailAuthCredential,
                    completion: ((AuthDataResult?, Error?) -> Void)?) {
    if hasEmailPasswordCredential {
      User.callInMainThreadWithAuthDataResultAndError(
        callback: completion,
        result: nil,
        error: AuthErrorUtils
          .providerAlreadyLinkedError()
      )
      return
    }
    switch emailCredential.emailType {
    case let .password(password):
      let result = AuthDataResult(withUser: self, additionalUserInfo: nil)
      link(withEmail: emailCredential.email, password: password, authResult: result, completion)
    case let .link(link):
      internalGetToken(backend: backend) { accessToken, error in
        var queryItems = AuthWebUtils.parseURL(link)
        if link.count == 0 {
          if let urlComponents = URLComponents(string: link),
             let query = urlComponents.query {
            queryItems = AuthWebUtils.parseURL(query)
          }
        }
        guard let actionCode = queryItems["oobCode"],
              let requestConfiguration = self.auth?.requestConfiguration else {
          fatalError("Internal Auth Error: Missing oobCode or requestConfiguration")
        }
        let request = EmailLinkSignInRequest(email: emailCredential.email,
                                             oobCode: actionCode,
                                             requestConfiguration: requestConfiguration)
        request.idToken = accessToken
        Task {
          do {
            let response = try await self.backend.call(with: request)
            guard let idToken = response.idToken,
                  let refreshToken = response.refreshToken else {
              fatalError("Internal Auth Error: missing token in EmailLinkSignInResponse")
            }
            try await self.updateTokenAndRefreshUser(
              idToken: idToken,
              refreshToken: refreshToken,
              expirationDate: response.approximateExpirationDate,
              requestConfiguration: requestConfiguration
            )
            User.callInMainThreadWithAuthDataResultAndError(
              callback: completion,
              result: AuthDataResult(withUser: self, additionalUserInfo: nil),
              error: nil
            )
          } catch {
            User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                            result: nil,
                                                            error: error)
          }
        }
      }
    }
  }

  #if !os(watchOS)
    private func link(withGameCenterCredential gameCenterCredential: GameCenterAuthCredential,
                      completion: ((AuthDataResult?, Error?) -> Void)?) {
      internalGetToken(backend: backend) { accessToken, error in
        guard let requestConfiguration = self.auth?.requestConfiguration,
              let publicKeyURL = gameCenterCredential.publicKeyURL,
              let signature = gameCenterCredential.signature,
              let salt = gameCenterCredential.salt else {
          fatalError("Internal Auth Error: Nil value field for SignInWithGameCenterRequest")
        }
        let request = SignInWithGameCenterRequest(playerID: gameCenterCredential.playerID,
                                                  teamPlayerID: gameCenterCredential.teamPlayerID,
                                                  gamePlayerID: gameCenterCredential.gamePlayerID,
                                                  publicKeyURL: publicKeyURL,
                                                  signature: signature,
                                                  salt: salt,
                                                  timestamp: gameCenterCredential.timestamp,
                                                  displayName: gameCenterCredential.displayName,
                                                  requestConfiguration: requestConfiguration)
        request.accessToken = accessToken
        Task {
          do {
            let response = try await self.backend.call(with: request)
            guard let idToken = response.idToken,
                  let refreshToken = response.refreshToken else {
              fatalError("Internal Auth Error: missing token in link(withGameCredential")
            }
            try await self.updateTokenAndRefreshUser(
              idToken: idToken,
              refreshToken: refreshToken,
              expirationDate: response.approximateExpirationDate,
              requestConfiguration: requestConfiguration
            )
            User.callInMainThreadWithAuthDataResultAndError(
              callback: completion,
              result: AuthDataResult(withUser: self, additionalUserInfo: nil),
              error: nil
            )
          } catch {
            User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                            result: nil,
                                                            error: error)
          }
        }
      }
    }
  #endif

  #if os(iOS)
    private func link(withPhoneCredential phoneCredential: PhoneAuthCredential,
                      completion: ((AuthDataResult?, Error?) -> Void)?) {
      internalUpdateOrLinkPhoneNumber(credential: phoneCredential,
                                      isLinkOperation: true) { error in
        if let error {
          User.callInMainThreadWithAuthDataResultAndError(
            callback: completion,
            result: nil,
            error: error
          )
        } else {
          let result = AuthDataResult(withUser: self, additionalUserInfo: nil)
          User.callInMainThreadWithAuthDataResultAndError(
            callback: completion,
            result: result,
            error: nil
          )
        }
      }
    }
  #endif

  // Update the new token and refresh user info again.
  private func updateTokenAndRefreshUser(idToken: String,
                                         refreshToken: String,
                                         expirationDate: Date?,
                                         requestConfiguration: AuthRequestConfiguration) async throws {
    return try await userProfileUpdate
      .updateTokenAndRefreshUser(
        user: self,
        idToken: idToken,
        refreshToken: refreshToken,
        expirationDate: expirationDate
      )
  }

  /// Signs out this user if the user or the token is invalid.
  /// - Parameter error: The error from the server.
  func signOutIfTokenIsInvalid(withError error: Error) {
    let code = (error as NSError).code
    if code == AuthErrorCode.userNotFound.rawValue ||
      code == AuthErrorCode.userDisabled.rawValue ||
      code == AuthErrorCode.invalidUserToken.rawValue ||
      code == AuthErrorCode.userTokenExpired.rawValue {
      AuthLog.logNotice(code: "I-AUT000016",
                        message: "Invalid user token detected, user is automatically signed out.")
      try? auth?.signOutByForce(withUserID: uid)
    }
  }

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  /// - Parameter callback: The block to invoke when the token is available. Invoked asynchronously
  /// on the  global work thread in the future.
  func internalGetToken(forceRefresh: Bool = false,
                        backend: AuthBackend,
                        callback: @escaping (String?, Error?) -> Void,
                        callCallbackOnMain: Bool = false) {
    Task {
      do {
        let token = try await internalGetTokenAsync(forceRefresh: forceRefresh, backend: backend)
        if callCallbackOnMain {
          Auth.wrapMainAsync(callback: callback, with: .success(token))
        } else {
          callback(token, nil)
        }
      } catch {
        if callCallbackOnMain {
          Auth.wrapMainAsync(callback: callback, with: .failure(error))
        } else {
          callback(nil, error)
        }
      }
    }
  }

  /// Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
  /// - Parameter forceRefresh
  func internalGetTokenAsync(forceRefresh: Bool = false,
                             backend: AuthBackend) async throws -> String {
    var keychainError = false
    do {
      let (token, tokenUpdated) = try await tokenService.fetchAccessToken(
        forcingRefresh: forceRefresh, backend: backend
      )
      if tokenUpdated {
        if let error = updateKeychain() {
          keychainError = true
          throw error
        }
      }
      return token!
    } catch {
      if !keychainError {
        signOutIfTokenIsInvalid(withError: error)
      }
      throw error
    }
  }

  /// Updates the keychain for user token or info changes.
  /// - Returns: An `Error` on failure.
  func updateKeychain() -> Error? {
    return auth?.updateKeychain(withUser: self)
  }

  /// Calls a callback in main thread with error.
  /// - Parameter callback: The callback to be called in main thread.
  /// - Parameter error: The error to pass to callback.

  class func callInMainThreadWithError(callback: ((Error?) -> Void)?, error: Error?) {
    if let callback {
      DispatchQueue.main.async {
        callback(error)
      }
    }
  }

  /// Calls a callback in main thread with user and error.
  /// - Parameter callback: The callback to be called in main thread.
  /// - Parameter user: The user to pass to callback if there is no error.
  /// - Parameter error: The error to pass to callback.
  private class func callInMainThreadWithUserAndError(callback: ((User?, Error?) -> Void)?,
                                                      user: User,
                                                      error: Error?) {
    if let callback {
      DispatchQueue.main.async {
        callback((error != nil) ? nil : user, error)
      }
    }
  }

  /// Calls a callback in main thread with user and error.
  /// - Parameter callback: The callback to be called in main thread.
  private class func callInMainThreadWithAuthDataResultAndError(callback: (
    (AuthDataResult?, Error?) -> Void
  )?,
  result: AuthDataResult? = nil,
  error: Error? = nil) {
    if let callback {
      DispatchQueue.main.async {
        callback(result, error)
      }
    }
  }

  // MARK: NSSecureCoding

  private let kUserIDCodingKey = "userID"
  private let kHasEmailPasswordCredentialCodingKey = "hasEmailPassword"
  private let kAnonymousCodingKey = "anonymous"
  private let kEmailCodingKey = "email"
  private let kPhoneNumberCodingKey = "phoneNumber"
  private let kEmailVerifiedCodingKey = "emailVerified"
  private let kDisplayNameCodingKey = "displayName"
  private let kPhotoURLCodingKey = "photoURL"
  private let kProviderDataKey = "providerData"
  private let kAPIKeyCodingKey = "APIKey"
  private let kFirebaseAppIDCodingKey = "firebaseAppID"
  private let kTokenServiceCodingKey = "tokenService"
  private let kMetadataCodingKey = "metadata"
  private let kMultiFactorCodingKey = "multiFactor"
  private let kTenantIDCodingKey = "tenantID"

  public static let supportsSecureCoding = true

  public func encode(with coder: NSCoder) {
    coder.encode(uid, forKey: kUserIDCodingKey)
    coder.encode(isAnonymous, forKey: kAnonymousCodingKey)
    coder.encode(hasEmailPasswordCredential, forKey: kHasEmailPasswordCredentialCodingKey)
    coder.encode(providerDataRaw, forKey: kProviderDataKey)
    coder.encode(email, forKey: kEmailCodingKey)
    coder.encode(phoneNumber, forKey: kPhoneNumberCodingKey)
    coder.encode(isEmailVerified, forKey: kEmailVerifiedCodingKey)
    coder.encode(photoURL, forKey: kPhotoURLCodingKey)
    coder.encode(displayName, forKey: kDisplayNameCodingKey)
    coder.encode(metadata, forKey: kMetadataCodingKey)
    coder.encode(tenantID, forKey: kTenantIDCodingKey)
    if let auth {
      coder.encode(auth.requestConfiguration.apiKey, forKey: kAPIKeyCodingKey)
      coder.encode(auth.requestConfiguration.appID, forKey: kFirebaseAppIDCodingKey)
    }
    coder.encode(tokenService, forKey: kTokenServiceCodingKey)
    #if os(iOS)
      coder.encode(multiFactor, forKey: kMultiFactorCodingKey)
    #endif
  }

  public required init?(coder: NSCoder) {
    guard let userID = coder.decodeObject(of: NSString.self, forKey: kUserIDCodingKey) as? String,
          let tokenService = coder.decodeObject(of: SecureTokenService.self,
                                                forKey: kTokenServiceCodingKey) else {
      return nil
    }
    let anonymous = coder.decodeBool(forKey: kAnonymousCodingKey)
    let hasEmailPasswordCredential = coder.decodeBool(forKey: kHasEmailPasswordCredentialCodingKey)
    let displayName = coder.decodeObject(
      of: NSString.self,
      forKey: kDisplayNameCodingKey
    ) as? String
    let photoURL = coder.decodeObject(of: NSURL.self, forKey: kPhotoURLCodingKey) as? URL
    let email = coder.decodeObject(of: NSString.self, forKey: kEmailCodingKey) as? String
    let phoneNumber = coder.decodeObject(
      of: NSString.self,
      forKey: kPhoneNumberCodingKey
    ) as? String
    let emailVerified = coder.decodeBool(forKey: kEmailVerifiedCodingKey)
    let classes = [NSDictionary.self, NSString.self, UserInfoImpl.self]
    let providerData = coder.decodeObject(of: classes, forKey: kProviderDataKey)
      as? [String: UserInfoImpl]
    let metadata = coder.decodeObject(of: UserMetadata.self, forKey: kMetadataCodingKey)
    let tenantID = coder.decodeObject(of: NSString.self, forKey: kTenantIDCodingKey) as? String
    #if os(iOS)
      let multiFactor = coder.decodeObject(of: MultiFactor.self, forKey: kMultiFactorCodingKey)
    #endif
    self.tokenService = tokenService
    uid = userID
    isAnonymous = anonymous
    self.hasEmailPasswordCredential = hasEmailPasswordCredential
    self.email = email
    isEmailVerified = emailVerified
    self.displayName = displayName
    self.photoURL = photoURL
    providerDataRaw = providerData ?? [:]
    self.phoneNumber = phoneNumber
    self.metadata = metadata ?? UserMetadata(withCreationDate: nil, lastSignInDate: nil)
    self.tenantID = tenantID

    // Note, in practice, the caller will set the `auth` property of this user
    // instance which will as a side-effect overwrite the request configuration.
    // The assignment here is a best-effort placeholder.
    let apiKey = coder.decodeObject(of: NSString.self, forKey: kAPIKeyCodingKey) as? String
    let appID = coder.decodeObject(
      of: NSString.self,
      forKey: kFirebaseAppIDCodingKey
    ) as? String
    requestConfiguration = AuthRequestConfiguration(apiKey: apiKey ?? "", appID: appID ?? "")

    // This property will be overwritten later via the `user.auth` property update. For now, a
    // placeholder is set as the property update should happen right after this initializer.
    backend = AuthBackend(rpcIssuer: AuthBackendRPCIssuer())

    userProfileUpdate = UserProfileUpdate()
    #if os(iOS)
      self.multiFactor = multiFactor ?? MultiFactor()
      super.init()
      multiFactor?.user = self
    #endif
  }
}
