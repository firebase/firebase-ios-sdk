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

class SettingsTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)
  let validSettings: [String: Any] = [
    "cache_duration": 10,
    "app_quality": [
      "sessions_enabled": false,
      "sampling_rate": 0.5,
      "session_timeout_seconds": 10,
    ],
  ]
  let validSettings2: [String: Any] = [
    "cache_duration": 20,
    "app_quality": [
      "sessions_enabled": true,
      "sampling_rate": 0.2,
      "session_timeout_seconds": 20,
    ],
  ]
  let corruptedJSONString: String = "{{{{ non_key: non\"value {}"
  var cache: SettingsCacheClient!
  var appInfo: MockApplicationInfo!
  var downloader: MockSettingsDownloader!
  var settings: SettingsProtocol!

  override func setUp() {
    super.setUp()
    appInfo = MockApplicationInfo()
    downloader = MockSettingsDownloader(successResponse: validSettings)
    cache = SettingsCache()
    cache.removeCache() // just resintantiating cache isn't enough because of persistence
    settings = Settings(appInfo: appInfo, downloader: downloader, cache: cache)
  }

  func test_noCacheSaved_returnsDefaultSettings() {
    downloader.shouldSucceed = false
    settings.fetchAndCacheSettings(currentTime: Date.distantFuture)
    XCTAssertNil(cache.cacheContent)
    XCTAssertNil(cache.cacheKey)
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  func test_successfulFetch_returnsCachedSettings() {
    appInfo.mockAllInfo()
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: date)

    // Should be same as self.validSettings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)
  }

  func test_cacheKeyIsNotExpired_stopsFetchFromProceeding() {
    // Given
    appInfo.mockAllInfo()
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: date)

    // When
    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    // downloader will return new setting
    downloader.successResponse = validSettings2
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // fetch did not happen, still provide old cached settings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)
  }

  func test_cacheKeyExpiredFromAppVersion_fetchNewSettingsOrContinueOldSettings() {
    // Given
    appInfo.mockAllInfo()
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: date)

    // When
    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    appInfo.appBuildVersion = "testNewAppBuildVersion"
    appInfo.appDisplayVersion = "testNewAppDisplayVersion"
    // downloader fails
    downloader.shouldSucceed = false
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // However, still provide already cached settings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)

    // When
    // time passed = 5, TTL = 10, time passed < TTL
    // downloader succeeds
    downloader.successResponse = validSettings2
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // provide new settings
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.2)
    XCTAssertEqual(settings.sessionTimeout, 20)
  }

  func test_cacheKeyExpiredFromTTL_fetchNewSettingsOrContinueOldSettings() {
    // Given
    appInfo.mockAllInfo()
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: date)

    // When
    // time passed = 11, TTL = 10, tim passed > TTL
    let now = date.addingTimeInterval(11)
    // downloader fails
    downloader.shouldSucceed = false
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // However, still provide already cached settings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)

    // When
    // time passed = 11, TTL = 10, time passed < TTL
    // downloader succeeds
    downloader.successResponse = validSettings2
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // provide new settings
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.2)
    XCTAssertEqual(settings.sessionTimeout, 20)
  }

  func test_cacheKeyGoogleAppIDChanged_fetchNewSettingsOrUseDefaults() {
    // Given
    appInfo.mockAllInfo()
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: date)

    // When
    // change appID
    appInfo.appID = "testDifferentGoogleAppID"
    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    // downloader fails
    downloader.shouldSucceed = false
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // provide default settings
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)

    // When
    // time passed = 5, TTL = 10, time passed < TTL
    // downloader succeeds
    downloader.successResponse = validSettings2
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // provide new settings
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.2)
    XCTAssertEqual(settings.sessionTimeout, 20)
  }

  func test_corruptedCache_returnsDefaultSettings() {
    // Given
    appInfo.mockAllInfo()
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: date)
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)

    // When
    write(jsonString: corruptedJSONString, isCacheKey: false)
    // Then
    // should provide default values
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)

    // When
    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    downloader.successResponse = validSettings2
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // Fetch proceeds, provide new settings
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.2)
    XCTAssertEqual(settings.sessionTimeout, 20)
  }

  func test_corruptedCacheKey_returnsDefaultSettings() {
    // Given
    appInfo.mockAllInfo()
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: date)
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)

    // When
    // cache key is corrupted, and fetch fails
    write(jsonString: corruptedJSONString, isCacheKey: true)
    downloader.shouldSucceed = false
    settings.fetchAndCacheSettings(currentTime: date)
    // Then
    // should provide default values
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)

    // When
    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    downloader.successResponse = validSettings2
    downloader.shouldSucceed = true
    settings.fetchAndCacheSettings(currentTime: now)
    // Then
    // Fetch proceeds, provide new settings
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.2)
    XCTAssertEqual(settings.sessionTimeout, 20)
  }

  func write(jsonString: String, isCacheKey: Bool) {
    let name = isCacheKey ? "firebase-sessions-cache-key" : "firebase-sessions-settings"
    UserDefaults.standard.set(jsonString, forKey: name)
  }
}
