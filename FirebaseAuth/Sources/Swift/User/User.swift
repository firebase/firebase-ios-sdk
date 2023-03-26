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

/** @class User
    @brief Represents a user. Firebase Auth does not attempt to validate users
        when loading them from the keychain. Invalidated users (such as those
        whose passwords have been changed on another client) are automatically
        logged out when an auth-dependent operation is attempted or when the
        ID token is automatically refreshed.
    @remarks This class is thread-safe.
 */
@objc(FIRUser) public class User: NSObject, UserInfo, NSSecureCoding {
  /** @property anonymous
      @brief Indicates the user represents an anonymous user.
   */
  @objc public private(set) var isAnonymous: Bool
  @objc public func anonymous() -> Bool { return isAnonymous }

  /** @property emailVerified
      @brief Indicates the email address associated with this user has been verified.
   */
  @objc public private(set) var isEmailVerified: Bool
  @objc public func emailVerified() -> Bool { return isEmailVerified }

  /** @property providerData
      @brief Profile data for each identity provider, if any.
      @remarks This data is cached on sign-in and updated when linking or unlinking.
   */
  @objc public var providerData: [UserInfoImpl] {
    return Array(providerDataRaw.values)
  }

  private var providerDataRaw: [String: UserInfoImpl]

  /** @property metadata
      @brief Metadata associated with the Firebase user in question.
   */
  @objc public private(set) var metadata: UserMetadata

  /** @property tenantID
      @brief The tenant ID of the current user. nil if none is available.
   */
  @objc public private(set) var tenantID: String?

  #if os(iOS)
    /** @property multiFactor
         @brief Multi factor object associated with the user.
             This property is available on iOS only.
     */
    @objc public private(set) var multiFactor: MultiFactor
  #endif

  /** @fn updateEmail:completion:
      @brief Updates the email address for the user. On success, the cached user profile data is
          updated.
      @remarks May fail if there is already an account with this email address that was created using
          email and password authentication.

      @param email The email address for the user.
      @param completion Optionally; the block invoked when the user profile change has finished.
          Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
              sent in the request.
          + `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
              the console for this action.
          + `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
              sending update email.
          + `AuthErrorCodeEmailAlreadyInUse` - Indicates the email is already in use by another
              account.
          + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
          + `AuthErrorCodeRequiresRecentLogin` - Updating a user’s email is a security
              sensitive operation that requires a recent login from the user. This error indicates
              the user has not signed in recently enough. To resolve, reauthenticate the user by
              calling `reauthenticate(with:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @objc(updateEmail:completion:)
  public func updateEmail(to email: String, completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.updateEmail(email: email, password: nil) { error in
        User.callInMainThreadWithError(callback: completion, error: error)
      }
    }
  }

  /** @fn updateEmail
      @brief Updates the email address for the user. On success, the cached user profile data is
          updated.
      @remarks May fail if there is already an account with this email address that was created using
          email and password authentication.

      @param email The email address for the user.
      @throws Error on failure.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
              sent in the request.
          + `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
              the console for this action.
          + `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
              sending update email.
          + `AuthErrorCodeEmailAlreadyInUse` - Indicates the email is already in use by another
              account.
          + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.
          + `AuthErrorCodeRequiresRecentLogin` - Updating a user’s email is a security
              sensitive operation that requires a recent login from the user. This error indicates
              the user has not signed in recently enough. To resolve, reauthenticate the user by
              calling `reauthenticate(with:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func updateEmail(to email: String) async throws {
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

  /** @fn updatePassword:completion:
      @brief Updates the password for the user. On success, the cached user profile data is updated.

      @param password The new password for the user.
      @param completion Optionally; the block invoked when the user profile change has finished.
          Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeOperationNotAllowed` - Indicates the administrator disabled
              sign in with the specified identity provider.
          + `AuthErrorCodeRequiresRecentLogin` - Updating a user’s password is a security
              sensitive operation that requires a recent login from the user. This error indicates
              the user has not signed in recently enough. To resolve, reauthenticate the user by
              calling `reauthenticate(with:)`.
          + `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
              considered too weak. The `NSLocalizedFailureReasonErrorKey` field in the `userInfo`
              dictionary object will contain more detailed explanation that can be shown to the user.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @objc(updatePassword:completion:)
  public func updatePassword(to password: String, completion: ((Error?) -> Void)? = nil) {
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

  /** @fn updatePassword
      @brief Updates the password for the user. On success, the cached user profile data is updated.

      @param password The new password for the user.
      @throws Error on failure.

      @remarks Possible error codes:

          + `AuthErrorCodeOperationNotAllowed` - Indicates the administrator disabled
              sign in with the specified identity provider.
          + `AuthErrorCodeRequiresRecentLogin` - Updating a user’s password is a security
              sensitive operation that requires a recent login from the user. This error indicates
              the user has not signed in recently enough. To resolve, reauthenticate the user by
              calling `reauthenticate(with:)`.
          + `AuthErrorCodeWeakPassword` - Indicates an attempt to set a password that is
              considered too weak. The `NSLocalizedFailureReasonErrorKey` field in the `userInfo`
              dictionary object will contain more detailed explanation that can be shown to the user.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func updatePassword(to password: String) async throws {
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
    /** @fn updatePhoneNumberCredential:completion:
        @brief Updates the phone number for the user. On success, the cached user profile data is
            updated.
            This method is available on iOS only.

        @param phoneNumberCredential The new phone number credential corresponding to the phone number
            to be added to the Firebase account, if a phone number is already linked to the account this
            new phone number will replace it.
        @param completion Optionally; the block invoked when the user profile change has finished.
            Invoked asynchronously on the main thread in the future.

        @remarks Possible error codes:

            + `AuthErrorCodeRequiresRecentLogin` - Updating a user’s phone number is a security
                sensitive operation that requires a recent login from the user. This error indicates
                the user has not signed in recently enough. To resolve, reauthenticate the user by
                calling `reauthenticate(with:)`.

        @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
     */
    @objc(updatePhoneNumberCredential:completion:)
    public func updatePhoneNumber(_ credential: PhoneAuthCredential,
                                  completion: ((Error?) -> Void)? = nil) {
      kAuthGlobalWorkQueue.async {
        self.internalUpdateOrLinkPhoneNumber(credential: credential,
                                             isLinkOperation: false) { error in
          User.callInMainThreadWithError(callback: completion, error: error)
        }
      }
    }

