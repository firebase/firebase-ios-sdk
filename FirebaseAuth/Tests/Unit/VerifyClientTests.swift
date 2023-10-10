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
class VerifyClientTests: RPCBaseTests {
  private let kAPPTokenKey = "appToken"
  private let kFakeAppToken = "kAPPTokenKey"
  private let kIsSandboxKey = "isSandbox"
  private let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyClient?key=APIKey"

  /** @fn testVerifyClientRequest
      @brief Tests the VerifyClient request.
   */
  func testVerifyClientRequest() async throws {
    let request = makeVerifyClientRequest()
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kAPPTokenKey,
      value: kFakeAppToken
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertTrue(try XCTUnwrap(requestDictionary[kIsSandboxKey] as? Bool))
  }

  func testVerifyClientRequestErrors() async throws {
    let kMissingAppCredentialErrorMessage = "MISSING_APP_CREDENTIAL"
    let kInvalidAppCredentialErrorMessage = "INVALID_APP_CREDENTIAL"

    try await checkBackendError(
      request: makeVerifyClientRequest(),
      message: kMissingAppCredentialErrorMessage,
      errorCode: AuthErrorCode.missingAppCredential
    )
    try await checkBackendError(
      request: makeVerifyClientRequest(),
      message: kInvalidAppCredentialErrorMessage,
      errorCode: AuthErrorCode.invalidAppCredential
    )
  }

  /** @fn testSuccessfulVerifyClientResponse
      @brief Tests a successful attempt of the verify password flow.
   */
  func testSuccessfulVerifyClientResponse() async throws {
    let kReceiptKey = "receipt"
    let kFakeReceipt = "receipt"
    let kSuggestedTimeOutKey = "suggestedTimeout"
    let kFakeSuggestedTimeout = "1234"

    rpcIssuer?.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: [
        kReceiptKey: kFakeReceipt,
        kSuggestedTimeOutKey: kFakeSuggestedTimeout,
      ])
    }
    let rpcResponse = try await AuthBackend.call(with: makeVerifyClientRequest())
    XCTAssertEqual(rpcResponse.receipt, kFakeReceipt)
    let timeOut = try XCTUnwrap(rpcResponse.suggestedTimeOutDate?.timeIntervalSinceNow)
    XCTAssertEqual(timeOut, 1234, accuracy: 0.1)
  }

  private func makeVerifyClientRequest() -> VerifyClientRequest {
    return VerifyClientRequest(withAppToken: kFakeAppToken,
                               isSandbox: true,
                               requestConfiguration: makeRequestConfiguration())
  }
}
