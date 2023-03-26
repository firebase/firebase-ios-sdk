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

  func testDeleteAccount() throws {
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kInvalidUserTokenErrorMessage = "INVALID_ID_TOKEN:"
    let kCredentialTooOldErrorMessage = "CREDENTIAL_TOO_OLD_LOGIN_AGAIN:"
    try checkRequest(
      request: makeDeleteAccountRequest(),
      expected: kExpectedAPIURL,
      key: kLocalIDKey,
      value: kLocalID
    )
    try checkBackendError(
      request: makeDeleteAccountRequest(),
      message: kUserDisabledErrorMessage,
      errorCode: AuthErrorCode.userDisabled
    )
    try checkBackendError(
      request: makeDeleteAccountRequest(),
      message: kInvalidUserTokenErrorMessage,
      errorCode: AuthErrorCode.invalidUserToken
    )
    try checkBackendError(
      request: makeDeleteAccountRequest(),
      message: kCredentialTooOldErrorMessage,
      errorCode: AuthErrorCode.requiresRecentLogin
    )
  }

  /** @fn testSuccessfulDeleteAccount
      @brief This test checks for a successful response
   */
  func testSuccessfulDeleteAccountResponse() throws {
    var callbackInvoked = false
    var rpcError: NSError?

    AuthBackend.post(withRequest: makeDeleteAccountRequest()) { response, error in
      callbackInvoked = true
      rpcError = error as? NSError
    }

    _ = try rpcIssuer?.respond(withJSON: [:])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
  }

  private func makeDeleteAccountRequest() -> DeleteAccountRequest {
    return DeleteAccountRequest(localID: kLocalID,
                                accessToken: "Access Token",
                                requestConfiguration: makeRequestConfiguration())
  }
}
