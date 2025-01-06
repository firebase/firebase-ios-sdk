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

/** @class StartMFAEnrollmentRequestTests
    @brief Tests for @c StartMFAEnrollmentRequest
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class StartMFAEnrollmentRequestTests: RPCBaseTests {
  let kAPIKey = "APIKey"
  let kIDToken = "idToken"
  let kTOTPEnrollmentInfo = "totpEnrollmentInfo"
  let kPhoneEnrollmentInfo = "enrollmentInfo"
  let kPhoneNumber = "phoneNumber"
  let kReCAPTCHAToken = "recaptchaToken"
  let kCaptchaResponse = "captchaResponse"
  let kRecaptchaVersion = "recaptchaVersion"

  /**
   @fn testTOTPStartMFAEnrollmentRequest
   @brief Tests the Start MFA Enrollment using TOTP request.
   */
  func testTOTPStartMFAEnrollmentRequest() async throws {
    let kIDToken = "idToken"
    let kTOTPEnrollmentInfo = "totpEnrollmentInfo"
    let kPhoneEnrollmentInfo = "enrollmentInfo"

    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let requestInfo = AuthProtoStartMFATOTPEnrollmentRequestInfo()
    let request = StartMFAEnrollmentRequest(idToken: kIDToken,
                                            totpEnrollmentInfo: requestInfo,
                                            requestConfiguration: requestConfiguration)

    let expectedURL =
      "https://identitytoolkit.googleapis.com/v2/accounts/mfaEnrollment:start?key=\(kAPIKey)"

    do {
      try await checkRequest(
        request: request,
        expected: expectedURL,
        key: kIDToken,
        value: kIDToken
      )
    } catch {
      // Ignore error from missing users array in fake JSON return.
      return
    }
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    let totpInfo = try XCTUnwrap(requestDictionary[kTOTPEnrollmentInfo] as? [String: String])
    XCTAssertEqual(totpInfo, [:])
    XCTAssertNil(requestDictionary[kPhoneEnrollmentInfo])
  }

  /**
   @fn testPhoneStartMFAEnrollmentRequest
   @brief Tests the Start MFA Enrollment using SMS request.
   */
  func testPhoneStartMFAEnrollmentInjectRecaptchaFields() async throws {
    // created a base startMFAEnrollment Request
    let testPhoneNumber = "1234567890"
    let testRecaptchaToken = "RECAPTCHA_FAKE_TOKEN"

    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let smsEnrollmentInfo = AuthProtoStartMFAPhoneRequestInfo(
      phoneNumber: testPhoneNumber,
      codeIdentity: CodeIdentity.recaptcha(testRecaptchaToken)
    )
    let request = StartMFAEnrollmentRequest(idToken: kIDToken,
                                            enrollmentInfo: smsEnrollmentInfo,
                                            requestConfiguration: requestConfiguration)

    // inject reCAPTCHA response
    let testRecaptchaResponse = "RECAPTCHA_FAKE_RESPONSE"
    let testRecaptchaVersion = "RECAPTCHA_FAKE_ENTERPRISE"
    request.injectRecaptchaFields(
      recaptchaResponse: testRecaptchaResponse,
      recaptchaVersion: testRecaptchaVersion
    )

    let expectedURL =
      "https://identitytoolkit.googleapis.com/v2/accounts/mfaEnrollment:start?key=\(kAPIKey)"

    do {
      try await checkRequest(
        request: request,
        expected: expectedURL,
        key: kIDToken,
        value: kIDToken
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
