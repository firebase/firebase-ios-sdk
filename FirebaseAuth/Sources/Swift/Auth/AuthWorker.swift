// Copyright 2024 Google LLC
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

#if COCOAPODS
  @_implementationOnly import GoogleUtilities
#else
  @_implementationOnly import GoogleUtilities_AppDelegateSwizzler
  @_implementationOnly import GoogleUtilities_Environment
#endif

#if canImport(UIKit)
  import UIKit
#endif

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
actor AuthWorker {
  let requestConfiguration: AuthRequestConfiguration

  func getLanguageCode() -> String? {
    return requestConfiguration.languageCode
  }

  func setLanguageCode(_ code: String?) {
    requestConfiguration.languageCode = code
  }

  /// The manager for APNs tokens used by phone number auth.
  var tokenManager: AuthAPNSTokenManager!

  func tokenManagerCancel(error: Error) {
    tokenManager.cancel(withError: error)
  }

  func tokenManagerSet(_ token: Data, type: AuthAPNSTokenType) {
    tokenManager.token = AuthAPNSToken(withData: token, type: type)
  }

  func tokenManagerGet() -> AuthAPNSTokenManager {
    return tokenManager
  }

  func getToken(forcingRefresh forceRefresh: Bool) async throws -> String? {
    // Enable token auto-refresh if not already enabled.
    guard let auth = requestConfiguration.auth else {
      return nil
    }
    auth.getTokenInternal(forcingRefresh: forceRefresh)

    // Call back with 'nil' if there is no current user.
    guard let currentUser = auth.currentUser else {
      return nil
    }
    return try await currentUser.internalGetTokenAsync(forceRefresh: forceRefresh)
  }

  /// Only for testing
  func tokenManagerInit(_ manager: AuthAPNSTokenManager) {
    tokenManager = manager
  }

  func fetchSignInMethods(forEmail email: String) async throws -> [String] {
    let request = CreateAuthURIRequest(identifier: email,
                                       continueURI: "http:www.google.com",
                                       requestConfiguration: requestConfiguration)
    let response = try await AuthBackend.call(with: request)
    return response.signinMethods ?? []
  }

  func signIn(withEmail email: String, password: String) async throws -> AuthDataResult {
    let credential = EmailAuthCredential(withEmail: email, password: password)
    return try await internalSignInAndRetrieveData(withCredential: credential,
                                                   isReauthentication: false)
  }

  func signIn(withEmail email: String, link: String) async throws -> AuthDataResult {
    let credential = EmailAuthCredential(withEmail: email, link: link)
    return try await internalSignInAndRetrieveData(withCredential: credential,
                                                   isReauthentication: false)
  }

  func signIn(with credential: AuthCredential) async throws -> AuthDataResult {
    return try await internalSignInAndRetrieveData(withCredential: credential,
                                                   isReauthentication: false)
  }

  #if os(iOS)
    func signIn(with provider: FederatedAuthProvider,
                uiDelegate: AuthUIDelegate?) async throws -> AuthDataResult {
      let credential = try await provider.credential(with: uiDelegate)
      return try await internalSignInAndRetrieveData(
        withCredential: credential,
        isReauthentication: false
      )
    }
  #endif

  func signInAnonymously() async throws -> AuthDataResult {
    if let currentUser = requestConfiguration.auth?.currentUser,
       currentUser.isAnonymous {
      return AuthDataResult(withUser: currentUser, additionalUserInfo: nil)
    }
    let request = SignUpNewUserRequest(requestConfiguration: requestConfiguration)
    let response = try await AuthBackend.call(with: request)
    let user = try await completeSignIn(
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
    return AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
  }

  func signIn(withCustomToken token: String) async throws -> AuthDataResult {
    let request = VerifyCustomTokenRequest(token: token,
                                           requestConfiguration: requestConfiguration)
    let response = try await AuthBackend.call(with: request)
    let user = try await completeSignIn(
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
    return AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
  }

  func createUser(withEmail email: String, password: String) async throws -> AuthDataResult {
    let request = SignUpNewUserRequest(email: email,
                                       password: password,
                                       displayName: nil,
                                       idToken: nil,
                                       requestConfiguration: requestConfiguration)
    #if os(iOS)
      let response = try await injectRecaptcha(request: request,
                                               action: AuthRecaptchaAction.signUpPassword)
    #else
      let response = try await AuthBackend.call(with: request)
    #endif
    let user = try await completeSignIn(
      withAccessToken: response.idToken,
      accessTokenExpirationDate: response.approximateExpirationDate,
      refreshToken: response.refreshToken,
      anonymous: false
    )
    let additionalUserInfo = AdditionalUserInfo(providerID: EmailAuthProvider.id,
                                                profile: nil,
                                                username: nil,
                                                isNewUser: true)
    return AuthDataResult(withUser: user, additionalUserInfo: additionalUserInfo)
  }

  func confirmPasswordReset(withCode code: String, newPassword: String) async throws {
    let request = ResetPasswordRequest(oobCode: code,
                                       newPassword: newPassword,
                                       requestConfiguration: requestConfiguration)
    _ = try await AuthBackend.call(with: request)
  }

  func checkActionCode(_ code: String) async throws -> ActionCodeInfo {
    let request = ResetPasswordRequest(oobCode: code,
                                       newPassword: nil,
                                       requestConfiguration: requestConfiguration)
    let response = try await AuthBackend.call(with: request)

    let operation = ActionCodeInfo.actionCodeOperation(forRequestType: response.requestType)
    guard let email = response.email else {
      fatalError("Internal Auth Error: Failed to get a ResetPasswordResponse")
    }
    return ActionCodeInfo(withOperation: operation,
                          email: email,
                          newEmail: response.verifiedEmail)
  }

  func verifyPasswordResetCode(_ code: String) async throws -> String {
    let info = try await checkActionCode(code)
    return info.email
  }

  func applyActionCode(_ code: String) async throws {
    let request = SetAccountInfoRequest(requestConfiguration: requestConfiguration)
    request.oobCode = code
    _ = try await AuthBackend.call(with: request)
  }

  func sendPasswordReset(withEmail email: String,
                         actionCodeSettings: ActionCodeSettings? = nil) async throws {
    let request = GetOOBConfirmationCodeRequest.passwordResetRequest(
      email: email,
      actionCodeSettings: actionCodeSettings,
      requestConfiguration: requestConfiguration
    )
    #if os(iOS)
      _ = try await injectRecaptcha(request: request,
                                    action: AuthRecaptchaAction.getOobCode)
    #else
      _ = try await AuthBackend.call(with: request)
    #endif
  }

  func sendSignInLink(toEmail email: String,
                      actionCodeSettings: ActionCodeSettings) async throws {
    let request = GetOOBConfirmationCodeRequest.signInWithEmailLinkRequest(
      email,
      actionCodeSettings: actionCodeSettings,
      requestConfiguration: requestConfiguration
    )
    #if os(iOS)
      _ = try await injectRecaptcha(request: request,
                                    action: AuthRecaptchaAction.getOobCode)
    #else
      _ = try await AuthBackend.call(with: request)
    #endif
  }

  func signOut() throws {
    guard requestConfiguration.auth?.currentUser != nil else {
      return
    }
    try updateCurrentUser(nil, byForce: false, savingToDisk: true)
  }

  func updateCurrentUser(_ user: User) async throws {
    if user.requestConfiguration.apiKey != requestConfiguration.apiKey {
      // If the API keys are different, then we need to confirm that the user belongs to the same
      // project before proceeding.
      user.requestConfiguration = requestConfiguration
      try await user.reload()
    }
    try updateCurrentUser(user, byForce: true, savingToDisk: true)
  }

  /// Continue with the rest of the Auth object initialization in the worker actor.
  func protectedDataInitialization(_ keychainStorageProvider: AuthKeychainStorage) {
    // Load current user from Keychain.
    guard let auth = requestConfiguration.auth else {
      return
    }
    if let keychainServiceName = Auth.keychainServiceName(forAppName: auth.firebaseAppName) {
      auth.keychainServices = AuthKeychainServices(service: keychainServiceName,
                                                   storage: keychainStorageProvider)
      auth.storedUserManager = AuthStoredUserManager(
        serviceName: keychainServiceName,
        keychainServices: auth.keychainServices
      )
    }
    do {
      if let storedUserAccessGroup = auth.storedUserManager.getStoredUserAccessGroup() {
        try auth.internalUseUserAccessGroup(storedUserAccessGroup)
      } else {
        let user = try auth.getUser()
        try updateCurrentUser(user, byForce: false, savingToDisk: false)
        if let user {
          auth.tenantID = user.tenantID
          auth.lastNotifiedUserToken = user.rawAccessToken()
        }
      }
    } catch {
      #if canImport(UIKit)
        if (error as NSError).code == AuthErrorCode.keychainError.rawValue {
          // If there's a keychain error, assume it is due to the keychain being accessed
          // before the device is unlocked as a result of prewarming, and listen for the
          // UIApplicationProtectedDataDidBecomeAvailable notification.
          auth.addProtectedDataDidBecomeAvailableObserver()
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
      tokenManager = AuthAPNSTokenManager(withApplication: application)
      auth.appCredentialManager = AuthAppCredentialManager(withKeychain: auth.keychainServices)
      auth.notificationManager = AuthNotificationManager(
        withApplication: application,
        appCredentialManager: auth.appCredentialManager
      )

      GULAppDelegateSwizzler.registerAppDelegateInterceptor(auth)
      GULSceneDelegateSwizzler.registerSceneDelegateInterceptor(auth)
    #endif
  }

  func updateEmail(user: User,
                   email: String?,
                   password: String?) async throws {
    let hadEmailPasswordCredential = user.hasEmailPasswordCredential
    try await executeUserUpdateWithChanges(user: user) { userAccount, request in
      if let email {
        request.email = email
      }
      if let password {
        request.password = password
      }
    }
    if let email {
      user.email = email
    }
    if user.email != nil {
      guard !hadEmailPasswordCredential else {
        if let error = user.updateKeychain() {
          throw error
        }
        return
      }
      // The list of providers need to be updated for the newly added email-password provider.
      let accessToken = try await user.internalGetTokenAsync()
      let getAccountInfoRequest = GetAccountInfoRequest(accessToken: accessToken,
                                                        requestConfiguration: requestConfiguration)
      do {
        let accountInfoResponse = try await AuthBackend.call(with: getAccountInfoRequest)
        if let users = accountInfoResponse.users {
          for userAccountInfo in users {
            // Set the account to non-anonymous if there are any providers, even if
            // they're not email/password ones.
            if let providerUsers = userAccountInfo.providerUserInfo {
              if providerUsers.count > 0 {
                user.isAnonymous = false
                for providerUserInfo in providerUsers {
                  if providerUserInfo.providerID == EmailAuthProvider.id {
                    user.hasEmailPasswordCredential = true
                    break
                  }
                }
              }
            }
          }
        }
        user.update(withGetAccountInfoResponse: accountInfoResponse)
        if let error = user.updateKeychain() {
          throw error
        }
      } catch {
        user.signOutIfTokenIsInvalid(withError: error)
        throw error
      }
    }
  }

  /// Performs a setAccountInfo request by mutating the results of a getAccountInfo response,
  /// atomically in regards to other calls to this method.
  /// - Parameter changeBlock: A block responsible for mutating a template `SetAccountInfoRequest`
  /// - Parameter callback: A block to invoke when the change is complete. Invoked asynchronously on
  /// the auth global work queue in the future.
  private func executeUserUpdateWithChanges(user: User,
                                            changeBlock: @escaping (GetAccountInfoResponseUser,
                                                                    SetAccountInfoRequest)
                                              -> Void) async throws {
    let userAccountInfo = try await getAccountInfoRefreshingCache(user)
    let accessToken = try await user.internalGetTokenAsync()

    // Mutate setAccountInfoRequest in block
    let setAccountInfoRequest = SetAccountInfoRequest(requestConfiguration: requestConfiguration)
    setAccountInfoRequest.accessToken = accessToken
    changeBlock(userAccountInfo, setAccountInfoRequest)
    do {
      let accountInfoResponse = try await AuthBackend.call(with: setAccountInfoRequest)
      if let idToken = accountInfoResponse.idToken,
         let refreshToken = accountInfoResponse.refreshToken {
        let tokenService = SecureTokenService(
          withRequestConfiguration: requestConfiguration,
          accessToken: idToken,
          accessTokenExpirationDate: accountInfoResponse.approximateExpirationDate,
          refreshToken: refreshToken
        )
        try await user.setTokenService(tokenService: tokenService)
      }
    } catch {
      user.signOutIfTokenIsInvalid(withError: error)
      throw error
    }
  }

  /// Gets the users' account data from the server, updating our local values.
  /// - Parameter callback: Invoked when the request to getAccountInfo has completed, or when an
  /// error has been detected. Invoked asynchronously on the auth global work queue in the future.
  private func getAccountInfoRefreshingCache(_ user: User) async throws
    -> GetAccountInfoResponseUser {
    let token = try await user.internalGetTokenAsync()
    let request = GetAccountInfoRequest(accessToken: token,
                                        requestConfiguration: requestConfiguration)
    do {
      let accountInfoResponse = try await AuthBackend.call(with: request)
      user.update(withGetAccountInfoResponse: accountInfoResponse)
      if let error = user.updateKeychain() {
        throw error
      }
      return (accountInfoResponse.users?.first)!
    } catch {
      user.signOutIfTokenIsInvalid(withError: error)
      throw error
    }
  }

  func reauthenticate(with credential: AuthCredential) async throws -> AuthDataResult {
    do {
      let authResult = try await internalSignInAndRetrieveData(
        withCredential: credential,
        isReauthentication: true
      )
      let user = authResult.user
      guard user.uid == requestConfiguration.auth?.getUserID() else {
        throw AuthErrorUtils.userMismatchError()
      }
      // TODO: set tokenService migration

      return authResult
    } catch {
      if (error as NSError).code == AuthErrorCode.userNotFound.rawValue {
        throw AuthErrorUtils.userMismatchError()
      }
      throw error
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
    if user == requestConfiguration.auth?.currentUser {
      // TODO: local
      requestConfiguration.auth?.possiblyPostAuthStateChangeNotification()
    }
    if let user {
      if user.tenantID != requestConfiguration.auth?.tenantID {
        let error = AuthErrorUtils.tenantIDMismatchError()
        throw error
      }
    }
    var throwError: Error?
    if saveToDisk {
      do {
        // TODO: call local saveSuer
        try requestConfiguration.auth?.saveUser(user)
      } catch {
        throwError = error
      }
    }
    if throwError == nil || force {
      requestConfiguration.auth?.currentUser = user
      // TODO:
      requestConfiguration.auth?.possiblyPostAuthStateChangeNotification()
    }
    if let throwError {
      throw throwError
    }
  }

  func useEmulator(withHost host: String, port: Int) async {
    // If host is an IPv6 address, it should be formatted with surrounding brackets.
    let formattedHost = host.contains(":") ? "[\(host)]" : host
    requestConfiguration.emulatorHostAndPort = "\(formattedHost):\(port)"
    #if os(iOS)
      requestConfiguration.auth?.settings?.appVerificationDisabledForTesting = true
    #endif
  }

  #if os(iOS)
    func canHandleNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
      guard let auth = requestConfiguration.auth else {
        return false
      }
      return auth.notificationManager.canHandle(notification: userInfo)
    }

    func canHandle(_ url: URL) -> Bool {
      guard let auth = requestConfiguration.auth,
            let authURLPresenter = auth.authURLPresenter as? AuthURLPresenter else {
        return false
      }
      return authURLPresenter.canHandle(url: url)
    }

  #endif

  func autoTokenRefresh(accessToken: String, retry: Bool, delay: TimeInterval) async {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    guard let auth = requestConfiguration.auth,
          let currentUser = auth.currentUser else {
      return
    }
    let accessToken = currentUser.rawAccessToken()
    guard currentUser.rawAccessToken() == accessToken else {
      // Another auto refresh must have been scheduled, so keep _autoRefreshScheduled unchanged.
      return
    }
    auth.autoRefreshScheduled = false
    if auth.isAppInBackground {
      return
    }
    let uid = currentUser.uid
    do {
      _ = try await currentUser.internalGetTokenAsync(forceRefresh: true)
      if auth.currentUser?.uid != uid {
        return
      }
    } catch {
      // Kicks off exponential back off logic to retry failed attempt. Starts with one minute
      // delay (60 seconds) if this is the first failed attempt.
      let rescheduleDelay = retry ? min(delay * 2, 16 * 60) : 60
      auth.scheduleAutoTokenRefresh(withDelay: rescheduleDelay, retry: true)
    }
  }

  func fetchAccessToken(user: User,
                        forcingRefresh forceRefresh: Bool) async throws -> (String?, Bool) {
    if !forceRefresh, user.tokenService.hasValidAccessToken() {
      return (user.tokenService.accessToken, false)
    } else {
      AuthLog.logDebug(code: "I-AUT000017", message: "Fetching new token from backend.")
      return try await user.tokenService.requestAccessToken(retryIfExpired: true)
    }
  }

  private func internalSignInAndRetrieveData(withCredential credential: AuthCredential,
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
    let response = try await AuthBackend.call(with: request)
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
        return try await AuthBackend.call(with: request)
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
        return try await AuthBackend.call(with: request)
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
      let response = try await AuthBackend.call(with: request)
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
    guard let auth = requestConfiguration.auth, auth.isSignIn(withEmailLink: link) else {
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
    let response = try await AuthBackend.call(with: request)
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

  private func internalSignInUser(withEmail email: String, password: String) async throws -> User {
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
      let response = try await AuthBackend.call(with: request)
    #endif
    return try await completeSignIn(
      withAccessToken: response.idToken,
      accessTokenExpirationDate: response.approximateExpirationDate,
      refreshToken: response.refreshToken,
      anonymous: false
    )
  }

  #if os(iOS)
    func injectRecaptcha<T: AuthRPCRequest>(request: T,
                                            action: AuthRecaptchaAction) async throws -> T
      .Response {
      let recaptchaVerifier = AuthRecaptchaVerifier.shared(auth: requestConfiguration.auth)
      if recaptchaVerifier.enablementStatus(forProvider: AuthRecaptchaProvider.password) {
        try await recaptchaVerifier.injectRecaptchaFields(request: request,
                                                          provider: AuthRecaptchaProvider.password,
                                                          action: action)
      } else {
        do {
          return try await AuthBackend.call(with: request)
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
      return try await AuthBackend.call(with: request)
    }
  #endif

  private func completeSignIn(withAccessToken accessToken: String?,
                              accessTokenExpirationDate: Date?,
                              refreshToken: String?,
                              anonymous: Bool) async throws -> User {
    return try await User.retrieveUser(withAuth: requestConfiguration.auth!,
                                       accessToken: accessToken,
                                       accessTokenExpirationDate: accessTokenExpirationDate,
                                       refreshToken: refreshToken,
                                       anonymous: anonymous)
  }

  init(requestConfiguration: AuthRequestConfiguration) {
    self.requestConfiguration = requestConfiguration
  }
}
