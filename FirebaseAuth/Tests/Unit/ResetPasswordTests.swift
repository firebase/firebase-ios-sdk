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
class ResetPasswordTests: RPCBaseTests {
  let kTestOOBCode = "OOBCode"
  let kTestNewPassword = "newPassword:-)"

  func testResetPasswordRequest() async throws {
    let kOOBCodeKey = "oobCode"
    let kNewPasswordKey = "newPassword"
    let kExpectedAPIURL =
      "https://www.googleapis.com/identitytoolkit/v3/relyingparty/resetPassword?key=APIKey"
    try await checkRequest(
      request: makeResetPasswordRequest(),
      expected: kExpectedAPIURL,
      key: kNewPasswordKey,
      value: kTestNewPassword
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kOOBCodeKey], kTestOOBCode)
  }

  func testResetPasswordRequestErrors() async throws {
    let kUserDisabledErrorMessage = "USER_DISABLED"
    let kOperationNotAllowedErrorMessage = "OPERATION_NOT_ALLOWED"
    let kExpiredActionCodeErrorMessage = "EXPIRED_OOB_CODE"
    let kInvalidActionCodeErrorMessage = "INVALID_OOB_CODE"
    let kWeakPasswordErrorMessagePrefix = "WEAK_PASSWORD : "

    try await checkBackendError(
      request: makeResetPasswordRequest(),
      message: kUserDisabledErrorMessage,
      errorCode: AuthErrorCode.userDisabled
    )
    try await checkBackendError(
      request: makeResetPasswordRequest(),
      message: kOperationNotAllowedErrorMessage,
      errorCode: AuthErrorCode.operationNotAllowed
    )
    try await checkBackendError(
      request: makeResetPasswordRequest(),
      message: kExpiredActionCodeErrorMessage,
      errorCode: AuthErrorCode.expiredActionCode
    )
    try await checkBackendError(
      request: makeResetPasswordRequest(),
      message: kInvalidActionCodeErrorMessage,
      errorCode: AuthErrorCode.invalidActionCode
    )
    try await checkBackendError(
      request: makeResetPasswordRequest(),
      message: kWeakPasswordErrorMessagePrefix,
      errorCode: AuthErrorCode.weakPassword
    )
  }

  /** @fn testSuccessfulResetPassword
      @brief Tests a successful reset password flow.
   */
  func testSuccessfulResetPassword() async throws {
    let kTestEmail = "test@email.com"
    let kExpectedResetPasswordRequestType = "PASSWORD_RESET"

    rpcIssuer.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: ["email": kTestEmail,
                                             "requestType": kExpectedResetPasswordRequestType])
    }
    let rpcResponse = try await AuthBackend.call(with: makeResetPasswordRequest())

    XCTAssertEqual(rpcResponse.email, kTestEmail)
    XCTAssertEqual(rpcResponse.requestType, kExpectedResetPasswordRequestType)
  }

  private func makeResetPasswordRequest() -> ResetPasswordRequest {
    return ResetPasswordRequest(oobCode: kTestOOBCode, newPassword: kTestNewPassword,
                                requestConfiguration: makeRequestConfiguration())
  }
}
