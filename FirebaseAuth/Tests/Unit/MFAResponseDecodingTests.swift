// Copyright 2026 Google LLC
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
import FirebaseCore

/// Tests that malformed multi-factor data from the backend is rejected or skipped instead of
/// crashing.
class MFAResponseDecodingTests: RPCBaseTests {
  /** @fn testStartMFAEnrollmentResponseWithTOTPSessionInfo
      @brief A TOTP session info with a shared secret key is decoded.
   */
  func testStartMFAEnrollmentResponseWithTOTPSessionInfo() throws {
    let response = try StartMFAEnrollmentResponse(dictionary: [
      "totpSessionInfo": [
        "sharedSecretKey": "SECRET",
        "verificationCodeLength": 6,
        "hashingAlgorithm": "SHA1",
        "periodSec": 30,
        "sessionInfo": "SESSION",
      ] as [String: AnyHashable],
    ])
    let totpSessionInfo = try XCTUnwrap(response.totpSessionInfo)
    XCTAssertEqual(totpSessionInfo.sharedSecretKey, "SECRET")
    XCTAssertEqual(totpSessionInfo.verificationCodeLength, 6)
    XCTAssertEqual(totpSessionInfo.hashingAlgorithm, "SHA1")
    XCTAssertEqual(totpSessionInfo.periodSec, 30)
    XCTAssertEqual(totpSessionInfo.sessionInfo, "SESSION")
  }

  /** @fn testStartMFAEnrollmentResponseWithoutSharedSecretKeyThrows
      @brief A TOTP session info whose shared secret key is missing or isn't a string is rejected
          with an error instead of crashing.
   */
  func testStartMFAEnrollmentResponseWithoutSharedSecretKeyThrows() {
    // `nil` leaves `sharedSecretKey` out of the response.
    let sharedSecretKeys: [AnyHashable?] = [nil, NSNull(), 123]
    for sharedSecretKey in sharedSecretKeys {
      var totpSessionInfo: [String: AnyHashable] = ["verificationCodeLength": 6]
      totpSessionInfo["sharedSecretKey"] = sharedSecretKey
      XCTAssertThrowsError(
        try StartMFAEnrollmentResponse(dictionary: ["totpSessionInfo": totpSessionInfo])
      ) { error in
        XCTAssertEqual((error as NSError).code, AuthErrorCode.internalError.rawValue)
      }
    }
  }

  #if os(iOS) || os(macOS)
    private let kAppName = "test-MFAResponseDecodingTests"
    private var auth: Auth?

    /// Two valid enrollments, plus a phone and a TOTP enrollment without an enrollment ID.
    private let mixedEnrollmentsJSON: [[String: AnyHashable]] = [
      ["phoneInfo": "+15555550100", "mfaEnrollmentId": "phone-id"],
      ["phoneInfo": "+15555550101"],
      ["totpInfo": [String: AnyHashable](), "mfaEnrollmentId": "totp-id"],
      ["totpInfo": [String: AnyHashable]()],
    ]

    override func setUp() {
      super.setUp()
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.apiKey = "FAKE_API_KEY"
      options.projectID = "myProjectID"
      FirebaseApp.configure(name: kAppName, options: options)
      auth = Auth(app: FirebaseApp.app(name: kAppName)!,
                  keychainStorageProvider: FakeAuthKeychainStorage(),
                  backend: authBackend)
    }

    override func tearDown() {
      auth = nil
      FirebaseApp.resetApps()
      super.tearDown()
    }

    /** @fn testMultiFactorSkipsEnrollmentsWithoutEnrollmentID
        @brief Enrolled factors without an enrollment ID are skipped instead of crashing, and the
            other factors are kept.
     */
    func testMultiFactorSkipsEnrollmentsWithoutEnrollmentID() {
      let enrollments = mixedEnrollmentsJSON.map { AuthProtoMFAEnrollment(dictionary: $0) }
      let multiFactor = MultiFactor(withMFAEnrollments: enrollments)
      XCTAssertEqual(multiFactor.enrolledFactors.map(\.uid), ["phone-id", "totp-id"])
    }

    /** @fn testSecondFactorRequiredErrorSkipsHintsWithoutEnrollmentID
        @brief When sign-in requires a second factor, hints without an enrollment ID are skipped
            instead of crashing, and the other hints are kept.
     */
    func testSecondFactorRequiredErrorSkipsHintsWithoutEnrollmentID() async throws {
      let auth = try XCTUnwrap(auth)
      rpcIssuer.respondBlock = {
        try self.rpcIssuer.respond(withJSON: [
          "mfaPendingCredential": "PENDING_CREDENTIAL",
          "mfaInfo": self.mixedEnrollmentsJSON,
        ])
      }
      let request = VerifyPasswordRequest(email: kEmail,
                                          password: kFakePassword,
                                          requestConfiguration: auth.requestConfiguration)
      do {
        _ = try await authBackend.call(with: request)
        XCTFail("Expected secondFactorRequired")
      } catch {
        let nsError = error as NSError
        XCTAssertEqual(nsError.code, AuthErrorCode.secondFactorRequired.rawValue)
        let resolver = try XCTUnwrap(
          nsError.userInfo[AuthErrors.userInfoMultiFactorResolverKey] as? MultiFactorResolver
        )
        XCTAssertEqual(resolver.hints.map(\.uid), ["phone-id", "totp-id"])
      }
    }
  #endif
}
