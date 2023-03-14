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
@objc(FIRUser) public class User: NSObject, UserInfo {
  /** @property anonymous
      @brief Indicates the user represents an anonymous user.
   */
  @objc private(set) public var isAnonymous: Bool

  /** @property emailVerified
      @brief Indicates the email address associated with this user has been verified.
   */
  @objc private(set) public var isEmailVerified: Bool

  /** @property refreshToken
      @brief A refresh token; useful for obtaining new access tokens independently.
      @remarks This property should only be used for advanced scenarios, and is not typically needed.
   */
  @objc public let refreshToken: String

  /** @property providerData
      @brief Profile data for each identity provider, if any.
      @remarks This data is cached on sign-in and updated when linking or unlinking.
   */
  @objc private(set) public var providerData :  [String: UserInfoImpl]

  /** @property metadata
      @brief Metadata associated with the Firebase user in question.
   */
  @objc private(set) public var metadata: UserMetadata

  /** @property tenantID
      @brief The tenant ID of the current user. nil if none is available.
   */
  @objc private(set) public var tenantID: String

  #if os(iOS)
  /** @property multiFactor
      @brief Multi factor object associated with the user.
          This property is available on iOS only.
  */
  @objc private(set) public var multiFactor: MultiFactor
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
  public func updateEmail(to email: String, completion: ((Error?) -> Void)?) {
    kAuthGlobalWorkQueue.async {
      self.updateEmail(email: email, password: nil) { error in
        User.callInMainThreadWithError(callback: completion, error: error)
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
  public func updatePassword(to password: String, completion: ((Error?) -> Void)?) {
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
  @objc
  public func updatePhoneNumberCredential(credential: PhoneAuthCredential,
                                          completion: ((Error?) -> Void)?) {
    kAuthGlobalWorkQueue.async {
      self.internalUpdateOrLinkPhoneNumber(credential: credential,
                                           isLinkOperation: false) { error in
        User.callInMainThreadWithError(callback: completion, error: error)
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

  /** @fn reloadWithCompletion:
      @brief Reloads the user's profile data from the server.

      @param completion Optionally; the block invoked when the reload has finished. Invoked
          asynchronously on the main thread in the future.

      @remarks May fail with a `AuthErrorCodeRequiresRecentLogin` error code. In this case
          you should call `reauthenticate(with:)` before re-invoking
          `updateEmail(to:)`.

      @remarks See `AuthErrors` for a list of error codes that are common to all API methods.
   */
  @objc public func reload(withCompletion completion: ((Error?) -> Void)?) {
    kAuthGlobalWorkQueue.async {
      self.getAccountInfoRefreshingCache() { user, error in
        User.callInMainThreadWithError(callback: completion, error: error)
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
  @objc public func reauthenticate(withCredential credential: AuthCredential,

                                   completion: ((AuthDataResult?, Error?) -> Void)?) {
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
                                                    error: AuthErrorUtils.userMismatchError())
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

  /** @fn reauthenticateWithCredential:
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
  public func reauthenticate(withCredential credential: AuthCredential) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation() { continuation in
      self.reauthenticate(withCredential: credential) { result, error in
        if let result {
          continuation.resume(returning: result)
        } else if let error {
          continuation.resume(throwing: error)
        }
      }
    }
  }

  #if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
  /** @fn reauthenticateWithProvider:UIDelegate:completion:
      @brief Renews the user's authentication using the provided auth provider instance.
          This method is available on iOS, macOS Catalyst, and tvOS only.

      @param provider An instance of an auth provider used to initiate the reauthenticate flow.
      @param UIDelegate Optionally an instance of a class conforming to the `AuthUIDelegate`
          protocol, used for presenting the web context. If nil, a default `AuthUIDelegate`
          will be used.
      @param completion Optionally; a block which is invoked when the reauthenticate flow finishes, or
          is canceled. Invoked asynchronously on the main thread in the future.
   */
  @objc(reauthenticateWithProvider:UIDelegate:completion:)
  public func reauthenticate(withProvider provider: FederatedAuthProvider,
                                   uiDelegate: AuthUIDelegate?,
                                   completion: ((AuthDataResult?, Error?) -> Void)?) {
    // TODO: Why isn't the `#if` around the function?
    #if os(iOS)
    kAuthGlobalWorkQueue.async {
      provider.getCredentialWith(uiDelegate) { credential, error in
        if let error {
          if let completion {
            completion(nil, error)
          }
          return
        }
        if let credential {
          self.reauthenticate(withCredential: credential, completion: completion)
        }
      }
    }
    #endif
  }

  /** @fn reauthenticateWithProvider:UIDelegate:
      @brief Renews the user's authentication using the provided auth provider instance.
          This method is available on iOS, macOS Catalyst, and tvOS only.

      @param provider An instance of an auth provider used to initiate the reauthenticate flow.
      @param UIDelegate Optionally an instance of a class conforming to the `AuthUIDelegate`
          protocol, used for presenting the web context. If nil, a default `AuthUIDelegate`
          will be used.
      @returns An AuthDataResult.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  public func reauthenticate(withProvider provider: FederatedAuthProvider,
                                   uiDelegate: AuthUIDelegate?) async throws -> AuthDataResult {
    return try await withCheckedThrowingContinuation() { continuation in
      self.reauthenticate(withProvider: provider, uiDelegate: uiDelegate) { result, error in
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
    self.getIDToken(forcingRefresh:false, completion: completion)
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
  public func getIDToken(forcingRefresh forceRefresh: Bool,
                         completion: ((String?, Error?) -> Void)?) {
    self.getIDTokenResult(forcingRefresh: forceRefresh) { tokenResult, error in
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
    return try await withCheckedThrowingContinuation() { continuation in
      self.getIDTokenResult(forcingRefresh:forceRefresh) { tokenResult, error in
        if let tokenResult {
          continuation.resume(returning: tokenResult.token)
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
    self.getIDTokenResult(forcingRefresh: false) { tokenResult, error in
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
  public func getIDTokenResult(forcingRefresh forceRefresh: Bool,
                               completion: ((AuthTokenResult?, Error?) -> Void)?) {
    kAuthGlobalWorkQueue.async {
      self.internalGetToken(forceRefresh: forceRefresh) { token, error in
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
  public func getIDTokenResult(forcingRefresh forceRefresh: Bool) async throws -> AuthTokenResult {
    return try await withCheckedThrowingContinuation() { continuation in
      self.getIDTokenResult(forcingRefresh:forceRefresh) { tokenResult, error in
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
  @objc public func link(withCredential credential: AuthCredential,
                         completion: ((AuthDataResult?, Error?) -> Void)?) {

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
  public func link(withCredential credential: AuthCredential) async -> AuthDataResult {

 }

#if os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
  /** @fn linkWithProvider:UIDelegate:completion:
      @brief link the user with the provided auth provider instance.
          This method is available on iOS, macOS Catalyst, and tvOS only.

      @param provider An instance of an auth provider used to initiate the link flow.
      @param UIDelegate Optionally an instance of a class conforming to the `AuthUIDelegate`
          protocol used for presenting the web context. If nil, a default `AuthUIDelegate`
          will be used.
      @param completion Optionally; a block which is invoked when the link flow finishes, or
          is canceled. Invoked asynchronously on the main thread in the future.
   */
@objc(linkWithProvider:UIDelegate:completion:)
public func link(withProvider provider: FederatedAuthProvider,
                                 uiDelegate: AuthUIDelegate?,
                                 completion: ((AuthDataResult?, Error?) -> Void)?) {

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
public func link(withProvider provider: FederatedAuthProvider,
                                 uiDelegate: AuthUIDelegate) async -> AuthDataResult {

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
                                   completion: ((User?, Error?) -> Void)?) {

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
  public func unlink(fromProvider provider: String) async -> User {

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
  @objc public func sendEmailVerification(withCompletion completion: ((Error) -> Void)?) {

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
  @objc public func sendEmailVerification(actionCodeSettings: ActionCodeSettings,
                                          withCompletion completion: ((Error) -> Void)?) {

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
  @objc public func delete(withCompletion completion: ((Error) -> Void)?) {

  }

  /** @fn sendEmailVerificationBeforeUpdatingEmail:completion:
      @brief Send an email to verify the ownership of the account then update to the new email.
      @param email The email to be updated to.
      @param completion Optionally; the block invoked when the request to send the verification
          email is complete, or fails.
  */
  @objc public func sendEmailVerificationBeforeUpdating(email: String, completion: ((Error) -> Void)?) {

  }

  /** @fn sendEmailVerificationBeforeUpdatingEmail:completion:
      @brief Send an email to verify the ownership of the account then update to the new email.
      @param email The email to be updated to.
      @param actionCodeSettings An `ActionCodeSettings` object containing settings related to
          handling action codes.
      @param completion Optionally; the block invoked when the request to send the verification
          email is complete, or fails.
  */
  @objc public func sendEmailVerificationBeforeUpdating(email: String,
                                                        actionCodeSettings: ActionCodeSettings,
                                                        completion: ((Error) -> Void)?) {

  }
  public var providerID: String

  /** @property uid
      @brief The provider's user ID for the user.
   */
  public var uid: String

  /** @property displayName
      @brief The name of the user.
   */
  public var displayName: String?

  /** @property photoURL
      @brief The URL of the user's profile photo.
   */
  public var photoURL: URL?

  /** @property email
      @brief The user's email address.
   */
  public var email: String?

  /** @property phoneNumber
      @brief A phone number associated with the user.
      @remarks This property is only available for users authenticated via phone number auth.
   */
  public var phoneNumber: String?

  /** @var hasEmailPasswordCredential
                 @brief Whether or not the user can be authenticated by using Firebase email and password.
              */
  private var hasEmailPasswordCredential: Bool

  /** @var _taskQueue
      @brief Used to serialize the update profile calls.
   */
  private var taskQueue: AuthSerialTaskQueue

  /** @var _tokenService
      @brief A secure token service associated with this user. For performing token exchanges and
          refreshing access tokens.
   */
  private var tokenService: SecureTokenService

  /** @property auth
      @brief A weak reference to a FIRAuth instance associated with this instance.
   */
  private weak var auth: Auth?

  // MARK: Private functions

  private func updateEmail(email: String?, password: String?, callback: (Error?) -> Void) {
    let hadEmailPasswordCredential = self.hasEmailPasswordCredential
    self.executeUserUpdateWithChanges(changeBlock: { user, request in
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
          self.internalGetToken() { accessToken, error in
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
  private func executeUserUpdateWithChanges(changeBlock: (GetAccountInfoResponseUser,
                                                          SetAccountInfoRequest) -> Void,
                                            callback: (Error?) -> Void) {
    taskQueue.enqueueTask() { complete in
      self.getAccountInfoRefreshingCache() { user, error in
        if let error {
          complete()
          callback(error)
          return
        }
        guard let user else {
          fatalError("Internal error: Both user and error are nil")
        }
        self.internalGetToken() { accessToken, error in
          if let error {
            complete()
            callback(error)
            return
          }
          if let configuration = self.auth?.requestConfiguration {
            // Mutate setAccountInfoRequest in block:
            var setAccountInfoRequest = SetAccountInfoRequest(requestConfiguration: configuration)
            setAccountInfoRequest.accessToken = accessToken
            changeBlock(user, setAccountInfoRequest)
            // Execute request:
            AuthBackend.post(withRequest: setAccountInfoRequest) { response, error in
              if let error {
                self.signOutIfTokenIsInvalid(withError: error)
                complete()
                return
              }
              if let accountInfoResponse = response as? SetAccountInfoResponse {
                if let idToken = accountInfoResponse.idToken,
                   let refreshToken = accountInfoResponse.refreshToken {
                  let tokenService = SecureTokenService(
                    withRequestConfiguration: configuration,
                    accessToken: idToken,
                    accessTokenExpirationDate: accountInfoResponse.approximateExpirationDate,
                    refreshToken: refreshToken)
                  self.setTokenService(tokenService: tokenService) { error in
                    complete()
                    callback(error)
                    return
                  }
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
  private func setTokenService(tokenService: SecureTokenService, callback: (Error?) -> Void) {
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
  private func getAccountInfoRefreshingCache(callback: (GetAccountInfoResponseUser?, Error?) -> Void) {
    self.internalGetToken() { token, error in
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
    self.providerData = providerData
    #if os(iOS)
    if let enrollments = user.MFAEnrollments {
      self.multiFactor = MultiFactor(mfaEnrollments: enrollments)
    }
    multiFactor.user = self
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
                                               completion: (Error?) -> Void) {
    self.internalGetToken() { accessToken, error in
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
              refreshToken: refreshToken)
          }
        }
        // Get account info to update cached user info.
        self.getAccountInfoRefreshingCache() { user, error in
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
  private func internalGetToken(forceRefresh: Bool = false,
                                              callback: (String?, Error?) -> Void) {
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
  private func updateKeychain() -> Error? {
    if let error = self.auth.updateKeychain(with: self) {
      return error
    }
    return nil
  }

  /** @fn callInMainThreadWithError
      @brief Calls a callback in main thread with error.
      @param callback The callback to be called in main thread.
      @param error The error to pass to callback.
   */
  private class func callInMainThreadWithError(callback: ((Error?) -> Void)?, error: Error?) {
    if let callback {
      DispatchQueue.main.async {
        callback(error)
      }
    }
  }

  /** @fn callInMainThreadWithUserAndError
      @brief Calls a callback in main thread with user and error.
      @param callback The callback to be called in main thread.
      @param result The result to pass to callback if there is no error.
      @param error The error to pass to callback.
   */
  private class func callInMainThreadWithAuthDataResultAndError(
    callback: ((AuthDataResult?, Error?) -> Void)?,
                                                                result: AuthDataResult?,
                                                                error: Error?) {
    if let callback {
      DispatchQueue.main.async {
        callback(result, error)
      }
    }
  }

}
