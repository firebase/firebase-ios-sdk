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
    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testStartPasskeyEnrollmentResponseSuccess() async throws {
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
      XCTAssertNotNil(request as ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest)
      try? await deleteCurrentUserAsync()
    }

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testStartPasskeyEnrollmentFailureWithInvalidToken() async throws {
      try await signInAnonymouslyAsync()
      guard let user = Auth.auth().currentUser else {
        XCTFail("Expected a signed-in user")
        return
      }
      let config = user.requestConfiguration
      let token = "invalidToken"
      let badRequest = StartPasskeyEnrollmentRequest(idToken: token, requestConfiguration: config)
      do {
        _ = try await user.backend.call(with: badRequest)
        XCTFail("Expected .invalidUserToken")
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code) {
          XCTAssertEqual(code, .invalidUserToken, "Expected .invalidUserToken, got \(code)")
        } else {
          XCTFail("Unexpected error: \(error)")
        }
        let message = (ns.userInfo[NSLocalizedDescriptionKey] as? String ?? "").uppercased()
        XCTAssertTrue(
          message
            .contains(
              "THIS USER'S CREDENTIAL ISN'T VALID FOR THIS PROJECT. THIS CAN HAPPEN IF THE USER'S TOKEN HAS BEEN TAMPERED WITH, OR IF THE USER DOESN’T BELONG TO THE PROJECT ASSOCIATED WITH THE API KEY USED IN YOUR REQUEST."
            ),
          "Expected invalidUserToken, got: \(message)"
        )
      }
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
        let message = (ns.userInfo[NSLocalizedDescriptionKey] as? String ?? "").uppercased()
        XCTAssertTrue(
          message
            .contains(
              "THIS USER'S CREDENTIAL ISN'T VALID FOR THIS PROJECT. THIS CAN HAPPEN IF THE USER'S TOKEN HAS BEEN TAMPERED WITH, OR IF THE USER DOESN’T BELONG TO THE PROJECT ASSOCIATED WITH THE API KEY USED IN YOUR REQUEST."
            ),
          "Expected invalidUserToken, got: \(message)"
        )
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

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testStartPasskeySignInSuccess() async throws {
      let assertionRequest = try await Auth.auth().startPasskeySignIn()
      XCTAssertFalse(assertionRequest.relyingPartyIdentifier.isEmpty,
                     "rpID should be non-empty")
      XCTAssertFalse(assertionRequest.challenge.isEmpty,
                     "challenge should be non-empty")
      XCTAssertNotNil(
        assertionRequest as ASAuthorizationPlatformPublicKeyCredentialAssertionRequest
      )
    }

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testFinalizePasskeySignInFailureInvalidAttestation() async throws {
      let auth = Auth.auth()
      let config = auth.requestConfiguration
      let badRequest = FinalizePasskeySignInRequest(
        credentialID: "fakeCredentialId".data(using: .utf8)!.base64EncodedString(),
        clientDataJSON: "fakeClientData".data(using: .utf8)!.base64EncodedString(),
        authenticatorData: "fakeAuthenticatorData".data(using: .utf8)!.base64EncodedString(),
        signature: "fakeSignature".data(using: .utf8)!.base64EncodedString(),
        userId: "fakeUID".data(using: .utf8)!.base64EncodedString(),
        requestConfiguration: config
      )
      do {
        _ = try await auth.backend.call(with: badRequest)
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code) {
          XCTAssertEqual(code, .userNotFound)
        }
      }
    }

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testFinalizePasskeySignInFailureIncorrectAttestation() async throws {
      let auth = Auth.auth()
      let config = auth.requestConfiguration
      let badRequest = FinalizePasskeySignInRequest(
        credentialID: "",
        clientDataJSON: "",
        authenticatorData: "",
        signature: "",
        userId: "",
        requestConfiguration: config
      )
      do {
        _ = try await auth.backend.call(with: badRequest)
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code) {
          XCTAssertEqual(code, .userNotFound)
        }
      }
    }

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func DRAFTtestUnenrollPasskeySuccess() async throws {
      let testEmail = "sample.ios.auth@gmail.com"
      let testPassword = "sample.ios.auth"
      let testCredentialId = "cred_id"
      let auth = Auth.auth()
      try await auth.signIn(withEmail: testEmail, password: testPassword)
      guard let user = Auth.auth().currentUser else {
        XCTFail("Expected a signed-in user")
        return
      }
      try? await user.reload()
      let prevPasskeys = user.enrolledPasskeys ?? []
      XCTAssertTrue(
        prevPasskeys.contains { $0.credentialID == testCredentialId },
        "Precondition failed: passkey \(testCredentialId) is not enrolled on this account."
      )
      let prevCount = prevPasskeys.count
      let _ = try await user.unenrollPasskey(withCredentialID: testCredentialId)
      try? await user.reload()
      let updatedPasskeys = user.enrolledPasskeys ?? []
      XCTAssertFalse(
        updatedPasskeys.contains { $0.credentialID == testCredentialId },
        "Passkey \(testCredentialId) should be removed after unenroll."
      )
      XCTAssertEqual(
        updatedPasskeys.count, prevCount - 1,
        "Exactly one passkey should have been removed."
      )
      XCTAssertNil(
        updatedPasskeys.first { $0.credentialID == testCredentialId },
        "Passkey \(testCredentialId) should not exist after unenroll."
      )
    }

    @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
    func testUnenrollPasskeyFailure() async throws {
      let testEmail = "sample.ios.auth@gmail.com"
      let testPassword = "sample.ios.auth"
      let testCredentialId = "FCBopZ3mzjfPNXqWXXjAM/ZnnlQ="
      let auth = Auth.auth()
      try await auth.signIn(withEmail: testEmail, password: testPassword)
      guard let user = Auth.auth().currentUser else {
        XCTFail("Expected a signed-in user")
        return
      }
      try? await user.reload()
      do {
        let _ = try await user.unenrollPasskey(withCredentialID: testCredentialId)
        XCTFail("Expected invalid passkey error")
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code) {
          XCTAssertEqual(code, .missingPasskeyEnrollment,
                         "Expected .missingPasskeyEnrollment, got \(code)")
        }
        let message = (ns.userInfo[NSLocalizedDescriptionKey] as? String ?? "").uppercased()
        XCTAssertTrue(
          message
            .contains(
              "CANNOT FIND THE PASSKEY LINKED TO THE CURRENT ACCOUNT"
            ),
          "Expected Missing Passkey Enrollment error, got: \(message)"
        )
      }
    }
  }

#endif
