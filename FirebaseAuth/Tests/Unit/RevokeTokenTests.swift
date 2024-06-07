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
class RevokeTokenTests: RPCBaseTests {
  private let kAPPTokenKey = "appToken"
  private let kFakeAppToken = "kAPPTokenKey"
  private let kFakeTokenKey = "token"
  private let kFakeToken = "fakeToken"
  private let kFakeIDTokenKey = "idToken"
  private let kFakeIDToken = "fakeIDToken"
  private let kFakeProviderIDKey = "providerId"
  private let kFakeTokenTypeKey = "tokenType"
  private let kExpectedAPIURL =
    "https://identitytoolkit.googleapis.com/v2/accounts:revokeToken?key=APIKey"

  /** @fn testRevokeTokenRequest
      @brief Tests the RevokeToken request.
   */
  func testRevokeTokenRequest() async throws {
    let request = makeRevokeTokenRequest()
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kFakeTokenKey,
      value: kFakeToken
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kFakeProviderIDKey], AuthProviderID.apple.rawValue)
    XCTAssertEqual(requestDictionary[kFakeTokenTypeKey], "3")
  }

  /** @fn testSuccessfulRevokeTokenResponse
      @brief Tests a successful attempt of the verify password flow.
   */
  func testSuccessfulRevokeTokenResponse() async throws {
    rpcIssuer.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: [:])
    }
    let rpcResponse = try await AuthBackend.call(with: makeRevokeTokenRequest())
    XCTAssertNotNil(rpcResponse)
  }

  private func makeRevokeTokenRequest() -> RevokeTokenRequest {
    return RevokeTokenRequest(withToken: kFakeToken,
                              idToken: kFakeIDToken,
                              requestConfiguration: makeRequestConfiguration())
  }
}
