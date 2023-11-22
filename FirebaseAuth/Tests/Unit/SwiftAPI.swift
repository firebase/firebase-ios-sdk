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

#if !os(macOS)
  import UIKit
#endif

/// This file tests public methods and enums. Each function maps to a public header file.

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthAPI_hOnlyTests: XCTestCase {
  // Each function corresponds with a public header.
  func FIRActionCodeSettings_h() {
    let codeSettings = FirebaseAuth.ActionCodeSettings()
    codeSettings.setIOSBundleID("abc")
    codeSettings.setAndroidPackageName("name", installIfNotAvailable: true, minimumVersion: "10.0")
    let _: Bool = codeSettings.handleCodeInApp
    let _: Bool = codeSettings.androidInstallIfNotAvailable
    if let _: URL = codeSettings.url,
       let _: String = codeSettings.iOSBundleID,
       let _: String = codeSettings.androidPackageName,
       let _: String = codeSettings.androidMinimumVersion,
       let _: String = codeSettings.dynamicLinkDomain {}
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func FIRAuthAdditionalUserInfo_h(credential: AuthCredential) async throws {
    let auth = FirebaseAuth.Auth.auth()
    let user = auth.currentUser!
    let authDataResult = try await user.reauthenticate(with: credential)
    let additionalUserInfo = authDataResult.additionalUserInfo!

    let _: String = additionalUserInfo.providerID
    let _: Bool = additionalUserInfo.isNewUser
    if let _: [String: Any] = additionalUserInfo.profile,
       let _: String = additionalUserInfo.username {}
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func ActionCodeOperationTests() async throws {
    let auth = FirebaseAuth.Auth.auth()
    let info = try await auth.checkActionCode("code")
    let _: ActionCodeOperation = info.operation
    if let _: String = info.email,
       let _: String = info.previousEmail {}
  }

  func ActionCodeURL() {
    if let url = FirebaseAuth.ActionCodeURL(link: "string") {
      let _: ActionCodeOperation = url.operation
      if let _: String = url.apiKey,
         let _: String = url.code,
         let _: URL = url.continueURL,
         let _: String = url.languageCode {}
    }
  }

  func authProperties(auth: Auth) {
    let _: Bool = auth.shareAuthStateAcrossDevices
    if let _: FirebaseApp = auth.app,
       let _: User = auth.currentUser,
       let _: String = auth.languageCode,
       let _: AuthSettings = auth.settings,
       let _: String = auth.userAccessGroup,
       let _: String = auth.tenantID,
       let _: String = auth.customAuthDomain
    {}

    #if os(iOS)
      if let _: Data = auth.apnsToken {}
      auth.apnsToken = Data()
    #endif
  }

  func FIRAuth_h(credential: AuthCredential) throws {
    let auth = FirebaseAuth.Auth.auth()
    let user = auth.currentUser!
    auth.updateCurrentUser(user) { _ in
    }
    auth.signIn(withEmail: "abc@abc.com", password: "password") { result, error in
    }
    auth.signIn(withEmail: "abc@abc.com", link: "link") { result, error in
    }
    #if os(iOS)
      let provider = OAuthProvider(providerID: "abc")
      provider.getCredentialWith(nil) { credential, error in
        auth.signIn(with: credential!) { result, error in
        }
      }
      auth.signIn(with: OAuthProvider(providerID: "abc"), uiDelegate: nil) { result, error in
      }
    #endif
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
    _ = auth.isSignIn(withEmailLink: "link")
    let handle = auth.addStateDidChangeListener { auth, user in
    }
    auth.removeStateDidChangeListener(handle)
    _ = auth.addIDTokenDidChangeListener { auth, user in
    }
    auth.removeIDTokenDidChangeListener(handle)
    auth.useAppLanguage()
    auth.useEmulator(withHost: "myHost", port: 123)
    #if os(iOS)
      _ = auth.canHandle(URL(fileURLWithPath: "/my/path"))
      auth.setAPNSToken(Data(), type: AuthAPNSTokenType.prod)
      _ = auth.canHandleNotification([:])
      #if !targetEnvironment(macCatalyst)
        auth.initializeRecaptchaConfig { _ in
        }
      #endif
    #endif
    auth.revokeToken(withAuthorizationCode: "A")
    try auth.useUserAccessGroup("abc")
    let nilUser = try auth.getStoredUser(forAccessGroup: "def")
    // If nilUser is not optional, this will raise a compiler error.
    // This condition does not need to execute, and may not if prior
    // functions throw.
    if let _ = nilUser {
      XCTAssert(true)
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func FIRAuth_hAsync(credential: AuthCredential) async throws {
    let auth = FirebaseAuth.Auth.auth()
    let user = auth.currentUser!
    try await auth.updateCurrentUser(user)
    _ = try await auth.signIn(withEmail: "abc@abc.com", password: "password")
    _ = try await auth.signIn(withEmail: "abc@abc.com", link: "link")
    _ = try await auth.signIn(with: credential)
    #if os(iOS) && !targetEnvironment(macCatalyst)
      try await auth.initializeRecaptchaConfig()
    #endif
    _ = try await auth.signIn(with: OAuthProvider(providerID: "abc"), uiDelegate: nil)
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
    try await auth.revokeToken(withAuthorizationCode: "string")
  }

  #if !os(macOS)
    func FIRAuthAPNSTokenType_h() {
      _ = AuthAPNSTokenType.unknown
      _ = AuthAPNSTokenType.sandbox
      _ = AuthAPNSTokenType.prod
    }
  #endif

  func authCredential(credential: AuthCredential) {
    let _: String = credential.provider
  }

  func authDataResult(result: AuthDataResult) {
    let _: User = result.user
    if let _: AdditionalUserInfo = result.additionalUserInfo,
       let _: AuthCredential = result.credential {}
  }

  func FIRAuthErrors_h() {
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
    _ = AuthErrorCode.recaptchaNotEnabled
    _ = AuthErrorCode.missingRecaptchaToken
    _ = AuthErrorCode.invalidRecaptchaToken
    _ = AuthErrorCode.invalidRecaptchaAction
    _ = AuthErrorCode.missingClientType
    _ = AuthErrorCode.missingRecaptchaVersion
    _ = AuthErrorCode.invalidRecaptchaVersion
    _ = AuthErrorCode.invalidReqType
    _ = AuthErrorCode.keychainError
    _ = AuthErrorCode.internalError
    _ = AuthErrorCode.malformedJWT
  }

  func authSettings(settings: AuthSettings) {
    let _: Bool = settings.isAppVerificationDisabledForTesting
    settings.isAppVerificationDisabledForTesting = true
  }

  func authTokenResult(result: AuthTokenResult) {
    let _: String = result.token
    let _: Date = result.expirationDate
    let _: Date = result.authDate
    let _: Date = result.issuedAtDate
    let _: String = result.signInProvider
    let _: String = result.signInSecondFactor
    let _: [String: Any] = result.claims
  }

  #if !os(macOS) && !os(watchOS)
    func FIRAuthUIDelegate_h() {
      class AuthUIImpl: NSObject, AuthUIDelegate {
        func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                     completion: (() -> Void)? = nil) {}

        func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {}
      }
      let obj = AuthUIImpl()
      obj.present(UIViewController(), animated: true) {}
      obj.dismiss(animated: false) {}
    }
  #endif

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func FIRAuthUIDelegate_hAsync() async {
    class AuthUIImpl: NSObject, AuthUIDelegate {
      func present(_ viewControllerToPresent: UIViewController, animated flag: Bool) async {}

      func dismiss(animated flag: Bool) async {}
    }
    let obj = AuthUIImpl()
    await obj.present(UIViewController(), animated: true)
    await obj.dismiss(animated: false)
  }

  func FIREmailAuthProvider_h() {
    _ = EmailAuthProvider.credential(withEmail: "e@email.com", password: "password")
    _ = EmailAuthProvider.credential(withEmail: "e@email.com", link: "link")
  }

  func FIRFacebookAuthProvider_h() {
    _ = FacebookAuthProvider.credential(withAccessToken: "token")
  }

  #if os(iOS)
    func FIRFederatedAuthProvider_h() {
      class FederatedAuthImplementation: NSObject, FederatedAuthProvider {
        func getCredentialWith(_ UIDelegate: AuthUIDelegate?,
                               completion: ((AuthCredential?, Error?) -> Void)? = nil) {}
      }
      let obj = FederatedAuthImplementation()
      obj.getCredentialWith(nil) { _, _ in
      }
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    func FIRFedederatedAuthProvider_hAsync() async throws {
      class FederatedAuthImplementation: NSObject, FederatedAuthProvider {
        func credential(with UIDelegate: AuthUIDelegate?) async throws -> AuthCredential {
          return FacebookAuthProvider.credential(withAccessToken: "token")
        }
      }
      let obj = FederatedAuthImplementation()
      try await _ = obj.credential(with: nil)
    }
  #endif

  #if !os(watchOS)
    func FIRGameCenterAuthProvider_h() {
      GameCenterAuthProvider.getCredential { _, _ in
      }
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    func FIRGameCenterAuthProvider_hAsync() async throws {
      _ = try await GameCenterAuthProvider.getCredential()
    }
  #endif

  func FIRGitHubAuthProvider_h() {
    _ = GitHubAuthProvider.credential(withToken: "token")
  }

  func FIRGoogleAuthProvider_h() {
    _ = GoogleAuthProvider.credential(withIDToken: "token", accessToken: "aToken")
  }

  #if os(iOS)
    func FIRMultiFactor_h(obj: MultiFactor) {
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      let credential = provider.credential(withVerificationID: "id",
                                           verificationCode: "code")
      obj.getSessionWithCompletion { _, _ in
      }
      obj
        .enroll(with: PhoneMultiFactorGenerator.assertion(with: credential),
                displayName: "name") { _ in
        }
      let mfi = obj.enrolledFactors[0]
      obj.unenroll(with: mfi) { _ in
      }
      obj.unenroll(withFactorUID: "uid") { _ in
      }
      let _: [MultiFactorInfo] = obj.enrolledFactors
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    func FIRMultiFactor_hAsync(obj: MultiFactor) async throws {
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      let credential = provider.credential(withVerificationID: "id",
                                           verificationCode: "code")
      _ = try await obj.session()
      try await obj.enroll(
        with: PhoneMultiFactorGenerator.assertion(with: credential),
        displayName: "name"
      )
      let mfi = obj.enrolledFactors[0]
      try await obj.unenroll(with: mfi)
      try await obj.unenroll(withFactorUID: "uid")
    }

    func multiFactorAssertion(assertion: MultiFactorAssertion) {
      let _: String = assertion.factorID
    }

    func multiFactorInfo(mfi: MultiFactorInfo) {
      let _: String = mfi.uid
      let _: Date = mfi.enrollmentDate
      let _: String = mfi.factorID
      if let _: String = mfi.displayName {}
    }

    func FIRMultiFactorResolver_h(error: NSError) {
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      let credential = provider.credential(withVerificationID: "id",
                                           verificationCode: "code")
      if let obj = error
        .userInfo[AuthErrorUserInfoMultiFactorResolverKey] as? MultiFactorResolver {
        obj.resolveSignIn(with: PhoneMultiFactorGenerator.assertion(with: credential)) { _, _ in
        }
        let _: MultiFactorSession = obj.session
        let _: [MultiFactorInfo] = obj.hints
        let _: Auth = obj.auth
      }
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    func FIRMultiFactorResolver_hAsync(error: NSError) async throws {
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      let credential = provider.credential(withVerificationID: "id",
                                           verificationCode: "code")
      if let obj = error
        .userInfo[AuthErrorUserInfoMultiFactorResolverKey] as? MultiFactorResolver {
        _ = try await obj.resolveSignIn(with: PhoneMultiFactorGenerator.assertion(with: credential))
      }
    }
  #endif

  func oauthCredential(credential: OAuthCredential) {
    if let _: String = credential.idToken,
       let _: String = credential.accessToken,
       let _: String = credential.secret {}
  }

  func FIROAuthProvider_h() {
    let provider = OAuthProvider(providerID: "id", auth: FirebaseAuth.Auth.auth())
    _ = provider.providerID
    #if os(iOS)
      _ = OAuthProvider.credential(withProviderID: "id", idToken: "idToden", accessToken: "token")
      _ = OAuthProvider.credential(withProviderID: "id", accessToken: "token")
      _ = OAuthProvider.credential(withProviderID: "id", idToken: "idToken", rawNonce: "nonce",
                                   accessToken: "token")
      _ = OAuthProvider.credential(withProviderID: "id", idToken: "idToken", rawNonce: "nonce")
      _ = OAuthProvider.appleCredential(withIDToken: "idToken",
                                        rawNonce: "nonce",
                                        fullName: nil)
      provider.getCredentialWith(provider as? AuthUIDelegate) { credential, error in
      }
    #endif
    let _: String = provider.providerID
    if let _: [String] = provider.scopes,
       let _: [String: String] = provider.customParameters {}
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func FIROAuthProvider_h() async throws {
    let provider = OAuthProvider(providerID: "abc")
    #if os(iOS)
      provider.getCredentialWith(provider as? AuthUIDelegate) { credential, error in
      }
      _ = try await provider.credential(with: provider as? AuthUIDelegate)
    #endif
  }

  #if os(iOS)
    func FIRPhoneAuthProvider_h(mfi: PhoneMultiFactorInfo) {
      _ = PhoneAuthProvider.provider()
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      provider.verifyPhoneNumber("123", uiDelegate: nil) { _, _ in
      }
      provider.verifyPhoneNumber("123", uiDelegate: nil, multiFactorSession: nil) { _, _ in
      }
      provider.verifyPhoneNumber(
        with: mfi,
        uiDelegate: nil,
        multiFactorSession: nil
      ) { _, _ in
      }
      _ = provider.credential(withVerificationID: "id", verificationCode: "code")
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    func FIRPhoneAuthProvider_hAsync(mfi: PhoneMultiFactorInfo) async throws {
      _ = PhoneAuthProvider.provider()
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      _ = try await provider.verifyPhoneNumber("123", uiDelegate: nil)
      _ = try await provider.verifyPhoneNumber("123", uiDelegate: nil, multiFactorSession: nil)
      _ = try await provider.verifyPhoneNumber(with: mfi, uiDelegate: nil,
                                               multiFactorSession: nil)
      _ = try await provider.verifyPhoneNumber("123", uiDelegate: nil, multiFactorSession: nil)
    }

    func FIRPhoneMultiFactorGenerator_h() {
      let credential = PhoneAuthProvider.provider().credential(withVerificationID: "id",
                                                               verificationCode: "code")
      _ = PhoneMultiFactorGenerator.assertion(with: credential)
    }

    func phoneMultiFactorInfo(mfi: PhoneMultiFactorInfo) {
      let _: String = mfi.phoneNumber
    }

    func FIRTOTPSecret_h(session: MultiFactorSession) async throws {
      let obj = try await TOTPMultiFactorGenerator.generateSecret(with: session)
      _ = obj.sharedSecretKey()
      _ = obj.generateQRCodeURL(withAccountName: "name", issuer: "issuer")
      obj.openInOTPApp(withQRCodeURL: "url")
    }

    func FIRTOTPMultiFactorGenerator_h(session: MultiFactorSession, secret: TOTPSecret) {
      TOTPMultiFactorGenerator.generateSecret(with: session) { _, _ in
      }
      _ = TOTPMultiFactorGenerator.assertionForEnrollment(with: secret,
                                                          oneTimePassword: "code")
      _ = TOTPMultiFactorGenerator.assertionForSignIn(
        withEnrollmentID: "id", oneTimePassword: "code"
      )
    }

    @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
    func FIRTOTPMultiFactorGenerator_hAsync(session: MultiFactorSession) async throws {
      _ = try await TOTPMultiFactorGenerator.generateSecret(with: session)
    }
  #endif

  func FIRTwitterAuthProvider_h() {
    _ = TwitterAuthProvider.credential(withToken: "token", secret: "secret")
  }

  func FIRUser_h() {
    let auth = FirebaseAuth.Auth.auth()
    let user = auth.currentUser!
    let credential = GoogleAuthProvider.credential(withIDToken: "token", accessToken: "aToken")
    user.updatePassword(to: "password") { _ in
    }
    let changeRequest = user.createProfileChangeRequest()
    user.reload { _ in
    }
    user.reauthenticate(with: credential) { _, _ in
    }
    #if os(iOS)
      let phoneCredential = PhoneAuthProvider.provider().credential(withVerificationID: "id",
                                                                    verificationCode: "code")
      user.updatePhoneNumber(phoneCredential) { _ in
      }
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      user.reauthenticate(with: provider as! FederatedAuthProvider, uiDelegate: nil)
      user.link(with: provider as! FederatedAuthProvider, uiDelegate: nil) { _, _ in
      }
    #endif
    user.getIDTokenResult { _, _ in
    }
    user.getIDTokenResult(forcingRefresh: true) { _, _ in
    }
    user.getIDToken { _, _ in
    }
    user.getIDTokenForcingRefresh(true) { _, _ in
    }
    user.link(with: credential) { _, _ in
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
    let _: String = user.providerID
    let _: String = user.uid
    if let _: String = user.displayName,
       let _: URL = user.photoURL,
       let _: String = user.email,
       let _: String = user.phoneNumber {}
  }

  func userProperties(user: User) {
    let changeRequest = user.createProfileChangeRequest()
    let _: Bool = user.isAnonymous
    let _: Bool = user.isEmailVerified
    let _: [UserInfo] = user.providerData
    let _: UserMetadata = user.metadata
    #if os(iOS)
      let _: MultiFactor = user.multiFactor
    #endif
    if let _: String = user.refreshToken,
       let _: String = user.tenantID,
       let _: String = changeRequest.displayName,
       let _: URL = changeRequest.photoURL {}
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  func FIRUser_hAsync() async throws {
    let auth = FirebaseAuth.Auth.auth()
    let user = auth.currentUser!
    let credential = GoogleAuthProvider.credential(withIDToken: "token", accessToken: "aToken")
    try await user.updatePassword(to: "password")
    let changeRequest = user.createProfileChangeRequest()
    try await user.reload()
    try await user.reauthenticate(with: credential)
    #if os(iOS)
      let phoneCredential = PhoneAuthProvider.provider().credential(withVerificationID: "id",
                                                                    verificationCode: "code")
      try await user.updatePhoneNumber(phoneCredential)
      let provider = PhoneAuthProvider.provider(auth: FirebaseAuth.Auth.auth())
      try await user.reauthenticate(with: provider as! FederatedAuthProvider, uiDelegate: nil)
      try await user.link(with: provider as! FederatedAuthProvider, uiDelegate: nil)
    #endif
    _ = try await user.getIDTokenResult()
    _ = try await user.getIDTokenResult(forcingRefresh: true)
    _ = try await user.getIDToken()
    _ = try await user.link(with: credential)
    _ = try await user.unlink(fromProvider: "abc")
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

  func userInfoProperties(userInfo: UserInfo) {
    let _: String = userInfo.providerID
    let _: String = userInfo.uid
    if let _: String = userInfo.displayName,
       let _: URL = userInfo.photoURL,
       let _: String = userInfo.email,
       let _: String = userInfo.phoneNumber {}
  }

  func userMetadataProperties(metadata: UserMetadata) {
    if let _: Date = metadata.lastSignInDate,
       let _: Date = metadata.creationDate {}
  }
}
