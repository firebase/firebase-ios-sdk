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
  let fileManager: FileManager = .default
  var settingsFileManager: SettingsFileManagerProtocol!
  var settings: Settings!
  var appInfo: MockApplicationInfo!

  override func setUp() {
    appInfo = MockApplicationInfo()
    settingsFileManager = MockSettingsFileManager(fileManager: fileManager)
    settings = Settings(fileManager: settingsFileManager, appInfo: appInfo)
  }

  func test_noCacheSaved_returnsDefaultSettings() {
    XCTAssertTrue(settings.isCacheExpired)
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  func test_activatedCache_returnsCachedSettings() {
    appInfo.mockAllInfo()
    let cacheKey = Settings.CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)

    // time passed = 5, TTL = 10, time passed < TTL
    let now = date.addingTimeInterval(5)
    settings.loadCache(googleAppID: appInfo.appID, currentTime: now)
    // Should be same as self.validSettings
    XCTAssertFalse(settings.isCacheExpired)
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)
  }

  func test_cacheKeyExpiredFromAppVersion_marksCacheAsExpired() {
    appInfo.mockAllInfo()
    let cacheKey = Settings.CacheKey(
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
    settings.loadCache(googleAppID: appInfo.appID, currentTime: now)
    // App version change warrants refetch
    XCTAssertTrue(settings.isCacheExpired) // only change from self.validSettings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)
  }

  func test_cacheKeyExpiredFromTTL_marksCacheAsExpired() {
    appInfo.mockAllInfo()
    let cacheKey = Settings.CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)

    // time passed = 11, TTL = 10, tim passed > TTL
    let now = date.addingTimeInterval(11)
    settings.loadCache(googleAppID: appInfo.appID, currentTime: now)
    XCTAssertTrue(settings.isCacheExpired) // only change from self.validSettings
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)
  }

  func test_cacheKeyGoogleAppIDChanged_returnsDefaultSettings() {
    appInfo.mockAllInfo()
    let cacheKey = Settings.CacheKey(
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
    settings.loadCache(googleAppID: appInfo.appID, currentTime: now)
    // these are the default settings
    XCTAssertTrue(settings.isCacheExpired)
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  func test_corruptedCache_returnsDefaultSettings() {
    // First write and load a valid settings file
    appInfo.mockAllInfo()
    let cacheKey = Settings.CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)
    let now = date.addingTimeInterval(5)
    settings.loadCache(googleAppID: appInfo.appID, currentTime: now)
    XCTAssertFalse(settings.isCacheExpired)
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)

    // Then write a corrupted one and reload it
    write(jsonString: corruptedJSONString)
    settings.loadCache(googleAppID: appInfo.appID, currentTime: now)
    // should have default values
    XCTAssertTrue(settings.isCacheExpired)
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  func test_corruptedCacheKey_returnsDefaultSettings() {
    // First write and load a valid settings file
    appInfo.mockAllInfo()
    let cacheKey = Settings.CacheKey(
      createdAt: date,
      googleAppID: appInfo.appID,
      appVersion: appInfo.synthesizedVersion
    )
    write(settings: validSettings)
    write(cacheKey: cacheKey)
    let now = date.addingTimeInterval(5)
    settings.loadCache(googleAppID: appInfo.appID, currentTime: now)
    XCTAssertFalse(settings.isCacheExpired)
    XCTAssertFalse(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 0.5)
    XCTAssertEqual(settings.sessionTimeout, 10)

    // Then write a corrupted one and reload it
    write(jsonString: corruptedJSONString, isCacheKey: true)
    settings.loadCache(googleAppID: appInfo.appID, currentTime: now)
    // should have default values
    XCTAssertTrue(settings.isCacheExpired)
    XCTAssertTrue(settings.sessionsEnabled)
    XCTAssertEqual(settings.samplingRate, 1)
    XCTAssertEqual(settings.sessionTimeout, 30 * 60)
  }

  // TODO: make Settings.CacheKey private again after implementing download and save
  func write(cacheKey: Settings.CacheKey) {
    do {
      try JSONEncoder().encode(cacheKey).write(to:
        settingsFileManager.settingsCacheKeyPath)
    } catch {
      print("SettingsTests: \(error)")
    }
  }

  func write(settings: [String: Any]) {
    do {
      try JSONSerialization.data(withJSONObject: settings)
        .write(to: settingsFileManager.settingsCacheContentPath)
    } catch {
      print("SettingsTests: \(error)")
    }
  }

  func write(jsonString: String, isCacheKey: Bool = true) {
    let path = isCacheKey ? settingsFileManager.settingsCacheKeyPath : settingsFileManager
      .settingsCacheContentPath
    do {
      try jsonString.write(to: path, atomically: false, encoding: .utf8)
    } catch {
      print("SettingsTests: \(error)")
    }
  }
}
