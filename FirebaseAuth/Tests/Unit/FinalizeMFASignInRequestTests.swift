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

/** @class FinalizeMFASignInRequestTests
    @brief Tests for @c FinalizeMFASignInRequest
 */
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class FinalizeMFASignInRequestTests: RPCBaseTests {
  let kAPIKey = "APIKey"

  /**
   @fn testTOTPFinalizeMFASignInRequest
   @brief Tests the Start MFA Enrollment using TOTP request.
   */
  func testTOTPFinalizeMFASignInRequest() async throws {
    let kMfaPendingCredential = "mfaPendingCredential"
    let kMfaEnrollmentID = "mfaEnrollmentId"
    let kVerificationCode = "verificationCode"
    let kTOTPVerificationInfo = "totpVerificationInfo"
    let kPhoneVerificationInfo = "phoneVerificationInfo"

    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let requestInfo = AuthProtoFinalizeMFATOTPSignInRequestInfo(mfaEnrollmentID: kMfaEnrollmentID,
                                                                verificationCode: kVerificationCode)
    let request = FinalizeMFASignInRequest(mfaPendingCredential: kMfaPendingCredential,
                                           verificationInfo: requestInfo,
                                           requestConfiguration: requestConfiguration)

    let expectedURL =
      "https://identitytoolkit.googleapis.com/v2/accounts/mfaSignIn:finalize?key=\(kAPIKey)"

    try await checkRequest(
      request: request,
      expected: expectedURL,
      key: kMfaPendingCredential,
      value: kMfaPendingCredential
    )
    let requestDictionary = try XCTUnwrap(rpcIssuer.decodedRequest as? [String: AnyHashable])
    XCTAssertEqual(requestDictionary[kMfaEnrollmentID], kMfaEnrollmentID)
    let totpInfo = try XCTUnwrap(requestDictionary[kTOTPVerificationInfo] as? [String: String])
    XCTAssertEqual(totpInfo["verificationCode"], kVerificationCode)
    XCTAssertNil(requestDictionary[kPhoneVerificationInfo])
  }
}