    /** @fn updatePhoneNumberCredential
        @brief Updates the phone number for the user. On success, the cached user profile data is
            updated.
            This method is available on iOS only.

        @param phoneNumberCredential The new phone number credential corresponding to the phone number
            to be added to the Firebase account, if a phone number is already linked to the account this
            new phone number will replace it.
        @throws an error.

        @remarks Possible error codes:

            + `AuthErrorCodeRequiresRecentLogin` - Updating a user’s phone number is a security
                sensitive operation that requires a recent login from the user. This error indicates
                the user has not signed in recently enough. To resolve, reauthenticate the user by
                calling `reauthenticate(with:)`.

        @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    public func updatePhoneNumber(_ credential: PhoneAuthCredential) async throws {
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

  /** @fn profileChangeRequest
      @brief Creates an object which may be used to change the user's profile data.

      @remarks Set the properties of the returned object, then call
          `UserProfileChangeRequest.commitChanges()` to perform the updates atomically.

      @return An object which may be used to change the user's profile data atomically.
   */
  @objc(profileChangeRequest)
  public func createProfileChangeRequest() -> UserProfileChangeRequest {
    var result: UserProfileChangeRequest?
    kAuthGlobalWorkQueue.sync {
      result = UserProfileChangeRequest(self)
    }
    // TODO: Is there a way to do without force unwrap?
    return result!
  }

  /** @property refreshToken
      @brief A refresh token; useful for obtaining new access tokens independently.
      @remarks This property should only be used for advanced scenarios, and is not typically needed.
   */
  @objc public var refreshToken: String? {
    var result: String?
    kAuthGlobalWorkQueue.sync {
      result = self.tokenService.refreshToken
    }
    return result
  }

  /** @fn reloadWithCompletion:
      @brief Reloads the user's profile data from the server.

      @param completion Optionally; the block invoked when the reload has finished. Invoked
          asynchronously on the main thread in the future.

      @remarks May fail with a `AuthErrorCodeRequiresRecentLogin` error code. In this case
          you should call `reauthenticate(with:)` before re-invoking
          `updateEmail(to:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc public func reload(withCompletion completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.getAccountInfoRefreshingCache { user, error in
        User.callInMainThreadWithError(callback: completion, error: error)
      }
    }
  }

  /** @fn reload
      @brief Reloads the user's profile data from the server.

      @param completion Optionally; the block invoked when the reload has finished. Invoked
          asynchronously on the main thread in the future.

      @remarks May fail with a `AuthErrorCodeRequiresRecentLogin` error code. In this case
          you should call `reauthenticate(with:)` before re-invoking
          `updateEmail(to:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func reload() async throws {
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

  /** @fn reauthenticateWithCredential:completion:
      @brief Renews the user's authentication tokens by validating a fresh set of credentials supplied
          by the user  and returns additional identity provider data.

      @param credential A user-supplied credential, which will be validated by the server. This can be
          a successful third-party identity provider sign-in, or an email address and password.
      @param completion Optionally; the block invoked when the re-authentication operation has
          finished. Invoked asynchronously on the main thread in the future.

      @remarks If the user associated with the supplied credential is different from the current user,
          or if the validation of the supplied credentials fails; an error is returned and the current
          user remains signed in.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
              This could happen if it has expired or it is malformed.
          + `AuthErrorCodeOperationNotAllowed` - Indicates that accounts with the
              identity provider represented by the credential are not enabled. Enable them in the
              Auth section of the Firebase console.
          + `AuthErrorCodeEmailAlreadyInUse` -  Indicates the email asserted by the credential
              (e.g. the email in a Facebook access token) is already in use by an existing account,
              that cannot be authenticated with this method. Call `Auth.fetchSignInMethods(forEmail:)`
              for this user’s email and then prompt them to sign in with any of the sign-in providers
              returned. This error will only be thrown if the "One account per email address"
              setting is enabled in the Firebase console, under Auth settings. Please note that the
              error code raised in this specific situation may not be the same on Web and Android.
          + `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
          + `AuthErrorCodeWrongPassword` - Indicates the user attempted reauthentication with
              an incorrect password, if credential is of the type `EmailPasswordAuthCredential`.
          + `AuthErrorCodeUserMismatch` -  Indicates that an attempt was made to
              reauthenticate with a user which is not the current user.
          + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc(reauthenticateWithCredential:completion:)
  public func reauthenticate(with credential: AuthCredential,
                             completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.auth?.internalSignInAndRetrieveData(with: credential, isReauthentication: true) {
        authResult, error in
        if let error {
          // If "user not found" error returned by backend,
          // translate to user mismatch error which is more
          // accurate.
          var reportError: Error = error
          if (error as NSError).code == AuthErrorCode.userNotFound.rawValue {
            reportError = AuthErrorUtils.userMismatchError()
          }
          User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                          result: authResult,
                                                          error: reportError)
          return
        }
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
        self.setTokenService(tokenService: user.tokenService) { error in
          User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                          result: authResult,
                                                          error: error)
        }
      }
    }
  }

  /** @fn reauthenticateWithCredential
      @brief Renews the user's authentication tokens by validating a fresh set of credentials supplied
          by the user  and returns additional identity provider data.

      @param credential A user-supplied credential, which will be validated by the server. This can be
          a successful third-party identity provider sign-in, or an email address and password.
      @returns An AuthDataResult.

      @remarks If the user associated with the supplied credential is different from the current user,
          or if the validation of the supplied credentials fails; an error is returned and the current
          user remains signed in.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidCredential` - Indicates the supplied credential is invalid.
              This could happen if it has expired or it is malformed.
          + `AuthErrorCodeOperationNotAllowed` - Indicates that accounts with the
              identity provider represented by the credential are not enabled. Enable them in the
              Auth section of the Firebase console.
          + `AuthErrorCodeEmailAlreadyInUse` -  Indicates the email asserted by the credential
              (e.g. the email in a Facebook access token) is already in use by an existing account,
              that cannot be authenticated with this method. Call `Auth.fetchSignInMethods(forEmail:)`
              for this user’s email and then prompt them to sign in with any of the sign-in providers
              returned. This error will only be thrown if the "One account per email address"
              setting is enabled in the Firebase console, under Auth settings. Please note that the
              error code raised in this specific situation may not be the same on Web and Android.
          + `AuthErrorCodeUserDisabled` - Indicates the user's account is disabled.
          + `AuthErrorCodeWrongPassword` - Indicates the user attempted reauthentication with
              an incorrect password, if credential is of the type `EmailPasswordAuthCredential`.
          + `AuthErrorCodeUserMismatch` -  Indicates that an attempt was made to
              reauthenticate with a user which is not the current user.
          + `AuthErrorCodeInvalidEmail` - Indicates the email address is malformed.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  public func reauthenticate(with credential: AuthCredential) async throws -> AuthDataResult {
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
    /** @fn reauthenticateWithProvider:UIDelegate:completion:
        @brief Renews the user's authentication using the provided auth provider instance.
            This method is available on iOS only.

        @param provider An instance of an auth provider used to initiate the reauthenticate flow.
        @param UIDelegate Optionally an instance of a class conforming to the `AuthUIDelegate`
            protocol, used for presenting the web context. If nil, a default `AuthUIDelegate`
            will be used.
        @param completion Optionally; a block which is invoked when the reauthenticate flow finishes, or
            is canceled. Invoked asynchronously on the main thread in the future.
     */
    @objc(reauthenticateWithProvider:UIDelegate:completion:)
    public func reauthenticate(with provider: FederatedAuthProvider,
                               uiDelegate: AuthUIDelegate?,
                               completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
      kAuthGlobalWorkQueue.async {
        provider.getCredentialWith(uiDelegate) { credential, error in
          if let error {
            if let completion {
              completion(nil, error)
            }
            return
          }
          if let credential {
            self.reauthenticate(with: credential, completion: completion)
          }
        }
      }
    }

