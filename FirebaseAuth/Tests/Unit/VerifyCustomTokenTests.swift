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
class VerifyCustomTokenTests: RPCBaseTests {
  private let kTestTokenKey = "token"
  private let kTestToken = "test token"
  private let kReturnSecureTokenKey = "returnSecureToken"
  private let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken?key=APIKey"

  /** @fn testVerifyCustomTokenRequest
      @brief Tests the verify custom token request.
   */
  func testVerifyCustomTokenRequest() async throws {
    let request = makeVerifyCustomTokenRequest()
    request.returnSecureToken = false
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kTestTokenKey,
      value: kTestToken
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertNil(requestDictionary[kReturnSecureTokenKey])
  }

  /** @fn testVerifyCustomTokenRequestOptionalFields
      @brief Tests the verify custom token request with optional fields.
   */
  func testVerifyCustomTokenRequestOptionalFields() async throws {
    let request = makeVerifyCustomTokenRequest()
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kTestTokenKey,
      value: kTestToken
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertTrue(try XCTUnwrap(requestDictionary[kReturnSecureTokenKey] as? Bool))
  }

  func testVerifyCustomTokenRequestErrors() async throws {
    let kInvalidCustomTokenErrorMessage = "INVALID_CUSTOM_TOKEN"
    let kInvalidCustomTokenServerErrorMessage = "INVALID_CUSTOM_TOKEN : Detailed Error"
    let kInvalidCustomTokenEmptyServerErrorMessage = "INVALID_CUSTOM_TOKEN :"
    let kInvalidCustomTokenErrorDetails = "Detailed Error"
    let kCredentialMismatchErrorMessage = "CREDENTIAL_MISMATCH:"

    try await checkBackendError(
      request: makeVerifyCustomTokenRequest(),
      message: kInvalidCustomTokenErrorMessage,
      errorCode: AuthErrorCode.invalidCustomToken
    )
    try await checkBackendError(
      request: makeVerifyCustomTokenRequest(),
      message: kInvalidCustomTokenServerErrorMessage,
      errorCode: AuthErrorCode.invalidCustomToken,
      checkLocalizedDescription: kInvalidCustomTokenErrorDetails
    )
    try await checkBackendError(
      request: makeVerifyCustomTokenRequest(),
      message: kInvalidCustomTokenEmptyServerErrorMessage,
      errorCode: AuthErrorCode.invalidCustomToken,
      checkLocalizedDescription: "The custom token format is incorrect. Please check the documentation."
    )
    try await checkBackendError(
      request: makeVerifyCustomTokenRequest(),
      message: kCredentialMismatchErrorMessage,
      errorCode: AuthErrorCode.customTokenMismatch
    )
  }

  /** @fn testSuccessfulVerifyCustomTokenResponse
      @brief This test simulates a successful verify CustomToken flow.
   */
  func testSuccessfulVerifyCustomTokenResponse() async throws {
    let kIDTokenKey = "idToken"
    let kTestIDToken = "ID_TOKEN"
    let kTestExpiresIn = "12345"
    let kTestRefreshToken = "REFRESH_TOKEN"
    let kExpiresInKey = "expiresIn"
    let kRefreshTokenKey = "refreshToken"
    let kIsNewUserKey = "isNewUser"

    rpcIssuer.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: [
        kIDTokenKey: kTestIDToken,
        kExpiresInKey: kTestExpiresIn,
        kRefreshTokenKey: kTestRefreshToken,
        kIsNewUserKey: true,
      ])
    }
    let rpcResponse = try await AuthBackend.call(with: makeVerifyCustomTokenRequest())
    XCTAssertEqual(rpcResponse.idToken, kTestIDToken)
    XCTAssertEqual(rpcResponse.refreshToken, kTestRefreshToken)
    let expiresIn = try XCTUnwrap(rpcResponse.approximateExpirationDate?.timeIntervalSinceNow)
    XCTAssertEqual(expiresIn, 12345, accuracy: 0.1)
    XCTAssertTrue(rpcResponse.isNewUser)
  }

  private func makeVerifyCustomTokenRequest() -> VerifyCustomTokenRequest {
    return VerifyCustomTokenRequest(token: kTestToken,
                                    requestConfiguration: makeRequestConfiguration())
  }
}
