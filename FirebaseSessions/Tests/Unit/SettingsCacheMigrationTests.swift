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
    // 1. Setup legacy components to write data using the legacy implementation
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
    // This ensures we are testing against the exact disk format used by the old version
    let legacySettings = LegacyRemoteSettings(appInfo: appInfo, downloader: downloader)
    legacySettings.updateSettings(currentTime: Date())

    // 2. Initialize the "New" SettingsCache
    // This will load from the same UserDefaults location
    let cache = SettingsCache(namespace: namespace)

    // 3. Verify it reads the data correctly via value(forKey:)

    // Check root key (should be preserved)
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

    // Verify legacy "root_key" is removed (because newSettings didn't have it)
    XCTAssertNil(storedRoot["root_key"])

    // Verify "other_namespace" is removed (overwrite behavior confirmed)
    XCTAssertNil(storedRoot["other_namespace"])
  }

  func test_ReadFromLegacyData_MissingNamespace_ReturnsNil() {
    // 1. Setup Legacy Data without the namespace
    let legacyServerResponse: [String: Any] = [
      "cache_duration": 60,
      "other_namespace": [
        "some_key": "some_value",
      ],
    ]
    userDefaults.setObject(legacyServerResponse, forKey: contentKey)

    // 2. Initialize Cache
    let cache = SettingsCache(namespace: namespace)

    // 3. Verify
    let cacheDuration: Double? = cache.rootValue(forKey: "cache_duration")
    XCTAssertEqual(cacheDuration, 60)
    let sessionsEnabled: Bool? = cache.namespacedValue(forKey: "sessions_enabled")
    XCTAssertNil(sessionsEnabled)
  }

  func test_ReadFromLegacyData_TypeMismatch_ReturnsNil() {
    // 1. Setup Legacy Data with mismatched types
    let legacyServerResponse: [String: Any] = [
      namespace: [
        "sessions_enabled": "true", // String instead of Bool
        "sampling_rate": "0.5", // String instead of Double
      ],
    ]
    userDefaults.setObject(legacyServerResponse, forKey: contentKey)

    // 2. Initialize Cache
    let cache = SettingsCache(namespace: namespace)

    // 3. Verify
    let sessionsEnabled: Bool? = cache.namespacedValue(forKey: "sessions_enabled")
    XCTAssertNil(sessionsEnabled)
    let samplingRate: Double? = cache.namespacedValue(forKey: "sampling_rate")
    XCTAssertNil(samplingRate)
  }

  func test_ReadFromLegacyData_CorruptedRoot_ReturnsEmpty() {
    // 1. Setup Corrupted Data (String instead of Dict)
    userDefaults.setObject("Not A Dictionary", forKey: contentKey)

    // 2. Initialize Cache
    let cache = SettingsCache(namespace: namespace)

    // 3. Verify it starts empty
    let duration: Double? = cache.rootValue(forKey: "cache_duration")
    XCTAssertNil(duration)
    let enabled: Bool? = cache.namespacedValue(forKey: "sessions_enabled")
    XCTAssertNil(enabled)
  }

  func test_MetadataMigration_HonorsLegacyCacheKey() {
    // 1. Setup Legacy Data & Metadata
    let appInfo = MockApplicationInfo()
    let creationTime = Date()

    let legacyResponse: [String: Any] = [
      "cache_duration": 86400, // 24 hours
      "app_quality": ["sessions_enabled": true],
    ]
    let downloader = MockSettingsDownloader(successResponse: legacyResponse)
    let legacySettings = LegacyRemoteSettings(appInfo: appInfo, downloader: downloader)

    // Write legacy settings at 'creationTime'
    legacySettings.updateSettings(currentTime: creationTime)

    // 2. Initialize New Cache
    let cache = SettingsCache(namespace: namespace)

    // 3. Verify Not Expired (Time < Duration)
    // Advance time by 1 hour (much less than 24h)
    let futureTime = creationTime.addingTimeInterval(3600)
    XCTAssertFalse(cache.isExpired(for: appInfo, time: futureTime))

    // 4. Verify Expired (Time > Duration)
    // Advance time by 25 hours
    let wayFutureTime = creationTime.addingTimeInterval(86400 + 1)
    XCTAssertTrue(cache.isExpired(for: appInfo, time: wayFutureTime))
  }

  func test_Downgrade_WriteFromNew_ReadFromLegacy_Success() {
    // 1. Initialize New Cache and Write Data
    let cache = SettingsCache(namespace: namespace)
    let newSettings: [String: Any] = [
      namespace: [
        "sessions_enabled": false,
        "sampling_rate": 0.25,
        "session_timeout_seconds": 300,
      ],
      "cache_duration": 120,
    ]
    cache.updateContents(newSettings)

    // 2. Initialize Legacy Component (Simulating Downgrade)
    let appInfo = MockApplicationInfo()
    let downloader = MockSettingsDownloader(successResponse: [:]) // Not used for reading
    let legacySettings = LegacyRemoteSettings(appInfo: appInfo, downloader: downloader)

    // 3. Verify Legacy component can read the data written by New Cache
    XCTAssertEqual(legacySettings.sessionsEnabled, false)
    XCTAssertEqual(legacySettings.samplingRate, 0.25)
    XCTAssertEqual(legacySettings.sessionTimeout, 300)
    // LegacySettingsCache reads cache_duration internally to determine expiration
    // We can verify it didn't crash and read the values correctly.
  }
}
