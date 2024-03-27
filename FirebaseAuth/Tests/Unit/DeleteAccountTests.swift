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
class DeleteAccountTests: RPCBaseTests {
  /** @var kLocalIDKey
      @brief The name of the "localID" property in the request.
   */
  let kLocalIDKey = "localId"

  /** @var kExpectedAPIURL
      @brief The expected URL for the test calls.
   */
  let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/deleteAccount?key=APIKey"

  func testDeleteAccount() async throws {
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kInvalidUserTokenErrorMessage = "INVALID_ID_TOKEN:"
    let kCredentialTooOldErrorMessage = "CREDENTIAL_TOO_OLD_LOGIN_AGAIN:"
    try await checkRequest(
      request: makeDeleteAccountRequest(),
      expected: kExpectedAPIURL,
      key: kLocalIDKey,
      value: kLocalID
    )
    try await checkBackendError(
      request: makeDeleteAccountRequest(),
      message: kUserDisabledErrorMessage,
      errorCode: AuthErrorCode.userDisabled
    )
    try await checkBackendError(
      request: makeDeleteAccountRequest(),
      message: kInvalidUserTokenErrorMessage,
      errorCode: AuthErrorCode.invalidUserToken
    )
    try await checkBackendError(
      request: makeDeleteAccountRequest(),
      message: kCredentialTooOldErrorMessage,
      errorCode: AuthErrorCode.requiresRecentLogin
    )
  }

  /** @fn testSuccessfulDeleteAccount
      @brief This test checks for a successful response
   */
  func testSuccessfulDeleteAccountResponse() async throws {
    rpcIssuer?.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: [:])
    }
    let rpcResponse = try await AuthBackend.call(with: makeDeleteAccountRequest())
    XCTAssertNotNil(rpcResponse)
  }

  private func makeDeleteAccountRequest() -> DeleteAccountRequest {
    return DeleteAccountRequest(localID: kLocalID,
                                accessToken: "Access Token",
                                requestConfiguration: makeRequestConfiguration())
  }
}
