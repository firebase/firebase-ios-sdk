// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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
import XCTest

@testable import FirebaseAuth

import FirebaseCore

class AuthTests: RPCBaseTests {
  static let kAccessToken = "TEST_ACCESS_TOKEN"
  static let kNewAccessToken = "NEW_ACCESS_TOKEN"
  static let kFakeAPIKey = "FAKE_API_KEY"
  var auth: Auth!
  static var testNum = 0
  var authDispatcherCallback: (() -> Void)?

  override func setUp() {
    super.setUp()
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = AuthTests.kFakeAPIKey
    options.projectID = "myProjectID"
    let name = "test-AuthTests\(AuthTests.testNum)"
    AuthTests.testNum = AuthTests.testNum + 1
    FirebaseApp.configure(name: name, options: options)
    #if os(macOS) && !FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN
      let keychainStorageProvider = FakeAuthKeychainServices.self
    #else
      let keychainStorageProvider = AuthKeychainServices.self
    #endif // os(macOS) && !FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN
    auth = Auth(
      app: FirebaseApp.app(name: name)!,
      keychainStorageProvider: keychainStorageProvider
    )

    // Set authDispatcherCallback implementation in order to save the token refresh task for later
    // execution.
    AuthDispatcher.shared.dispatchAfterImplementation = { delay, queue, task in
      XCTAssertNotNil(task)
      XCTAssertGreaterThan(delay, 0)
      XCTAssertEqual(kAuthGlobalWorkQueue, queue)
      self.authDispatcherCallback = task
    }
    // Wait until Auth initialization completes
    waitForAuthGlobalWorkQueueDrain()
  }

  private func waitForAuthGlobalWorkQueueDrain() {
    let workerSemaphore = DispatchSemaphore(value: 0)
    kAuthGlobalWorkQueue.async {
      workerSemaphore.signal()
    }
    _ = workerSemaphore.wait(timeout: DispatchTime.distantFuture)
  }

  /** @fn testFetchSignInMethodsForEmailSuccess
      @brief Tests the flow of a successful @c fetchSignInMethodsForEmail:completion: call.
   */
  func testFetchSignInMethodsForEmailSuccess() throws {
    let allSignInMethods = ["emailLink", "facebook.com"]
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer in `fetchSignInMethods`.
    let group = createGroup()

    auth?.fetchSignInMethods(forEmail: kEmail) { signInMethods, error in
      // 4. After the response triggers the callback, verify the returned signInMethods.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(signInMethods, allSignInMethods)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? CreateAuthURIRequest)
    XCTAssertEqual(request.identifier, kEmail)
    XCTAssertEqual(request.endpoint, "createAuthUri")
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["signinMethods": allSignInMethods])

    waitForExpectations(timeout: 5)
  }

  /** @fn testFetchSignInMethodsForEmailFailure
      @brief Tests the flow of a failed @c fetchSignInMethodsForEmail:completion: call.
   */
  func testFetchSignInMethodsForEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    let group = createGroup()

    auth?.fetchSignInMethods(forEmail: kEmail) { signInMethods, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(signInMethods)
      let rpcError = (error as? NSError)!
      XCTAssertEqual(rpcError.code, AuthErrorCode.tooManyRequests.rawValue)
      expectation.fulfill()
    }
    group.wait()

    let message = "TOO_MANY_ATTEMPTS_TRY_LATER"
    try rpcIssuer?.respond(serverErrorMessage: message)

