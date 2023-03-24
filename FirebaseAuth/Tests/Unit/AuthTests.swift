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
  private let kEmail = "user@company.com"
  private let kFakePassword = "!@#$%^"
  private let kDisplayName = "DisplayName"
  private let kLocalID = "testLocalId"
  static let kAccessToken = "TEST_ACCESS_TOKEN"
  private let kFakeOobCode = "fakeOobCode"
  private let kRefreshToken = "fakeRefreshToken"
  private let kCustomToken = "CUSTOM_TOKEN"
  private let kFakeEmailSignInLink = "https://test.app.goo.gl/?link=https://test.firebase" +
    "app.com/__/auth/action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueU" +
    "rl%3Dhttps://test.apps.com&ibi=com.test.com&ifl=https://test.firebaseapp.com/__/auth/" +
    "action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://" +
    "test.apps.com"
  private let kFakeEmailSignInDeeplink =
    "https://example.domain.com/?apiKey=testAPIKey&oobCode=testoobcode&mode=signIn"
  private let kContinueURL = "continueURL"
  static let kFakeAPIKey = "FAKE_API_KEY"
  static var auth: Auth?

  override class func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = kFakeAPIKey
    options.projectID = "myProjectID"
    FirebaseApp.configure(name: "test-AuthTests", options: options)
    auth = Auth.auth(app: FirebaseApp.app(name: "test-AuthTests")!)
  }

  override func setUp() {
    super.setUp()
    // Set FIRAuthDispatcher implementation in order to save the token refresh task for later
    // execution.
    AuthDispatcher.shared.dispatchAfterImplementation = { delay, queue, task in
      XCTAssertNotNil(task)
      XCTAssertGreaterThan(delay, 0)
      // TODO:
      XCTFail("implement this")
      // XCTAssertEqual(FIRAuthGlobalWorkQueue(), queue)
      //          XCTAssertEqualObjects(FIRAuthGlobalWorkQueue(), queue);
      //          self->_FIRAuthDispatcherCallback = task;
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

    AuthTests.auth?.fetchSignInMethods(forEmail: kEmail) { signInMethods, error in
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

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

    AuthTests.auth?.fetchSignInMethods(forEmail: kEmail) { signInMethods, error in
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

  // TODO: Three PhoneAuth tests here.

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

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signIn(withEmail: kEmail, link: link) { authResult, error in
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])

    waitForExpectations(timeout: 10)
    assertUser(AuthTests.auth?.currentUser)
  }

  /** @fn testSignInWithEmailLinkFailure
      @brief Tests the flow of a failed @c signInWithEmail:link:completion: call.
   */
  func testSignInWithEmailLinkFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signIn(withEmail: kEmail, link: kFakeEmailSignInLink) { authResult, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "INVALID_OOB_CODE")
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
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

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])

    waitForExpectations(timeout: 10)
    assertUser(AuthTests.auth?.currentUser)
  }

  /** @fn testSignInWithEmailPasswordFailure
      @brief Tests the flow of a failed @c signInWithEmail:password:completion: call.
   */
  func testSignInWithEmailPasswordFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
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
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
  }

  /** @fn testResetPasswordSuccess
      @brief Tests the flow of a successful @c confirmPasswordResetWithCode:newPassword:completion:
          call.
   */
  func testResetPasswordSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: [:])

    waitForExpectations(timeout: 10)
  }

  /** @fn testResetPasswordFailure
      @brief Tests the flow of a failed @c confirmPasswordResetWithCode:newPassword:completion:
          call.
   */
  func testResetPasswordFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?
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
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
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

    try AuthTests.auth?.signOut()
    AuthTests.auth?.checkActionCode(kFakeOobCode) { info, error in
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["email": kEmail,
                                      "requestType": verifyEmailRequestType,
                                      "newEmail": kNewEmail])
    waitForExpectations(timeout: 10)
  }

  /** @fn testCheckActionCodeFailure
      @brief Tests the flow of a failed @c checkActionCode:completion call.
   */
  func testCheckActionCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.checkActionCode(kFakeOobCode) { info, error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.expiredActionCode.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "EXPIRED_OOB_CODE")
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
  }

  /** @fn testApplyActionCodeSuccess
      @brief Tests the flow of a successful @c applyActionCode:completion call.
   */
  func testApplyActionCodeSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.applyActionCode(kFakeOobCode) { error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? SetAccountInfoRequest)
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: [:])
    waitForExpectations(timeout: 10)
  }

  /** @fn testApplyActionCodeFailure
      @brief Tests the flow of a failed @c checkActionCode:completion call.
   */
  func testApplyActionCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.applyActionCode(kFakeOobCode) { error in
      // 3. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.invalidActionCode.rawValue)
      XCTAssertNotNil((error as? NSError)?.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    // 2. Send the response from the fake backend.
    try rpcIssuer?.respond(serverErrorMessage: "INVALID_OOB_CODE")
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
  }

  /** @fn testVerifyPasswordResetCodeSuccess
      @brief Tests the flow of a successful @c verifyPasswordResetCode:completion call.
   */
  func testVerifyPasswordResetCodeSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
      // 4. After the response triggers the callback, verify the returned result.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(email, self.kEmail)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? ResetPasswordRequest)
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.oobCode, kFakeOobCode)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["email": kEmail])
    waitForExpectations(timeout: 10)
  }

  /** @fn testVerifyPasswordResetCodeFailure
      @brief Tests the flow of a failed @c verifyPasswordResetCode:completion call.
   */
  func testVerifyPasswordResetCodeFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
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
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
  }

  // TODO: 12 tests signIn(withCredential ...) not visible in swift

  /** @fn testSignInAnonymouslySuccess
      @brief Tests the flow of a successful @c signInAnonymouslyWithCompletion: call.
   */
  func testSignInAnonymouslySuccess() throws {
    let expectation = self.expectation(description: #function)
    setFakeSecureTokenService()
    setFakeGetAccountProviderAnonymous()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signInAnonymously { authResult, error in
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
    XCTAssertNil(request.email)
    XCTAssertNil(request.password)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])
    waitForExpectations(timeout: 10)
    assertUserAnonymous(try XCTUnwrap(AuthTests.auth?.currentUser))
  }

  /** @fn testSignInAnonymouslyFailure
      @brief Tests the flow of a failed @c signInAnonymouslyWithCompletion: call.
   */
  func testSignInAnonymouslyFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.verifyPasswordResetCode(kFakeOobCode) { email, error in
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
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
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

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signIn(withCustomToken: kCustomToken) { authResult, error in
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.token, kCustomToken)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": false,
                                      "refreshToken": kRefreshToken])
    waitForExpectations(timeout: 10)
    assertUser(AuthTests.auth?.currentUser)
  }

  /** @fn testSignInWithCustomTokenFailure
      @brief Tests the flow of a failed @c signInWithCustomToken:completion: call.
   */
  func testSignInWithCustomTokenFailure() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signIn(withCustomToken: kCustomToken) { authResult, error in
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
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
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

    try AuthTests.auth?.signOut()
    AuthTests.auth?.createUser(withEmail: kEmail, password: kFakePassword) { authResult, error in
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.password, kFakePassword)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": AuthTests.kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])
    waitForExpectations(timeout: 10)
    assertUser(AuthTests.auth?.currentUser)
  }

  /** @fn testCreateUserWithEmailPasswordFailure
      @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call.
   */
  func testCreateUserWithEmailPasswordFailure() throws {
    let expectation = self.expectation(description: #function)
    let reason = "The password must be 6 characters long or more."

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.createUser(withEmail: kEmail, password: kFakePassword) { authResult, error in
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
    waitForExpectations(timeout: 10)
    XCTAssertNil(AuthTests.auth?.currentUser)
  }

  /** @fn testCreateUserEmptyPasswordFailure
      @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call due to an
          empty password. This error occurs on the client side, so there is no need to fake an RPC
          response.
   */
  func testCreateUserEmptyPasswordFailure() throws {
    let expectation = self.expectation(description: #function)
    try AuthTests.auth?.signOut()
    AuthTests.auth?.createUser(withEmail: kEmail, password: "") { authResult, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult?.user)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.weakPassword.rawValue)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 10)
  }

  /** @fn testCreateUserEmptyEmailFailure
      @brief Tests the flow of a failed @c createUserWithEmail:password:completion: call due to an
          empty email adress. This error occurs on the client side, so there is no need to fake an RPC
          response.
   */
  func testCreateUserEmptyEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    try AuthTests.auth?.signOut()
    AuthTests.auth?.createUser(withEmail: "", password: kFakePassword) { authResult, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(authResult?.user)
      XCTAssertEqual((error as? NSError)?.code, AuthErrorCode.missingEmail.rawValue)
      expectation.fulfill()
    }
    waitForExpectations(timeout: 10)
  }

  /** @fn testSendPasswordResetEmailSuccess
      @brief Tests the flow of a successful @c sendPasswordReset call.
   */
  func testSendPasswordResetEmailSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake rpcIssuer in `fetchSignInMethods`.
    let group = createGroup()

    AuthTests.auth?.sendPasswordReset(withEmail: kEmail) { error in
      // 4. After the response triggers the callback, verify success.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake rpcIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(rpcIssuer?.request as? GetOOBConfirmationCodeRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

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

    AuthTests.auth?.sendPasswordReset(withEmail: kEmail) { error in
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

    AuthTests.auth?.sendSignInLink(toEmail: kEmail,
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
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

    AuthTests.auth?.sendSignInLink(toEmail: kEmail,
                                   actionCodeSettings: fakeActionCodeSettings()) { error in
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

  /** @fn testUpdateCurrentUserFailure
      @brief Tests the flow of a failed @c updateCurrentUser:completion:
          call.
   */
  func testUpdateCurrentUserFailure() throws {
    let kTestAccessToken = "fakeAccessToken"
    // try waitForSignInWithAccessToken(fakeAccessToken: kTestAccessToken)
    let kTestAPIKey2 = "fakeAPIKey2"
    // TODO: next line deadlocks
    let user2 = AuthTests.auth?.currentUser

    // TODO: requestConfiguration not visible in FIRUser yet.
//    user2?.requestConfiguration = AuthRequestConfiguration(APIKey: kTestAPIKey2, appID: kTestFirebaseAppID)
  }

//  - (void)testUpdateCurrentUserFailure {
//    NSString *kTestAccessToken = @"fakeAccessToken";
//    NSString *kTestAPIKey = @"fakeAPIKey";
//    [self waitForSignInWithAccessToken:kTestAccessToken APIKey:kTestAPIKey completion:nil];
//    NSString *kTestAPIKey2 = @"fakeAPIKey2";
//    FIRUser *user2 = [FIRAuth auth].currentUser;
//    user2.requestConfiguration = [[FIRAuthRequestConfiguration alloc] initWithAPIKey:kTestAPIKey2
//                                                                               appID:kFirebaseAppID];
//    OCMExpect([_mockBackend getAccountInfo:[OCMArg any] callback:[OCMArg any]])
//        .andDispatchError2([FIRAuthErrorUtils invalidAPIKeyError]);
//    XCTestExpectation *expectation = [self expectationWithDescription:@"callback"];
//    [[FIRAuth auth] updateCurrentUser:user2
//                           completion:^(NSError *_Nullable error) {
//                             XCTAssertEqual(error.code, FIRAuthErrorCodeInvalidAPIKey);
//                             [expectation fulfill];
//                           }];
//    [self waitForExpectationsWithTimeout:kExpectationTimeout handler:nil];
//    OCMVerifyAll(_mockBackend);
//  }

  // MARK: Helper Functions

  private func waitForSignInWithAccessToken(fakeAccessToken: String = kAccessToken) throws {
    let kRefreshToken = "fakeRefreshToken"
    let expectation = self.expectation(description: #function)
    setFakeGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake rpcIssuer.
    let group = createGroup()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signIn(withEmail: kEmail, password: kFakePassword) { authResult, error in
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
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
    XCTAssertTrue(request.returnSecureToken)

    // 3. Send the response from the fake backend.
    try rpcIssuer?.respond(withJSON: ["idToken": fakeAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "refreshToken": kRefreshToken])

    waitForExpectations(timeout: 10)
    assertUser(AuthTests.auth?.currentUser)
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

  private func setFakeSecureTokenService() {
    rpcIssuer?.fakeSecureTokenServiceJSON = ["access_token": AuthTests.kAccessToken]
  }

  private func setFakeGetAccountProvider() {
    let kProviderUserInfoKey = "providerUserInfo"
    let kPhotoUrlKey = "photoUrl"
    let kTestPhotoURL = "testPhotoURL"
    let kProviderIDkey = "providerId"
    let kDisplayNameKey = "displayName"
    let kFederatedIDKey = "federatedId"
    let kTestFederatedID = "testFederatedId"
    let kEmailKey = "email"
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kTestProviderID = "testProviderID"
    let kEmailVerifiedKey = "emailVerified"
    let kLocalIDKey = "localId"

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kProviderUserInfoKey: [[
        kProviderIDkey: kTestProviderID,
        kDisplayNameKey: kDisplayName,
        kPhotoUrlKey: kTestPhotoURL,
        kFederatedIDKey: kTestFederatedID,
        kEmailKey: kEmail,
      ]],
      kLocalIDKey: kLocalID,
      kDisplayNameKey: kDisplayName,
      kEmailKey: kEmail,
      kPhotoUrlKey: kTestPhotoURL,
      kEmailVerifiedKey: true,
      kPasswordHashKey: kTestPasswordHash,
    ]]
  }

  private func setFakeGetAccountProviderAnonymous() {
    let kPasswordHashKey = "passwordHash"
    let kTestPasswordHash = "testPasswordHash"
    let kLocalIDKey = "localId"

    rpcIssuer?.fakeGetAccountProviderJSON = [[
      kLocalIDKey: kLocalID,
      kPasswordHashKey: kTestPasswordHash,
    ]]
  }

  private func createGroup() -> DispatchGroup {
    let group = DispatchGroup()
    rpcIssuer?.group = group
    group.enter()
    return group
  }

  private func fakeActionCodeSettings() -> ActionCodeSettings {
    let settings = ActionCodeSettings()
    settings.handleCodeInApp = true
    settings.url = URL(string: kContinueURL)
    return settings
  }
}
