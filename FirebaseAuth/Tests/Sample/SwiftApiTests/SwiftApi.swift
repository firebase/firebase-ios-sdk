/*
 * Copyright 2022 Google LLC
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

import Foundation
import XCTest

import FirebaseAuth
import FirebaseCore

/// This file tests public methods and enums. Properties are not included.
/// Each function maps to a public header file.

class AuthApiBuildOnlyTests: XCTestCase {
  // Each function corresponds with a public header.
  func FIRActionCodeSettingsBuild() {
    let codeSettings = FirebaseAuth.ActionCodeSettings()
    codeSettings.setIOSBundleID("abc")
    codeSettings.setAndroidPackageName("name", installIfNotAvailable: true, minimumVersion: "10.0")
  }

  func FIRAuthBuild() throws {
    let auth = FirebaseAuth.Auth.auth()
    let authApp = FirebaseAuth.Auth.auth(app: FirebaseApp.app()!)
    let user = auth.currentUser!
    auth.updateCurrentUser(user) { _ in
    }
    authApp.fetchSignInMethods(forEmail: "abc@abc.com") { string, error in
    }
    auth.signIn(withEmail: "abc@abc.com", password: "password") { result, error in
    }
    auth.signIn(withEmail: "abc@abc.com", link: "link") { result, error in
    }
    let provider = OAuthProvider(providerID: "abc")
    auth.signIn(with: OAuthProvider(providerID: "abc"), uiDelegate: nil) { result, error in
    }
    provider.getCredentialWith(nil) { credential, error in
      auth.signIn(with: credential!) { result, error in
      }
    }
    auth.signIn(with: OAuthProvider(providerID: "abc"), uiDelegate: nil) { result, error in
    }
    auth.signInAnonymously { result, error in
    }
    auth.signIn(withCustomToken: "abc") { result, error in
    }
    auth.createUser(withEmail: "email", password: "password") { result, error in
    }
    auth.confirmPasswordReset(withCode: "code", newPassword: "password") { error in
    }
    auth.checkActionCode("abc") { codeInfo, error in
    }
    auth.verifyPasswordResetCode("code") { email, error in
    }
    auth.applyActionCode("code") { error in
    }
    auth.sendPasswordReset(withEmail: "email") { error in
    }
    let actionCodeSettings = ActionCodeSettings()
    auth.sendPasswordReset(withEmail: "email", actionCodeSettings: actionCodeSettings) { error in
    }
    auth.sendSignInLink(toEmail: "email", actionCodeSettings: actionCodeSettings) { error in
    }
    try auth.signOut()
    auth.isSignIn(withEmailLink: "link")
    let handle = auth.addStateDidChangeListener { auth, user in
    }
    auth.removeStateDidChangeListener(handle)
    auth.addIDTokenDidChangeListener { auth, user in
    }
    auth.removeIDTokenDidChangeListener(handle)
    auth.useAppLanguage()
    auth.useEmulator(withHost: "myHost", port: 123)
    auth.canHandle(URL(fileURLWithPath: "/my/path"))
    auth.setAPNSToken(Data(), type: AuthAPNSTokenType(rawValue: 2)!)
    auth.canHandleNotification([:])
    try auth.useUserAccessGroup("abc")
    try auth.getStoredUser(forAccessGroup: "def")
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func FIRAuthBuildAsync() async throws {
      let auth = FirebaseAuth.Auth.auth()
      let user = auth.currentUser!
      try await auth.updateCurrentUser(user)
      _ = try await auth.fetchSignInMethods(forEmail: "abc@abc.com")
      _ = try await auth.signIn(withEmail: "abc@abc.com", password: "password")
      _ = try await auth.signIn(withEmail: "abc@abc.com", link: "link")
      let provider = OAuthProvider(providerID: "abc")
      let credential = try await provider.credential(with: nil)
      _ = try await auth.signIn(with: OAuthProvider(providerID: "abc"), uiDelegate: nil)
      _ = try await auth.signIn(with: credential)
      _ = try await auth.signInAnonymously()
      _ = try await auth.signIn(withCustomToken: "abc")
      _ = try await auth.createUser(withEmail: "email", password: "password")
      _ = try await auth.confirmPasswordReset(withCode: "code", newPassword: "password")
      _ = try await auth.checkActionCode("abc")
      _ = try await auth.verifyPasswordResetCode("code")
      _ = try await auth.applyActionCode("code")
      _ = try await auth.sendPasswordReset(withEmail: "email")
      let actionCodeSettings = ActionCodeSettings()
      _ = try await auth.sendPasswordReset(
        withEmail: "email",
        actionCodeSettings: actionCodeSettings
      )
      _ = try await auth.sendSignInLink(toEmail: "email", actionCodeSettings: actionCodeSettings)
    }
  #endif

  func FIRAuthAPNSTokenTypeBuild() {
    _ = AuthAPNSTokenType.unknown
    _ = AuthAPNSTokenType.sandbox
    _ = AuthAPNSTokenType.prod
  }

  func FIRAuthErrorsBuild() {
    _ = AuthErrorCode.invalidCustomToken
    _ = AuthErrorCode.customTokenMismatch
    _ = AuthErrorCode.invalidCredential
    _ = AuthErrorCode.userDisabled
    _ = AuthErrorCode.operationNotAllowed
    _ = AuthErrorCode.emailAlreadyInUse
    _ = AuthErrorCode.invalidEmail
    _ = AuthErrorCode.wrongPassword
    _ = AuthErrorCode.tooManyRequests
    _ = AuthErrorCode.userNotFound
    _ = AuthErrorCode.accountExistsWithDifferentCredential
    _ = AuthErrorCode.requiresRecentLogin
    _ = AuthErrorCode.providerAlreadyLinked
    _ = AuthErrorCode.noSuchProvider
    _ = AuthErrorCode.invalidUserToken
    _ = AuthErrorCode.networkError
    _ = AuthErrorCode.userTokenExpired
    _ = AuthErrorCode.invalidAPIKey
    _ = AuthErrorCode.userMismatch
    _ = AuthErrorCode.credentialAlreadyInUse
    _ = AuthErrorCode.weakPassword
    _ = AuthErrorCode.appNotAuthorized
    _ = AuthErrorCode.expiredActionCode
    _ = AuthErrorCode.invalidActionCode
    _ = AuthErrorCode.invalidMessagePayload
    _ = AuthErrorCode.invalidSender
    _ = AuthErrorCode.invalidRecipientEmail
    _ = AuthErrorCode.missingEmail
    _ = AuthErrorCode.missingIosBundleID
    _ = AuthErrorCode.missingAndroidPackageName
    _ = AuthErrorCode.unauthorizedDomain
    _ = AuthErrorCode.invalidContinueURI
    _ = AuthErrorCode.missingContinueURI
    _ = AuthErrorCode.missingPhoneNumber
    _ = AuthErrorCode.invalidPhoneNumber
    _ = AuthErrorCode.missingVerificationCode
    _ = AuthErrorCode.invalidVerificationCode
    _ = AuthErrorCode.missingVerificationID
    _ = AuthErrorCode.invalidVerificationID
    _ = AuthErrorCode.missingAppCredential
    _ = AuthErrorCode.invalidAppCredential
    _ = AuthErrorCode.sessionExpired
    _ = AuthErrorCode.quotaExceeded
    _ = AuthErrorCode.missingAppToken
    _ = AuthErrorCode.notificationNotForwarded
    _ = AuthErrorCode.appNotVerified
    _ = AuthErrorCode.captchaCheckFailed
    _ = AuthErrorCode.webContextAlreadyPresented
    _ = AuthErrorCode.webContextCancelled
    _ = AuthErrorCode.appVerificationUserInteractionFailure
    _ = AuthErrorCode.invalidClientID
    _ = AuthErrorCode.webNetworkRequestFailed
    _ = AuthErrorCode.webInternalError
    _ = AuthErrorCode.webSignInUserInteractionFailure
    _ = AuthErrorCode.localPlayerNotAuthenticated
    _ = AuthErrorCode.nullUser
    _ = AuthErrorCode.dynamicLinkNotActivated
    _ = AuthErrorCode.invalidProviderID
    _ = AuthErrorCode.tenantIDMismatch
    _ = AuthErrorCode.unsupportedTenantOperation
    _ = AuthErrorCode.invalidDynamicLinkDomain
    _ = AuthErrorCode.rejectedCredential
    _ = AuthErrorCode.gameKitNotLinked
    _ = AuthErrorCode.secondFactorRequired
    _ = AuthErrorCode.missingMultiFactorSession
    _ = AuthErrorCode.missingMultiFactorInfo
    _ = AuthErrorCode.invalidMultiFactorSession
    _ = AuthErrorCode.multiFactorInfoNotFound
    _ = AuthErrorCode.adminRestrictedOperation
    _ = AuthErrorCode.unverifiedEmail
    _ = AuthErrorCode.secondFactorAlreadyEnrolled
    _ = AuthErrorCode.maximumSecondFactorCountExceeded
    _ = AuthErrorCode.unsupportedFirstFactor
    _ = AuthErrorCode.emailChangeNeedsVerification
    _ = AuthErrorCode.missingOrInvalidNonce
    _ = AuthErrorCode.missingClientIdentifier
    _ = AuthErrorCode.keychainError
    _ = AuthErrorCode.internalError
    _ = AuthErrorCode.malformedJWT
  }

  func FIRAuthUIDelegateBuild() {
    class AuthUIImpl: NSObject, AuthUIDelegate {
      func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                   completion: (() -> Void)? = nil) {}

      func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {}
    }
    let obj = AuthUIImpl()
    obj.present(UIViewController(), animated: true) {}
    obj.dismiss(animated: false) {}
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func FIRAuthUIDelegateBuildAsync() async {
      class AuthUIImpl: NSObject, AuthUIDelegate {
        func present(_ viewControllerToPresent: UIViewController, animated flag: Bool) async {}

        func dismiss(animated flag: Bool) async {}
      }
      let obj = AuthUIImpl()
      await obj.present(UIViewController(), animated: true)
      await obj.dismiss(animated: false)
    }
  #endif

  func FIREmailAuthProviderBuild() {
    _ = EmailAuthProvider.credential(withEmail: "e@email.com", password: "password")
    _ = EmailAuthProvider.credential(withEmail: "e@email.com", link: "link")
  }

  func FIRFacebookAuthProviderBuild() {
    _ = FacebookAuthProvider.credential(withAccessToken: "token")
  }

  func FIRFdederatedAuthProviderBuild() {
    class FederatedAuthImplementation: NSObject, FederatedAuthProvider {
      func getCredentialWith(_ UIDelegate: AuthUIDelegate?,
                             completion: ((AuthCredential?, Error?) -> Void)? = nil) {}
    }
    let obj = FederatedAuthImplementation()
    obj.getCredentialWith(nil) { _, _ in
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func FIRFedederatedAuthProviderBuildAsync() async throws {
      class FederatedAuthImplementation: NSObject, FederatedAuthProvider {
        func credential(with UIDelegate: AuthUIDelegate?) async throws -> AuthCredential {
          return FacebookAuthProvider.credential(withAccessToken: "token")
        }
      }
      let obj = FederatedAuthImplementation()
      try await _ = obj.credential(with: nil)
    }
  #endif

  func FIRGameCenterAuthProviderBuild() {
    GameCenterAuthProvider.getCredential { _, _ in
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func FIRGameCenterAuthProviderBuildAsync() async throws {
      _ = try await GameCenterAuthProvider.getCredential()
    }
  #endif

  func FIRGitHubAuthProviderBuild() {
    _ = GitHubAuthProvider.credential(withToken: "token")
  }

  func FIRGoogleAuthProviderBuild() {
    _ = GoogleAuthProvider.credential(withIDToken: "token", accessToken: "aToken")
  }

  func FIRMultiFactorBuild() {
    let obj = MultiFactor()
    obj.getSessionWithCompletion { _, _ in
    }
    obj.enroll(with: MultiFactorAssertion(), displayName: "name") { _ in
    }
    obj.unenroll(with: MultiFactorInfo()) { _ in
    }
    obj.unenroll(withFactorUID: "uid") { _ in
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func FIRMultiFactorBuildAsync() async throws {
      let obj = MultiFactor()
      try await obj.session()
      try await obj.enroll(with: MultiFactorAssertion(), displayName: "name")
      try await obj.unenroll(with: MultiFactorInfo())
      try await obj.unenroll(withFactorUID: "uid")
    }
  #endif

  func FIRMultiFactorResolverBuild() {
    let obj = MultiFactorResolver()
    obj.resolveSignIn(with: MultiFactorAssertion()) { _, _ in
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func FIRMultiFactorResolverBuildAsync() async throws {
      let obj = MultiFactorResolver()
      try await obj.resolveSignIn(with: MultiFactorAssertion())
    }
  #endif

  func FIROAuthProviderBuild() {
    let provider = OAuthProvider(providerID: "id", auth: FirebaseAuth.Auth.auth())
    _ = provider.providerID
    _ = OAuthProvider.credential(withProviderID: "id", idToken: "idToden", accessToken: "token")
    _ = OAuthProvider.credential(withProviderID: "id", accessToken: "token")
    _ = OAuthProvider.credential(withProviderID: "id", idToken: "idToken", rawNonce: "nonce",
                                 accessToken: "token")
    _ = OAuthProvider.credential(withProviderID: "id", idToken: "idToken", rawNonce: "nonce")
  }

  func FIRPhoneAuthProviderBuild() {
    _ = PhoneAuthProvider.provider()
    let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
    provider.verifyPhoneNumber("123", uiDelegate: nil) { _, _ in
    }
    provider.verifyPhoneNumber("123", uiDelegate: nil, multiFactorSession: nil) { _, _ in
    }
    provider.verifyPhoneNumber(
      with: PhoneMultiFactorInfo(),
      uiDelegate: nil,
      multiFactorSession: nil
    ) { _, _ in
    }
    provider.verifyPhoneNumber("123", uiDelegate: nil, multiFactorSession: nil) { _, _ in
    }
    provider.credential(withVerificationID: "id", verificationCode: "code")
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func FIRPhoneAuthProviderBuildAsync() async throws {
      _ = PhoneAuthProvider.provider()
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      try await provider.verifyPhoneNumber("123", uiDelegate: nil)
      try await provider.verifyPhoneNumber("123", uiDelegate: nil, multiFactorSession: nil)
      try await provider.verifyPhoneNumber(with: PhoneMultiFactorInfo(), uiDelegate: nil,
                                           multiFactorSession: nil)
      try await provider.verifyPhoneNumber("123", uiDelegate: nil, multiFactorSession: nil)
    }
  #endif

  func FIRPhoneMultiFactorGeneratorBuild() {
    let credential = PhoneAuthProvider.provider().credential(withVerificationID: "id",
                                                             verificationCode: "code")
    PhoneMultiFactorGenerator.assertion(with: credential)
  }

  func FIRTwitterAuthProviderBuild() {
    _ = TwitterAuthProvider.credential(withToken: "token", secret: "secret")
  }

  func FIRUserBuild() {
    let auth = FirebaseAuth.Auth.auth()
    let user = auth.currentUser!
    let credential = PhoneAuthProvider.provider().credential(withVerificationID: "id",
                                                             verificationCode: "code")
    let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
    user.updateEmail(to: "email") { _ in
    }
    user.updatePassword(to: "password") { _ in
    }
    user.updatePhoneNumber(credential) { _ in
    }
    let changeRequest = user.createProfileChangeRequest()
    user.reload { _ in
    }
    user.reauthenticate(with: credential) { _, _ in
    }
    user.reauthenticate(with: provider as! FederatedAuthProvider, uiDelegate: nil)
    user.getIDTokenResult { _, _ in
    }
    user.getIDTokenResult(forcingRefresh: true) { _, _ in
    }
    user.getIDTokenResult { _, _ in
    }
    user.getIDTokenForcingRefresh(true) { _, _ in
    }
    user.link(with: credential) { _, _ in
    }
    user.link(with: provider as! FederatedAuthProvider, uiDelegate: nil) { _, _ in
    }
    user.unlink(fromProvider: "abc") { _, _ in
    }
    user.sendEmailVerification { _ in
    }
    user.sendEmailVerification(with: ActionCodeSettings()) { _ in
    }
    user.delete { _ in
    }
    user.sendEmailVerification(beforeUpdatingEmail: "email") { _ in
    }
    user.sendEmailVerification(
      beforeUpdatingEmail: "email",
      actionCodeSettings: ActionCodeSettings()
    ) { _ in
    }
    changeRequest.commitChanges { _ in
    }
  }

  #if compiler(>=5.5) && canImport(_Concurrency)
    @available(iOS 15, tvOS 15, macOS 12, watchOS 8, *)
    func FIRUserBuildAsync() async throws {
      let auth = FirebaseAuth.Auth.auth()
      let user = auth.currentUser!
      let credential = PhoneAuthProvider.provider().credential(withVerificationID: "id",
                                                               verificationCode: "code")
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      try await user.updateEmail(to: "email")
      try await user.updatePassword(to: "password")
      try await user.updatePhoneNumber(credential)
      let changeRequest = user.createProfileChangeRequest()
      try await user.reload()
      try await user.reauthenticate(with: credential)
      try await user.reauthenticate(with: provider as! FederatedAuthProvider, uiDelegate: nil)
      try await user.getIDTokenResult()
      try await user.getIDTokenResult(forcingRefresh: true)
      try await user.getIDTokenResult()
      try await user.link(with: credential)
      try await user.link(with: provider as! FederatedAuthProvider, uiDelegate: nil)
      try await user.unlink(fromProvider: "abc")
      try await user.sendEmailVerification()
      try await user.sendEmailVerification(with: ActionCodeSettings())
      try await user.delete()
      try await user.sendEmailVerification(beforeUpdatingEmail: "email")
      try await user.sendEmailVerification(
        beforeUpdatingEmail: "email",
        actionCodeSettings: ActionCodeSettings()
      )
      try await changeRequest.commitChanges()
    }
  #endif
}
