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
  import Foundation
  import XCTest

  @available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
  class FinalizePasskeyEnrollmentRequestTests: XCTestCase {
    private var request: FinalizePasskeyEnrollmentRequest!
    private var fakeConfig: AuthRequestConfiguration!

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
      request = FinalizePasskeyEnrollmentRequest(
        idToken: "ID_TOKEN",
        name: "MyPasskey",
        credentialID: "CRED_ID",
        clientDataJSON: "CLIENT_JSON",
        attestationObject: "ATTEST_OBJ",
        requestConfiguration: fakeConfig
      )

      XCTAssertEqual(request.idToken, "ID_TOKEN")
      XCTAssertEqual(request.name, "MyPasskey")
      XCTAssertEqual(request.credentialID, "CRED_ID")
      XCTAssertEqual(request.clientDataJSON, "CLIENT_JSON")
      XCTAssertEqual(request.attestationObject, "ATTEST_OBJ")
      XCTAssertEqual(request.endpoint, "accounts/passkeyEnrollment:finalize")
      XCTAssertTrue(request.useIdentityPlatform)
    }

    func testUnencodedHTTPRequestBodyWithoutTenantId() {
      request = FinalizePasskeyEnrollmentRequest(
        idToken: "ID_TOKEN",
        name: "MyPasskey",
        credentialID: "CRED_ID",
        clientDataJSON: "CLIENT_JSON",
        attestationObject: "ATTEST_OBJ",
        requestConfiguration: fakeConfig
      )

      let body = request.unencodedHTTPRequestBody
      XCTAssertNotNil(body)
      XCTAssertEqual(body?["idToken"] as? String, "ID_TOKEN")
      XCTAssertEqual(body?["name"] as? String, "MyPasskey")

      let authReg = body?["authenticatorRegistrationResponse"] as? [String: AnyHashable]
      XCTAssertNotNil(authReg)
      XCTAssertEqual(authReg?["id"] as? String, "CRED_ID")

      let authResp = authReg?["response"] as? [String: AnyHashable]
      XCTAssertEqual(authResp?["clientDataJSON"] as? String, "CLIENT_JSON")
      XCTAssertEqual(authResp?["attestationObject"] as? String, "ATTEST_OBJ")

      XCTAssertNil(body?["tenantId"])
    }

    func testUnencodedHTTPRequestBodyWithTenantId() {
      // setting up fake auth to set tenantId
      let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                    gcmSenderID: "00000000000000000-00000000000-000000000")
      options.apiKey = AuthTests.kFakeAPIKey
      options.projectID = "myProjectID"
      let name = "test-AuthTests\(AuthTests.testNum)"
      AuthTests.testNum = AuthTests.testNum + 1
      let fakeAuth = Auth(app: FirebaseApp(instanceWithName: name, options: options))
      fakeAuth.tenantID = "TEST_TENANT"
      let configWithTenant = AuthRequestConfiguration(
        apiKey: "FAKE_API_KEY",
        appID: "FAKE_APP_ID",
        auth: fakeAuth
      )
      request = FinalizePasskeyEnrollmentRequest(
        idToken: "ID_TOKEN",
        name: "MyPasskey",
        credentialID: "CRED_ID",
        clientDataJSON: "CLIENT_JSON",
        attestationObject: "ATTEST_OBJ",
        requestConfiguration: configWithTenant
      )
      let body = request.unencodedHTTPRequestBody
      XCTAssertEqual(body?["tenantId"] as? String, "TENANT_ID")
    }
  }

#endif
