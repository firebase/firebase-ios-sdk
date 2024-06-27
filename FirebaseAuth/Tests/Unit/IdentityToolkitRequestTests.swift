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

/// @class IdentityToolkitRequestTests
///    @brief Tests for @c IdentityToolkitRequest
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class IdentityToolkitRequestTests: XCTestCase {
  let kEndpoint = "endpoint"
  let kAPIKey = "APIKey"
  let kEmulatorHostAndPort = "emulatorhost:12345"

  /** @fn testInitWithEndpointExpectedRequestURL
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs.
   */
  func testInitWithEndpointExpectedRequestURL() {
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let request = IdentityToolkitRequest(endpoint: kEndpoint,
                                         requestConfiguration: requestConfiguration)
    let expectedURL = "https://www.googleapis.com/identitytoolkit/v3/relyingparty/\(kEndpoint)" +
      "?key=\(kAPIKey)"
    XCTAssertEqual(expectedURL, request.requestURL().absoluteString)
  }

  /** @fn testInitWithEndpointUseStagingExpectedRequestURL
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs when the staging endpoint is specified.
   */
  func testInitWithEndpointUseStagingExpectedRequestURL() {
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let request = IdentityToolkitRequest(endpoint: kEndpoint,
                                         requestConfiguration: requestConfiguration,
                                         useStaging: true)
    let expectedURL = "https://staging-www.sandbox.googleapis.com/identitytoolkit/v3/" +
      "relyingparty/\(kEndpoint)?key=\(kAPIKey)"
    XCTAssertEqual(expectedURL, request.requestURL().absoluteString)
  }

  /** @fn testInitWithEndpointUseIdentityPlatformExpectedRequestURL
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs when the Identity Platform endpoint is specified.
   */
  func testInitWithEndpointUseIdentityPlatformExpectedRequestURL() {
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let request = IdentityToolkitRequest(endpoint: kEndpoint,
                                         requestConfiguration: requestConfiguration,
                                         useIdentityPlatform: true)
    let expectedURL = "https://identitytoolkit.googleapis.com/v2/\(kEndpoint)?key=\(kAPIKey)"
    XCTAssertEqual(expectedURL, request.requestURL().absoluteString)
  }

  /** @fn testInitWithEndpointUseIdentityPlatformUseStagingExpectedRequestURL
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs when the Identity Platform and staging endpoint is specified.
   */
  func testInitWithEndpointUseIdentityPlatformUseStagingExpectedRequestURL() {
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    let request = IdentityToolkitRequest(endpoint: kEndpoint,
                                         requestConfiguration: requestConfiguration,
                                         useIdentityPlatform: true,
                                         useStaging: true)
    let expectedURL = "https://staging-identitytoolkit.sandbox.googleapis.com/v2" +
      "/\(kEndpoint)?key=\(kAPIKey)"
    XCTAssertEqual(expectedURL, request.requestURL().absoluteString)
  }

  /** @fn testInitWithEndpointUseEmulatorExpectedRequestURL
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs when the emulator is used.
   */
  func testInitWithEndpointUseEmulatorExpectedRequestURL() {
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    requestConfiguration.emulatorHostAndPort = kEmulatorHostAndPort
    let request = IdentityToolkitRequest(endpoint: kEndpoint,
                                         requestConfiguration: requestConfiguration)
    let expectedURL = "http://\(kEmulatorHostAndPort)/www.googleapis.com/identitytoolkit/v3/" +
      "relyingparty/\(kEndpoint)?key=\(kAPIKey)"
    XCTAssertEqual(expectedURL, request.requestURL().absoluteString)
  }

  /** @fn testInitWithEndpointUseIdentityPlatformUseEmulatorExpectedRequestURL
      @brief Tests the @c requestURL method to make sure the URL it produces corresponds to the
     request inputs when the emulator is used with the Identity Platform endpoint.
   */
  func testInitWithEndpointUseIdentityPlatformUseEmulatorExpectedRequestURL() {
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID")
    requestConfiguration.emulatorHostAndPort = kEmulatorHostAndPort
    let request = IdentityToolkitRequest(endpoint: kEndpoint,
                                         requestConfiguration: requestConfiguration,
                                         useIdentityPlatform: true)
    let expectedURL = "http://\(kEmulatorHostAndPort)/identitytoolkit.googleapis.com/v2/" +
      "\(kEndpoint)?key=\(kAPIKey)"
    XCTAssertEqual(expectedURL, request.requestURL().absoluteString)
  }

  /** @fn testExpectedTenantIDWithNonDefaultFIRApp
      @brief Tests the request correctly populated the tenant ID from a non default app.
   */
  func testExpectedTenantIDWithNonDefaultFIRApp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.apiKey = kAPIKey
    let nonDefaultApp = FirebaseApp(instanceWithName: "nonDefaultApp", options: options)
    let nonDefaultAuth = Auth(app: nonDefaultApp)
    nonDefaultAuth.tenantID = "tenant-id"
    let requestConfiguration = AuthRequestConfiguration(apiKey: kAPIKey, appID: "appID",
                                                        auth: nonDefaultAuth)
    requestConfiguration.emulatorHostAndPort = kEmulatorHostAndPort
    let request = IdentityToolkitRequest(endpoint: kEndpoint,
                                         requestConfiguration: requestConfiguration,
                                         useIdentityPlatform: true)
    XCTAssertEqual("tenant-id", request.tenantID)
  }
}
