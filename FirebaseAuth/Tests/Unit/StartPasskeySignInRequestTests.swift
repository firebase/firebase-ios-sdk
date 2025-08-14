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
  final class StartPasskeySignInRequestTests: XCTestCase {
    private var config: AuthRequestConfiguration!

    override func setUp() {
      super.setUp()
      config = AuthRequestConfiguration(
        apiKey: "FAKE_API_KEY",
        appID: "FAKE_APP_ID"
      )
    }

    override func tearDown() {
      config = nil
      super.tearDown()
    }

    func testInit_SetsEndpointAndConfig() {
      let request = StartPasskeySignInRequest(requestConfiguration: config)
      XCTAssertEqual(request.endpoint, "accounts/passkeySignIn:start")
      XCTAssertTrue(request.useIdentityPlatform)
      XCTAssertEqual(request.requestConfiguration().apiKey, "FAKE_API_KEY")
      XCTAssertEqual(request.requestConfiguration().appID, "FAKE_APP_ID")
    }

    func testUnencodedHTTPRequestBody_WithTenantId() {
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
      _ = AuthRequestConfiguration(apiKey: "apiKey", appID: "appId")
      let request = StartPasskeySignInRequest(
        requestConfiguration: configWithTenant
      )
      let body = request.unencodedHTTPRequestBody
      XCTAssertEqual(body!["tenantId"], "TEST_TENANT")
    }

    func testUnencodedHTTPRequestBody_WithoutTenantId() {
      let request = StartPasskeySignInRequest(requestConfiguration: config)
      XCTAssertNil(request.unencodedHTTPRequestBody)
    }
  }

#endif
