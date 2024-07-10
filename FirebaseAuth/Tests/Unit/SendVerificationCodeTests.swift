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
      @brief Tests the sendVerificationCode request with a ReCAPTCHA token.
   */
  func testSendVerificationCodeRequestReCAPTCHA() async throws {
    let request = makeSendVerificationCodeRequest(CodeIdentity.recaptcha(kTestReCAPTCHAToken))
    XCTAssertEqual(request.phoneNumber, kTestPhoneNumber)
    switch request.codeIdentity {
    case let .recaptcha(token):
      XCTAssertEqual(token, kTestReCAPTCHAToken)
    default:
      XCTFail("Should be a reCAPTCHA")
    }
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kPhoneNumberKey,
      value: kTestPhoneNumber
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary["recaptchaToken"], kTestReCAPTCHAToken)
  }

  /** @fn testSendVerificationCodeRequest
      @brief Tests the sendVerificationCode request with an App Credential
   */
  func testSendVerificationCodeRequestCredential() async throws {
    let credential = AuthAppCredential(receipt: kTestReceipt, secret: kTestSecret)
    let request = makeSendVerificationCodeRequest(CodeIdentity.credential(credential))
    XCTAssertEqual(request.phoneNumber, kTestPhoneNumber)
    switch request.codeIdentity {
    case let .credential(credential):
      XCTAssertEqual(credential.secret, kTestSecret)
      XCTAssertEqual(credential.receipt, kTestReceipt)
    default:
      XCTFail("Should be a credential")
    }
    try await checkRequest(
      request: request,
      expected: kExpectedAPIURL,
      key: kPhoneNumberKey,
      value: kTestPhoneNumber
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kReceiptKey], kTestReceipt)
    XCTAssertEqual(requestDictionary[kSecretKey], kTestSecret)
  }

  func testSendVerificationCodeRequestErrors() async throws {
    let kInvalidPhoneNumberErrorMessage = "INVALID_PHONE_NUMBER"
    let kQuotaExceededErrorMessage = "QUOTA_EXCEEDED"
    let kAppNotVerifiedErrorMessage = "APP_NOT_VERIFIED"
    let kCaptchaCheckFailedErrorMessage = "CAPTCHA_CHECK_FAILED"

    try await checkBackendError(
      request: makeSendVerificationCodeRequest(CodeIdentity.recaptcha(kTestReCAPTCHAToken)),
      message: kInvalidPhoneNumberErrorMessage,
      errorCode: AuthErrorCode.invalidPhoneNumber
    )
    try await checkBackendError(
      request: makeSendVerificationCodeRequest(CodeIdentity.recaptcha(kTestReCAPTCHAToken)),
      message: kQuotaExceededErrorMessage,
      errorCode: AuthErrorCode.quotaExceeded
    )
    try await checkBackendError(
      request: makeSendVerificationCodeRequest(CodeIdentity.recaptcha(kTestReCAPTCHAToken)),
      message: kAppNotVerifiedErrorMessage,
      errorCode: AuthErrorCode.appNotVerified
    )
    try await checkBackendError(
      request: makeSendVerificationCodeRequest(CodeIdentity.recaptcha(kTestReCAPTCHAToken)),
      message: kCaptchaCheckFailedErrorMessage,
      errorCode: AuthErrorCode.captchaCheckFailed
    )
  }

  /** @fn testSuccessfulSendVerificationCodeResponse
      @brief This test simulates a successful verify CustomToken flow.
   */
  func testSuccessfulSendVerificationCodeResponse() async throws {
    let kVerificationIDKey = "sessionInfo"
    let kFakeVerificationID = "testVerificationID"

    rpcIssuer.respondBlock = {
      try self.rpcIssuer?.respond(withJSON: [kVerificationIDKey: kFakeVerificationID])
    }
    let rpcResponse = try await AuthBackend.call(with:
      makeSendVerificationCodeRequest(CodeIdentity.recaptcha(kTestReCAPTCHAToken)))
    XCTAssertNotNil(rpcResponse)
    XCTAssertEqual(rpcResponse.verificationID, kFakeVerificationID)
  }

  private func makeSendVerificationCodeRequest(_ codeIdentity: CodeIdentity)
    -> SendVerificationCodeRequest {
    return SendVerificationCodeRequest(phoneNumber: kTestPhoneNumber,
                                       codeIdentity: codeIdentity,
                                       requestConfiguration: makeRequestConfiguration())
  }
}
