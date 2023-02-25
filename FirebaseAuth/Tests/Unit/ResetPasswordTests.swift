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

class ResetPasswordTests: RPCBaseTests {
  let kTestOOBCode = "OOBCode"
  let kTestNewPassword = "newPassword:-)"

  func testResetPasswordRequest() throws {
    let kOOBCodeKey = "oobCode"
    let kNewPasswordKey = "newPassword"
    let kExpectedAPIURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/resetPassword?key=APIKey"
    let issuer = try checkRequest(
      request: makeResetPasswordRequest(),
      expected: kExpectedAPIURL,
      key: kNewPasswordKey,
      value: kTestNewPassword
    )
    let requestDictionary = try XCTUnwrap(issuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kOOBCodeKey], kTestOOBCode)
  }

  func testResetPasswordRequestErrors() throws {
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kOperationNotAllowedErrorMessage = "OPERATION_NOT_ALLOWED"
    let kExpiredActionCodeErrorMessage = "EXPIRED_OOB_CODE"
    let kInvalidActionCodeErrorMessage = "INVALID_OOB_CODE"
    let kWeakPasswordErrorMessagePrefix = "WEAK_PASSWORD : "

    try checkBackendError(
      request: makeResetPasswordRequest(),
      message: kUserDisabledErrorMessage,
      errorCode: AuthErrorCode.userDisabled
    )
    try checkBackendError(
      request: makeResetPasswordRequest(),
      message: kOperationNotAllowedErrorMessage,
      errorCode: AuthErrorCode.operationNotAllowed
    )
    try checkBackendError(
      request: makeResetPasswordRequest(),
      message: kExpiredActionCodeErrorMessage,
      errorCode: AuthErrorCode.expiredActionCode
    )
    try checkBackendError(
      request: makeResetPasswordRequest(),
      message: kInvalidActionCodeErrorMessage,
      errorCode: AuthErrorCode.invalidActionCode
    )
    try checkBackendError(
      request: makeResetPasswordRequest(),
      message: kWeakPasswordErrorMessagePrefix,
      errorCode: AuthErrorCode.weakPassword
    )
  }

  /** @fn testSuccessfulResetPassword
      @brief Tests a successful reset password flow.
   */
  func testSuccessfulResetPassword() throws {
    let kTestEmail = "test@email.com"
    let kExpectedResetPasswordRequestType = "PASSWORD_RESET"
    var callbackInvoked = false
    var rpcResponse: ResetPasswordResponse?
    var rpcError: NSError?

    AuthBackend.post(withRequest: makeResetPasswordRequest()) { response, error in
      callbackInvoked = true
      rpcResponse = response as? ResetPasswordResponse
      rpcError = error as? NSError
    }

    _ = try RPCIssuer?.respond(withJSON: ["email": kTestEmail,
                                          "requestType": kExpectedResetPasswordRequestType])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(rpcResponse?.email, kTestEmail)
    XCTAssertEqual(rpcResponse?.requestType, kExpectedResetPasswordRequestType)
  }

  private func makeResetPasswordRequest() -> ResetPasswordRequest {
    return ResetPasswordRequest(oobCode: kTestOOBCode, newPassword: kTestNewPassword,
                                requestConfiguration: makeRequestConfiguration())
  }
}
