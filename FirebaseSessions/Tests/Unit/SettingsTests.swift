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
    "sessions_enabled": false,
    "sampling_rate": 0.5,
    "session_timeout": 10,
  ]
  let corruptedJSONString: String = "{{{{ non_key: non\"value {}"
  var cache: SettingsCacheClient!
  var settings: Settings!
  var appInfo: MockApplicationInfo!

  override func setUp() {
    appInfo = MockApplicationInfo()
    cache = SettingsCache()
    cache.removeCache()
    settings = Settings(cache: cache, appInfo: appInfo)
  }

  func test_noCacheSaved_returnsDefaultSettings() {
    XCTAssertTrue(settings.isCacheExpired(currentTime: Date.distantFuture))
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  func test_activatedCache_returnsCachedSettings() {
    appInfo.mockAllInfo()
    let cacheKey = CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)

    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    XCTAssertFalse(settings.isCacheExpired(currentTime: now))
    // Should be same as self.validSettings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)
  }

  func test_cacheKeyExpiredFromAppVersion_marksCacheAsExpired() {
    appInfo.mockAllInfo()
    let cacheKey = CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)

    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    appInfo.appBuildVersion = "testNewAppBuildVersion"
    appInfo.appDisplayVersion = "testNewAppDisplayVersion"
    XCTAssertTrue(settings.isCacheExpired(currentTime: now)) // requires refetch
    // However, still provide already cached settings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)
  }

  func test_cacheKeyExpiredFromTTL_marksCacheAsExpired() {
    appInfo.mockAllInfo()
    let cacheKey = CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)

    // time passed = 11, TTL = 10, tim passed > TTL
    let now = date.addingTimeInterval(11)
    XCTAssertTrue(settings.isCacheExpired(currentTime: now)) // requires refetch
    // However, still provide already cached settings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)
  }

  func test_cacheKeyGoogleAppIDChanged_returnsDefaultSettings() {
    appInfo.mockAllInfo()
    let cacheKey = CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)

    // change appID
    appInfo.appID = "testDifferentGoogleAppID"
    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    XCTAssertTrue(settings.isCacheExpired(currentTime: now)) // requires refetch
    // provide default settings
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  func test_corruptedCache_returnsDefaultSettings() {
    // First write and load a valid settings file
    appInfo.mockAllInfo()
    let cacheKey = CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)
    let now = date.addingTimeInterval(5)
    XCTAssertFalse(settings.isCacheExpired(currentTime: now))
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)

    // Then write a corrupted one and reload it
    write(jsonString: corruptedJSONString)
    XCTAssertTrue(settings.isCacheExpired(currentTime: now))
    // should have default values
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  func test_corruptedCacheKey_returnsDefaultSettings() {
    // First write and load a valid settings file
    appInfo.mockAllInfo()
    let cacheKey = CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)
    let now = date.addingTimeInterval(5)
    XCTAssertFalse(settings.isCacheExpired(currentTime: now))
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)

    // Then write a corrupted one and reload it
    write(jsonString: corruptedJSONString, isCacheKey: true)
    XCTAssertTrue(settings.isCacheExpired(currentTime: now))
    // should have default values
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  // TODO: make Settings.CacheKey private again after implementing download and save
  func write(cacheKey: CacheKey) {
    do {
      try UserDefaults.standard.set(
        JSONEncoder().encode(cacheKey),
        forKey: "firebase-sessions-cache-key"
      )
    } catch {
      print("SettingsTests: \(error)")
    }
  }

  func write(settings: [String: Any]) {
    UserDefaults.standard.set(settings, forKey: "firebase-sessions-settings")
  }

  func write(jsonString: String, isCacheKey: Bool = true) {
    let name = isCacheKey ? "firebase-sessions-cache-key" : "firebase-sessions-settings"
    UserDefaults.standard.set(jsonString, forKey: name)
  }
}
