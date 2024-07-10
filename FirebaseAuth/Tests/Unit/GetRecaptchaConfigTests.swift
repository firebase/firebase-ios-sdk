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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class GetRecaptchaConfigTests: RPCBaseTests {
  /** @fn testGetRecaptchaConfigRequest
      @brief Tests get Recaptcha config request.
   */
  func testGetRecaptchaConfigRequest() async throws {
    let request = GetRecaptchaConfigRequest(requestConfiguration: makeRequestConfiguration())
    //    let _ = try await AuthBackend.call(with: request)
    XCTAssertFalse(request.containsPostBody)

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

  /** @fn testSuccessfulGetRecaptchaConfigRequest
      @brief This test simulates a successful @c getRecaptchaConfig Flow.
   */
  func testSuccessfulGetRecaptchaConfigRequest() async throws {
    let kTestRecaptchaKey = "projects/123/keys/456"
    let request = GetRecaptchaConfigRequest(requestConfiguration: makeRequestConfiguration())

    rpcIssuer.recaptchaSiteKey = kTestRecaptchaKey
    let response = try await AuthBackend.call(with: request)
    XCTAssertEqual(response.recaptchaKey, kTestRecaptchaKey)
    XCTAssertNil(response.enforcementState)
  }
}
