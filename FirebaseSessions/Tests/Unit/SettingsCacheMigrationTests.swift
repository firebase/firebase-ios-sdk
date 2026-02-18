// Copyright 2026 Google LLC
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

#if SWIFT_PACKAGE
  internal import GoogleUtilities_UserDefaults
#else
  internal import GoogleUtilities
#endif

class SettingsCacheMigrationTests: XCTestCase {
  private let userDefaults = GULUserDefaults.standard()
  private let contentKey = "firebase-sessions-settings"
  private let namespace = "app_quality"

  override func setUp() {
    super.setUp()
    userDefaults.removeObject(forKey: contentKey)
  }

  override func tearDown() {
    userDefaults.removeObject(forKey: contentKey)
    super.tearDown()
  }

  func test_ReadFromLegacyData_Success() {
    // 1. Setup Legacy Components to write data "The Old Way"
    let appInfo = MockApplicationInfo()

    // Simulate server response with Ints
    let legacyServerResponse: [String: Any] = [
      "cache_duration": 60, // Int
      "app_quality": [
        "sessions_enabled": true,
        "sampling_rate": 0.5,
        "session_timeout_seconds": 10, // Int
      ],
    ]
    let downloader = MockSettingsDownloader(successResponse: legacyServerResponse)

    // Use LegacyRemoteSettings to fetch and write to disk
    // This ensures we are testing against the EXACT disk format used by the old version
    let legacySettings = LegacyRemoteSettings(appInfo: appInfo, downloader: downloader)
    legacySettings.updateSettings(currentTime: Date())

    // 2. Initialize the "New" SettingsCache
    // This will load from the same UserDefaults location
    let cache = SettingsCache(namespace: namespace)

    // 3. Verify it reads the data correctly via value(forKey:)

    // Check ROOT key (should be preserved)
    let cacheDuration: TimeInterval? = cache.rootValue(forKey: "cache_duration")
    XCTAssertEqual(cacheDuration, 60.0)

    // Check namespaced keys (should be found in namespace)
    XCTAssertEqual(cache.namespacedValue(forKey: "sessions_enabled"), true)
    XCTAssertEqual(cache.namespacedValue(forKey: "sampling_rate"), 0.5)
    // Check NSNumber bridging (Int -> Double)
    let timeout: TimeInterval? = cache.namespacedValue(forKey: "session_timeout_seconds")
    XCTAssertEqual(timeout, 10.0)
  }

  func test_WriteOverwritesOtherNamespaces_MatchesLegacyBehavior() {
    // 1. Setup initial state with Legacy Writer
    let appInfo = MockApplicationInfo()
    let initialResponse: [String: Any] = [
      "root_key": 999,
      "app_quality": ["some_key": 123],
    ]
    let downloader = MockSettingsDownloader(successResponse: initialResponse)
    let legacySettings = LegacyRemoteSettings(appInfo: appInfo, downloader: downloader)
    legacySettings.updateSettings(currentTime: Date())

    // 2. Inject "Other Namespace" data directly into UserDefaults
    var rootDict = userDefaults.object(forKey: contentKey) as? [String: Any] ?? [:]
    rootDict["other_namespace"] = ["other_key": "other_value"]
    userDefaults.setObject(rootDict, forKey: contentKey)

    // 3. Initialize New Cache and Update
    let cache = SettingsCache(namespace: namespace)

    // Construct new settings mimicking the server structure
    let newSettings: [String: Any] = [
      namespace: ["some_key": 456, "new_key": "hello"],
    ]
    cache.updateContents(newSettings)

    // 4. Verify Persistence on Disk
    guard let storedRoot = userDefaults.object(forKey: contentKey) as? [String: Any] else {
      XCTFail("Could not read root dictionary from UserDefaults")
      return
    }

    // Verify our namespace updated
    if let storedAppQuality = storedRoot[namespace] as? [String: Any] {
      XCTAssertEqual(storedAppQuality["some_key"] as? Int, 456)
      XCTAssertEqual(storedAppQuality["new_key"] as? String, "hello")
    } else {
      XCTFail("Namespace \(namespace) missing from disk")
    }

    // Verify legacy "root_key" is GONE (because newSettings didn't have it)
    XCTAssertNil(storedRoot["root_key"])

    // Verify "other_namespace" is GONE (Overwrite behavior confirmed)
    XCTAssertNil(storedRoot["other_namespace"])
  }
}
