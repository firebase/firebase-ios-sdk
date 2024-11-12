// Copyright 2024 Google LLC
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

/** @class StartMFASignInRequestTests
    @brief Tests for @c StartMFASignInRequest
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StartMFASignInRequestTests: RPCBaseTests {
  let kAPIKey = "APIKey"
  let kMfaEnrollmentId = "mfaEnrollmentId"
  let kTOTPEnrollmentInfo = "totpEnrollmentInfo"
  let kPhoneEnrollmentInfo = "enrollmentInfo"
  let kPhoneNumber = "phoneNumber"
  let kReCAPTCHAToken = "recaptchaToken"
  let kCaptchaResponse = "captchaResponse"
  let kRecaptchaVersion = "recaptchaVersion"

  /**
   @fn testPhoneStartMFASignInRequest
   @brief Tests the Start MFA Sign In using SMS request.
   */
  func testPhoneStartMFASignInRequest() async throws {
    let testPendingCredential = "FAKE_PENDING_CREDENTIAL"
    let testEnrollmentID = "FAKE_ENROLLMENT_ID"
    let testPhoneNumber = "1234567890"
    let testRecaptchaToken = "RECAPTCHA_FAKE_TOKEN"

    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let smsSignInInfo = AuthProtoStartMFAPhoneRequestInfo(
      phoneNumber: testPhoneNumber,
      codeIdentity: CodeIdentity.recaptcha(testRecaptchaToken)
    )

    let request = StartMFASignInRequest(
      MFAPendingCredential: testPendingCredential,
      MFAEnrollmentID: testEnrollmentID,
      signInInfo: smsSignInInfo,
      requestConfiguration: requestConfiguration
    )

    let expectedURL =
      "https://identitytoolkit.googleapis.com/v2/accounts/mfaSignIn:start?key=\(kAPIKey)"

    // inject reCAPTCHA response
    let testRecaptchaResponse = "RECAPTCHA_FAKE_RESPONSE"
    let testRecaptchaVersion = "RECAPTCHA_FAKE_ENTERPRISE"
    request.injectRecaptchaFields(
      recaptchaResponse: testRecaptchaResponse,
      recaptchaVersion: testRecaptchaVersion
    )

    do {
      try await checkRequest(
        request: request,
        expected: expectedURL,
        key: kMfaEnrollmentId,
        value: testEnrollmentID
      )
    } catch {
      // Ignore error from missing users array in fake JSON return.
      return
    }

    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    let smsInfo = try XCTUnwrap(requestDictionary["phoneEnrollmentInfo"] as? [String: String])
    XCTAssertEqual(smsInfo[kPhoneNumber], testPhoneNumber)
    XCTAssertEqual(smsInfo[kReCAPTCHAToken], testRecaptchaToken)
    XCTAssertEqual(smsInfo[kRecaptchaVersion], kRecaptchaVersion)
    XCTAssertEqual(smsInfo[kCaptchaResponse], testRecaptchaResponse)

    XCTAssertNil(requestDictionary[kTOTPEnrollmentInfo])
  }
}
