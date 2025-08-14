/*
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#if os(iOS) || os(tvOS) || os(macOS)

  import AuthenticationServices
  @testable import FirebaseAuth
  import Foundation
  import XCTest

  @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
  class PasskeyTests: TestsBase {
    // MARK: Enrollment Tests

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testStartPasskeyEnrollmentSuccess() async throws {
      try await signInAnonymouslyAsync()
      guard let user = Auth.auth().currentUser else {
        XCTFail("Expected a signed-in user")
        return
      }
      try? await user.reload()
      let request = try await user.startPasskeyEnrollment(withName: "Test1Passkey")
      XCTAssertFalse(request.relyingPartyIdentifier.isEmpty, "rpID should be non-empty")
      XCTAssertFalse(request.challenge.isEmpty, "challenge should be non-empty")
      XCTAssertNotNil(request.userID, "userID should be present")
      try? await deleteCurrentUserAsync()
    }

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testStartPasskeyEnrollmentFailureWithInvalidToken() async throws {
      try await signInAnonymouslyAsync()
      guard let user = Auth.auth().currentUser else {
        XCTFail("Expected a signed-in user")
        return
      }
      // user not reloaded hence id token not updated
      let request = try await user.startPasskeyEnrollment(withName: "Test2Passkey")
      XCTAssertFalse(request.relyingPartyIdentifier.isEmpty, "rpID should be non-empty")
      XCTAssertFalse(request.challenge.isEmpty, "challenge should be non-empty")
      XCTAssertNotNil(request.userID, "userID should be present")
      try? await deleteCurrentUserAsync()
    }

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testFinalizePasskeyEnrollmentFailureWithInvalidToken() async throws {
      try await signInAnonymouslyAsync()
      guard let user = Auth.auth().currentUser else {
        XCTFail("Expected a signed-in user")
        return
      }
      let badRequest = FinalizePasskeyEnrollmentRequest(
        idToken: "invalidToken",
        name: "fakeName",
        credentialID: "fakeCredentialId".data(using: .utf8)!.base64EncodedString(),
        clientDataJSON: "fakeClientData".data(using: .utf8)!.base64EncodedString(),
        attestationObject: "fakeAttestion".data(using: .utf8)!.base64EncodedString(),
        requestConfiguration: user.requestConfiguration
      )
      do {
        _ = try await user.backend.call(with: badRequest)
        XCTFail("Expected invalid_user_token")
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code) {
          XCTAssertEqual(code, .invalidUserToken, "Expected .invalidUserToken, got \(code)")
        }
      }
      try? await deleteCurrentUserAsync()
    }

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testFinalizePasskeyEnrollmentFailureWithoutAttestation() async throws {
      try await signInAnonymouslyAsync()
      guard let user = Auth.auth().currentUser else {
        XCTFail("Expected a signed-in user")
        return
      }
      try? await user.reload()
      let token = user.rawAccessToken()
      let badRequest = FinalizePasskeyEnrollmentRequest(
        idToken: token,
        name: "fakeName",
        credentialID: "fakeCredentialId".data(using: .utf8)!.base64EncodedString(),
        clientDataJSON: "fakeClientData".data(using: .utf8)!.base64EncodedString(),
        attestationObject: "fakeAttestion".data(using: .utf8)!.base64EncodedString(),
        requestConfiguration: user.requestConfiguration
      )
      do {
        _ = try await user.backend.call(with: badRequest)
        XCTFail("Expected invalid_authenticator_response")
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code) {
          XCTAssertEqual(code, .invalidAuthenticatorResponse,
                         "Expected .invalidAuthenticatorResponse, got \(code)")
        }
        let message = (ns.userInfo[NSLocalizedDescriptionKey] as? String ?? "").uppercased()
        XCTAssertTrue(
          message
            .contains(
              "DURING PASSKEY ENROLLMENT AND SIGN IN, THE AUTHENTICATOR RESPONSE IS NOT PARSEABLE, MISSING REQUIRED FIELDS, OR CERTAIN FIELDS ARE INVALID VALUES THAT COMPROMISE THE SECURITY OF THE SIGN-IN OR ENROLLMENT."
            ),
          "Expected INVALID_AUTHENTICATOR_RESPONSE, got: \(message)"
        )
      }
      try? await deleteCurrentUserAsync()
    }
  }

#endif
