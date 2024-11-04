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

/** @class FinalizeMFAEnrollmentRequestTests
    @brief Tests for @c FinalizeMFAEnrollmentRequest
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FinalizeMFAEnrollmentRequestTests: RPCBaseTests {
  let kAPIKey = "APIKey"

  /**
   @fn testTOTPFinalizeMFAEnrollmentRequest
   @brief Tests the Finalize MFA Enrollment using TOTP request.
   */
  func testTOTPStartMFAEnrollmentRequest() async throws {
    try await assertTOTPStartMFAEnrollmentRequest(displayName: "sparky")
  }

  func testTOTPStartMFAEnrollmentRequest_WhenDisplayNameIsNil() async throws {
    try await assertTOTPStartMFAEnrollmentRequest(displayName: nil)
  }

  func assertTOTPStartMFAEnrollmentRequest(displayName: String?) async throws {
    let kIDToken = "idToken"
    let kDisplayName = "displayName"
    let kSessionInfo = "sessionInfo"
    let kVerificationCode = "code"
    let kTOTPVerificationInfo = "totpVerificationInfo"
    let kPhoneVerificationInfo = "phoneVerificationInfo"

    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let requestInfo = AuthProtoFinalizeMFATOTPEnrollmentRequestInfo(sessionInfo: kSessionInfo,
                                                                    verificationCode: kVerificationCode)
    let request = FinalizeMFAEnrollmentRequest(idToken: kIDToken,
                                               displayName: displayName,
                                               totpVerificationInfo: requestInfo,
                                               requestConfiguration: requestConfiguration)

    let expectedURL =
      "https://identitytoolkit.googleapis.com/v2/accounts/mfaEnrollment:finalize?key=" +
      "\(kAPIKey)"

    try await checkRequest(
      request: request,
      expected: expectedURL,
      key: kIDToken,
      value: kIDToken
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kDisplayName], displayName)
    let totpInfo = try XCTUnwrap(requestDictionary[kTOTPVerificationInfo] as? [String: String])
    XCTAssertEqual(totpInfo["verificationCode"], kVerificationCode)
    XCTAssertNil(requestDictionary[kPhoneVerificationInfo])
  }
}
