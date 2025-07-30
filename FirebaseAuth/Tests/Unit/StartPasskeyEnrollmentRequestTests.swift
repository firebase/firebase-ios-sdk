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

@testable import FirebaseAuth
import Foundation
import FirebaseCore
import XCTest

@available(iOS 15.0, macOS 12.0, tvOS 16.0, *)
class StartPasskeyEnrollmentRequestTests: XCTestCase {

  private var request: StartPasskeyEnrollmentRequest!
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

  func testInitWithValidIdTokenAndConfiguration() {
    request = StartPasskeyEnrollmentRequest(
      idToken: "FAKE_ID_TOKEN",
      requestConfiguration: fakeConfig
    )
    XCTAssertEqual(request.idToken, "FAKE_ID_TOKEN")
    XCTAssertEqual(request.endpoint, "accounts/passkeyEnrollment:start")
    XCTAssertTrue(request.useIdentityPlatform)
  }

  func testUnencodedHTTPRequestBodyWithoutTenantId() {
    request = StartPasskeyEnrollmentRequest(
      idToken: "FAKE_ID_TOKEN",
      requestConfiguration: fakeConfig
    )
    let body = request.unencodedHTTPRequestBody
    XCTAssertNotNil(body)
    XCTAssertEqual(body?["idToken"] as? String, "FAKE_ID_TOKEN")
    XCTAssertNil(body?["tenantId"])
  }

  func testUnencodedHTTPRequestBodyWithTenantId() {
    //setting up fake auth to set tenantId
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
    request = StartPasskeyEnrollmentRequest(
      idToken: "FAKE_ID_TOKEN",
      requestConfiguration: configWithTenant
    )
    let body = request.unencodedHTTPRequestBody
    XCTAssertNotNil(body)
    XCTAssertEqual(body?["idToken"] as? String, "FAKE_ID_TOKEN")
    XCTAssertEqual(body?["tenantId"] as? String, "TEST_TENANT")
  }
}
