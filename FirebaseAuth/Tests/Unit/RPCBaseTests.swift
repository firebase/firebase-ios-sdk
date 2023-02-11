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

class RPCBaseTests: XCTestCase {
  /** @var kTestAPIKey
      @brief Fake API key used for testing.
   */
  let kTestAPIKey = "APIKey"

  /** @var kTestFirebaseAppID
      @brief Fake Firebase app ID used for testing.
   */
  let kTestFirebaseAppID = "appID"

  /** @var kTestIdentifier
      @brief Fake identifier key used for testing.
   */
  let kTestIdentifier = "Identifier"

  var RPCIssuer: FakeBackendRPCIssuer?

  override func setUp() {
    RPCIssuer = FakeBackendRPCIssuer()
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: RPCIssuer)
  }

  override func tearDown() {
    RPCIssuer = nil
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: nil)
  }

  /** @fn checkRequest
      @brief Tests the encoding of a request.
   */
  func checkRequest(request: AuthRPCRequest, expected: String, key: String, value: String) {
    AuthBackend.post(withRequest: request) { response, error in
      XCTFail("No explicit response from the fake backend.")
    }
    XCTAssertEqual(RPCIssuer?.requestURL?.absoluteString, expected)
    guard let requestDictionary = RPCIssuer?.decodedRequest as? [AnyHashable: String] else {
      XCTFail("decodedRequest is not a dictionary")
      return
    }
    XCTAssertEqual(requestDictionary[key], value)
  }

  /** @fn checkBackendError
      @brief This test checks error messagess from the backend map to the expected error codes
   */
  func checkBackendError(request: AuthRPCRequest, message: String,
                         errorCode: AuthErrorCode) throws {
    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    _ = try RPCIssuer?.respond(serverErrorMessage: message)

    XCTAssert(callbackInvoked)
    XCTAssertEqual(rpcError?.code, errorCode.rawValue)
    XCTAssertNil(rpcResponse)
  }

  func makeRequestConfiguration() -> AuthRequestConfiguration {
    return AuthRequestConfiguration(
      APIKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
  }
}