    /** @fn reauthenticateWithProvider:UIDelegate
        @brief Renews the user's authentication using the provided auth provider instance.
            This method is available on iOS only.

        @param provider An instance of an auth provider used to initiate the reauthenticate flow.
        @param UIDelegate Optionally an instance of a class conforming to the `AuthUIDelegate`
            protocol, used for presenting the web context. If nil, a default `AuthUIDelegate`
            will be used.
        @returns An AuthDataResult.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    @discardableResult
    public func reauthenticate(with provider: FederatedAuthProvider,
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

  /** @fn getIDTokenWithCompletion:
      @brief Retrieves the Firebase authentication token, possibly refreshing it if it has expired.

      @param completion Optionally; the block invoked when the token is available. Invoked
          asynchronously on the main thread in the future.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc(getIDTokenWithCompletion:)
  public func getIDToken(completion: ((String?, Error?) -> Void)?) {
    // |getIDTokenForcingRefresh:completion:| is also a public API so there is no need to dispatch to
    // global work queue here.
    getIDTokenForcingRefresh(false, completion: completion)
  }

  /** @fn getIDTokenForcingRefresh:completion:
      @brief Retrieves the Firebase authentication token, possibly refreshing it if it has expired.

      @param forceRefresh Forces a token refresh. Useful if the token becomes invalid for some reason
          other than an expiration.
      @param completion Optionally; the block invoked when the token is available. Invoked
          asynchronously on the main thread in the future.

      @remarks The authentication token will be refreshed (by making a network request) if it has
          expired, or if `forceRefresh` is true.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc(getIDTokenForcingRefresh:completion:)
  public func getIDTokenForcingRefresh(_ forceRefresh: Bool,
                                       completion: ((String?, Error?) -> Void)?) {
    getIDTokenResult(forcingRefresh: forceRefresh) { tokenResult, error in
      if let completion {
        DispatchQueue.main.async {
          completion(tokenResult?.token, error)
        }
      }
    }
  }

  /** @fn getIDTokenForcingRefresh:completion:
      @brief Retrieves the Firebase authentication token, possibly refreshing it if it has expired.

      @param forceRefresh Forces a token refresh. Useful if the token becomes invalid for some reason
          other than an expiration.
      @returns The Token.

      @remarks The authentication token will be refreshed (by making a network request) if it has
          expired, or if `forceRefresh` is true.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func getIDToken(forcingRefresh forceRefresh: Bool = false) async throws -> String {
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

  /** @fn getIDTokenResultWithCompletion:
      @brief Retrieves the Firebase authentication token, possibly refreshing it if it has expired.

      @param completion Optionally; the block invoked when the token is available. Invoked
          asynchronously on the main thread in the future.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc(getIDTokenResultWithCompletion:)
  public func getIDTokenResult(completion: ((AuthTokenResult?, Error?) -> Void)?) {
    getIDTokenResult(forcingRefresh: false) { tokenResult, error in
      if let completion {
        DispatchQueue.main.async {
          completion(tokenResult, error)
        }
      }
    }
  }

  /** @fn getIDTokenResultForcingRefresh:completion:
      @brief Retrieves the Firebase authentication token, possibly refreshing it if it has expired.

      @param forceRefresh Forces a token refresh. Useful if the token becomes invalid for some reason
          other than an expiration.
      @param completion Optionally; the block invoked when the token is available. Invoked
          asynchronously on the main thread in the future.

      @remarks The authentication token will be refreshed (by making a network request) if it has
          expired, or if `forceRefresh` is YES.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc(getIDTokenResultForcingRefresh:completion:)
  public func getIDTokenResult(forcingRefresh: Bool,
                               completion: ((AuthTokenResult?, Error?) -> Void)?) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken(forceRefresh: forcingRefresh) { token, error in
        var tokenResult: AuthTokenResult?
        if let token {
          tokenResult = AuthTokenResult.tokenResult(token: token)
          AuthLog.logDebug(code: "I-AUT000017", message: "Actual token expiration date: " +
            "\(String(describing: tokenResult?.expirationDate))," +
            "current date: \(Date())")
        }
        if let completion {
          DispatchQueue.main.async {
            completion(tokenResult, error)
          }
        }
      }
    }
  }

  /** @fn getIDTokenResultForcingRefresh
      @brief Retrieves the Firebase authentication token, possibly refreshing it if it has expired.

      @param forceRefresh Forces a token refresh. Useful if the token becomes invalid for some reason
          other than an expiration.
      @returns The token.

      @remarks The authentication token will be refreshed (by making a network request) if it has
          expired, or if `forceRefresh` is YES.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func getIDTokenResult(forcingRefresh forceRefresh: Bool = false) async throws
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

  /** @fn linkWithCredential:completion:
      @brief Associates a user account from a third-party identity provider with this user and
          returns additional identity provider data.

      @param credential The credential for the identity provider.
      @param completion Optionally; the block invoked when the unlinking is complete, or fails.
          Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeProviderAlreadyLinked` - Indicates an attempt to link a provider of a
              type already linked to this account.
          + `AuthErrorCodeCredentialAlreadyInUse` - Indicates an attempt to link with a
              credential that has already been linked with a different Firebase account.
          + `AuthErrorCodeOperationNotAllowed` - Indicates that accounts with the identity
              provider represented by the credential are not enabled. Enable them in the Auth section
              of the Firebase console.

      @remarks This method may also return error codes associated with `updateEmail(to:)` and
          `updatePassword(to:)` on `User`.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @objc(linkWithCredential:completion:)
  public func link(with credential: AuthCredential,
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

      self.taskQueue.enqueueTask { complete in
        let completeWithError = { result, error in
          complete()
          User.callInMainThreadWithAuthDataResultAndError(callback: completion, result: result,
                                                          error: error)
        }
        self.internalGetToken { accessToken, error in
          if let error {
            completeWithError(nil, error)
            return
          }
          guard let requestConfiguration = self.auth?.requestConfiguration else {
            fatalError("Internal Error: Unexpected nil requestConfiguration.")
          }
          let request = VerifyAssertionRequest(providerID: credential.provider,
                                               requestConfiguration: requestConfiguration)
          credential.prepare(request)
          request.accessToken = accessToken
          AuthBackend.post(withRequest: request) { rawResponse, error in
            if let error {
              self.signOutIfTokenIsInvalid(withError: error)
              completeWithError(nil, error)
              return
            }
            guard let response = rawResponse as? VerifyAssertionResponse else {
              fatalError("Internal Auth Error: response type is not an VerifyAssertionResponse")
            }
            let additionalUserInfo = AdditionalUserInfo
              .userInfo(verifyAssertionResponse: response)
            let updatedOAuthCredential = OAuthCredential(withVerifyAssertionResponse: response)
            let result = AuthDataResult(withUser: self, additionalUserInfo: additionalUserInfo,
                                        credential: updatedOAuthCredential)
            guard let idToken = response.idToken,
                  let refreshToken = response.refreshToken else {
              fatalError("Internal Auth Error: missing token in EmailLinkSignInResponse")
            }
            self.updateTokenAndRefreshUser(idToken: idToken,
                                           refreshToken: refreshToken,
                                           accessToken: accessToken,
                                           expirationDate: response.approximateExpirationDate,
                                           result: result,
                                           requestConfiguration: requestConfiguration,
                                           completion: completion)
          }
        }
      }
    }
  }

  /** @fn linkWithCredential:
      @brief Associates a user account from a third-party identity provider with this user and
          returns additional identity provider data.

      @param credential The credential for the identity provider.
      @returns The AuthDataResult.

      @remarks Possible error codes:

          + `AuthErrorCodeProviderAlreadyLinked` - Indicates an attempt to link a provider of a
              type already linked to this account.
          + `AuthErrorCodeCredentialAlreadyInUse` - Indicates an attempt to link with a
              credential that has already been linked with a different Firebase account.
          + `AuthErrorCodeOperationNotAllowed` - Indicates that accounts with the identity
              provider represented by the credential are not enabled. Enable them in the Auth section
              of the Firebase console.

      @remarks This method may also return error codes associated with `updateEmail(to:)` and
          `updatePassword(to:)` on `User`.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @discardableResult
  public func link(with credential: AuthCredential) async throws -> AuthDataResult {
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
    /** @fn linkWithProvider:UIDelegate:completion:
        @brief link the user with the provided auth provider instance.
            This method is available on iOSonly.

        @param provider An instance of an auth provider used to initiate the link flow.
        @param UIDelegate Optionally an instance of a class conforming to the `AuthUIDelegate`
            protocol used for presenting the web context. If nil, a default `AuthUIDelegate`
            will be used.
        @param completion Optionally; a block which is invoked when the link flow finishes, or
            is canceled. Invoked asynchronously on the main thread in the future.
     */
    @objc(linkWithProvider:UIDelegate:completion:)
    public func link(with provider: FederatedAuthProvider,
                     uiDelegate: AuthUIDelegate?,
                     completion: ((AuthDataResult?, Error?) -> Void)? = nil) {
      kAuthGlobalWorkQueue.async {
        provider.getCredentialWith(uiDelegate) { credential, error in
          if let error {
            if let completion {
              completion(nil, error)
            }
          } else {
            guard let credential else {
              fatalError("Failed to get credential for link withProvider")
            }
            self.link(with: credential, completion: completion)
          }
        }
      }
    }

