// Copyright 2025 Google LLC
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

#if os(iOS) || os(tvOS) || os(macOS)

  @testable import FirebaseAuth
  import FirebaseCore
  import XCTest

  @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
  class FinalizePasskeySignInRequestTests: XCTestCase {
    private var request: FinalizePasskeySignInRequest!
    private var fakeConfig: AuthRequestConfiguration!

    // Fake values
    private let kCredentialID = "FAKE_CREDENTIAL_ID"
    private let kClientDataJSON = "FAKE_CLIENT_DATA"
    private let kAuthenticatorData = "FAKE_AUTHENTICATOR_DATA"
    private let kSignature = "FAKE_SIGNATURE"
    private let kUserId = "FAKE_USERID"

    override func setUp() {
      super.setUp()
      fakeConfig = AuthRequestConfiguration(
        apiKey: "FAKE_API_KEY",
        appID: "FAKE_APP_ID"
      )
    }

    override func tearDown() {
      request = nil
      fakeConfig = nil
      super.tearDown()
    }

    func testInitWithValidParameters() {
      request = FinalizePasskeySignInRequest(
        credentialID: kCredentialID,
        clientDataJSON: kClientDataJSON,
        authenticatorData: kAuthenticatorData,
        signature: kSignature,
        userId: kUserId,
        requestConfiguration: fakeConfig
      )
      XCTAssertEqual(request.credentialID, kCredentialID)
      XCTAssertEqual(request.clientDataJSON, kClientDataJSON)
      XCTAssertEqual(request.authenticatorData, kAuthenticatorData)
      XCTAssertEqual(request.signature, kSignature)
      XCTAssertEqual(request.userId, kUserId)
      XCTAssertEqual(request.endpoint, "accounts/passkeySignIn:finalize")
      XCTAssertTrue(request.useIdentityPlatform)
    }

    func testUnencodedHTTPRequestBodyWithoutTenantId() {
      request = FinalizePasskeySignInRequest(
        credentialID: kCredentialID,
        clientDataJSON: kClientDataJSON,
        authenticatorData: kAuthenticatorData,
        signature: kSignature,
        userId: kUserId,
        requestConfiguration: fakeConfig
      )
      guard let postBody = request.unencodedHTTPRequestBody else {
        return XCTFail("Body should not be nil")
      }
      guard let authnAssertionResp =
        postBody["authenticatorAuthenticationResponse"] as? [String: AnyHashable] else {
        return XCTFail("Missing authenticatorAuthenticationResponse")
      }
      XCTAssertEqual(authnAssertionResp["id"] as? String, kCredentialID)
      guard let response = authnAssertionResp["response"] as? [String: AnyHashable] else {
        return XCTFail("Missing nested response dictionary")
      }
      XCTAssertEqual(response["clientDataJSON"] as? String, kClientDataJSON)
      XCTAssertEqual(response["authenticatorData"] as? String, kAuthenticatorData)
      XCTAssertEqual(response["signature"] as? String, kSignature)
      XCTAssertEqual(response["userHandle"] as? String, kUserId)
      XCTAssertNil(postBody["tenantId"]) // no tenant by default
    }

    func testUnencodedHTTPRequestBodyWithTenantId() {
      let options = FirebaseOptions(
        googleAppID: "0:0000000000000:ios:0000000000000000",
        gcmSenderID: "00000000000000000-00000000000-000000000"
      )
      options.apiKey = "FAKE_API_KEY"
      options.projectID = "myProjectID"
      let app = FirebaseApp(instanceWithName: "testApp", options: options)
      let auth = Auth(app: app)
      auth.tenantID = "TEST_TENANT"
      let configWithTenant = AuthRequestConfiguration(
        apiKey: "FAKE_API_KEY",
        appID: "FAKE_APP_ID",
        auth: auth
      )
      request = FinalizePasskeySignInRequest(
        credentialID: kCredentialID,
        clientDataJSON: kClientDataJSON,
        authenticatorData: kAuthenticatorData,
        signature: kSignature,
        userId: kUserId,
        requestConfiguration: configWithTenant
      )
      guard let body = request.unencodedHTTPRequestBody else {
        return XCTFail("Body should not be nil")
      }
      XCTAssertEqual(body["tenantId"] as? String, "TEST_TENANT")
      // also checking structure remains same with tenant
      guard let top = body["authenticatorAuthenticationResponse"] as? [String: AnyHashable] else {
        return XCTFail("Missing authenticatorAuthenticationResponse")
      }
      XCTAssertEqual(top["id"] as? String, kCredentialID)
      guard let response = top["response"] as? [String: AnyHashable] else {
        return XCTFail("Missing nested response dictionary")
      }
      XCTAssertEqual(response["clientDataJSON"] as? String, kClientDataJSON)
      XCTAssertEqual(response["authenticatorData"] as? String, kAuthenticatorData)
      XCTAssertEqual(response["signature"] as? String, kSignature)
      XCTAssertEqual(response["userHandle"] as? String, kUserId)
    }
  }

#endif