    waitForExpectations(timeout: 5)
  }

  #if os(iOS)
    /** @fn testPhoneAuthSuccess
        @brief Tests the flow of a successful @c signInWithCredential:completion for phone auth.
     */
    func testPhoneAuthSuccess() throws {
      let kVerificationID = "55432"
      let kVerificationCode = "12345678"
      let expectation = self.expectation(description: #function)
      setFakeGetAccountProvider()
      setFakeSecureTokenService()

      // 1. Create a group to synchronize request creation by the fake rpcIssuer.
      let group = createGroup()

      try auth?.signOut()
      let credential = PhoneAuthProvider.provider(auth: auth)
        .credential(withVerificationID: kVerificationID,
                    verificationCode: kVerificationCode)
      auth?.signIn(with: credential) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        guard let user = authResult?.user,
              let additionalUserInfo = authResult?.additionalUserInfo else {
          XCTFail("authResult.user or additionalUserInfo is missing")
          return
        }
        XCTAssertEqual(user.refreshToken, self.kRefreshToken)
        XCTAssertFalse(user.isAnonymous)
        XCTAssertTrue(additionalUserInfo.isNewUser)
        XCTAssertNil(error)
        expectation.fulfill()
      }
      group.wait()

      // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
      let request = try XCTUnwrap(rpcIssuer?.request as? VerifyPhoneNumberRequest)
      XCTAssertEqual(request.verificationCode, kVerificationCode)
      XCTAssertEqual(request.verificationID, kVerificationID)

      // 3. Send the response from the fake backend.
      try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                        "isNewUser": true,
                                        "refreshToken": kRefreshToken])

      waitForExpectations(timeout: 5)
      assertUser(auth?.currentUser)
    }

    /** @fn testPhoneAuthMissingVerificationCode
        @brief Tests the flow of an unsuccessful @c signInWithCredential:completion for phone auth due
            to an empty verification code
     */
    func testPhoneAuthMissingVerificationCode() throws {
      let kVerificationID = "55432"
      let kVerificationCode = ""
      let expectation = self.expectation(description: #function)
      setFakeGetAccountProvider()
      setFakeSecureTokenService()

      try auth?.signOut()
      let credential = PhoneAuthProvider.provider(auth: auth)
        .credential(withVerificationID: kVerificationID,
                    verificationCode: kVerificationCode)
      auth?.signIn(with: credential) { authResult, error in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(authResult)
        XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.missingVerificationCode.rawValue)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testPhoneAuthMissingVerificationID
        @brief Tests the flow of an unsuccessful @c signInWithCredential:completion for phone auth due
            to an empty verification ID.
     */
    func testPhoneAuthMissingVerificationID() throws {
      let kVerificationID = ""
      let kVerificationCode = "123"
      let expectation = self.expectation(description: #function)
      setFakeGetAccountProvider()
      setFakeSecureTokenService()

      try auth?.signOut()
      let credential = PhoneAuthProvider.provider(auth: auth)
        .credential(withVerificationID: kVerificationID,
                    verificationCode: kVerificationCode)
      auth?.signIn(with: credential) { authResult, error in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(authResult)
        XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.missingVerificationID.rawValue)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  #endif

  /** @fn testSignInWithEmailLinkSuccess
      @brief Tests the flow of a successful @c signInWithEmail:link:completion: call.
   */
  func testSignInWithEmailLinkSuccess() throws {
    try signInWithEmailLinkSuccessWithLinkOrDeeplink(link: kFakeEmailSignInLink)
  }

  /** @fn testSignInWithEmailLinkSuccessDeeplink
      @brief Tests the flow of a successful @c signInWithEmail:link: call using a deep link.
   */
  func testSignInWithEmailLinkSuccessDeeplink() throws {
    try signInWithEmailLinkSuccessWithLinkOrDeeplink(link: kFakeEmailSignInDeeplink)
  }

  private func signInWithEmailLinkSuccessWithLinkOrDeeplink(link: String) throws {
    let fakeCode = "testoobcode"
    let expectation = self.expectation(description: #function)
    setFakeGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.signIn(withEmail: kEmail, link: link) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      guard let user = authResult?.user else {
        XCTFail("authResult.user is missing")
        return
      }
      XCTAssertEqual(user.refreshToken, self.kRefreshToken)
      XCTAssertFalse(user.isAnonymous)
      XCTAssertEqual(user.email, self.kEmail)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? EmailLinkSignInRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.oobCode, fakeCode)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])

    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  /** @fn testSignInWithEmailLinkFailure
      @brief Tests the flow of a failed @c signInWithEmail:link:completion: call.
   */
  func testSignInWithEmailLinkFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.signIn(withEmail: kEmail, link: kFakeEmailSignInLink) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "INVALID_OOB_CODE")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testSignInAndRetrieveDataWithEmailPasswordSuccess
      @brief Tests the flow of a successful @c signInAndRetrieveDataWithEmail:password:completion:
          call. Superset of historical testSignInWithEmailPasswordSuccess.
   */
  func testSignInAndRetrieveDataWithEmailPasswordSuccess() throws {
    let kRefreshToken = "fakeRefreshToken"
    let expectation = self.expectation(description: #function)
    setFakeGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      guard let user = authResult?.user else {
        XCTFail("authResult.user is missing")
        return
      }
      XCTAssertEqual(user.refreshToken, kRefreshToken)
      XCTAssertFalse(user.isAnonymous)
      XCTAssertEqual(user.email, self.kEmail)
      guard let additionalUserInfo = authResult?.additionalUserInfo else {
        XCTFail("authResult.additionalUserInfo is missing")
        return
      }
      XCTAssertFalse(additionalUserInfo.isNewUser)
      XCTAssertEqual(additionalUserInfo.providerID, EmailAuthProvider.id)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? VerifyPasswordRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.password, kFakePassword)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])

    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  /** @fn testSignInWithEmailPasswordFailure
      @brief Tests the flow of a failed @c signInWithEmail:password:completion: call.
   */
  func testSignInWithEmailPasswordFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.wrongPassword.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "INVALID_PASSWORD")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testResetPasswordSuccess
      @brief Tests the flow of a successful @c confirmPasswordResetWithCode:newPassword:completion:
          call.
   */
  func testResetPasswordSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?
      .confirmPasswordReset(withCode: kFakeOobCode, newPassword: kFakePassword) { error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        expectation.fulfill()
      }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? ResetPasswordRequest)
    XCTAssertEqual(request.oobCode, kFakeOobCode)
    XCTAssertEqual(request.updatedPassword, kFakePassword)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: [:])

    waitForExpectations(timeout: 5)
  }

  /** @fn testResetPasswordFailure
      @brief Tests the flow of a failed @c confirmPasswordResetWithCode:newPassword:completion:
          call.
   */
  func testResetPasswordFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?
      .confirmPasswordReset(withCode: kFakeOobCode, newPassword: kFakePassword) { error in
        // 3. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
        XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
        expectation.fulfill()
      }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "INVALID_OOB_CODE")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testCheckActionCodeSuccess
      @brief Tests the flow of a successful @c checkActionCode:completion call.
   */
  func testCheckActionCodeSuccess() throws {
    let kNewEmail = "newEmail@example.com"
    let verifyEmailRequestType = "VERIFY_EMAIL"
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.checkActionCode(kFakeOobCode) { info, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      XCTAssertEqual(info?.email, kNewEmail)
      XCTAssertEqual(info?.operation, ActionCodeOperation.verifyEmail)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? ResetPasswordRequest)
    XCTAssertEqual(request.oobCode, kFakeOobCode)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["email": kEmail,
                                      "requestType": verifyEmailRequestType,
                                      "newEmail": kNewEmail])
    waitForExpectations(timeout: 5)
  }

  /** @fn testCheckActionCodeFailure
      @brief Tests the flow of a failed @c checkActionCode:completion call.
   */
  func testCheckActionCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.checkActionCode(kFakeOobCode) { info, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.expiredActionCode.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "EXPIRED_OOB_CODE")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testApplyActionCodeSuccess
      @brief Tests the flow of a successful @c applyActionCode:completion call.
   */
  func testApplyActionCodeSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.applyActionCode(kFakeOobCode) { error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? SetAccountInfoRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: [:])
    waitForExpectations(timeout: 5)
  }

  /** @fn testApplyActionCodeFailure
      @brief Tests the flow of a failed @c checkActionCode:completion call.
   */
  func testApplyActionCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.applyActionCode(kFakeOobCode) { error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "INVALID_OOB_CODE")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testVerifyPasswordResetCodeSuccess
      @brief Tests the flow of a successful @c verifyPasswordResetCode:completion call.
   */
  func testVerifyPasswordResetCodeSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(email, self.kEmail)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? ResetPasswordRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.oobCode, kFakeOobCode)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["email": kEmail])
    waitForExpectations(timeout: 5)
  }

  /** @fn testVerifyPasswordResetCodeFailure
      @brief Tests the flow of a failed @c verifyPasswordResetCode:completion call.
   */
  func testVerifyPasswordResetCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(email)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "INVALID_OOB_CODE")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testSignInWithEmailLinkCredentialSuccess
      @brief Tests the flow of a successfully @c signInWithCredential:completion: call with an
          email sign-in link credential using FIREmailAuthProvider.
   */
  func testSignInWithEmailLinkCredentialSuccess() throws {
    let expectation = self.expectation(description: #function)
    let fakeCode = "testoobcode"
    setFakeGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    let emailCredential = EmailAuthProvider.credential(
      withEmail: kEmail,
      link: kFakeEmailSignInLink
    )
    auth?.signIn(with: emailCredential) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      guard let user = authResult?.user else {
        XCTFail("authResult.user or additionalUserInfo is missing")
        return
      }
      XCTAssertEqual(user.refreshToken, self.kRefreshToken)
      XCTAssertFalse(user.isAnonymous)
      XCTAssertEqual(user.email, self.kEmail)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? EmailLinkSignInRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.oobCode, fakeCode)
    XCTAssertEqual(request.email, kEmail)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])
    waitForExpectations(timeout: 5)
  }

  /** @fn testSignInWithEmailLinkCredentialFailure
      @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
          email-email sign-in link credential using FIREmailAuthProvider.
   */
  func testSignInWithEmailLinkCredentialFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    let emailCredential = EmailAuthProvider.credential(
      withEmail: kEmail,
      link: kFakeEmailSignInLink
    )
    auth?.signIn(with: emailCredential) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.userDisabled.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "USER_DISABLED")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testSignInWithEmailCredentialSuccess
      @brief Tests the flow of a successfully @c signInWithCredential:completion: call with an
          email-password credential.
   */
  func testSignInWithEmailCredentialSuccess() throws {
    let expectation = self.expectation(description: #function)
    setFakeGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    let emailCredential = EmailAuthProvider.credential(withEmail: kEmail, password: kFakePassword)
    auth?.signIn(with: emailCredential) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      guard let user = authResult?.user else {
        XCTFail("authResult.user or additionalUserInfo is missing")
        return
      }
      XCTAssertEqual(user.refreshToken, self.kRefreshToken)
      XCTAssertFalse(user.isAnonymous)
      XCTAssertEqual(user.email, self.kEmail)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? VerifyPasswordRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.password, kFakePassword)
    XCTAssertEqual(request.email, kEmail)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])
    waitForExpectations(timeout: 5)
  }

  /** @fn testSignInWithEmailCredentialFailure
      @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
          email-password credential.
   */
  func testSignInWithEmailCredentialFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    let emailCredential = EmailAuthProvider.credential(withEmail: kEmail, password: kFakePassword)
    auth?.signIn(with: emailCredential) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.userDisabled.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "USER_DISABLED")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testSignInWithEmailCredentialEmptyPassword
      @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
          email-password credential using an empty password. This error occurs on the client side,
          so there is no need to fake an RPC response.
   */
  func testSignInWithEmailCredentialEmptyPassword() throws {
    let expectation = self.expectation(description: #function)
    let emailCredential = EmailAuthProvider.credential(withEmail: kEmail, password: "")
    auth?.signIn(with: emailCredential) { authResult, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.wrongPassword.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  #if os(iOS)
    class FakeProvider: NSObject, FederatedAuthProvider {
      @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
      func credential(with UIDelegate: FirebaseAuth.AuthUIDelegate?) async throws ->
        FirebaseAuth.AuthCredential {
        fatalError("Should not use this async method yet")
      }

      func getCredentialWith(_ UIDelegate: FirebaseAuth.AuthUIDelegate?,
                             completion: ((FirebaseAuth.AuthCredential?, Error?) -> Void)?) {
        let credential = OAuthCredential(withProviderID: GoogleAuthProvider.id,
                                         sessionID: kOAuthSessionID,
                                         OAuthResponseURLString: kOAuthRequestURI)
        XCTAssertEqual(credential.OAuthResponseURLString, kOAuthRequestURI)
        XCTAssertEqual(credential.sessionID, kOAuthSessionID)
        completion?(credential, nil)
      }
    }

    /** @fn testSignInWithProviderSuccess
        @brief Tests a successful @c signInWithProvider:UIDelegate:completion: call with an OAuth
            provider configured for Google.
     */
    func testSignInWithProviderSuccess() throws {
      let expectation = self.expectation(description: #function)
      setFakeGoogleGetAccountProvider()
      setFakeSecureTokenService()

      // 1. Create a group to synchronize request creation by the fake rpcIssuer.
      let group = createGroup()

      try auth.signOut()
      auth.signIn(with: FakeProvider(), uiDelegate: nil) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        do {
          try self.assertUserGoogle(authResult?.user)
        } catch {
          XCTFail("\(error)")
        }
        XCTAssertNil(error)
        expectation.fulfill()
      }
      group.wait()

      // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
      let request = try XCTUnwrap(rpcIssuer?.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                        "refreshToken": kRefreshToken,
                                        "federatedId": kGoogleID,
                                        "providerId": GoogleAuthProvider.id,
                                        "localId": kLocalID,
                                        "displayName": kDisplayName,
                                        "rawUserInfo": kGoogleProfile,
                                        "username": kUserName])
      waitForExpectations(timeout: 5)
      try assertUserGoogle(auth.currentUser)
    }

    /** @fn testSignInWithProviderFailure
        @brief Tests a failed @c signInWithProvider:UIDelegate:completion: call with the error code
            FIRAuthErrorCodeWebSignInUserInteractionFailure.
     */
    func testSignInWithProviderFailure() throws {
      let expectation = self.expectation(description: #function)
      setFakeGoogleGetAccountProvider()
      setFakeSecureTokenService()

      // 1. Create a group to synchronize request creation by the fake rpcIssuer.
      let group = createGroup()

      try auth.signOut()
      auth.signIn(with: FakeProvider(), uiDelegate: nil) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(authResult)
        XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.userDisabled.rawValue)
        expectation.fulfill()
      }
      group.wait()

      // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
      let request = try XCTUnwrap(rpcIssuer?.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try rpcIssuer?.respond(serverErrorMessage: "USER_DISABLED")
      waitForExpectations(timeout: 5)
    }

    /** @fn testSignInWithGoogleAccountExistsError
        @brief Tests the flow of a failed @c signInWithCredential:completion: with a Google credential
            where the backend returns a needs @needConfirmation equal to true. An
            FIRAuthErrorCodeAccountExistsWithDifferentCredential error should be thrown.
     */
    func testSignInWithGoogleAccountExistsError() throws {
      let expectation = self.expectation(description: #function)
      setFakeGoogleGetAccountProvider()
      setFakeSecureTokenService()

      // 1. Create a group to synchronize request creation by the fake rpcIssuer.
      let group = createGroup()

      try auth.signOut()
      let googleCredential = GoogleAuthProvider.credential(withIDToken: kGoogleIDToken,
                                                           accessToken: kGoogleAccessToken)
      auth.signIn(with: googleCredential) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(authResult)
        XCTAssertEqual((error as? NSError)?.code,
                       AuthErrorCode.accountExistsWithDifferentCredential.rawValue)
        expectation.fulfill()
      }
      group.wait()

      // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
      let request = try XCTUnwrap(rpcIssuer?.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertEqual(request.providerIDToken, kGoogleIDToken)
      XCTAssertEqual(request.providerAccessToken, kGoogleAccessToken)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                        "refreshToken": kRefreshToken,
                                        "federatedId": kGoogleID,
                                        "providerId": GoogleAuthProvider.id,
                                        "localId": kLocalID,
                                        "displayName": kGoogleDisplayName,
                                        "rawUserInfo": kGoogleProfile,
                                        "username": kUserName,
                                        "needConfirmation": true])
      waitForExpectations(timeout: 5)
    }

    /** @fn testSignInWithOAuthCredentialSuccess
        @brief Tests the flow of a successful @c signInWithCredential:completion: call with a generic
            OAuth credential (In this case, configured for the Google IDP).
     */
    func testSignInWithOAuthCredentialSuccess() throws {
      let expectation = self.expectation(description: #function)
      setFakeGoogleGetAccountProvider()
      setFakeSecureTokenService()

      // 1. Create a group to synchronize request creation by the fake rpcIssuer.
      let group = createGroup()

      try auth.signOut()
      auth.signIn(with: FakeProvider(), uiDelegate: nil) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        do {
          try self.assertUserGoogle(authResult?.user)
        } catch {
          XCTFail("\(error)")
        }
        XCTAssertNil(error)
        expectation.fulfill()
      }
      group.wait()

      // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
      let request = try XCTUnwrap(rpcIssuer?.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertEqual(request.requestURI, AuthTests.kOAuthRequestURI)
      XCTAssertEqual(request.sessionID, AuthTests.kOAuthSessionID)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                        "refreshToken": kRefreshToken,
                                        "federatedId": kGoogleID,
                                        "providerId": GoogleAuthProvider.id,
                                        "localId": kLocalID,
                                        "displayName": kGoogleDisplayName,
                                        "rawUserInfo": kGoogleProfile,
                                        "username": kUserName])
      waitForExpectations(timeout: 5)
      try assertUserGoogle(auth.currentUser)
    }
  #endif

  /** @fn testSignInWithCredentialSuccess
      @brief Tests the flow of a successful @c signInWithCredential:completion: call
          with an Google Sign-In credential.
      Note: also a superset of the former testSignInWithGoogleCredentialSuccess
   */
  func testSignInWithCredentialSuccess() throws {
    let expectation = self.expectation(description: #function)
    setFakeGoogleGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth.signOut()
    let googleCredential = GoogleAuthProvider.credential(withIDToken: kGoogleIDToken,
                                                         accessToken: kGoogleAccessToken)
    auth.signIn(with: googleCredential) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      do {
        try self.assertUserGoogle(authResult?.user)
        guard let additionalUserInfo = authResult?.additionalUserInfo,
              let profile = additionalUserInfo.profile as? [String: String] else {
          XCTFail("authResult.additionalUserInfo is missing")
          return
        }
        XCTAssertEqual(profile, self.kGoogleProfile)
        XCTAssertEqual(additionalUserInfo.username, self.kGoogleDisplayName)
        XCTAssertEqual(additionalUserInfo.providerID, GoogleAuthProvider.id)
      } catch {
        XCTFail("\(error)")
      }
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? VerifyAssertionRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
    XCTAssertEqual(request.providerIDToken, kGoogleIDToken)
    XCTAssertEqual(request.providerAccessToken, kGoogleAccessToken)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                      "refreshToken": kRefreshToken,
                                      "federatedId": kGoogleID,
                                      "providerId": GoogleAuthProvider.id,
                                      "localId": kLocalID,
                                      "displayName": kGoogleDisplayName,
                                      "rawUserInfo": kGoogleProfile,
                                      "username": kGoogleDisplayName])
    waitForExpectations(timeout: 5)
    try assertUserGoogle(auth.currentUser)
  }

  /** @fn testSignInWithGoogleCredentialFailure
      @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
          Google Sign-In credential.
   */
  func testSignInWithGoogleCredentialFailure() throws {
    let expectation = self.expectation(description: #function)
    setFakeGoogleGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth.signOut()
    let googleCredential = GoogleAuthProvider.credential(withIDToken: kGoogleIDToken,
                                                         accessToken: kGoogleAccessToken)
    auth.signIn(with: googleCredential) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.emailAlreadyInUse.rawValue)
      XCTAssertEqual((error as? NSError)?.userInfo[NSLocalizedDescriptionKey] as? String,
                     "The email address is already in use by another account.")
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? VerifyAssertionRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "EMAIL_EXISTS")
    waitForExpectations(timeout: 5)
  }

  /** @fn testSignInWithAppleCredentialFullNameInRequest
      @brief Tests the flow of a successful @c signInWithCredential:completion: call
          with an Apple Sign-In credential with a full name. This test differentiates from
          @c testSignInWithCredentialSuccess only in verifying the full name.
   */
  func testSignInWithAppleCredentialFullNameInRequest() throws {
    let expectation = self.expectation(description: #function)
    let kAppleIDToken = "APPLE_ID_TOKEN"
    let kFirst = "First"
    let kLast = "Last"
    var fullName = PersonNameComponents()
    fullName.givenName = kFirst
    fullName.familyName = kLast
    setFakeGoogleGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth.signOut()
    let appleCredential = OAuthProvider.appleCredential(withIDToken: kAppleIDToken,
                                                        rawNonce: nil,
                                                        fullName: fullName)
    auth.signIn(with: appleCredential) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      do {
        try self.assertUserGoogle(authResult?.user)
        guard let additionalUserInfo = authResult?.additionalUserInfo,
              let profile = additionalUserInfo.profile as? [String: String] else {
          XCTFail("authResult.additionalUserInfo is missing")
          return
        }
        XCTAssertEqual(profile, self.kGoogleProfile)
        XCTAssertEqual(additionalUserInfo.username, self.kGoogleDisplayName)
        XCTAssertEqual(additionalUserInfo.providerID, AuthProviderString.apple.rawValue)
      } catch {
        XCTFail("\(error)")
      }
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? VerifyAssertionRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.providerID, AuthProviderString.apple.rawValue)
    XCTAssertEqual(request.providerIDToken, kAppleIDToken)
    XCTAssertEqual(request.fullName, fullName)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                      "refreshToken": kRefreshToken,
                                      "federatedId": kGoogleID,
                                      "providerId": AuthProviderString.apple.rawValue,
                                      "localId": kLocalID,
                                      "displayName": kGoogleDisplayName,
                                      "rawUserInfo": kGoogleProfile,
                                      "firstName": kFirst,
                                      "lastName": kLast,
                                      "username": kGoogleDisplayName])
    waitForExpectations(timeout: 5)
    XCTAssertNotNil(auth.currentUser)
  }

  /** @fn testSignInAnonymouslySuccess
      @brief Tests the flow of a successful @c signInAnonymouslyWithCompletion: call.
   */
  func testSignInAnonymouslySuccess() throws {
    let expectation = self.expectation(description: #function)
    setFakeSecureTokenService()
    setFakeGetAccountProviderAnonymous()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.signInAnonymously { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertNil(error)
      XCTAssertTrue(Thread.isMainThread)
      self.assertUserAnonymous(authResult?.user)
      guard let userInfo = authResult?.additionalUserInfo else {
        XCTFail("authResult.additionalUserInfo is missing")
        return
      }
      XCTAssertTrue(userInfo.isNewUser)
      XCTAssertNil(userInfo.username)
      XCTAssertNil(userInfo.profile)
      XCTAssertNil(userInfo.providerID)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? SignUpNewUserRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertNil(request.email)
    XCTAssertNil(request.password)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])
    waitForExpectations(timeout: 5)
    assertUserAnonymous(try XCTUnwrap(auth?.currentUser))
  }

  /** @fn testSignInAnonymouslyFailure
      @brief Tests the flow of a failed @c signInAnonymouslyWithCompletion: call.
   */
  func testSignInAnonymouslyFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(email)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.operationNotAllowed.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "OPERATION_NOT_ALLOWED")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testSignInWithCustomTokenSuccess
      @brief Tests the flow of a successful @c signInWithCustomToken:completion: call.
   */
  func testSignInWithCustomTokenSuccess() throws {
    let expectation = self.expectation(description: #function)
    setFakeSecureTokenService()
    setFakeGetAccountProvider()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.signIn(withCustomToken: kCustomToken) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      self.assertUser(authResult?.user)
      guard let userInfo = authResult?.additionalUserInfo else {
        XCTFail("authResult.additionalUserInfo is missing")
        return
      }
      XCTAssertFalse(userInfo.isNewUser)
      XCTAssertNil(userInfo.username)
      XCTAssertNil(userInfo.profile)
      XCTAssertNil(userInfo.providerID)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? VerifyCustomTokenRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.token, kCustomToken)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": false,
                                      "refreshToken": kRefreshToken])
    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  /** @fn testSignInWithCustomTokenFailure
      @brief Tests the flow of a failed @c signInWithCustomToken:completion: call.
   */
  func testSignInWithCustomTokenFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.signIn(withCustomToken: kCustomToken) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult?.user)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidCustomToken.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "INVALID_CUSTOM_TOKEN")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testCreateUserWithEmailPasswordSuccess
      @brief Tests the flow of a successful @c createUserWithEmail:password:completion: call.
   */
  func testCreateUserWithEmailPasswordSuccess() throws {
    let expectation = self.expectation(description: #function)
    setFakeSecureTokenService()
    setFakeGetAccountProvider()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.createUser(withEmail: kEmail, password: kFakePassword) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      self.assertUser(authResult?.user)
      guard let userInfo = authResult?.additionalUserInfo else {
        XCTFail("authResult.additionalUserInfo is missing")
        return
      }
      XCTAssertTrue(userInfo.isNewUser)
      XCTAssertNil(userInfo.username)
      XCTAssertNil(userInfo.profile)
      XCTAssertEqual(userInfo.providerID, EmailAuthProvider.id)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? SignUpNewUserRequest)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.password, kFakePassword)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])
    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  /** @fn testCreateUserWithEmailPasswordFailure
      @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call.
   */
  func testCreateUserWithEmailPasswordFailure() throws {
    let expectation = self.expectation(description: #function)
    let reason = "The password must be 6 characters long or more."

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try auth?.signOut()
    auth?.createUser(withEmail: kEmail, password: kFakePassword) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult?.user)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.weakPassword.rawValue)
      XCTAssertEqual((error as? NSError)?.userInfo[NSLocalizedDescriptionKey] as? String, reason)
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "WEAK_PASSWORD")
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testCreateUserEmptyPasswordFailure
      @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call due to an
          empty password. This error occurs on the client side, so there is no need to fake an RPC
          response.
   */
  func testCreateUserEmptyPasswordFailure() throws {
    let expectation = self.expectation(description: #function)
    try auth?.signOut()
    auth?.createUser(withEmail: kEmail, password: "") { authResult, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult?.user)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.weakPassword.rawValue)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testCreateUserEmptyEmailFailure
      @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call due to an
          empty email adress. This error occurs on the client side, so there is no need to fake an RPC
          response.
   */
  func testCreateUserEmptyEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    try auth?.signOut()
    auth?.createUser(withEmail: "", password: kFakePassword) { authResult, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult?.user)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.missingEmail.rawValue)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testSendPasswordResetEmailSuccess
      @brief Tests the flow of a successful @c sendPasswordReset call.
   */
  func testSendPasswordResetEmailSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer in `fetchSignInMethods`.
    let group = createGroup()

    auth?.sendPasswordReset(withEmail: kEmail) { error in
      // 4. After the response triggers the callback, verify success.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? GetOOBConfirmationCodeRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    _ = try rpcIssuer?.respond(withJSON: [:])

    waitForExpectations(timeout: 5)
  }

  /** @fn testSendPasswordResetEmailFailure
      @brief Tests the flow of a failed @c sendPasswordReset call.
   */
  func testSendPasswordResetEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    let group = createGroup()

    auth?.sendPasswordReset(withEmail: kEmail) { error in
      XCTAssertTrue(Thread.isMainThread)
      let rpcError = (error as? NSError)!
      XCTAssertEqual(rpcError.code, AuthErrorCode.appNotAuthorized.rawValue)
      XCTAssertNotNil(rpcError.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    try rpcIssuer?.respond(underlyingErrorMessage: "ipRefererBlocked")

    waitForExpectations(timeout: 5)
  }

//  /** @fn testSendSignInLinkToEmailSuccess
//      @brief Tests the flow of a successful @c sendSignInLinkToEmail call.
//   */
  func testSendSignInLinkToEmailSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer in `fetchSignInMethods`.
    let group = createGroup()

    auth?.sendSignInLink(toEmail: kEmail,
                         actionCodeSettings: fakeActionCodeSettings()) { error in
      // 4. After the response triggers the callback, verify success.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? GetOOBConfirmationCodeRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.continueURL, kContinueURL)
    XCTAssertTrue(request.handleCodeInApp)

    // 3. Send the response from the fake backend.
    _ = try rpcIssuer?.respond(withJSON: [:])

    waitForExpectations(timeout: 5)
  }

  /** @fn testSendSignInLinkToEmailFailure
      @brief Tests the flow of a failed @c sendSignInLink call.
   */
  func testSendSignInLinkToEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    let group = createGroup()

    auth?.sendSignInLink(toEmail: kEmail,
                         actionCodeSettings: fakeActionCodeSettings()) { error in
      XCTAssertTrue(Thread.isMainThread)
      let rpcError = error as? NSError
      XCTAssertEqual(rpcError?.code, AuthErrorCode.appNotAuthorized.rawValue)
      XCTAssertNotNil(rpcError?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    try rpcIssuer?.respond(underlyingErrorMessage: "ipRefererBlocked")
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateCurrentUserFailure
      @brief Tests the flow of a failed @c updateCurrentUser:completion:
          call.
   */
  func testUpdateCurrentUserFailure() throws {
    try waitForSignInWithAccessToken()
    let expectation = self.expectation(description: #function)
    let kTestAPIKey2 = "fakeAPIKey2"
    let auth = try XCTUnwrap(auth)
    let user2 = auth.currentUser
    user2?.requestConfiguration = AuthRequestConfiguration(apiKey: kTestAPIKey2,
                                                           appID: kTestFirebaseAppID)
    let group = createGroup()
    // Clear fake so we can inject error
    rpcIssuer?.fakeGetAccountProviderJSON = nil
    auth.updateCurrentUser(user2) { error in
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidAPIKey.rawValue)
      expectation.fulfill()
    }
    group.wait()
    try rpcIssuer?.respond(underlyingErrorMessage: "keyInvalid")
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateCurrentUserFailureNetworkError
      @brief Tests the flow of a failed @c updateCurrentUser:completion:
          call with a network error.
   */
  func testUpdateCurrentUserFailureNetworkError() throws {
    try waitForSignInWithAccessToken()
    let expectation = self.expectation(description: #function)
    let kTestAPIKey2 = "fakeAPIKey2"
    let auth = try XCTUnwrap(auth)
    let user2 = auth.currentUser
    user2?.requestConfiguration = AuthRequestConfiguration(apiKey: kTestAPIKey2,
                                                           appID: kTestFirebaseAppID)
    let group = createGroup()
    // Clear fake so we can inject error
    rpcIssuer?.fakeGetAccountProviderJSON = nil
    auth.updateCurrentUser(user2) { error in
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.networkError.rawValue)
      expectation.fulfill()
    }
    group.wait()
    let kFakeErrorDomain = "fakeDomain"
    let kFakeErrorCode = -1
    let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
    try rpcIssuer?.respond(withData: nil, error: responseError)
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateCurrentUserFailureNullUser
      @brief Tests the flow of a failed @c updateCurrentUser:completion:
          call with FIRAuthErrorCodeNullUser.
   */
  func testUpdateCurrentUserFailureNullUser() throws {
    try waitForSignInWithAccessToken()
    let expectation = self.expectation(description: #function)
    auth.updateCurrentUser(nil) { error in
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.nullUser.rawValue)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateCurrentUserFailureTenantIDMismatch
   @brief Tests the flow of a failed @c updateCurrentUser:completion:
   call with FIRAuthErrorCodeTenantIDMismatch.
   */
  func testUpdateCurrentUserFailureTenantIDMismatch() throws {
    // User without tenant id
    try waitForSignInWithAccessToken()
    let auth = try XCTUnwrap(auth)
    let user1 = auth.currentUser
    try auth.signOut()

    // User with tenant id "tenant-id"
    auth.tenantID = "tenant-id-1"
    let kTestAccessToken2 = "fakeAccessToken2"
    try waitForSignInWithAccessToken(fakeAccessToken: kTestAccessToken2)
    let user2 = auth.currentUser

    try auth.signOut()
    auth.tenantID = "tenant-id-2"
    let expectation = self.expectation(description: #function)

    auth.updateCurrentUser(user1) { error in
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.tenantIDMismatch.rawValue)
      expectation.fulfill()
    }

    try auth.signOut()
    auth.tenantID = "tenant-id-2"
    let expectation2 = self.expectation(description: "tenant-id-test2")

    auth.updateCurrentUser(user2) { error in
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.tenantIDMismatch.rawValue)
      expectation2.fulfill()
    }

    try auth.signOut()
    auth.tenantID = nil
    let expectation3 = self.expectation(description: "tenant-id-test3")

    auth.updateCurrentUser(user2) { error in
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.tenantIDMismatch.rawValue)
      expectation3.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testUpdateCurrentUserSuccess
      @brief Tests the flow of a successful @c updateCurrentUser:completion:
          call with a network error.
   */
  func testUpdateCurrentUserSuccess() throws {
    // Sign in with the first user.
    try waitForSignInWithAccessToken()
    let auth = try XCTUnwrap(auth)
    let user1 = auth.currentUser
    let kTestAPIKey = "fakeAPIKey"
    user1?.requestConfiguration = AuthRequestConfiguration(apiKey: kTestAPIKey,
                                                           appID: kTestFirebaseAppID)
    try auth.signOut()

    let kTestAccessToken2 = "fakeAccessToken2"
    try waitForSignInWithAccessToken(fakeAccessToken: kTestAccessToken2)
    let user2 = auth.currentUser

    let expectation = self.expectation(description: #function)
    // Current user should now be user2.
    XCTAssertEqual(auth.currentUser, user2)

    auth.updateCurrentUser(user1) { error in
      XCTAssertNil(error)
      // Current user should now be user1.
      XCTAssertEqual(auth.currentUser, user1)
      XCTAssertNotEqual(auth.currentUser, user2)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testSignOut
      @brief Tests the @c signOut: method.
   */
  func testSignOut() throws {
    try waitForSignInWithAccessToken()
    // Verify signing out succeeds and clears the current user.
    let auth = try XCTUnwrap(auth)
    try auth.signOut()
    XCTAssertNil(auth.currentUser)
  }

  /** @fn testIsSignInWithEmailLink
       @brief Tests the @c isSignInWithEmailLink: method.
   */
  func testIsSignInWithEmailLink() throws {
    let auth = try XCTUnwrap(auth)
    let kBadSignInEmailLink = "http://www.facebook.com"
    XCTAssertTrue(auth.isSignIn(withEmailLink: kFakeEmailSignInLink))
    XCTAssertTrue(auth.isSignIn(withEmailLink: kFakeEmailSignInDeeplink))
    XCTAssertFalse(auth.isSignIn(withEmailLink: kBadSignInEmailLink))
    XCTAssertFalse(auth.isSignIn(withEmailLink: ""))
  }

  /** @fn testAuthStateChanges
      @brief Tests @c addAuthStateDidChangeListener: and @c removeAuthStateDidChangeListener: methods.
   */
  func testAuthStateChanges() throws {
    // Set up listener.
    let auth = try XCTUnwrap(auth)
    var shouldHaveUser = false
    var expectation: XCTestExpectation?
    let listener = { listenerAuth, user in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(auth, listenerAuth)
      XCTAssertEqual(user, auth.currentUser)
      if shouldHaveUser {
        XCTAssertNotNil(user)
      } else {
        XCTAssertNil(user)
      }
      // `expectation` being nil means the listener is not expected to be fired at this moment.
      XCTAssertNotNil(expectation)
      expectation?.fulfill()
    }
    try auth.signOut()

    // Listener should fire immediately when attached.
    expectation = self.expectation(description: "initial")
    shouldHaveUser = false
    let handle = auth.addStateDidChangeListener(listener)
    waitForExpectations(timeout: 5)
    expectation = nil

    // Listener should fire for signing in.
    expectation = self
      .expectation(description: "sign-in") // waited on in waitForSignInWithAccessToken
    shouldHaveUser = true
    try waitForSignInWithAccessToken()

    // Listener should not fire for signing in again.
    expectation = nil
    shouldHaveUser = true
    try waitForSignInWithAccessToken()

    // Listener should fire for signing out.
    expectation = self.expectation(description: "sign-out")
    shouldHaveUser = false
    try auth.signOut()
    waitForExpectations(timeout: 5)

    // Listener should no longer fire once detached.
    expectation = nil
    auth.removeStateDidChangeListener(handle)
    try waitForSignInWithAccessToken()
  }

  /** @fn testIDTokenChanges
      @brief Tests @c addIDTokenDidChangeListener: and @c removeIDTokenDidChangeListener: methods.
   */
  func testIDTokenChanges() throws {
    // Set up listener.
    let auth = try XCTUnwrap(auth)
    var shouldHaveUser = false
    var expectation: XCTestExpectation?
    let listener = { listenerAuth, user in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(auth, listenerAuth)
      XCTAssertEqual(user, auth.currentUser)
      if shouldHaveUser {
        XCTAssertNotNil(user)
      } else {
        XCTAssertNil(user)
      }
      // `expectation` being nil means the listener is not expected to be fired at this moment.
      XCTAssertNotNil(expectation)
      expectation?.fulfill()
    }
    try auth.signOut()

    // Listener should fire immediately when attached.
    expectation = self.expectation(description: "initial")
    shouldHaveUser = false
    let handle = auth.addIDTokenDidChangeListener(listener)
    waitForExpectations(timeout: 5)
    expectation = nil

    // Listener should fire for signing in. Expectation is waited on in waitForSignInWithAccessToken.
    expectation = self.expectation(description: "sign-in")
    shouldHaveUser = true
    try waitForSignInWithAccessToken()

    // Listener should not fire for signing in again.
    expectation = nil
    shouldHaveUser = true
    try waitForSignInWithAccessToken()

    // Listener should fire for signing in again as the same user with another access token.
    expectation = self.expectation(description: "sign-in")
    shouldHaveUser = true
    try waitForSignInWithAccessToken(fakeAccessToken: AuthTests.kNewAccessToken)

    // Listener should fire for signing out.
    expectation = self.expectation(description: "sign-out")
    shouldHaveUser = false
    try auth.signOut()
    waitForExpectations(timeout: 5)

    // Listener should no longer fire once detached.
    expectation = nil
    auth.removeStateDidChangeListener(handle)
    try waitForSignInWithAccessToken()
  }

  /** @fn testUseEmulator
      @brief Tests the @c useEmulatorWithHost:port: method.
   */
  func testUseEmulator() throws {
    auth.useEmulator(withHost: "host", port: 12345)
    XCTAssertEqual("host:12345", auth.requestConfiguration.emulatorHostAndPort)
    #if os(iOS)
      let settings = try XCTUnwrap(auth.settings)
      XCTAssertTrue(settings.isAppVerificationDisabledForTesting)
    #endif
  }

  /** @fn testUseEmulatorNeverCalled
      @brief Tests that the emulatorHostAndPort stored in @c FIRAuthRequestConfiguration is nil if the
     @c useEmulatorWithHost:port: is not called.
   */
  func testUseEmulatorNeverCalled() throws {
    XCTAssertNil(auth.requestConfiguration.emulatorHostAndPort)
    #if os(iOS)
      let settings = try XCTUnwrap(auth.settings)
      XCTAssertFalse(settings.isAppVerificationDisabledForTesting)
    #endif
  }

  /** @fn testUseEmulatorIPv6Address
      @brief Tests the @c useEmulatorWithHost:port: method with an IPv6 host address.
   */
  func testUseEmulatorIPv6Address() throws {
    auth.useEmulator(withHost: "::1", port: 12345)
    XCTAssertEqual("[::1]:12345", auth.requestConfiguration.emulatorHostAndPort)
    #if os(iOS)
      let settings = try XCTUnwrap(auth.settings)
      XCTAssertTrue(settings.isAppVerificationDisabledForTesting)
    #endif
  }

  // MARK: Automatic Token Refresh Tests.

  /** @fn testAutomaticTokenRefresh
      @brief Tests a successful flow to automatically refresh tokens for a signed in user.
   */
  func testAutomaticTokenRefresh() throws {
    try auth.signOut()
    // Enable auto refresh
    enableAutoTokenRefresh()

    // Sign in a user.
    try waitForSignInWithAccessToken()

    setFakeSecureTokenService(fakeAccessToken: AuthTests.kNewAccessToken)

    // Verify that the current user's access token is the "old" access token before automatic token
    // refresh.
    XCTAssertEqual(AuthTests.kAccessToken, auth.currentUser?.rawAccessToken())

    // Execute saved token refresh task.
    let expectation = self.expectation(description: #function)
    kAuthGlobalWorkQueue.async {
      XCTAssertNotNil(self.authDispatcherCallback)
      self.authDispatcherCallback?()
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    waitForAuthGlobalWorkQueueDrain()

    // Verify that current user's access token is the "new" access token provided in the mock secure
    // token response during automatic token refresh.
    XCTAssertEqual(AuthTests.kNewAccessToken, auth.currentUser?.rawAccessToken())
  }

  /** @fn testAutomaticTokenRefreshInvalidTokenFailure
      @brief Tests an unsuccessful flow to auto refresh tokens with an "invalid token" error.
          This error should cause the user to be signed out.
   */
  func testAutomaticTokenRefreshInvalidTokenFailure() throws {
    try auth.signOut()
    // Enable auto refresh
    enableAutoTokenRefresh()

    // Sign in a user.
    try waitForSignInWithAccessToken()

    // Set up expectation for secureToken RPC made by a failed attempt to refresh tokens.
    rpcIssuer?.secureTokenErrorString = "INVALID_ID_TOKEN"

    // Verify that the current user's access token is the "old" access token before automatic token
    // refresh.
    XCTAssertEqual(AuthTests.kAccessToken, auth.currentUser?.rawAccessToken())

    // Execute saved token refresh task.
    let expectation = self.expectation(description: #function)
    kAuthGlobalWorkQueue.async {
      XCTAssertNotNil(self.authDispatcherCallback)
      self.authDispatcherCallback?()
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    waitForAuthGlobalWorkQueueDrain()

    // Verify that the user is nil after failed attempt to refresh tokens caused signed out.
    XCTAssertNil(auth.currentUser)
  }

  /** @fn testAutomaticTokenRefreshRetry
      @brief Tests that a retry is attempted for a automatic token refresh task (which is not due to
          invalid tokens). The initial attempt to refresh the access token fails, but the second
          attempt is successful.
   */
  func testAutomaticTokenRefreshRetry() throws {
    try auth.signOut()
    // Enable auto refresh
    enableAutoTokenRefresh()

    // Sign in a user.
    try waitForSignInWithAccessToken()

    // Set up expectation for secureToken RPC made by a failed attempt to refresh tokens.
    rpcIssuer?.secureTokenNetworkError = NSError(domain: "ERROR", code: -1)

    // Execute saved token refresh task.
    let expectation = self.expectation(description: #function)
    kAuthGlobalWorkQueue.async {
      XCTAssertNotNil(self.authDispatcherCallback)
      self.authDispatcherCallback?()
      self.authDispatcherCallback = nil
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    waitForAuthGlobalWorkQueueDrain()

    rpcIssuer?.secureTokenNetworkError = nil
    setFakeSecureTokenService(fakeAccessToken: AuthTests.kNewAccessToken)

    // The old access token should still be the current user's access token and not the new access
    // token (kNewAccessToken).
    XCTAssertEqual(AuthTests.kAccessToken, auth.currentUser?.rawAccessToken())

    // Execute saved token refresh task.
    let expectation2 = self.expectation(description: "dispatchAfterExpectation")
    kAuthGlobalWorkQueue.async {
      XCTAssertNotNil(self.authDispatcherCallback)
      self.authDispatcherCallback?()
      expectation2.fulfill()
    }
    waitForExpectations(timeout: 5)
    waitForAuthGlobalWorkQueueDrain()

    // Verify that current user's access token is the "new" access token provided in the mock secure
    // token response during automatic token refresh.
    XCTAssertEqual(AuthTests.kNewAccessToken, auth.currentUser?.rawAccessToken())
  }

  #if os(iOS)
    /** @fn testAutoRefreshAppForegroundedNotification
        @brief Tests that app foreground notification triggers the scheduling of an automatic token
            refresh task.
     */
    func testAutoRefreshAppForegroundedNotification() throws {
      try auth.signOut()
      // Enable auto refresh
      enableAutoTokenRefresh()

      // Sign in a user.
      try waitForSignInWithAccessToken()

      // Post "UIApplicationDidBecomeActiveNotification" to trigger scheduling token refresh task.
      NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)

      setFakeSecureTokenService(fakeAccessToken: AuthTests.kNewAccessToken)

      // Verify that the current user's access token is the "old" access token before automatic token
      // refresh.
      XCTAssertEqual(AuthTests.kAccessToken, auth.currentUser?.rawAccessToken())

      // Execute saved token refresh task.
      let expectation = self.expectation(description: #function)
      kAuthGlobalWorkQueue.async {
        XCTAssertNotNil(self.authDispatcherCallback)
        self.authDispatcherCallback?()
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
      waitForAuthGlobalWorkQueueDrain()

      // Verify that current user's access token is the "new" access token provided in the mock secure
      // token response during automatic token refresh.
      XCTAssertEqual(AuthTests.kNewAccessToken, auth.currentUser?.rawAccessToken())
    }
  #endif

  // MARK: Application Delegate tests.

  // MARK: Helper Functions

  private func enableAutoTokenRefresh() {
    let expectation = self.expectation(description: #function)
    auth.getToken(forcingRefresh: false) { token, error in
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  private func waitForSignInWithAccessToken(fakeAccessToken: String = kAccessToken) throws {
    let kRefreshToken = "fakeRefreshToken"
    let expectation = self.expectation(description: #function)
    setFakeGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      guard let user = authResult?.user else {
        XCTFail("authResult.user is missing")
        return
      }
      XCTAssertEqual(user.refreshToken, kRefreshToken)
      XCTAssertFalse(user.isAnonymous)
      XCTAssertEqual(user.email, self.kEmail)
      guard let additionalUserInfo = authResult?.additionalUserInfo else {
        XCTFail("authResult.additionalUserInfo is missing")
        return
      }
      XCTAssertFalse(additionalUserInfo.isNewUser)
      XCTAssertEqual(additionalUserInfo.providerID, EmailAuthProvider.id)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? VerifyPasswordRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.password, kFakePassword)
    XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": fakeAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "expiresIn": "3600",
                                      "refreshToken": kRefreshToken])

    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  private func assertUser(_ user: User?) {
    guard let user = user else {
      XCTFail("authResult.additionalUserInfo is missing")
      return
    }
    XCTAssertEqual(user.uid, kLocalID)
    XCTAssertEqual(user.displayName, kDisplayName)
    XCTAssertEqual(user.email, kEmail)
    XCTAssertFalse(user.isAnonymous)
    XCTAssertEqual(user.providerData.count, 1)
  }

  private func assertUserAnonymous(_ user: User?) {
    guard let user = user else {
      XCTFail("authResult.additionalUserInfo is missing")
      return
    }
    XCTAssertEqual(user.uid, kLocalID)
    XCTAssertNil(user.email)
    XCTAssertNil(user.displayName)
    XCTAssertTrue(user.isAnonymous)
    XCTAssertEqual(user.providerData.count, 0)
  }
}
