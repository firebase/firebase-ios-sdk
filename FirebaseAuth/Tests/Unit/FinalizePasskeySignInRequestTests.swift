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
      let body = request.unencodedHTTPRequestBody
      XCTAssertNotNil(body)
      let authnAssertionResp = body?["authenticatorAssertionResponse"] as? [String: AnyHashable]
      XCTAssertNotNil(authnAssertionResp)
      XCTAssertEqual(authnAssertionResp?["credentialId"] as? String, kCredentialID)
      let innerResponse =
        authnAssertionResp?["authenticatorAssertionResponse"] as? [String: AnyHashable]
      XCTAssertNotNil(innerResponse)
      XCTAssertEqual(innerResponse?["clientDataJSON"] as? String, kClientDataJSON)
      XCTAssertEqual(innerResponse?["authenticatorData"] as? String, kAuthenticatorData)
      XCTAssertEqual(innerResponse?["signature"] as? String, kSignature)
      XCTAssertEqual(innerResponse?["userHandle"] as? String, kUserId)
      XCTAssertNil(body?["tenantId"])
    }

    func testUnencodedHTTPRequestBodyWithTenantId() {
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.apiKey = "FAKE_API_KEY"
      options.projectID = "myProjectID"
      let fakeApp = FirebaseApp(instanceWithName: "testApp", options: options)
      let fakeAuth = Auth(app: fakeApp)
      fakeAuth.tenantID = "TEST_TENANT"
      let configWithTenant = AuthRequestConfiguration(
        apiKey: "FAKE_API_KEY",
        appID: "FAKE_APP_ID",
        auth: fakeAuth
      )
      request = FinalizePasskeySignInRequest(
        credentialID: kCredentialID,
        clientDataJSON: kClientDataJSON,
        authenticatorData: kAuthenticatorData,
        signature: kSignature,
        userId: kUserId,
        requestConfiguration: configWithTenant
      )

      let body = request.unencodedHTTPRequestBody
      XCTAssertEqual(body?["tenantId"] as? String, "TEST_TENANT")
    }
  }

#endif
