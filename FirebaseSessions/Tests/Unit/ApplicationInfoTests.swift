//
// Copyright 2022 Google LLC
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

import XCTest

@testable import FirebaseSessions

class ApplicationInfoTests: XCTestCase {
  var appInfo: ApplicationInfo!
  var mockNetworkInfo: MockNetworkInfo!

  override func setUp() {
    super.setUp()
    mockNetworkInfo = MockNetworkInfo()
    appInfo = ApplicationInfo(appID: "testAppID", networkInfo: mockNetworkInfo)
  }

  func test_LogEnvironment_hasProdAsDefault() {
    XCTAssertEqual(appInfo.environment, .prod)
  }

  func test_LogEnvironment_takesOverrideValues() {
    var envValues = ["FirebaseSessionsRunEnvironment": "prod"]
    var appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .prod)

    envValues = ["FirebaseSessionsRunEnvironment": "PROD"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .prod)

    // Verify staging overrides
    envValues = ["FirebaseSessionsRunEnvironment": "staging"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .staging)

    // Verify staging overrides
    envValues = ["FirebaseSessionsRunEnvironment": "STAGING"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .staging)

    // Verify autopush overrides
    envValues = ["FirebaseSessionsRunEnvironment": "autopush"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .autopush)

    envValues = ["FirebaseSessionsRunEnvironment": "AUTOPUSH"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .autopush)

    // Verify random overrides
    envValues = ["FirebaseSessionsRunEnvironment": "random"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .prod)

    envValues = ["FirebaseSessionsRunEnvironment": ""]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .prod)
  }

  func test_bundleVersions_correspondToVersion() {
    let appInfo = ApplicationInfo(
      appID: "testAppID",
      networkInfo: mockNetworkInfo,
      envParams: [:],
      infoDict: [
        "CFBundleVersion": "54321", // Build Version
        "CFBundleShortVersionString": "12.34.5", // Display Version
      ]
    )
    XCTAssertEqual(appInfo.appBuildVersion, "54321")
    XCTAssertEqual(appInfo.appDisplayVersion, "12.34.5")
  }
}
