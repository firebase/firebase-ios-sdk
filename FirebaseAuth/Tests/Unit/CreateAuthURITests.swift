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

class StorageAuthorizerTests: XCTestCase {
  /** @var kTestAPIKey
      @brief Fake API key used for testing.
   */
  let kTestAPIKey = "APIKey"

  /** @var kAuthUriKey
      @brief The name of the "authURI" property in the json response.
   */
  let kAuthUriKey = "authUri"

  /** @var kTestFirebaseAppID
      @brief Fake Firebase app ID used for testing.
   */
  let kTestFirebaseAppID = "appID"

  /** @var kTestAuthUri
      @brief The test value of the "authURI" property in the json response.
   */
  let kTestAuthUri = "AuthURI"

  /** @var kTestIdentifier
      @brief Fake identifier key used for testing.
   */
  let kTestIdentifier = "Identifier"

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

  /** @var kTestExpectedKind
      @brief The expected value for the "kind" parameter of a successful response.
   */

  let kTestExpectedKind = "identitytoolkit#CreateAuthUriResponse"
  /** @var kTestProviderID1
      @brief A valid value for a provider ID in the @c FIRCreateAuthURIResponse.allProviders array.
   */
  let kTestProviderID1 = "google.com"

  /** @var kTestProviderID2
      @brief A valid value for a provider ID in the @c FIRCreateAuthURIResponse.allProviders array.
   */
  let kTestProviderID2 = "facebook.com"

  /** @var kMissingContinueURIErrorMessage
      @brief The error returned by the server if continue Uri is invalid.
   */
  private let kMissingContinueURIErrorMessage = "MISSING_CONTINUE_URI:"

  /** @var kInvalidIdentifierErrorMessage
      @brief The error returned by the server if the identifier is invalid.
   */
  private let kInvalidIdentifierErrorMessage = "INVALID_IDENTIFIER"

  /** @var kInvalidEmailErrorMessage
      @brief The error returned by the server if the email is invalid.
   */
  private let kInvalidEmailErrorMessage = "INVALID_EMAIL"

  var RPCIssuer: FakeBackendRPCIssuer?

  override func setUp() {
    RPCIssuer = FakeBackendRPCIssuer()
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: RPCIssuer)
  }

  override func tearDown() {
    RPCIssuer = nil
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: nil)
  }

  /** @fn testCreateAuthUriRequest
      @brief Tests the encoding of an create auth URI request.
   */
  func testCreateAuthUriRequest() {
    let requestConfiguration = AuthRequestConfiguration(
      APIKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
    let request = CreateAuthURIRequest(identifier: kTestIdentifier,
                                       continueURI: kTestContinueURI,
                                       requestConfiguration: requestConfiguration)

    AuthBackend.post(withRequest: request) { response, error in
      XCTFail("No explicit response from the fake backend.")
    }
    XCTAssertEqual(RPCIssuer?.requestURL?.absoluteString, kExpectedAPIURL)
    guard let requestDictionary = RPCIssuer?.decodedRequest as? [AnyHashable: Any] else {
      XCTFail("decodedRequest is not a dictionary")
      return
    }
    XCTAssertEqual(requestDictionary[kContinueURITestKey] as? String, kTestContinueURI)
  }

  /** @fn testMissingContinueURIError
      @brief This test checks for invalid continue URI in the response.
   */
  func testMissingContinueURIError() throws {
    let requestConfiguration = AuthRequestConfiguration(
      APIKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
    let request = CreateAuthURIRequest(identifier: kTestIdentifier,
                                       continueURI: kTestContinueURI,
                                       requestConfiguration: requestConfiguration)

    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    _ = try RPCIssuer?.respond(serverErrorMessage: kMissingContinueURIErrorMessage)

    XCTAssert(callbackInvoked)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.missingContinueURI.rawValue)
    XCTAssertNil(rpcResponse)
  }

  /** @fn testInvalidIdentifierError
      @brief This test checks for the INVALID_IDENTIFIER error message from the backend.
   */
  func testInvalidIdentifierError() throws {
    let requestConfiguration = AuthRequestConfiguration(
      APIKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
    let request = CreateAuthURIRequest(identifier: kTestIdentifier,
                                       continueURI: kTestContinueURI,
                                       requestConfiguration: requestConfiguration)

    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    _ = try RPCIssuer?.respond(serverErrorMessage: kInvalidIdentifierErrorMessage)

    XCTAssert(callbackInvoked)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.invalidEmail.rawValue)
    XCTAssertNil(rpcResponse)
  }

  /** @fn testInvalidEmailError
      @brief This test checks for INVALID_EMAIL error message from the backend.
   */
  func testInvalidEmailError() throws {
    let requestConfiguration = AuthRequestConfiguration(
      APIKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
    let request = CreateAuthURIRequest(identifier: kTestIdentifier,
                                       continueURI: kTestContinueURI,
                                       requestConfiguration: requestConfiguration)

    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    _ = try RPCIssuer?.respond(serverErrorMessage: kInvalidEmailErrorMessage)

    XCTAssert(callbackInvoked)
    XCTAssertEqual(rpcError?.code, AuthErrorCode.invalidEmail.rawValue)
    XCTAssertNil(rpcResponse)
  }

  /** @fn testSuccessfulCreateAuthURI
      @brief This test checks for a successful response
   */
  func testSuccessfulCreateAuthURIResponse() throws {
    let requestConfiguration = AuthRequestConfiguration(
      APIKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
    let request = CreateAuthURIRequest(identifier: kTestIdentifier,
                                       continueURI: kTestContinueURI,
                                       requestConfiguration: requestConfiguration)

    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    _ = try RPCIssuer?.respond(withJSON: [kAuthUriKey: kTestAuthUri])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(rpcResponse?.authURI, kTestAuthUri)
  }

  func testRequestAndResponseEncoding() throws {
    let requestConfiguration = AuthRequestConfiguration(
      APIKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
    let request = CreateAuthURIRequest(identifier: kTestIdentifier,
                                       continueURI: kTestContinueURI,
                                       requestConfiguration: requestConfiguration)
    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    XCTAssertEqual(RPCIssuer?.requestURL?.absoluteString, kExpectedAPIURL)
    XCTAssertEqual(RPCIssuer?.decodedRequest?["identifier"] as? String, kTestIdentifier)
    XCTAssertEqual(RPCIssuer?.decodedRequest?["continueUri"] as? String, kTestContinueURI)

    _ = try RPCIssuer?
      .respond(withJSON: ["kind": kTestExpectedKind,
                          "allProviders": [kTestProviderID1, kTestProviderID2]])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(rpcResponse?.allProviders?.count, 2)
    XCTAssertEqual(rpcResponse?.allProviders?.first, kTestProviderID1)
    XCTAssertEqual(rpcResponse?.allProviders?[1], kTestProviderID2)
  }
}
