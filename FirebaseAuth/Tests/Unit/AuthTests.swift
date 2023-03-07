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
  private let kDisplayName = "DisplayName"
  private let kLocalID = "testLocalId"
  private let kAccessToken = "TEST_ACCESS_TOKEN"
  private let kFakeEmailSignInLink = "https://test.app.goo.gl/?link=https://test.firebase" +
    "app.com/__/auth/action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueU" +
    "rl%3Dhttps://test.apps.com&ibi=com.test.com&ifl=https://test.firebaseapp.com/__/auth/" +
    "action?apiKey%3DtestAPIKey%26mode%3DsignIn%26oobCode%3Dtestoobcode%26continueUrl%3Dhttps://" +
    "test.apps.com"
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

    // 1. Create a group to synchronize request creation by the fake RPCIssuer in `fetchSignInMethods`.
    let group = DispatchGroup()
    RPCIssuer?.group = group
    group.enter()

    AuthTests.auth?.fetchSignInMethods(forEmail: kEmail) { signInMethods, error in
      // 4. After the response triggers the callback, verify the returned signInMethods.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(signInMethods, allSignInMethods)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake RPCIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(RPCIssuer?.request as? CreateAuthURIRequest)
    XCTAssertEqual(request.identifier, kEmail)
    XCTAssertEqual(request.endpoint, "createAuthUri")
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try RPCIssuer?.respond(withJSON: ["signinMethods": allSignInMethods])

    waitForExpectations(timeout: 5)
  }

  /** @fn testFetchSignInMethodsForEmailFailure
      @brief Tests the flow of a failed @c fetchSignInMethodsForEmail:completion: call.
   */
  func testFetchSignInMethodsForEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    let group = DispatchGroup()
    RPCIssuer?.group = group
    group.enter()

    AuthTests.auth?.fetchSignInMethods(forEmail: kEmail) { signInMethods, error in
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(signInMethods)
      let rpcError = (error as? NSError)!
      XCTAssertEqual(rpcError.code, AuthErrorCode.tooManyRequests.rawValue)
      expectation.fulfill()
    }
    group.wait()

    let message = "TOO_MANY_ATTEMPTS_TRY_LATER"
    try RPCIssuer?.respond(serverErrorMessage: message)

    waitForExpectations(timeout: 5)
  }

  // TODO: Three PhoneAuth tests here.

  /** @fn testSignInWithEmailLinkSuccess
      @brief Tests the flow of a successful @c signInWithEmail:link:completion: call.
   */
  func testSignInWithEmailLinkSuccess() throws {
    let fakeCode = "testoobcode"
    let kRefreshToken = "fakeRefreshToken"
    let expectation = self.expectation(description: #function)
    setFakeGetAccountProvider()
    setFakeSecureTokenService()

    // 1. Create a group to synchronize request creation by the fake RPCIssuer in `fetchSignInMethods`.
    let group = DispatchGroup()
    RPCIssuer?.group = group
    group.enter()

    try AuthTests.auth?.signOut()
    AuthTests.auth?.signIn(withEmail: kEmail, link: kFakeEmailSignInLink) { authResult, error in
      // 4. After the response triggers the callback, verify the returned signInMethods.
      XCTAssertTrue(Thread.isMainThread)
      guard let user = authResult?.user else {
        XCTFail("authResult.user is missing")
        return
      }
      XCTAssertEqual(user.refreshToken, kRefreshToken)
      XCTAssertFalse(user.isAnonymous)
      XCTAssertEqual(user.email, self.kEmail)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake RPCIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(RPCIssuer?.request as? EmailLinkSignInRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.oobCode, fakeCode)
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    try RPCIssuer?.respond(withJSON: ["idToken": kAccessToken,
                                      "email": kEmail,
                                      "isNewUser": true,
                                      "expiresIn": "kTestTokenExpirationTimeInterval",
                                      "refreshToken": kRefreshToken])

    waitForExpectations(timeout: 10)
    assertUser(try XCTUnwrap(AuthTests.auth?.currentUser))
  }

  /** @fn testSendPasswordResetEmailSuccess
      @brief Tests the flow of a successful @c sendPasswordReset call.
   */
  func testSendPasswordResetEmailSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake RPCIssuer in `fetchSignInMethods`.
    let group = DispatchGroup()
    RPCIssuer?.group = group
    group.enter()

    AuthTests.auth?.sendPasswordReset(withEmail: kEmail) { error in
      // 4. After the response triggers the callback, verify success.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake RPCIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(RPCIssuer?.request as? GetOOBConfirmationCodeRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)

    // 3. Send the response from the fake backend.
    _ = try RPCIssuer?.respond(withJSON: [:])

    waitForExpectations(timeout: 5)
  }

  /** @fn testSendPasswordResetEmailFailure
      @brief Tests the flow of a failed @c sendPasswordReset call.
   */
  func testSendPasswordResetEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    let group = DispatchGroup()
    RPCIssuer?.group = group
    group.enter()

    AuthTests.auth?.sendPasswordReset(withEmail: kEmail) { error in
      XCTAssertTrue(Thread.isMainThread)
      let rpcError = (error as? NSError)!
      XCTAssertEqual(rpcError.code, AuthErrorCode.appNotAuthorized.rawValue)
      XCTAssertNotNil(rpcError.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    try RPCIssuer?.respond(underlyingErrorMessage: "ipRefererBlocked")

    waitForExpectations(timeout: 5)
  }

//  /** @fn testSendSignInLinkToEmailSuccess
//      @brief Tests the flow of a successful @c sendSignInLinkToEmail call.
//   */
  func testSendSignInLinkToEmailSuccess() throws {
    let expectation = self.expectation(description: #function)

    // 1. Create a group to synchronize request creation by the fake RPCIssuer in `fetchSignInMethods`.
    let group = DispatchGroup()
    RPCIssuer?.group = group
    group.enter()

    AuthTests.auth?.sendSignInLink(toEmail: kEmail,
                                   actionCodeSettings: fakeActionCodeSettings()) { error in
      // 4. After the response triggers the callback, verify success.
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertNil(error)
      expectation.fulfill()
    }
    group.wait()

    // 2. After the fake RPCIssuer leaves the group, validate the created Request instance.
    let request = try XCTUnwrap(RPCIssuer?.request as? GetOOBConfirmationCodeRequest)
    XCTAssertEqual(request.email, kEmail)
    XCTAssertEqual(request.APIKey, AuthTests.kFakeAPIKey)
    XCTAssertEqual(request.continueURL, kContinueURL)
    XCTAssertTrue(request.handleCodeInApp)

    // 3. Send the response from the fake backend.
    _ = try RPCIssuer?.respond(withJSON: [:])

    waitForExpectations(timeout: 5)
  }

  private func fakeActionCodeSettings() -> ActionCodeSettings {
    let settings = ActionCodeSettings()
    settings.handleCodeInApp = true
    settings.url = URL(string: kContinueURL)
    return settings
  }

  /** @fn testSendSignInLinkToEmailFailure
      @brief Tests the flow of a failed @c sendSignInLink call.
   */
  func testSendSignInLinkToEmailFailure() throws {
    let expectation = self.expectation(description: #function)
    let group = DispatchGroup()
    RPCIssuer?.group = group
    group.enter()

    AuthTests.auth?.sendSignInLink(toEmail: kEmail,
                                   actionCodeSettings: fakeActionCodeSettings()) { error in
      XCTAssertTrue(Thread.isMainThread)
      let rpcError = (error as? NSError)!
      XCTAssertEqual(rpcError.code, AuthErrorCode.appNotAuthorized.rawValue)
      XCTAssertNotNil(rpcError.userInfo[NSLocalizedDescriptionKey])
      expectation.fulfill()
    }
    group.wait()

    try RPCIssuer?.respond(underlyingErrorMessage: "ipRefererBlocked")

    waitForExpectations(timeout: 5)
  }

  // MARK: Helper Functions

  private func assertUser(_ user: User) {
    XCTAssertEqual(user.uid, kLocalID)
    XCTAssertEqual(user.displayName, kDisplayName)
    XCTAssertEqual(user.email, kEmail)
    XCTAssertFalse(user.isAnonymous)
    XCTAssertEqual(user.providerData.count, 1)
  }

  private func setFakeSecureTokenService() {
    RPCIssuer?.fakeSecureTokenServiceJSON = ["access_token": kAccessToken]
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

    RPCIssuer?.fakeGetAccountProviderJSON = [[
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
}
