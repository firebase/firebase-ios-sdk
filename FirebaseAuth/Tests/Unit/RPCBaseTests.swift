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
  var rpcImplementation: AuthBackendImplementation?

  override func setUp() {
    RPCIssuer = FakeBackendRPCIssuer()
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: RPCIssuer)
    rpcImplementation = AuthBackend.implementation()
  }

  override func tearDown() {
    RPCIssuer = nil
    AuthBackend.setDefaultBackendImplementationWithRPCIssuer(issuer: nil)
  }

  /** @fn checkRequest
      @brief Tests the encoding of a request.
   */
  @discardableResult func checkRequest(request: AuthRPCRequest,
                                       expected: String,
                                       key: String,
                                       value: String?,
                                       checkPostBody: Bool = false) throws -> FakeBackendRPCIssuer {
    AuthBackend.post(withRequest: request) { response, error in
      XCTFail("No explicit response from the fake backend.")
    }
    let rpcIssuer = try XCTUnwrap(RPCIssuer)
    XCTAssertEqual(rpcIssuer.requestURL?.absoluteString, expected)
    if checkPostBody,
       let containsPostBody = request.containsPostBody?() {
      XCTAssertFalse(containsPostBody)
    } else if let requestDictionary = rpcIssuer.decodedRequest as? [String: AnyHashable] {
      XCTAssertEqual(requestDictionary[key], value)
    } else {
      XCTFail("decodedRequest is not a dictionary")
    }
    return rpcIssuer
  }

  /** @fn checkBackendError
      @brief This test checks error messagess from the backend map to the expected error codes
   */
  func checkBackendError(request: AuthRPCRequest,
                         message: String = "",
                         reason: String? = nil,
                         json: [String: AnyHashable]? = nil,
                         errorCode: AuthErrorCode,
                         errorReason: String? = nil,
                         underlyingErrorKey: String? = nil,
                         checkLocalizedDescription: String? = nil) throws {
    var callbackInvoked = false
    var rpcResponse: CreateAuthURIResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: request) { response, error in
      callbackInvoked = true
      rpcResponse = response as? CreateAuthURIResponse
      rpcError = error as? NSError
    }

    if let json = json {
      _ = try RPCIssuer?.respond(withJSON: json)
    } else if let reason = reason {
      _ = try RPCIssuer?.respond(underlyingErrorMessage: reason, message: message)
    } else {
      _ = try RPCIssuer?.respond(serverErrorMessage: message)
    }

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcResponse)
    XCTAssertEqual(rpcError?.code, errorCode.rawValue)
    if errorCode == .internalError {
      let underlyingError = try XCTUnwrap(rpcError?.userInfo[NSUnderlyingErrorKey] as? NSError)
      XCTAssertNotNil(underlyingError.userInfo[AuthErrorUtils.userInfoDeserializedResponseKey])
    }
    if let errorReason {
      XCTAssertEqual(errorReason, rpcError?.userInfo[NSLocalizedFailureReasonErrorKey] as? String)
    }
    if let checkLocalizedDescription {
      let localizedDescription = try XCTUnwrap(rpcError?
        .userInfo[NSLocalizedDescriptionKey] as? String)
      XCTAssertEqual(checkLocalizedDescription, localizedDescription)
    }
  }

  func makeRequestConfiguration() -> AuthRequestConfiguration {
    return AuthRequestConfiguration(
      APIKey: kTestAPIKey,
      appID: kTestFirebaseAppID
    )
  }
}
