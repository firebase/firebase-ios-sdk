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

  func test_mccMNC_validatesCorrectly() {
    let expectations: [(mobileCountryCode: String, mobileNetworkCode: String, expected: String)] = [
      ("310", "004", "310004"),
      ("310", "01", "31001"),
      ("001", "50", "00150"),
    ]

    expectations
      .forEach { (mobileCountryCode: String, mobileNetworkCode: String, expected: String) in
        mockNetworkInfo.mobileCountryCode = mobileCountryCode
        mockNetworkInfo.mobileNetworkCode = mobileNetworkCode

        XCTAssertEqual(appInfo.mccMNC, expected)
      }
  }

  func test_mccMNC_isEmptyWhenInvalid() {
    let expectations: [(mobileCountryCode: String?, mobileNetworkCode: String?)] = [
      ("3100", "004"), // MCC too long
      ("31", "01"), // MCC too short
      ("310", "0512"), // MNC too long
      ("L00", "003"), // MCC contains non-decimal characters
      ("300", "00T"), // MNC contains non-decimal characters
      (nil, nil), // Handle nils gracefully
      (nil, "001"),
      ("310", nil),
    ]

    expectations.forEach { (mobileCountryCode: String?, mobileNetworkCode: String?) in
      mockNetworkInfo.mobileCountryCode = mobileCountryCode
      mockNetworkInfo.mobileNetworkCode = mobileNetworkCode

      XCTAssertEqual(appInfo.mccMNC, "")
    }
  }
  
  func test_LogEnvironment_hasProdAsDefault() {
    XCTAssertEqual(appInfo.environment, .prod)
  }

  func test_LogEnvironment_takesOverrideValues() {
    var envValues: [String: String] = ["FIREBASE_RUN_ENVIRONMENT": "prod"]
    var appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .prod)

    envValues = ["FIREBASE_RUN_ENVIRONMENT": "PROD"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .prod)

    // Verify staging overrides
    envValues = ["FIREBASE_RUN_ENVIRONMENT": "staging"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .staging)

    // Verify staging overrides
    envValues = ["FIREBASE_RUN_ENVIRONMENT": "STAGING"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .staging)

    // Verify autopush overrides
    envValues = ["FIREBASE_RUN_ENVIRONMENT": "autopush"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .autopush)

    envValues = ["FIREBASE_RUN_ENVIRONMENT": "AUTOPUSH"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .autopush)

    // Verify random overrides
    envValues = ["FIREBASE_RUN_ENVIRONMENT": "random"]
    appInfo = ApplicationInfo(appID: "testAppID", envParams: envValues)
    XCTAssertEqual(appInfo.environment, .prod)
  }
}
