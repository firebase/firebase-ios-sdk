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

@testable import FirebaseSessions
import XCTest

class SDKDefaultSettingsTests: XCTestCase {
  private var sdkDefaults: SDKDefaultSettings!

  override func setUp() {
    super.setUp()
    sdkDefaults = SDKDefaultSettings()
  }

  func test_SDKDefaultsSettings() {
    XCTAssertTrue(sdkDefaults.sessionsEnabled!)
    XCTAssertEqual(sdkDefaults.samplingRate, 1.0)
    XCTAssertEqual(sdkDefaults.sessionTimeout, 30 * 60)
  }

  func test_settingsNeverStale() {
    XCTAssertFalse(sdkDefaults.isSettingsStale())
  }
}
