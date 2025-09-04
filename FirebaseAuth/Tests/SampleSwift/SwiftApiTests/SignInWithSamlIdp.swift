/*
 * Copyright 2025 Google
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

#if os(iOS)

  @testable import FirebaseAuth
  import XCTest

  @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
  class SamlSignInIntegrationTests: TestsBase {
    func testSignInWithSamlFailureInvalidProvider() async throws {
      try? await deleteCurrentUserAsync()
      let invalidProvider = "saml.invalid"
      let spAcsUrl = "https://example.com/saml-acs"
      let samlResp = "samlResp"
      do {
        _ = try await Auth.auth().signInWithSamlIdp(
          ProviderId: invalidProvider,
          SpAcsUrl: spAcsUrl,
          SamlResp: samlResp
        )
        XCTFail("Expected failure for invalid provider ID")
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code) {
          XCTAssert([.operationNotAllowed].contains(code),
                    "Unexpected code: \(code)")
        } else {
          XCTFail("Unexpected error: \(error)")
        }
        let desc = (ns.userInfo[NSLocalizedDescriptionKey] as? String ?? "").uppercased()
        XCTAssert(
          desc.contains("THE IDENTITY PROVIDER CONFIGURATION IS NOT FOUND."),
          "Expected backend invalid provider message, got: \(desc)"
        )
      }
      XCTAssertNil(Auth.auth().currentUser)
    }

    func testSignInWithSamlFailureInvalidResponse() async throws {
      try? await deleteCurrentUserAsync()
      let providerId = "saml.googleidp"
      let spAcsUrl = "https://example.com/saml-acs"
      let invalidSamlResp = "invalid%25"

      do {
        _ = try await Auth.auth().signInWithSamlIdp(
          ProviderId: providerId,
          SpAcsUrl: spAcsUrl,
          SamlResp: invalidSamlResp
        )
        XCTFail("Expected failure for invalid SAMLResponse")
      } catch {
        let ns = error as NSError
        if let code = AuthErrorCode(rawValue: ns.code) {
          XCTAssert([.invalidCredential, .internalError].contains(code),
                    "Unexpected code: \(code)")
        } else {
          XCTFail("Unexpected error: \(error)")
        }
        let desc = (ns.userInfo[NSLocalizedDescriptionKey] as? String ?? "").uppercased()
        XCTAssert(
          desc.contains("UNABLE TO PARSE THE SAML TOKEN."),
          "Expected backend invalid credential message, got: \(desc)"
        )
      }
      XCTAssertNil(Auth.auth().currentUser)
    }
  }

#endif
