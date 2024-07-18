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
import FirebaseAuthInterop

import FirebaseCore

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AuthTests: RPCBaseTests {
  static let kAccessToken = "TEST_ACCESS_TOKEN"
  static let kNewAccessToken = "NEW_ACCESS_TOKEN"
  static let kFakeAPIKey = "FAKE_API_KEY"
  static let kFakeRecaptchaResponse = "RecaptchaResponse"
  static let kFakeRecaptchaVersion = "RecaptchaVersion"
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
    #if (os(macOS) && !FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN) || SWIFT_PACKAGE
      let keychainStorageProvider = FakeAuthKeychainStorage()
    #else
      let keychainStorageProvider = AuthKeychainStorageReal()
    #endif // (os(macOS) && !FIREBASE_AUTH_TESTING_USE_MACOS_KEYCHAIN) || SWIFT_PACKAGE
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

    rpcIssuer.respondBlock = {
      let request = try XCTUnwrap(self.rpcIssuer.request as? CreateAuthURIRequest)
      XCTAssertEqual(request.identifier, self.kEmail)
      XCTAssertEqual(request.endpoint, "createAuthUri")
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

      try self.rpcIssuer.respond(withJSON: ["signinMethods": allSignInMethods])
    }

    auth?.fetchSignInMethods(forEmail: kEmail) { signInMethods, error in
      // 4. After the response triggers the callback, verify the returned signInMethods.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(signInMethods, allSignInMethods)
      XCTAssertNil(error)
      expectation.fulfill()
    }

    waitForExpectations(timeout: 5)
  }

  /** @fn testFetchSignInMethodsForEmailFailure
      @brief Tests the flow of a failed @c fetchSignInMethodsForEmail:completion: call.
   */
  func testFetchSignInMethodsForEmailFailure() throws {
    let expectation = self.expectation(description: #function)

    rpcIssuer.respondBlock = {
      let message = "TOO_MANY_ATTEMPTS_TRY_LATER"
      try self.rpcIssuer.respond(serverErrorMessage: message)
    }
    auth?.fetchSignInMethods(forEmail: kEmail) { signInMethods, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(signInMethods)
      let rpcError = (error as? NSError)!
      XCTAssertEqual(rpcError.code, AuthErrorCode.tooManyRequests.rawValue)
      expectation.fulfill()
    }
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

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyPhoneNumberRequest)
        XCTAssertEqual(request.verificationCode, kVerificationCode)
        XCTAssertEqual(request.verificationID, kVerificationID)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                              "isNewUser": true,
                                              "refreshToken": self.kRefreshToken])
      }

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

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? EmailLinkSignInRequest)
      XCTAssertEqual(request.email, self.kEmail)
      XCTAssertEqual(request.oobCode, fakeCode)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

      try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                            "email": self.kEmail,
                                            "isNewUser": true,
                                            "refreshToken": self.kRefreshToken])
    }
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
    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  /** @fn testSignInWithEmailLinkFailure
      @brief Tests the flow of a failed @c signInWithEmail:link:completion: call.
   */
  func testSignInWithEmailLinkFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "INVALID_OOB_CODE")
    }
    try auth?.signOut()
    auth?.signIn(withEmail: kEmail, link: kFakeEmailSignInLink) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  #if os(iOS)
    /** @fn testSignInWithEmailPasswordWithRecaptchaSuccess
        @brief Tests the flow of a successful @c signInWithEmail:password:completion: call.
     */
    func testSignInWithEmailPasswordWithRecaptchaSuccess() throws {
      let kRefreshToken = "fakeRefreshToken"
      let expectation = self.expectation(description: #function)
      setFakeGetAccountProvider()
      setFakeSecureTokenService()

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyPasswordRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.password, self.kFakePassword)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertTrue(request.returnSecureToken)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                              "email": self.kEmail,
                                              "isNewUser": true,
                                              "refreshToken": kRefreshToken])
      }

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
      waitForExpectations(timeout: 5)
      assertUser(auth?.currentUser)
    }

    /** @fn testSignInWithEmailPasswordWithRecaptchaFallbackSuccess
        @brief Tests the flow of a successful @c signInWithEmail:password:completion: call.
     */
    func testSignInWithEmailPasswordWithRecaptchaFallbackSuccess() throws {
      let kRefreshToken = "fakeRefreshToken"
      let expectation = self.expectation(description: #function)
      setFakeGetAccountProvider()
      setFakeSecureTokenService()
      let kTestRecaptchaKey = "projects/123/keys/456"
      rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyPasswordRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.password, self.kFakePassword)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertTrue(request.returnSecureToken)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(serverErrorMessage: "MISSING_RECAPTCHA_TOKEN")
      }
      rpcIssuer.nextRespondBlock = {
        // 4. Validate again the created Request instance after the recaptcha retry.
        let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyPasswordRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.password, self.kFakePassword)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertTrue(request.returnSecureToken)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)
        // 5. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                              "email": self.kEmail,
                                              "isNewUser": true,
                                              "refreshToken": kRefreshToken])
      }

      try auth?.signOut()
      auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
        // 6. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
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
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
      assertUser(auth?.currentUser)
    }
  #endif

  /** @fn testSignInAndRetrieveDataWithEmailPasswordSuccess
      @brief Tests the flow of a successful @c signInAndRetrieveDataWithEmail:password:completion:
          call. Superset of historical testSignInWithEmailPasswordSuccess.
   */
  func testSignInAndRetrieveDataWithEmailPasswordSuccess() throws {
    let kRefreshToken = "fakeRefreshToken"
    let expectation = self.expectation(description: #function)
    setFakeGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyPasswordRequest)
      XCTAssertEqual(request.email, self.kEmail)
      XCTAssertEqual(request.password, self.kFakePassword)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                            "email": self.kEmail,
                                            "isNewUser": true,
                                            "refreshToken": kRefreshToken])
    }

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
    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  /** @fn testSignInWithEmailPasswordFailure
      @brief Tests the flow of a failed @c signInWithEmail:password:completion: call.
   */
  func testSignInWithEmailPasswordFailure() throws {
    let expectation = self.expectation(description: #function)

    rpcIssuer.respondBlock = {
      // 2. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "INVALID_PASSWORD")
    }

    try auth?.signOut()
    auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.wrongPassword.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testResetPasswordSuccess
      @brief Tests the flow of a successful @c confirmPasswordResetWithCode:newPassword:completion:
          call.
   */
  func testResetPasswordSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? ResetPasswordRequest)
      XCTAssertEqual(request.oobCode, self.kFakeOobCode)
      XCTAssertEqual(request.updatedPassword, self.kFakePassword)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: [:])
    }
    try auth?.signOut()
    auth?
      .confirmPasswordReset(withCode: kFakeOobCode, newPassword: kFakePassword) { error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        expectation.fulfill()
      }
    waitForExpectations(timeout: 5)
  }

  /** @fn testResetPasswordFailure
      @brief Tests the flow of a failed @c confirmPasswordResetWithCode:newPassword:completion:
          call.
   */
  func testResetPasswordFailure() throws {
    let expectation = self.expectation(description: #function)

    rpcIssuer.respondBlock = {
      // 2. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "INVALID_OOB_CODE")
    }

    try auth?.signOut()
    auth?
      .confirmPasswordReset(withCode: kFakeOobCode, newPassword: kFakePassword) { error in
        // 3. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
        XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
        expectation.fulfill()
      }
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

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? ResetPasswordRequest)
      XCTAssertEqual(request.oobCode, self.kFakeOobCode)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["email": self.kEmail,
                                            "requestType": verifyEmailRequestType,
                                            "newEmail": kNewEmail])
    }
    try auth?.signOut()
    auth?.checkActionCode(kFakeOobCode) { info, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      XCTAssertEqual(info?.email, kNewEmail)
      XCTAssertEqual(info?.operation, ActionCodeOperation.verifyEmail)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testCheckActionCodeFailure
      @brief Tests the flow of a failed @c checkActionCode:completion call.
   */
  func testCheckActionCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "EXPIRED_OOB_CODE")
    }
    try auth?.signOut()
    auth?.checkActionCode(kFakeOobCode) { info, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.expiredActionCode.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testApplyActionCodeSuccess
      @brief Tests the flow of a successful @c applyActionCode:completion call.
   */
  func testApplyActionCodeSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? SetAccountInfoRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: [:])
    }
    try auth?.signOut()
    auth?.applyActionCode(kFakeOobCode) { error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testApplyActionCodeFailure
      @brief Tests the flow of a failed @c checkActionCode:completion call.
   */
  func testApplyActionCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "INVALID_OOB_CODE")
    }
    try auth?.signOut()
    auth?.applyActionCode(kFakeOobCode) { error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  /** @fn testVerifyPasswordResetCodeSuccess
      @brief Tests the flow of a successful @c verifyPasswordResetCode:completion call.
   */
  func testVerifyPasswordResetCodeSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? ResetPasswordRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.oobCode, self.kFakeOobCode)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["email": self.kEmail])
    }
    try auth?.signOut()
    auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(email, self.kEmail)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testVerifyPasswordResetCodeFailure
      @brief Tests the flow of a failed @c verifyPasswordResetCode:completion call.
   */
  func testVerifyPasswordResetCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "INVALID_OOB_CODE")
    }
    try auth?.signOut()
    auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(email)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
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

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? EmailLinkSignInRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.oobCode, fakeCode)
      XCTAssertEqual(request.email, self.kEmail)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                            "isNewUser": true,
                                            "refreshToken": self.kRefreshToken])
    }
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
    waitForExpectations(timeout: 5)
  }

  /** @fn testSignInWithEmailLinkCredentialFailure
      @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
          email-email sign-in link credential using FIREmailAuthProvider.
   */
  func testSignInWithEmailLinkCredentialFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "USER_DISABLED")
    }
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

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyPasswordRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.password, self.kFakePassword)
      XCTAssertEqual(request.email, self.kEmail)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                            "isNewUser": true,
                                            "refreshToken": self.kRefreshToken])
    }
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
    waitForExpectations(timeout: 5)
  }

  /** @fn testSignInWithEmailCredentialFailure
      @brief Tests the flow of a failed @c signInWithCredential:completion: call with an
          email-password credential.
   */
  func testSignInWithEmailCredentialFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "USER_DISABLED")
    }
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
        let credential = OAuthCredential(withProviderID: GoogleAuthProvider.id,
                                         sessionID: kOAuthSessionID,
                                         OAuthResponseURLString: kOAuthRequestURI)
        XCTAssertEqual(credential.OAuthResponseURLString, kOAuthRequestURI)
        XCTAssertEqual(credential.sessionID, kOAuthSessionID)
        return credential
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

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyAssertionRequest)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
        XCTAssertTrue(request.returnSecureToken)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                              "refreshToken": self.kRefreshToken,
                                              "federatedId": self.kGoogleID,
                                              "providerId": GoogleAuthProvider.id,
                                              "localId": self.kLocalID,
                                              "displayName": self.kDisplayName,
                                              "rawUserInfo": self.kGoogleProfile,
                                              "username": self.kUserName])
      }
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

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyAssertionRequest)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
        XCTAssertTrue(request.returnSecureToken)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(serverErrorMessage: "USER_DISABLED")
      }
      try auth.signOut()
      auth.signIn(with: FakeProvider(), uiDelegate: nil) { authResult, error in
        // 4. After the response triggers the callback, verify the returned result.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(authResult)
        XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.userDisabled.rawValue)
        expectation.fulfill()
      }
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

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyAssertionRequest)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
        XCTAssertEqual(request.providerIDToken, self.kGoogleIDToken)
        XCTAssertEqual(request.providerAccessToken, self.kGoogleAccessToken)
        XCTAssertTrue(request.returnSecureToken)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                              "refreshToken": self.kRefreshToken,
                                              "federatedId": self.kGoogleID,
                                              "providerId": GoogleAuthProvider.id,
                                              "localId": self.kLocalID,
                                              "displayName": self.kGoogleDisplayName,
                                              "rawUserInfo": self.kGoogleProfile,
                                              "username": self.kUserName,
                                              "needConfirmation": true])
      }
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

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyAssertionRequest)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
        XCTAssertEqual(request.requestURI, AuthTests.kOAuthRequestURI)
        XCTAssertEqual(request.sessionID, AuthTests.kOAuthSessionID)
        XCTAssertTrue(request.returnSecureToken)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                              "refreshToken": self.kRefreshToken,
                                              "federatedId": self.kGoogleID,
                                              "providerId": GoogleAuthProvider.id,
                                              "localId": self.kLocalID,
                                              "displayName": self.kGoogleDisplayName,
                                              "rawUserInfo": self.kGoogleProfile,
                                              "username": self.kUserName])
      }
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
      waitForExpectations(timeout: 5)
      try assertUserGoogle(auth.currentUser)
    }
  #endif

  /** @fn testSignInWithCredentialSuccess
      @brief Tests the flow of a successful @c signInWithCredential:completion: call
          with a Google Sign-In credential.
      Note: also a superset of the former testSignInWithGoogleCredentialSuccess
   */
  func testSignInWithCredentialSuccess() throws {
    let expectation = self.expectation(description: #function)
    setFakeGoogleGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertEqual(request.providerIDToken, self.kGoogleIDToken)
      XCTAssertEqual(request.providerAccessToken, self.kGoogleAccessToken)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                            "refreshToken": self.kRefreshToken,
                                            "federatedId": self.kGoogleID,
                                            "providerId": GoogleAuthProvider.id,
                                            "localId": self.kLocalID,
                                            "displayName": self.kGoogleDisplayName,
                                            "rawUserInfo": self.kGoogleProfile,
                                            "username": self.kGoogleDisplayName])
    }
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

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, GoogleAuthProvider.id)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(serverErrorMessage: "EMAIL_EXISTS")
    }
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

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyAssertionRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, AuthProviderID.apple.rawValue)
      XCTAssertEqual(request.providerIDToken, kAppleIDToken)
      XCTAssertEqual(request.fullName, fullName)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": RPCBaseTests.kFakeAccessToken,
                                            "refreshToken": self.kRefreshToken,
                                            "federatedId": self.kGoogleID,
                                            "providerId": AuthProviderID.apple.rawValue,
                                            "localId": self.kLocalID,
                                            "displayName": self.kGoogleDisplayName,
                                            "rawUserInfo": self.kGoogleProfile,
                                            "firstName": kFirst,
                                            "lastName": kLast,
                                            "username": self.kGoogleDisplayName])
    }
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
        XCTAssertEqual(additionalUserInfo.providerID, AuthProviderID.apple.rawValue)
      } catch {
        XCTFail("\(error)")
      }
      XCTAssertNil(error)
      expectation.fulfill()
    }
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

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? SignUpNewUserRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertNil(request.email)
      XCTAssertNil(request.password)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                            "email": self.kEmail,
                                            "isNewUser": true,
                                            "refreshToken": self.kRefreshToken])
    }
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
      XCTAssertEqual(userInfo.providerID, "")
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    try assertUserAnonymous(XCTUnwrap(auth?.currentUser))
  }

  /** @fn testSignInAnonymouslyFailure
      @brief Tests the flow of a failed @c signInAnonymouslyWithCompletion: call.
   */
  func testSignInAnonymouslyFailure() throws {
    let expectation = self.expectation(description: #function)

    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(serverErrorMessage: "OPERATION_NOT_ALLOWED")
    }
    try auth?.signOut()
    auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(email)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.operationNotAllowed.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
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

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyCustomTokenRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.token, self.kCustomToken)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                            "email": self.kEmail,
                                            "isNewUser": false,
                                            "refreshToken": self.kRefreshToken])
    }
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
      XCTAssertEqual(userInfo.providerID, "")
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  /** @fn testSignInWithCustomTokenFailure
      @brief Tests the flow of a failed @c signInWithCustomToken:completion: call.
   */
  func testSignInWithCustomTokenFailure() throws {
    let expectation = self.expectation(description: #function)

    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(serverErrorMessage: "INVALID_CUSTOM_TOKEN")
    }
    try auth?.signOut()
    auth?.signIn(withCustomToken: kCustomToken) { authResult, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult?.user)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidCustomToken.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
    XCTAssertNil(auth?.currentUser)
  }

  #if os(iOS)
    /** @fn testCreateUserWithEmailPasswordWithRecaptchaVerificationSuccess
        @brief Tests the flow of a successful @c createUserWithEmail:password:completion: call.
     */
    func testCreateUserWithEmailPasswordWithRecaptchaVerificationSuccess() throws {
      let expectation = self.expectation(description: #function)
      let kTestRecaptchaKey = "projects/123/keys/456"
      rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey
      setFakeSecureTokenService()
      setFakeGetAccountProvider()

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? SignUpNewUserRequest)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.password, self.kFakePassword)
        XCTAssertTrue(request.returnSecureToken)

        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                              "email": self.kEmail,
                                              "isNewUser": true,
                                              "refreshToken": self.kRefreshToken])
      }
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
      waitForExpectations(timeout: 5)
      assertUser(auth?.currentUser)
    }

    /** @fn testCreateUserWithEmailPasswordWithRecaptchaVerificationFallbackSuccess
        @brief Tests the flow of a successful @c createUserWithEmail:password:completion: call.
     */
    func testCreateUserWithEmailPasswordWithRecaptchaVerificationFallbackSuccess() throws {
      let expectation = self.expectation(description: #function)
      let kTestRecaptchaKey = "projects/123/keys/456"
      rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey
      setFakeSecureTokenService()
      setFakeGetAccountProvider()

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? SignUpNewUserRequest)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.password, self.kFakePassword)
        XCTAssertTrue(request.returnSecureToken)

        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(serverErrorMessage: "MISSING_RECAPTCHA_TOKEN")
      }
      rpcIssuer.nextRespondBlock = {
        // 4. Validate again the created Request instance after the recaptcha retry.
        let request = try XCTUnwrap(self.rpcIssuer.request as? SignUpNewUserRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.password, self.kFakePassword)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertTrue(request.returnSecureToken)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)
        // 5. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                              "email": self.kEmail,
                                              "isNewUser": true,
                                              "refreshToken": self.kRefreshToken])
      }

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
      waitForExpectations(timeout: 5)
      assertUser(auth?.currentUser)
    }
  #endif

  /** @fn testCreateUserWithEmailPasswordSuccess
      @brief Tests the flow of a successful @c createUserWithEmail:password:completion: call.
   */
  func testCreateUserWithEmailPasswordSuccess() throws {
    let expectation = self.expectation(description: #function)
    setFakeSecureTokenService()
    setFakeGetAccountProvider()

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? SignUpNewUserRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.email, self.kEmail)
      XCTAssertEqual(request.password, self.kFakePassword)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                            "email": self.kEmail,
                                            "isNewUser": true,
                                            "refreshToken": self.kRefreshToken])
    }
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
    waitForExpectations(timeout: 5)
    assertUser(auth?.currentUser)
  }

  /** @fn testCreateUserWithEmailPasswordFailure
      @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call.
   */
  func testCreateUserWithEmailPasswordFailure() throws {
    let expectation = self.expectation(description: #function)
    let reason = "The password must be 6 characters long or more."

    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(serverErrorMessage: "WEAK_PASSWORD")
    }
    try auth?.signOut()
    auth?.createUser(withEmail: kEmail, password: kFakePassword) { authResult, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult?.user)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.weakPassword.rawValue)
      XCTAssertEqual((error as? NSError)?.userInfo[NSLocalizedDescriptionKey] as? String, reason)
      expectation.fulfill()
    }
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
          empty email address. This error occurs on the client side, so there is no need to fake an
          RPC response.
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

  #if os(iOS)
    /** @fn testSendPasswordResetEmailWithRecaptchaSuccess
        @brief Tests the flow of a successful @c sendPasswordResetWithEmail:completion: call.
     */
    func testSendPasswordResetEmailWithRecaptchaSuccess() throws {
      let expectation = self.expectation(description: #function)
      let kTestRecaptchaKey = "projects/123/keys/456"
      rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? GetOOBConfirmationCodeRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)

        // 3. Send the response from the fake backend.
        _ = try self.rpcIssuer.respond(withJSON: [:])
      }
      auth?.sendPasswordReset(withEmail: kEmail) { error in
        // 4. After the response triggers the callback, verify success.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testSendPasswordResetEmailWithRecaptchaFallbackSuccess
        @brief Tests the flow of a successful @c sendPasswordResetWithEmail:completion: call.
     */
    func testSendPasswordResetEmailWithRecaptchaFallbackSuccess() throws {
      let expectation = self.expectation(description: #function)
      let kTestRecaptchaKey = "projects/123/keys/456"
      rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? GetOOBConfirmationCodeRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)

        // 3. Send the response from the fake backend.
        try self.rpcIssuer.respond(serverErrorMessage: "MISSING_RECAPTCHA_TOKEN")
      }
      rpcIssuer.nextRespondBlock = {
        // 4. Validate again the created Request instance after the recaptcha retry.
        let request = try XCTUnwrap(self.rpcIssuer.request as? GetOOBConfirmationCodeRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)
        // 5. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                              "email": self.kEmail,
                                              "isNewUser": true,
                                              "refreshToken": self.kRefreshToken])
      }

      auth?.sendPasswordReset(withEmail: kEmail) { error in
        // 4. After the response triggers the callback, verify success.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  #endif

  /** @fn testSendPasswordResetEmailSuccess
      @brief Tests the flow of a successful @c sendPasswordReset call.
   */
  func testSendPasswordResetEmailSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? GetOOBConfirmationCodeRequest)
      XCTAssertEqual(request.email, self.kEmail)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)

      // 3. Send the response from the fake backend.
      _ = try self.rpcIssuer.respond(withJSON: [:])
    }
    auth?.sendPasswordReset(withEmail: kEmail) { error in
      // 4. After the response triggers the callback, verify success.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testSendPasswordResetEmailFailure
      @brief Tests the flow of a failed @c sendPasswordReset call.
   */
  func testSendPasswordResetEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(underlyingErrorMessage: "ipRefererBlocked")
    }
    auth?.sendPasswordReset(withEmail: kEmail) { error in
      XCTAssertTrue(Thread.isMainThread)
      let rpcError = (error as? NSError)!
      XCTAssertEqual(rpcError.code, AuthErrorCode.appNotAuthorized.rawValue)
      XCTAssertNotNil(rpcError.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  #if os(iOS)
    /** @fn testSendSignInLinkToEmailWithRecaptchaSuccess
        @brief Tests the flow of a successful @c sendSignInLinkToEmail:actionCodeSettings:  call.
     */
    func testSendSignInLinkToEmailWithRecaptchaSuccess() throws {
      let expectation = self.expectation(description: #function)
      let kTestRecaptchaKey = "projects/123/keys/456"
      rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? GetOOBConfirmationCodeRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertEqual(request.continueURL, self.kContinueURL)
        XCTAssertTrue(request.handleCodeInApp)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)

        // 3. Send the response from the fake backend.
        _ = try self.rpcIssuer.respond(withJSON: [:])
      }
      auth?.sendSignInLink(toEmail: kEmail,
                           actionCodeSettings: fakeActionCodeSettings()) { error in
        // 4. After the response triggers the callback, verify success.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }

    /** @fn testSendSignInLinkToEmailWithRecaptchaFallbackSuccess
        @brief Tests the flow of a successful @c sendSignInLinkToEmail:actionCodeSettings:  call.
     */
    func testSendSignInLinkToEmailWithRecaptchaFallbackSuccess() throws {
      let expectation = self.expectation(description: #function)
      let kTestRecaptchaKey = "projects/123/keys/456"
      rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey

      // 1. Setup respond block to test and fake send request.
      rpcIssuer.respondBlock = {
        // 2. Validate the created Request instance.
        let request = try XCTUnwrap(self.rpcIssuer.request as? GetOOBConfirmationCodeRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        XCTAssertEqual(request.continueURL, self.kContinueURL)
        XCTAssertTrue(request.handleCodeInApp)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)

        // 3. Send the response from the fake backend.
        _ = try self.rpcIssuer.respond(withJSON: [:])
      }
      rpcIssuer.nextRespondBlock = {
        // 4. Validate again the created Request instance after the recaptcha retry.
        let request = try XCTUnwrap(self.rpcIssuer.request as? GetOOBConfirmationCodeRequest)
        XCTAssertEqual(request.email, self.kEmail)
        XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
        request.injectRecaptchaFields(recaptchaResponse: AuthTests.kFakeRecaptchaResponse,
                                      recaptchaVersion: AuthTests.kFakeRecaptchaVersion)
        // 5. Send the response from the fake backend.
        try self.rpcIssuer.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                              "email": self.kEmail,
                                              "isNewUser": true,
                                              "refreshToken": self.kRefreshToken])
      }

      auth?.sendSignInLink(toEmail: kEmail,
                           actionCodeSettings: fakeActionCodeSettings()) { error in
        // 4. After the response triggers the callback, verify success.
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertNil(error)
        expectation.fulfill()
      }
      waitForExpectations(timeout: 5)
    }
  #endif

  /** @fn testSendSignInLinkToEmailSuccess
      @brief Tests the flow of a successful @c sendSignInLinkToEmail call.
   */
  func testSendSignInLinkToEmailSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Setup respond block to test and fake send request.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? GetOOBConfirmationCodeRequest)
      XCTAssertEqual(request.email, self.kEmail)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.continueURL, self.kContinueURL)
      XCTAssertTrue(request.handleCodeInApp)

      // 3. Send the response from the fake backend.
      _ = try self.rpcIssuer.respond(withJSON: [:])
    }
    auth?.sendSignInLink(toEmail: kEmail,
                         actionCodeSettings: fakeActionCodeSettings()) { error in
      // 4. After the response triggers the callback, verify success.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testSendSignInLinkToEmailFailure
      @brief Tests the flow of a failed @c sendSignInLink call.
   */
  func testSendSignInLinkToEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(underlyingErrorMessage: "ipRefererBlocked")
    }
    auth?.sendSignInLink(toEmail: kEmail,
                         actionCodeSettings: fakeActionCodeSettings()) { error in
      XCTAssertTrue(Thread.isMainThread)
      let rpcError = error as? NSError
      XCTAssertEqual(rpcError?.code, AuthErrorCode.appNotAuthorized.rawValue)
      XCTAssertNotNil(rpcError?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
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
    rpcIssuer.respondBlock = {
      try self.rpcIssuer.respond(underlyingErrorMessage: "keyInvalid")
    }
    // Clear fake so we can inject error
    rpcIssuer.fakeGetAccountProviderJSON = nil
    auth.updateCurrentUser(user2) { error in
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidAPIKey.rawValue)
      expectation.fulfill()
    }
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
    rpcIssuer.respondBlock = {
      let kFakeErrorDomain = "fakeDomain"
      let kFakeErrorCode = -1
      let responseError = NSError(domain: kFakeErrorDomain, code: kFakeErrorCode)
      try self.rpcIssuer.respond(withData: nil, error: responseError)
    }
    // Clear fake so we can inject error
    rpcIssuer.fakeGetAccountProviderJSON = nil
    auth.updateCurrentUser(user2) { error in
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.networkError.rawValue)
      expectation.fulfill()
    }
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

  /** @fn testRevokeTokenSuccess
      @brief Tests the flow of a successful @c revokeToken:completion.
   */
  func testRevokeTokenSuccess() throws {
    try waitForSignInWithAccessToken()
    let expectation = self.expectation(description: #function)
    let code = "code"

    rpcIssuer.respondBlock = {
      let request = try XCTUnwrap(self.rpcIssuer.request as? RevokeTokenRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, AuthProviderID.apple.rawValue)
      XCTAssertEqual(request.token, code)
      XCTAssertEqual(request.tokenType, .authorizationCode)

      // Send the response from the fake backend.
      _ = try self.rpcIssuer.respond(withJSON: [:])
    }
    auth?.revokeToken(withAuthorizationCode: code) { error in
      // Verify callback success.
      XCTAssertNil(error)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 5)
  }

  /** @fn testRevokeTokenMissingCallback
      @brief Tests the flow of  @c revokeToken:completion with a nil callback.
   */
  func testRevokeTokenMissingCallback() throws {
    try waitForSignInWithAccessToken()
    let code = "code"
    let issuer = rpcIssuer

    issuer?.respondBlock = {
      let request = try XCTUnwrap(issuer?.request as? RevokeTokenRequest)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertEqual(request.providerID, AuthProviderID.apple.rawValue)
      XCTAssertEqual(request.token, code)
      XCTAssertEqual(request.tokenType, .authorizationCode)

      // Send the response from the fake backend.
      _ = try issuer?.respond(withJSON: [:])
    }
    auth?.revokeToken(withAuthorizationCode: code)
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
    var fulfilled = false
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
      if !fulfilled {
        fulfilled = true
        expectation?.fulfill()
      }
    }
    try auth.signOut()

    // Listener should fire immediately when attached.
    expectation = self.expectation(description: "initial")
    shouldHaveUser = false
    let handle = auth.addIDTokenDidChangeListener(listener)
    waitForExpectations(timeout: 5)
    expectation = nil

    // Listener should fire for signing in. Expectation is waited on in
    // waitForSignInWithAccessToken.
    fulfilled = false
    expectation = self.expectation(description: "sign-in")
    shouldHaveUser = true
    try waitForSignInWithAccessToken()

    // Listener should not fire for signing in again.
    expectation = nil
    shouldHaveUser = true
    try waitForSignInWithAccessToken()

    // Listener should fire for signing in again as the same user with another access token.
    fulfilled = false
    expectation = self.expectation(description: "sign-in")
    shouldHaveUser = true
    try waitForSignInWithAccessToken(fakeAccessToken: AuthTests.kNewAccessToken)

    // Listener should fire for signing out.
    fulfilled = false
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
    RPCBaseTests.waitSleep()
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
    rpcIssuer.secureTokenErrorString = "INVALID_ID_TOKEN"

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
    RPCBaseTests.waitSleep()
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
    rpcIssuer.secureTokenNetworkError = NSError(domain: "ERROR", code: -1)

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

    rpcIssuer.secureTokenNetworkError = nil
    setFakeSecureTokenService(fakeAccessToken: AuthTests.kNewAccessToken)

    // The old access token should still be the current user's access token and not the new access
    // token (kNewAccessToken).
    XCTAssertEqual(AuthTests.kAccessToken, auth.currentUser?.rawAccessToken())

    // Execute saved token refresh task.
    let expectation2 = self.expectation(description: "dispatchAfterExpectation")
    kAuthGlobalWorkQueue.async {
      RPCBaseTests.waitSleep()
      XCTAssertNotNil(self.authDispatcherCallback)
      self.authDispatcherCallback?()
      expectation2.fulfill()
    }
    waitForExpectations(timeout: 5)
    waitForAuthGlobalWorkQueueDrain()

    // Time for callback to run.
    RPCBaseTests.waitSleep()

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

      // Verify that the current user's access token is the "old" access token before automatic
      // token refresh.
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

      // Time for callback to run.
      RPCBaseTests.waitSleep()

      // Verify that current user's access token is the "new" access token provided in the mock
      // secure token response during automatic token refresh.
      XCTAssertEqual(AuthTests.kNewAccessToken, auth.currentUser?.rawAccessToken())
    }
  #endif

  // MARK: Application Delegate tests.

  #if os(iOS)
    func testAppDidRegisterForRemoteNotifications_APNSTokenUpdated() {
      class FakeAuthTokenManager: AuthAPNSTokenManager {
        override var token: AuthAPNSToken? {
          get {
            return tokenStore
          }
          set(setToken) {
            tokenStore = setToken
          }
        }
      }
      let apnsToken = Data()
      auth.tokenManager = FakeAuthTokenManager(withApplication: UIApplication.shared)
      auth.application(UIApplication.shared,
                       didRegisterForRemoteNotificationsWithDeviceToken: apnsToken)
      XCTAssertEqual(auth.tokenManager.token?.data, apnsToken)
      XCTAssertEqual(auth.tokenManager.token?.type, .unknown)
    }

    func testAppDidFailToRegisterForRemoteNotifications_TokenManagerCancels() {
      class FakeAuthTokenManager: AuthAPNSTokenManager {
        var cancelled = false
        override func cancel(withError error: Error) {
          cancelled = true
        }
      }
      let error = NSError(domain: "AuthTests", code: -1)
      let fakeTokenManager = FakeAuthTokenManager(withApplication: UIApplication.shared)
      auth.tokenManager = fakeTokenManager
      XCTAssertFalse(fakeTokenManager.cancelled)
      auth.application(UIApplication.shared,
                       didFailToRegisterForRemoteNotificationsWithError: error)
      XCTAssertTrue(fakeTokenManager.cancelled)
    }

    func testAppDidReceiveRemoteNotificationWithCompletion_NotificationManagerHandleCanNotification() {
      class FakeNotificationManager: AuthNotificationManager {
        var canHandled = false
        override func canHandle(notification: [AnyHashable: Any]) -> Bool {
          canHandled = true
          return true
        }
      }
      let notification = ["test": ""]
      let fakeKeychain = AuthKeychainServices(
        service: "AuthTests",
        storage: FakeAuthKeychainStorage()
      )
      let appCredentialManager = AuthAppCredentialManager(withKeychain: fakeKeychain)
      let fakeNotificationManager = FakeNotificationManager(withApplication: UIApplication.shared,
                                                            appCredentialManager: appCredentialManager)
      auth.notificationManager = fakeNotificationManager
      XCTAssertFalse(fakeNotificationManager.canHandled)
      auth.application(UIApplication.shared,
                       didReceiveRemoteNotification: notification) { _ in
      }
      XCTAssertTrue(fakeNotificationManager.canHandled)
    }

    func testAppOpenURL_AuthPresenterCanHandleURL() throws {
      class FakeURLPresenter: AuthURLPresenter {
        var canHandled = false
        override func canHandle(url: URL) -> Bool {
          canHandled = true
          return true
        }
      }
      let url = try XCTUnwrap(URL(string: "https://localhost"))
      let fakeURLPresenter = FakeURLPresenter()
      auth.authURLPresenter = fakeURLPresenter
      XCTAssertFalse(fakeURLPresenter.canHandled)
      XCTAssertTrue(auth.application(UIApplication.shared, open: url, options: [:]))
      XCTAssertTrue(fakeURLPresenter.canHandled)
    }
  #endif // os(iOS)

  // MARK: Interoperability Tests

  func testComponentsRegistered() throws {
    // Verify that the components are registered properly. Check the count, because any time a new
    // component is added it should be added to the test suite as well.
    XCTAssertEqual(AuthComponent.componentsToRegister().count, 1)
    // TODO: Can/should we do something like?
    //  XCTAssert(component.protocol == @protocol(FIRAuthInterop));
  }

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

    // 1. Set up respondBlock to test request and send it to generate a fake response.
    rpcIssuer.respondBlock = {
      // 2. Validate the created Request instance.
      let request = try XCTUnwrap(self.rpcIssuer.request as? VerifyPasswordRequest)
      XCTAssertEqual(request.email, self.kEmail)
      XCTAssertEqual(request.password, self.kFakePassword)
      XCTAssertEqual(request.apiKey, AuthTests.kFakeAPIKey)
      XCTAssertTrue(request.returnSecureToken)

      // 3. Send the response from the fake backend.
      try self.rpcIssuer.respond(withJSON: ["idToken": fakeAccessToken,
                                            "email": self.kEmail,
                                            "isNewUser": true,
                                            "expiresIn": "3600",
                                            "refreshToken": kRefreshToken])
    }
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
