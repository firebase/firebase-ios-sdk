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
      // 4. After the reponse triggers the callback, verify the returned signInMethods.
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
    _ = try RPCIssuer?.respond(withJSON: ["signinMethods": allSignInMethods])

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
      // 4. After the reponse triggers the callback, verify the returned signInMethods.
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
      // 4. After the reponse triggers the callback, verify the returned signInMethods.
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
    settings.URL = URL(string: kContinueURL)
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
}