    /** @fn linkWithProvider:UIDelegate:
        @brief link the user with the provided auth provider instance.
            This method is available on iOS, macOS Catalyst, and tvOS only.

        @param provider An instance of an auth provider used to initiate the link flow.
        @param UIDelegate Optionally an instance of a class conforming to the `AuthUIDelegate`
            protocol used for presenting the web context. If nil, a default `AuthUIDelegate`
            will be used.
        @returns An AuthDataResult.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    @discardableResult
    public func link(with provider: FederatedAuthProvider,
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

  /** @fn unlinkFromProvider:completion:
      @brief Disassociates a user account from a third-party identity provider with this user.

      @param provider The provider ID of the provider to unlink.
      @param completion Optionally; the block invoked when the unlinking is complete, or fails.
          Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeNoSuchProvider` - Indicates an attempt to unlink a provider
              that is not linked to the account.
          + `AuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
              operation that requires a recent login from the user. This error indicates the user
              has not signed in recently enough. To resolve, reauthenticate the user by calling
              `reauthenticate(with:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @objc public func unlink(fromProvider provider: String,
                           completion: ((User?, Error?) -> Void)? = nil) {
    taskQueue.enqueueTask { complete in
      let completeAndCallbackWithError = { error in
        complete()
        User.callInMainThreadWithUserAndError(callback: completion, user: self,
                                              error: error)
      }
      self.internalGetToken { accessToken, error in
        if let error {
          completeAndCallbackWithError(error)
          return
        }
        guard let requestConfiguration = self.auth?.requestConfiguration else {
          fatalError("Internal Error: Unexpected nil requestConfiguration.")
        }
        let request = SetAccountInfoRequest(requestConfiguration: requestConfiguration)
        request.accessToken = accessToken

        if self.providerDataRaw[provider] == nil {
          completeAndCallbackWithError(AuthErrorUtils.noSuchProviderError())
          return
        }
        request.deleteProviders = [provider]
        AuthBackend.post(withRequest: request) { rawResponse, error in
          if let error {
            self.signOutIfTokenIsInvalid(withError: error)
            completeAndCallbackWithError(error)
            return
          }
          // We can't just use the provider info objects in FIRSetAccountInfoResponse
          // because they don't have localID and email fields. Remove the specific
          // provider manually.
          self.providerDataRaw.removeValue(forKey: provider)
          if provider == EmailAuthProvider.id {
            self.hasEmailPasswordCredential = false
          }
          #if os(iOS)
            // After successfully unlinking a phone auth provider, remove the phone number
            // from the cached user info.
            if provider == PhoneAuthProvider.id {
              self.phoneNumber = nil
            }
          #endif
          if let response = rawResponse as? SetAccountInfoResponse,
             let idToken = response.idToken,
             let refreshToken = response.refreshToken {
            let tokenService = SecureTokenService(withRequestConfiguration: requestConfiguration,
                                                  accessToken: idToken,
                                                  accessTokenExpirationDate: response
                                                    .approximateExpirationDate,
                                                  refreshToken: refreshToken)
            self.setTokenService(tokenService: tokenService) { error in
              completeAndCallbackWithError(error)
            }
            return
          }
          if let error = self.updateKeychain() {
            completeAndCallbackWithError(error)
            return
          }
          completeAndCallbackWithError(nil)
        }
      }
    }
  }

  /** @fn unlinkFromProvider:
      @brief Disassociates a user account from a third-party identity provider with this user.

      @param provider The provider ID of the provider to unlink.
      @returns The user.

      @remarks Possible error codes:

          + `AuthErrorCodeNoSuchProvider` - Indicates an attempt to unlink a provider
              that is not linked to the account.
          + `AuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
              operation that requires a recent login from the user. This error indicates the user
              has not signed in recently enough. To resolve, reauthenticate the user by calling
              `reauthenticate(with:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func unlink(fromProvider provider: String) async throws -> User {
    return try await withCheckedThrowingContinuation { continuation in
      self.unlink(fromProvider: provider) { result, error in
        if let result {
          continuation.resume(returning: result)
        } else if let error {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  /** @fn sendEmailVerificationWithCompletion:
      @brief Initiates email verification for the user.

      @param completion Optionally; the block invoked when the request to send an email verification
          is complete, or fails. Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
              sent in the request.
          + `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
              the console for this action.
          + `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
              sending update email.
          + `AuthErrorCodeUserNotFound` - Indicates the user account was not found.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @objc(sendEmailVerificationWithCompletion:)
  public func __sendEmailVerification(withCompletion completion: ((Error?) -> Void)?) {
    sendEmailVerification(withCompletion: completion)
  }

  /** @fn sendEmailVerificationWithActionCodeSettings:completion:
      @brief Initiates email verification for the user.

      @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
          handling action codes.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
              sent in the request.
          + `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
              the console for this action.
          + `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
              sending update email.
          + `AuthErrorCodeUserNotFound` - Indicates the user account was not found.
          + `AuthErrorCodeMissingIosBundleID` - Indicates that the iOS bundle ID is missing when
              a iOS App Store ID is provided.
          + `AuthErrorCodeMissingAndroidPackageName` - Indicates that the android package name
              is missing when the `androidInstallApp` flag is set to true.
          + `AuthErrorCodeUnauthorizedDomain` - Indicates that the domain specified in the
              continue URL is not allowlisted in the Firebase console.
          + `AuthErrorCodeInvalidContinueURI` - Indicates that the domain specified in the
              continue URL is not valid.
   */
  @objc(sendEmailVerificationWithActionCodeSettings:completion:)
  public func sendEmailVerification(with actionCodeSettings: ActionCodeSettings? = nil,
                                    withCompletion completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken { accessToken, error in
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
        AuthBackend.post(withRequest: request) { response, error in
          if let error {
            self.signOutIfTokenIsInvalid(withError: error)
          }
          User.callInMainThreadWithError(callback: completion, error: error)
        }
      }
    }
  }

  /** @fn sendEmailVerificationWithActionCodeSettings:
      @brief Initiates email verification for the user.

      @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
          handling action codes.

      @remarks Possible error codes:

          + `AuthErrorCodeInvalidRecipientEmail` - Indicates an invalid recipient email was
              sent in the request.
          + `AuthErrorCodeInvalidSender` - Indicates an invalid sender email is set in
              the console for this action.
          + `AuthErrorCodeInvalidMessagePayload` - Indicates an invalid email template for
              sending update email.
          + `AuthErrorCodeUserNotFound` - Indicates the user account was not found.
          + `AuthErrorCodeMissingIosBundleID` - Indicates that the iOS bundle ID is missing when
              a iOS App Store ID is provided.
          + `AuthErrorCodeMissingAndroidPackageName` - Indicates that the android package name
              is missing when the `androidInstallApp` flag is set to true.
          + `AuthErrorCodeUnauthorizedDomain` - Indicates that the domain specified in the
              continue URL is not allowlisted in the Firebase console.
          + `AuthErrorCodeInvalidContinueURI` - Indicates that the domain specified in the
              continue URL is not valid.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func sendEmailVerification(with actionCodeSettings: ActionCodeSettings? = nil) async throws
  {
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

  /** @fn deleteWithCompletion:
      @brief Deletes the user account (also signs out the user, if this was the current user).

      @param completion Optionally; the block invoked when the request to delete the account is
          complete, or fails. Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
              operation that requires a recent login from the user. This error indicates the user
              has not signed in recently enough. To resolve, reauthenticate the user by calling
              `reauthenticate(with:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @objc public func delete(withCompletion completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken { accessToken, error in
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
        let request = DeleteAccountRequest(localID: self.uid, accessToken: accessToken,
                                           requestConfiguration: requestConfiguration)
        AuthBackend.post(withRequest: request) { response, error in
          if let error {
            User.callInMainThreadWithError(callback: completion, error: error)
            return
          }
          do {
            try self.auth?.signOutByForce(withUserID: self.uid)
          } catch {
            User.callInMainThreadWithError(callback: completion, error: error)
            return
          }
          User.callInMainThreadWithError(callback: completion, error: error)
        }
      }
    }
  }

  /** @fn delete
      @brief Deletes the user account (also signs out the user, if this was the current user).

      @param completion Optionally; the block invoked when the request to delete the account is
          complete, or fails. Invoked asynchronously on the main thread in the future.

      @remarks Possible error codes:

          + `AuthErrorCodeRequiresRecentLogin` - Updating email is a security sensitive
              operation that requires a recent login from the user. This error indicates the user
              has not signed in recently enough. To resolve, reauthenticate the user by calling
              `reauthenticate(with:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all `User` methods.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func delete() async throws {
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

  /** @fn sendEmailVerificationBeforeUpdatingEmail:completion:
       @brief Send an email to verify the ownership of the account then update to the new email.
       @param email The email to be updated to.
       @param completion Optionally; the block invoked when the request to send the verification
           email is complete, or fails.
   */
  @objc(sendEmailVerificationBeforeUpdatingEmail:completion:)
  public func __sendEmailVerificationBeforeUpdating(email: String,
                                                    completion: ((Error?) -> Void)?) {
    sendEmailVerification(beforeUpdatingEmail: email, completion: completion)
  }

  /** @fn sendEmailVerificationBeforeUpdatingEmail:completion:
       @brief Send an email to verify the ownership of the account then update to the new email.
       @param email The email to be updated to.
       @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
           handling action codes.
       @param completion Optionally; the block invoked when the request to send the verification
           email is complete, or fails.
   */
  @objc public func sendEmailVerification(beforeUpdatingEmail email: String,
                                          actionCodeSettings: ActionCodeSettings? =
                                            nil,
                                          completion: ((Error?) -> Void)? = nil) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken { accessToken, error in
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
        AuthBackend.post(withRequest: request) { response, error in
          User.callInMainThreadWithError(callback: completion, error: error)
        }
      }
    }
  }

  /** @fn sendEmailVerificationBeforeUpdatingEmail:completion:
       @brief Send an email to verify the ownership of the account then update to the new email.
       @param email The email to be updated to.
       @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
           handling action codes.
       @throws on failure.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func sendEmailVerification(beforeUpdatingEmail newEmail: String,
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

  @objc public func rawAccessToken() -> String {
    return tokenService.accessToken
  }

  @objc public func accessTokenExpirationDate() -> Date? {
    return tokenService.accessTokenExpirationDate
  }

  // MARK: Internal implementations below

  init(withTokenService tokenService: SecureTokenService) {
    providerDataRaw = [:]
    taskQueue = AuthSerialTaskQueue()
    self.tokenService = tokenService
    isAnonymous = false
    isEmailVerified = false
    metadata = UserMetadata(withCreationDate: nil, lastSignInDate: nil)
    tenantID = nil
    #if os(iOS)
      multiFactor = MultiFactor(mfaEnrollments: [])
    #endif
    uid = ""
    hasEmailPasswordCredential = false
    requestConfiguration = AuthRequestConfiguration(apiKey: "", appID: "")
  }

  // TODO: internal Swift
  @objc public class func retrieveUser(withAuth auth: Auth,
                                       accessToken: String?,
                                       accessTokenExpirationDate: Date?,
                                       refreshToken: String?,
                                       anonymous: Bool,
                                       callback: @escaping (User?, Error?) -> Void) {
    guard let accessToken = accessToken,
          let refreshToken = refreshToken else {
      fatalError("Internal FirebaseAuth Error: nil token")
    }
    let tokenService = SecureTokenService(withRequestConfiguration: auth.requestConfiguration,
                                          accessToken: accessToken,
                                          accessTokenExpirationDate: accessTokenExpirationDate,
                                          refreshToken: refreshToken)
    let user = User(withTokenService: tokenService)
    user.auth = auth
    user.tenantID = auth.tenantID
    user.requestConfiguration = auth.requestConfiguration
    user.internalGetToken { accessToken, error in
      if let error {
        callback(nil, error)
        return
      }
      guard let accessToken else {
        fatalError("Internal FirebaseAuthError: Both error and accessToken are nil")
      }
      let getAccountInfoRequest = GetAccountInfoRequest(accessToken: accessToken,
                                                        requestConfiguration: user
                                                          .requestConfiguration)
      AuthBackend.post(withRequest: getAccountInfoRequest) { rawResponse, error in
        if let error {
          // No need to sign out user here for errors because the user hasn't been signed in yet.
          callback(nil, error)
          return
        }
        guard let response = rawResponse as? GetAccountInfoResponse else {
          fatalError("Internal FirebaseAuthError: Response should be a GetAccountInfoResponse")
        }
        user.isAnonymous = anonymous
        user.update(withGetAccountInfoResponse: response)
        callback(user, nil)
      }
    }
  }

  @objc public var providerID: String {
    return "Firebase"
  }

  /** @property uid
      @brief The provider's user ID for the user.
   */
  @objc public var uid: String

  /** @property displayName
      @brief The name of the user.
   */
  @objc public var displayName: String?

  /** @property photoURL
      @brief The URL of the user's profile photo.
   */
  @objc public var photoURL: URL?

  /** @property email
      @brief The user's email address.
   */
  @objc public var email: String?

  /** @property phoneNumber
      @brief A phone number associated with the user.
      @remarks This property is only available for users authenticated via phone number auth.
   */
  @objc public var phoneNumber: String?

  /** @var hasEmailPasswordCredential
      @brief Whether or not the user can be authenticated by using Firebase email and password.
   */
  private var hasEmailPasswordCredential: Bool

  /** @var _taskQueue
      @brief Used to serialize the update profile calls.
   */
  private var taskQueue: AuthSerialTaskQueue

  /** @property requestConfiguration
      @brief A strong reference to a requestConfiguration instance associated with this user instance.
   */
  // TODO: internal
  @objc public var requestConfiguration: AuthRequestConfiguration

  /** @var _tokenService
      @brief A secure token service associated with this user. For performing token exchanges and
          refreshing access tokens.
   */
  // TODO: internal
  @objc public var tokenService: SecureTokenService

  /** @property auth
      @brief A weak reference to a FIRAuth instance associated with this instance.
   */
  // TODO: internal
  @objc public weak var auth: Auth?

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
          self.internalGetToken { accessToken, error in
            if let error {
              callback(error)
              return
            }
            guard let accessToken else {
              fatalError("Auth Internal Error: Both accessToken and error are nil")
            }
            if let requestConfiguration = self.auth?.requestConfiguration {
              let getAccountInfoRequest = GetAccountInfoRequest(accessToken: accessToken,
                                                                requestConfiguration: requestConfiguration)
              AuthBackend.post(withRequest: getAccountInfoRequest) { response, error in
                if let error {
                  self.signOutIfTokenIsInvalid(withError: error)
                  callback(error)
                  return
                }
                guard let accountInfoResponse = response as? GetAccountInfoResponse else {
                  fatalError("Auth Internal Error: Response is not an GetAccountInfoResponse")
                }
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
              }
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

  /** @fn executeUserUpdateWithChanges:callback:
      @brief Performs a setAccountInfo request by mutating the results of a getAccountInfo response,
          atomically in regards to other calls to this method.
      @param changeBlock A block responsible for mutating a template @c FIRSetAccountInfoRequest
      @param callback A block to invoke when the change is complete. Invoked asynchronously on the
          auth global work queue in the future.
   */
  func executeUserUpdateWithChanges(changeBlock: @escaping (GetAccountInfoResponseUser,
                                                            SetAccountInfoRequest) -> Void,
                                    callback: @escaping (Error?) -> Void) {
    taskQueue.enqueueTask { complete in
      self.getAccountInfoRefreshingCache { user, error in
        if let error {
          complete()
          callback(error)
          return
        }
        guard let user else {
          fatalError("Internal error: Both user and error are nil")
        }
        self.internalGetToken { accessToken, error in
          if let error {
            complete()
            callback(error)
            return
          }
          if let configuration = self.auth?.requestConfiguration {
            // Mutate setAccountInfoRequest in block
            let setAccountInfoRequest = SetAccountInfoRequest(requestConfiguration: configuration)
            setAccountInfoRequest.accessToken = accessToken
            changeBlock(user, setAccountInfoRequest)
            // Execute request:
            AuthBackend.post(withRequest: setAccountInfoRequest) { response, error in
              if let error {
                self.signOutIfTokenIsInvalid(withError: error)
                complete()
                callback(error)
                return
              }
              if let accountInfoResponse = response as? SetAccountInfoResponse {
                if let idToken = accountInfoResponse.idToken,
                   let refreshToken = accountInfoResponse.refreshToken {
                  let tokenService = SecureTokenService(
                    withRequestConfiguration: configuration,
                    accessToken: idToken,
                    accessTokenExpirationDate: accountInfoResponse.approximateExpirationDate,
                    refreshToken: refreshToken
                  )
                  self.setTokenService(tokenService: tokenService) { error in
                    complete()
                    callback(error)
                  }
                  return
                }
              }
              complete()
              callback(nil)
            }
          }
        }
      }
    }
  }

  /** @fn setTokenService:callback:
      @brief Sets a new token service for the @c FIRUser instance.
      @param tokenService The new token service object.
      @param callback The block to be called in the global auth working queue once finished.
      @remarks The method makes sure the token service has access and refresh token and the new tokens
          are saved in the keychain before calling back.
   */
  private func setTokenService(tokenService: SecureTokenService,
                               callback: @escaping (Error?) -> Void) {
    tokenService.fetchAccessToken(forcingRefresh: false) { token, error, tokenUpdated in
      if let error {
        callback(error)
        return
      }
      self.tokenService = tokenService
      if let error = self.updateKeychain() {
        callback(error)
        return
      }
      callback(nil)
    }
  }

  /** @fn getAccountInfoRefreshingCache:
      @brief Gets the users's account data from the server, updating our local values.
      @param callback Invoked when the request to getAccountInfo has completed, or when an error has
          been detected. Invoked asynchronously on the auth global work queue in the future.
   */
  private func getAccountInfoRefreshingCache(callback: @escaping (GetAccountInfoResponseUser?,
                                                                  Error?) -> Void) {
    internalGetToken { token, error in
      if let error {
        callback(nil, error)
        return
      }
      guard let token else {
        fatalError("Internal Error: Both error and token are nil.")
      }
      guard let requestConfiguration = self.auth?.requestConfiguration else {
        fatalError("Internal Error: Unexpected nil requestConfiguration.")
      }
      let request = GetAccountInfoRequest(accessToken: token,
                                          requestConfiguration: requestConfiguration)
      AuthBackend.post(withRequest: request) { response, error in
        if let error {
          self.signOutIfTokenIsInvalid(withError: error)
          callback(nil, error)
        }
        guard let accountInfoResponse = response as? GetAccountInfoResponse else {
          fatalError("Internal Error: wrong response type")
        }
        self.update(withGetAccountInfoResponse: accountInfoResponse)
        if let error = self.updateKeychain() {
          callback(nil, error)
          return
        }
        callback(accountInfoResponse.users?.first, nil)
      }
    }
  }

  private func update(withGetAccountInfoResponse response: GetAccountInfoResponse) {
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
        let userInfo = UserInfoImpl.userInfo(withGetAccountInfoResponseProviderUserInfo:
          providerUserInfo)
        if let providerID = providerUserInfo.providerID {
          providerData[providerID] = userInfo
        }
      }
    }
    providerDataRaw = providerData
    #if os(iOS)
      if let enrollments = user.MFAEnrollments {
        multiFactor = MultiFactor(mfaEnrollments: enrollments)
      }
      // TODO: Revisit after port of Multifactor_internal.h
      // self.multiFactor.user = self
    #endif
  }

  #if os(iOS)
    /** @fn internalUpdateOrLinkPhoneNumber
        @brief Updates the phone number for the user. On success, the cached user profile data is
            updated.

        @param phoneAuthCredential The new phone number credential corresponding to the phone number
            to be added to the Firebase account, if a phone number is already linked to the account this
            new phone number will replace it.
        @param isLinkOperation Boolean value indicating whether or not this is a link operation.
        @param completion Optionally; the block invoked when the user profile change has finished.
            Invoked asynchronously on the global work queue in the future.
     */
    private func internalUpdateOrLinkPhoneNumber(credential: PhoneAuthCredential,
                                                 isLinkOperation: Bool,
                                                 completion: @escaping (Error?) -> Void) {
      internalGetToken { accessToken, error in
        if let error {
          completion(error)
          return
        }
        guard let accessToken = accessToken else {
          fatalError("Auth Internal Error: Both accessToken and error are nil")
        }
        guard let configuration = self.auth?.requestConfiguration,
              let verificationID = credential.verificationID,
              let verificationCode = credential.verificationCode else {
          fatalError("Auth Internal Error: nil value for VerifyPhoneNumberRequest initializer")
        }
        let operation = isLinkOperation ? AuthOperationType.link : AuthOperationType.update
        let request = VerifyPhoneNumberRequest(verificationID: verificationID,
                                               verificationCode: verificationCode,
                                               operation: operation,
                                               requestConfiguration: configuration)
        request.accessToken = accessToken
        AuthBackend.post(withRequest: request) { response, error in
          if let error {
            self.signOutIfTokenIsInvalid(withError: error)
            completion(error)
            return
          }
          // Update the new token and refresh user info again.
          if let verifyResponse = response as? VerifyPhoneNumberResponse {
            if let idToken = verifyResponse.idToken,
               let refreshToken = verifyResponse.refreshToken {
              self.tokenService = SecureTokenService(
                withRequestConfiguration: configuration,
                accessToken: idToken,
                accessTokenExpirationDate: verifyResponse.approximateExpirationDate,
                refreshToken: refreshToken
              )
            }
          }
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
        }
      }
    }
  #endif

  private func link(withEmailCredential emailCredential: EmailAuthCredential,
                    completion: ((AuthDataResult?, Error?) -> Void)?) {
    if let password = emailCredential.password {
      updateEmail(email: emailCredential.email, password: password) { error in
        if let error {
          User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                          result: nil,
                                                          error: error)
        } else {
          let result = AuthDataResult(withUser: self, additionalUserInfo: nil)
          User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                          result: result,
                                                          error: nil)
        }
      }
    } else {
      internalGetToken { accessToken, error in
        guard let link = emailCredential.link else {
          fatalError("Internal Auth Error: link is not an email Credential as expected.")
        }
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
        AuthBackend.post(withRequest: request) { rawResponse, error in
          if let error {
            User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                            result: nil,
                                                            error: error)
            return
          }
          guard let response = rawResponse as? EmailLinkSignInResponse else {
            fatalError("Internal Auth Error: response type is not an EmailLinkSignInResponse")
          }
          guard let idToken = response.idToken,
                let refreshToken = response.refreshToken else {
            fatalError("Internal Auth Error: missing token in EmailLinkSignInResponse")
          }
          self.updateTokenAndRefreshUser(idToken: idToken,
                                         refreshToken: refreshToken,
                                         accessToken: accessToken,
                                         expirationDate: response.approximateExpirationDate,
                                         result: AuthDataResult(
                                           withUser: self,
                                           additionalUserInfo: nil
                                         ),
                                         requestConfiguration: requestConfiguration,
                                         completion: completion)
        }
      }
    }
  }

  #if !os(watchOS)
    private func link(withGameCenterCredential gameCenterCredential: GameCenterAuthCredential,
                      completion: ((AuthDataResult?, Error?) -> Void)?) {
      internalGetToken { accessToken, error in
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
        AuthBackend.post(withRequest: request) { rawResponse, error in
          if let error {
            User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                            result: nil,
                                                            error: error)
            return
          }
          guard let response = rawResponse as? SignInWithGameCenterResponse else {
            fatalError("Internal Auth Error: response type is not an SignInWithGameCenterResponse")
          }
          guard let idToken = response.idToken,
                let refreshToken = response.refreshToken else {
            fatalError("Internal Auth Error: missing token in EmailLinkSignInResponse")
          }
          self.updateTokenAndRefreshUser(idToken: idToken,
                                         refreshToken: refreshToken,
                                         accessToken: accessToken,
                                         expirationDate: response.approximateExpirationDate,
                                         result: AuthDataResult(
                                           withUser: self,
                                           additionalUserInfo: nil
                                         ),
                                         requestConfiguration: requestConfiguration,
                                         completion: completion)
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
  private func updateTokenAndRefreshUser(idToken: String, refreshToken: String,
                                         accessToken: String?,
                                         expirationDate: Date?,
                                         result: AuthDataResult,
                                         requestConfiguration: AuthRequestConfiguration,
                                         completion: ((AuthDataResult?, Error?) -> Void)?) {
    tokenService = SecureTokenService(
      withRequestConfiguration: requestConfiguration,
      accessToken: idToken,
      accessTokenExpirationDate: expirationDate,
      refreshToken: refreshToken
    )
    internalGetToken { response, error in
      if let error {
        User.callInMainThreadWithAuthDataResultAndError(callback: completion, result: nil,
                                                        error: error)
        return
      }
      guard let accessToken else {
        fatalError("Internal Auth Error: nil access Token")
      }
      let getAccountInfoRequest = GetAccountInfoRequest(accessToken: accessToken,
                                                        requestConfiguration: requestConfiguration)
      AuthBackend.post(withRequest: getAccountInfoRequest) { rawResponse, error in
        if let error {
          self.signOutIfTokenIsInvalid(withError: error)
          User.callInMainThreadWithAuthDataResultAndError(callback: completion,
                                                          result: nil, error: error)
          return
        }
        guard let response = rawResponse as? GetAccountInfoResponse else {
          fatalError("Internal Auth Error: response is not a GetAccountInfoResponse")
        }
        self.isAnonymous = false
        self.update(withGetAccountInfoResponse: response)
        if let error = self.updateKeychain() {
          User.callInMainThreadWithAuthDataResultAndError(callback: completion, result: nil,
                                                          error: error)
          return
        }
        User.callInMainThreadWithAuthDataResultAndError(callback: completion, result: result,
                                                        error: nil)
      }
    }
  }

  /** @fn signOutIfTokenIsInvalidWithError:
      @brief Signs out this user if the user or the token is invalid.
      @param error The error from the server.
   */
  private func signOutIfTokenIsInvalid(withError error: Error) {
    let code = (error as NSError).code
    if code == AuthErrorCode.userNotFound.rawValue ||
      code == AuthErrorCode.userDisabled.rawValue ||
      code == AuthErrorCode.invalidUserToken.rawValue ||
      code == AuthErrorCode.userTokenExpired.rawValue {
      AuthLog.logNotice(code: "I-AUT000016",
                        message: "Invalid user token detected, user is automatically signed out.")
      try? auth?.signOutByForce(withUserID: uid)
    } else {
      // This case was ignored in the ObjC implementation.
      AuthLog.logWarning(code: "I-AUT000016",
                         message: "Unexpected error code after GetAccountInfoRequest")
    }
  }

  /** @fn internalGetToken
      @brief Retrieves the Firebase authentication token, possibly refreshing it if it has expired.
      @param callback The block to invoke when the token is available. Invoked asynchronously on the
          global work thread in the future.
   */
  // TODO: internal
  @objc(internalGetTokenForcingRefresh:callback:)
  public func internalGetToken(forceRefresh: Bool = false,
                               callback: @escaping (String?, Error?) -> Void) {
    tokenService.fetchAccessToken(forcingRefresh: forceRefresh) { token, error, tokenUpdated in
      if let error {
        callback(nil, error)
        return
      }
      if tokenUpdated {
        if let error = self.updateKeychain() {
          callback(nil, error)
          return
        }
      }
      callback(token, nil)
    }
  }

  /** @fn updateKeychain:
      @brief Updates the keychain for user token or info changes.
      @param error The error if NO is returned.
      @return Whether the operation is successful.
   */
  func updateKeychain() -> Error? {
    if self != auth?.rawCurrentUser {
      // No-op if the user is no longer signed in. This is not considered an error as we don't check
      // whether the user is still current on other callbacks of user operations either.
      return nil
    }
    do {
      try saveUser()
    } catch {
      return error
    }
    return nil
  }

  private func saveUser() throws {
    guard let auth = auth else {
      return
    }
    if auth.userAccessGroup == nil {
      let userKey = "\(auth.firebaseAppName)_firebase_user"
      #if os(watchOS)
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
      #else
        // Encode the user object.
        let archiveData = NSMutableData()
        let archiver = NSKeyedArchiver(forWritingWith: archiveData)
      #endif
      archiver.encode(self, forKey: userKey)
      archiver.finishEncoding()
      #if os(watchOS)
        let archiveData = archiver.encodedData
      #endif

      // Save the user object's encoded value.
      try auth.keychainServices.setData(archiveData as Data, forKey: userKey)

      // TODO: Compile this
//    } else {
//      try auth.storedUserManager.setStoredUser(
//        self,
//                                               forAccessGroup: auth.userAccessGroup,
//                                               shareAuthStateAcrossDevices: auth.shareAuthStateAcrossDevices,
//                                               projectIdentifier: auth.app.options.apiKey)
    }
  }

  /** @fn callInMainThreadWithError
      @brief Calls a callback in main thread with error.
      @param callback The callback to be called in main thread.
      @param error The error to pass to callback.
   */
  internal class func callInMainThreadWithError(callback: ((Error?) -> Void)?, error: Error?) {
    if let callback {
      DispatchQueue.main.async {
        callback(error)
      }
    }
  }

  /** @fn callInMainThreadWithUserAndError
      @brief Calls a callback in main thread with user and error.
      @param callback The callback to be called in main thread.
      @param user The user to pass to callback if there is no error.
      @param error The error to pass to callback.
   */
  private class func callInMainThreadWithUserAndError(callback: ((User?, Error?) -> Void)?,
                                                      user: User,
                                                      error: Error?) {
    if let callback {
      DispatchQueue.main.async {
        callback((error != nil) ? nil : user, error)
      }
    }
  }

  /** @fn callInMainThreadWithAuthDataResultAndError
      @brief Calls a callback in main thread with user and error.
      @param callback The callback to be called in main thread.
      @param result The result to pass to callback if there is no error.
      @param error The error to pass to callback.
   */
  private class func callInMainThreadWithAuthDataResultAndError(callback: ((AuthDataResult?,
                                                                            Error?) -> Void)?,
  result: AuthDataResult?,
  error: Error?) {
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

  public static var supportsSecureCoding = true

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
    guard let userID = coder.decodeObject(forKey: kUserIDCodingKey) as? String,
          let apiKey = coder.decodeObject(forKey: kAPIKeyCodingKey) as? String,
          let appID = coder.decodeObject(forKey: kFirebaseAppIDCodingKey) as? String,
          let tokenService = coder.decodeObject(forKey: kTokenServiceCodingKey)
          as? SecureTokenService else {
      return nil
    }
    let anonymous = coder.decodeBool(forKey: kAnonymousCodingKey)
    let hasEmailPasswordCredential = coder.decodeBool(forKey: kHasEmailPasswordCredentialCodingKey)
    let displayName = coder.decodeObject(forKey: kDisplayNameCodingKey) as? String
    let photoURL = coder.decodeObject(forKey: kPhotoURLCodingKey) as? URL
    let email = coder.decodeObject(forKey: kEmailCodingKey) as? String
    let phoneNumber = coder.decodeObject(forKey: kPhoneNumberCodingKey) as? String
    let emailVerified = coder.decodeBool(forKey: kEmailVerifiedCodingKey)
    let providerData = coder.decodeObject(forKey: kProviderDataKey) as? [String: UserInfoImpl]
    let metadata = coder.decodeObject(forKey: kMetadataCodingKey) as? UserMetadata
    let tenantID = coder.decodeObject(forKey: kTenantIDCodingKey) as? String
    #if os(iOS)
      let multiFactor = coder.decodeObject(forKey: kMultiFactorCodingKey) as? MultiFactor
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
    // The `heartbeatLogger` will be set later via a property update.
    requestConfiguration = AuthRequestConfiguration(apiKey: apiKey, appID: appID)
    taskQueue = AuthSerialTaskQueue()
    #if os(iOS)
      self.multiFactor = multiFactor ?? MultiFactor()
      // TODO: figure out next line.
      // multiFactor?.user = self
    #endif
  }
}
