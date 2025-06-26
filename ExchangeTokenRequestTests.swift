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
import FirebaseCore

/// Tests for `ExchangeTokenRequest`
@available(iOS 13, *)
class ExchangeTokenRequestTests: XCTestCase {
  // MARK: - Constants for Testing

  let kAPIKey = "test-api-key"
  let kProjectID = "test-project-id"
  let kLocation = "us-east1"
  let kTenantID = "test-tenant-id-123"
  let kIdToken = "a-very-long-and-secure-oidc-token-string"
  let kIdpConfigId = "oidc.my-test-provider"

  let kProductionHost = "identityplatform.googleapis.com"
  let kStagingHost = "staging-identityplatform.sandbox.googleapis.com"

  // MARK: - Test Cases

  /// Tests that the production URL is correctly formed for a specific region.
  func testProductionURLIsCorrectlyConstructed() {
    let (auth, app) = createTestAuthInstance(
      projectID: kProjectID,
      location: kLocation,
      tenantId: kTenantID
    )

    let request = ExchangeTokenRequest(
      idToken: kIdToken,
      idpConfigID: kIdpConfigId,
      config: auth.requestConfiguration,
      useStaging: false
    )

    let expectedHost = "\(kLocation)-\(kProductionHost)"
    let expectedURL = "https://\(expectedHost)/v2beta/projects/\(kProjectID)" +
      "/locations/\(kLocation)/tenants/\(kTenantID)/idpConfigs/\(kIdpConfigId):exchangeOidcToken?key=\(kAPIKey)"

    XCTAssertEqual(request.requestURL().absoluteString, expectedURL)
  }

  /// Tests that the production URL is correctly formed for the "prod-global" location.
  func testProductionURLIsCorrectlyConstructedForGlobalLocation() {
    let (auth, app) = createTestAuthInstance(
      projectID: kProjectID,
      location: "prod-global",
      tenantId: kTenantID
    )
    _ = app

    let request = ExchangeTokenRequest(
      idToken: kIdToken,
      idpConfigID: kIdpConfigId,
      config: auth.requestConfiguration,
      useStaging: false
    )

    let expectedHost = kProductionHost
    let expectedURL = "https://\(expectedHost)/v2beta/projects/\(kProjectID)" +
      "/locations/global/tenants/\(kTenantID)/idpConfigs/\(kIdpConfigId):exchangeOidcToken?key=\(kAPIKey)"

    XCTAssertEqual(request.requestURL().absoluteString, expectedURL)
  }

  /// Tests that the staging URL is correctly formed.
  func testStagingURLIsCorrectlyConstructed() {
    let (auth, app) = createTestAuthInstance(
      projectID: kProjectID,
      location: kLocation,
      tenantId: kTenantID
    )
    _ = app

    let request = ExchangeTokenRequest(
      idToken: kIdToken,
      idpConfigID: kIdpConfigId,
      config: auth.requestConfiguration,
      useStaging: true
    )

    let expectedHost = "\(kLocation)-\(kStagingHost)"
    let expectedURL = "https://\(expectedHost)/v2beta/projects/\(kProjectID)" +
      "/locations/\(kLocation)/tenants/\(kTenantID)/idpConfigs/\(kIdpConfigId):exchangeOidcToken?key=\(kAPIKey)"

    XCTAssertEqual(request.requestURL().absoluteString, expectedURL)
  }

  /// Tests that the unencoded HTTP body contains the correct id_token.
  func testUnencodedHTTPBodyIsCorrect() {
    let (auth, app) = createTestAuthInstance(
      projectID: kProjectID,
      location: kLocation,
      tenantId: kTenantID
    )
    _ = app

    let request = ExchangeTokenRequest(
      idToken: kIdToken,
      idpConfigID: kIdpConfigId,
      config: auth.requestConfiguration
    )

    let body = request.unencodedHTTPRequestBody
    XCTAssertNotNil(body)
    XCTAssertEqual(body?.count, 1)
    XCTAssertEqual(body?["id_token"] as? String, kIdToken)
  }

  // MARK: - Helper Function

  /// Creates a test FirebaseApp and Auth instance with specified configurations.
  private func createTestAuthInstance(projectID: String?, location: String?,
                                      tenantId: String?) -> (auth: Auth, app: FirebaseApp) {
    let appName = "TestApp-\(UUID().uuidString)"
    let options = FirebaseOptions(
      googleAppID: "1:1234567890:ios:abcdef123456",
      gcmSenderID: "1234567890"
    )
    options.apiKey = kAPIKey
    if let projectID = projectID {
      options.projectID = projectID
    }

    if FirebaseApp.app(name: appName) != nil {
      FirebaseApp.app(name: appName)?.delete { _ in }
    }
    let app = FirebaseApp(instanceWithName: appName, options: options)

    let auth = Auth(app: app)
    auth.app = app
    auth.requestConfiguration.location = location
    auth.requestConfiguration.tenantId = tenantId

    return (auth, app)
  }
}
