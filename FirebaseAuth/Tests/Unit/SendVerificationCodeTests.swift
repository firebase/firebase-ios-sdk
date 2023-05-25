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
class SendVerificationCodeTests: RPCBaseTests {
  private let kTestSecret = "secret"
  private let kTestReceipt = "receipt"
  private let kTestReCAPTCHAToken = "reCAPTCHAToken"
  private let kPhoneNumberKey = "phoneNumber"
  private let kReceiptKey = "iosReceipt"
  private let kSecretKey = "iosSecret"
  private let kExpectedAPIURL =
    "https://www.googleapis.com/identitytoolkit/v3/relyingparty/sendVerificationCode?key=APIKey"

  /** @fn testSendVerificationCodeRequest
      @brief Tests the sendVerificationCode request.
   */
  func testSendVerificationCodeRequest() throws {
    let request = makeSendVerificationCodeRequest()
    XCTAssertEqual(request.phoneNumber, kTestPhoneNumber)
    XCTAssertEqual(request.appCredential?.receipt, kTestReceipt)
    XCTAssertEqual(request.appCredential?.secret, kTestSecret)
    XCTAssertEqual(request.reCAPTCHAToken, kTestReCAPTCHAToken)
    let issuer = try checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kPhoneNumberKey,
      value: kTestPhoneNumber
    )
    let requestDictionary = try XCTUnwrap(issuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary["recaptchaToken"], kTestReCAPTCHAToken)
    XCTAssertEqual(requestDictionary[kReceiptKey], kTestReceipt)
    XCTAssertEqual(requestDictionary[kSecretKey], kTestSecret)
  }

  func testSendVerificationCodeRequestErrors() throws {
    let kInvalidPhoneNumberErrorMessage = "INVALID_PHONE_NUMBER"
    let kQuotaExceededErrorMessage = "QUOTA_EXCEEDED"
    let kAppNotVerifiedErrorMessage = "APP_NOT_VERIFIED"
    let kCaptchaCheckFailedErrorMessage = "CAPTCHA_CHECK_FAILED"

    try checkBackendError(
      request: makeSendVerificationCodeRequest(),
      message: kInvalidPhoneNumberErrorMessage,
      errorCode: AuthErrorCode.invalidPhoneNumber
    )
    try checkBackendError(
      request: makeSendVerificationCodeRequest(),
      message: kQuotaExceededErrorMessage,
      errorCode: AuthErrorCode.quotaExceeded
    )
    try checkBackendError(
      request: makeSendVerificationCodeRequest(),
      message: kAppNotVerifiedErrorMessage,
      errorCode: AuthErrorCode.appNotVerified
    )
    try checkBackendError(
      request: makeSendVerificationCodeRequest(),
      message: kCaptchaCheckFailedErrorMessage,
      errorCode: AuthErrorCode.captchaCheckFailed
    )
  }

  /** @fn testSuccessfulSendVerificationCodeResponse
      @brief This test simulates a successful verify CustomToken flow.
   */
  func testSuccessfulSendVerificationCodeResponse() throws {
    let kVerificationIDKey = "sessionInfo"
    let kFakeVerificationID = "testVerificationID"
    var callbackInvoked = false
    var rpcResponse: SendVerificationCodeResponse?
    var rpcError: NSError?

    AuthBackend.post(with: makeSendVerificationCodeRequest()) { response, error in
      callbackInvoked = true
      rpcResponse = response as? SendVerificationCodeResponse
      rpcError = error as? NSError
    }

    _ = try rpcIssuer?.respond(withJSON: [kVerificationIDKey: kFakeVerificationID])

    XCTAssert(callbackInvoked)
    XCTAssertNil(rpcError)
    XCTAssertEqual(rpcResponse?.verificationID, kFakeVerificationID)
  }

  private func makeSendVerificationCodeRequest() -> SendVerificationCodeRequest {
    let credential = AuthAppCredential(receipt: kTestReceipt, secret: kTestSecret)
    return SendVerificationCodeRequest(phoneNumber: kTestPhoneNumber,
                                       appCredential: credential,
                                       reCAPTCHAToken: kTestReCAPTCHAToken,
                                       requestConfiguration: makeRequestConfiguration())
  }
}
