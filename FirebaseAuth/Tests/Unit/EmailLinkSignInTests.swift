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
import XCTest

@testable import FirebaseAuth

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class EmailLinkSignInTests: RPCBaseTests {
  /** @var kTestEmail
      @brief The key for the "email" value in the request.
   */
  let kTestEmail = "TestEmail@email.com"

  /** @var kTestOOBCode
      @brief The test value for the "oobCode" in the request.
   */
  let kTestOOBCode = "TestOOBCode"

  /** @var kExpectedAPIURL
      @brief The expected URL for the test calls.
   */
  let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/emailLinkSignin?key=APIKey"

  /** @var kEmailKey
      @brief The key for the "identifier" value in the request.
   */
  let kEmailKey = "email"

  /** @var kEmailLinkKey
      @brief The key for the "oobCode" value in the request.
   */
  let kOOBCodeKey = "oobCode"

  /** @var kIDTokenKey
      @brief The key for the "IDToken" value in the request.
   */
  let kIDTokenKey = "idToken"

  /** @fn testEmailLinkRequestCreation
      @brief Tests the email link sign-in request with mandatory parameters.
   */
  func testEmailLinkRequest() async throws {
    rpcIssuer?.respondBlock = {
      XCTAssertEqual(self.rpcIssuer?.requestURL?.absoluteString, self.kExpectedAPIURL)
      guard let requestDictionary = self.rpcIssuer?.decodedRequest as? [AnyHashable: String] else {
        XCTFail("decodedRequest is not a dictionary")
        return
      }
      XCTAssertEqual(requestDictionary[self.kEmailKey], self.kTestEmail)
      XCTAssertEqual(requestDictionary[self.kOOBCodeKey], self.kTestOOBCode)
      XCTAssertNil(requestDictionary[self.kIDTokenKey])
      try self.rpcIssuer?.respond(withJSON: [:]) // unblock the await
    }
    let _ = try await AuthBackend.call(with: makeEmailLinkSignInRequest())
  }

  /** @fn testEmailLinkRequestCreationOptional
      @brief Tests the email link sign-in request with mandatory parameters and optional ID token.
   */
  func testEmailLinkRequestCreationOptional() async throws {
    let kTestIDToken = "testIDToken"
    let request = makeEmailLinkSignInRequest()
    request.idToken = kTestIDToken

    rpcIssuer?.respondBlock = {
      XCTAssertEqual(self.rpcIssuer?.requestURL?.absoluteString, self.kExpectedAPIURL)
      guard let requestDictionary = self.rpcIssuer?.decodedRequest as? [AnyHashable: String] else {
        XCTFail("decodedRequest is not a dictionary")
        return
      }
      XCTAssertEqual(requestDictionary[self.kEmailKey], self.kTestEmail)
      XCTAssertEqual(requestDictionary[self.kOOBCodeKey], self.kTestOOBCode)
      XCTAssertEqual(requestDictionary[self.kIDTokenKey], kTestIDToken)
      try self.rpcIssuer?.respond(withJSON: [:]) // unblock the await
    }
    let _ = try await AuthBackend.call(with: request)
  }

  func testEmailLinkSignInErrors() async throws {
    let kInvalidEmailErrorMessage = "INVALID_EMAIL"
    try await checkBackendError(
      request: makeEmailLinkSignInRequest(),
      message: kInvalidEmailErrorMessage,
      errorCode: AuthErrorCode.invalidEmail
    )
  }

  /** @fn testSuccessfulEmailLinkSignInResponse
      @brief Tests a successful email link sign-in response.
   */
  func testSuccessfulEmailLinkSignInResponse() async throws {
    let kTestIDTokenResponse = "fakeToken"
    let kTestEmailResponse = "fakeEmail@example.com"
    let kTestTokenExpirationTimeInterval: Double = 55 * 60
    let kTestRefreshToken = "testRefreshToken"

    rpcIssuer?.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: ["idToken": kTestIDTokenResponse,
                                             "email": kTestEmailResponse,
                                             "isNewUser": true,
                                             "expiresIn": "\(kTestTokenExpirationTimeInterval)",
                                             "refreshToken": kTestRefreshToken])
    }
    let response = try await AuthBackend.call(with: makeEmailLinkSignInRequest())

    XCTAssertEqual(response.idToken, kTestIDTokenResponse)
    XCTAssertEqual(response.email, kTestEmailResponse)
    XCTAssertEqual(response.refreshToken, kTestRefreshToken)
    XCTAssertTrue(response.isNewUser)
    XCTAssertEqual(response.idToken, kTestIDTokenResponse)
    let expirationTimeInterval = try XCTUnwrap(response.approximateExpirationDate)
      .timeIntervalSinceNow
    let testTimeInterval = Date(timeIntervalSinceNow: kTestTokenExpirationTimeInterval)
      .timeIntervalSinceNow
    let timeIntervalDifference = abs(expirationTimeInterval - testTimeInterval)
    XCTAssertLessThan(timeIntervalDifference, 0.001)
  }

  private func makeEmailLinkSignInRequest() -> EmailLinkSignInRequest {
    return EmailLinkSignInRequest(email: kTestEmail,
                                  oobCode: kTestOOBCode,
                                  requestConfiguration: makeRequestConfiguration())
  }
}
