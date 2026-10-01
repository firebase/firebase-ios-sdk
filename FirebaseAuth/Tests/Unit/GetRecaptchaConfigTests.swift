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

class GetRecaptchaConfigTests: RPCBaseTests {
  /** @fn testGetRecaptchaConfigRequest
      @brief Tests get Recaptcha config request.
   */
  func testGetRecaptchaConfigRequest() async throws {
    let request = GetRecaptchaConfigRequest(requestConfiguration: makeRequestConfiguration())
    //    let _ = try await authBackend.call(with: request)
    XCTAssertNil(request.unencodedHTTPRequestBody)

    // Confirm that the request has no decoded body as it is get request.
    XCTAssertNil(rpcIssuer.decodedRequest)
    let urlString = "https://identitytoolkit.googleapis.com/v2/recaptchaConfig?key=\(kTestAPIKey)" +
      "&clientType=CLIENT_TYPE_IOS&version=RECAPTCHA_ENTERPRISE"
    try await checkRequest(
      request: request,
      expected: urlString,
      key: "should_be_empty_dictionary",
      value: nil
    )
  }

  /** @fn testSuccessfulGetRecaptchaConfigRequestRecaptchaEnabled
      @brief This test simulates a successful @c getRecaptchaConfig Flow when recaptcha is enabled.
   */
  func testSuccessfulGetRecaptchaConfigRequestRecaptchaEnabled() async throws {
    let kTestRecaptchaKey = "projects/123/keys/456"
    let request = GetRecaptchaConfigRequest(requestConfiguration: makeRequestConfiguration())

    rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey
    let enforcementMode = "AUDIT"
    rpcIssuer.rceMode = enforcementMode
    let response = try await authBackend.call(with: request)
    XCTAssertEqual(response.recaptchaKey, kTestRecaptchaKey)
    XCTAssertEqual(
      response.enforcementState,
      [
        ["provider": "EMAIL_PASSWORD_PROVIDER", "enforcementState": enforcementMode],
        ["provider": "PHONE_PROVIDER", "enforcementState": enforcementMode],
      ]
    )
  }

  /** @fn testSuccessfulGetRecaptchaConfigRequestRecaptchaDisabled
   @brief This test simulates a successful @c getRecaptchaConfig Flow when recaptcha is disabled.
   */
  func testSuccessfulGetRecaptchaConfigRequestRecaptchaDisabled() async throws {
    let request = GetRecaptchaConfigRequest(requestConfiguration: makeRequestConfiguration())
    let enforcementMode = "OFF"
    rpcIssuer.rceMode = enforcementMode
    let response = try await authBackend.call(with: request)
    XCTAssertEqual(response.recaptchaKey, nil)
    XCTAssertEqual(
      response.enforcementState,
      [
        ["provider": "EMAIL_PASSWORD_PROVIDER", "enforcementState": enforcementMode],
        ["provider": "PHONE_PROVIDER", "enforcementState": enforcementMode],
      ]
    )
  }

  /** @fn testGetRecaptchaConfigResponseKeepsValidEntriesWhenSomeAreMalformed
      @brief Malformed enforcement state entries or fields must not discard the valid entries.
   */
  func testGetRecaptchaConfigResponseKeepsValidEntriesWhenSomeAreMalformed() async throws {
    let request = GetRecaptchaConfigRequest(requestConfiguration: makeRequestConfiguration())
    rpcIssuer.fakeRecaptchaConfigJSON = [
      "recaptchaKey": "projects/123/keys/456",
      "recaptchaEnforcementState": [
        ["provider": "PHONE_PROVIDER", "enforcementState": "ENFORCE", "newField": true]
          as [String: Any],
        ["provider": NSNull(), "enforcementState": "AUDIT"] as [String: Any],
        "not a dictionary",
        42,
        NSNull(),
        ["provider": "EMAIL_PASSWORD_PROVIDER", "enforcementState": "AUDIT"],
      ] as [Any],
    ]
    let response = try await authBackend.call(with: request)
    XCTAssertEqual(response.recaptchaKey, "projects/123/keys/456")
    XCTAssertEqual(
      response.enforcementState,
      [
        ["provider": "PHONE_PROVIDER", "enforcementState": "ENFORCE"],
        ["enforcementState": "AUDIT"],
        ["provider": "EMAIL_PASSWORD_PROVIDER", "enforcementState": "AUDIT"],
      ]
    )
  }

  /** @fn testGetRecaptchaConfigResponseWrongTypes
      @brief Fields of the wrong type are treated as missing rather than failing the request.
   */
  func testGetRecaptchaConfigResponseWrongTypes() async throws {
    let request = GetRecaptchaConfigRequest(requestConfiguration: makeRequestConfiguration())
    rpcIssuer.fakeRecaptchaConfigJSON = [
      "recaptchaKey": 123,
      "recaptchaEnforcementState": "ENFORCE",
    ]
    let response = try await authBackend.call(with: request)
    XCTAssertNil(response.recaptchaKey)
    XCTAssertNil(response.enforcementState)
  }

  /** @fn testGetRecaptchaConfigResponseNullAndEmpty
      @brief NSNull and empty values are handled without crashing.
   */
  func testGetRecaptchaConfigResponseNullAndEmpty() async throws {
    let request = GetRecaptchaConfigRequest(requestConfiguration: makeRequestConfiguration())
    rpcIssuer.fakeRecaptchaConfigJSON = [
      "recaptchaKey": NSNull(),
      "recaptchaEnforcementState": [] as [Any],
    ] as [String: Any]
    let response = try await authBackend.call(with: request)
    XCTAssertNil(response.recaptchaKey)
    XCTAssertEqual(response.enforcementState, [])

    rpcIssuer.fakeRecaptchaConfigJSON = [:]
    let emptyResponse = try await authBackend.call(with: request)
    XCTAssertNil(emptyResponse.recaptchaKey)
    XCTAssertNil(emptyResponse.enforcementState)
  }
}
