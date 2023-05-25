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

class CreateAuthURITests: RPCBaseTests {
  /** @var kContinueURITestKey
      @brief The key for the "continueUri" value in the request.
   */
  let kContinueURITestKey = "continueUri"

  /** @var kTestContinueURI
      @brief Fake Continue URI key used for testing.
   */
  let kTestContinueURI = "ContinueUri"

  /** @var kExpectedAPIURL
      @brief The expected URL for the test calls.
   */
  let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/createAuthUri?key=APIKey"

  func testCreateAuthUriRequest() throws {
    try checkRequest(
      request: makeAuthURIRequest(),
      expected: kExpectedAPIURL,
      key: kContinueURITestKey,
      value: kTestContinueURI
    )
  }

  func testCreateAuthUriErrors() throws {
    let kMissingContinueURIErrorMessage = "MISSING_CONTINUE_URI:"
    let kInvalidIdentifierErrorMessage = "INVALID_IDENTIFIER"
    let kInvalidEmailErrorMessage = "INVALID_EMAIL"
    try checkBackendError(
      request: makeAuthURIRequest(),
      message: kMissingContinueURIErrorMessage,
      errorCode: AuthErrorCode.missingContinueURI
    )
    try checkBackendError(
      request: makeAuthURIRequest(),
      message: kInvalidIdentifierErrorMessage,
      errorCode: AuthErrorCode.invalidEmail
    )
    try checkBackendError(
      request: makeAuthURIRequest(),
      message: kInvalidEmailErrorMessage,
      errorCode: AuthErrorCode.invalidEmail
    )
  }

  /** @fn testSuccessfulCreateAuthURI
      @brief This test checks for a successful response
   */
  func testSuccessfulCreateAuthURIResponse() throws {
    let kAuthUriKey = "authUri"
    let kTestAuthUri = "AuthURI"
    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(with: makeAuthURIRequest()) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }

    _ = try rpcIssuer?.respond(withJSON: [kAuthUriKey: kTestAuthUri])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(rpcResponse?.authURI, kTestAuthUri)
  }

  func testRequestAndResponseEncoding() throws {
    let kTestExpectedKind = "identitytoolkit#CreateAuthUriResponse"
    let kTestProviderID1 = "google.com"
    let kTestProviderID2 = "facebook.com"
    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(with: makeAuthURIRequest()) { response, error in
      callbackInvoked = true
      rpcResponse = response
      rpcError = error as? NSError
    }

    XCTAssertEqual(rpcIssuer?.requestURL?.absoluteString, kExpectedAPIURL)
    XCTAssertEqual(rpcIssuer?.decodedRequest?["identifier"] as? String, kTestIdentifier)
    XCTAssertEqual(rpcIssuer?.decodedRequest?["continueUri"] as? String, kTestContinueURI)

    _ = try rpcIssuer?
      .respond(withJSON: ["kind": kTestExpectedKind,
                          "allProviders": [kTestProviderID1, kTestProviderID2]])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(rpcResponse?.allProviders?.count, 2)
    XCTAssertEqual(rpcResponse?.allProviders?.first, kTestProviderID1)
    XCTAssertEqual(rpcResponse?.allProviders?[1], kTestProviderID2)
  }

  private func makeAuthURIRequest() -> CreateAuthURIRequest {
    return CreateAuthURIRequest(identifier: kTestIdentifier,
                                continueURI: kTestContinueURI,
                                requestConfiguration: makeRequestConfiguration())
  }
}
