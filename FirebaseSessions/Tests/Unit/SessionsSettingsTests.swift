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

class SessionsSettingsTests: XCTestCase {
  let validSettings: [String: Any] = [
    "cache_duration": 10,
    "app_quality": [
      "sessions_enabled": false,
      "sampling_rate": 0.5,
      "session_timeout_seconds": 10,
    ] as [String: Any],
  ]

  var cache: SettingsCacheClient!
  var appInfo: MockApplicationInfo!
  var downloader: MockSettingsDownloader!
  var remoteSettings: RemoteSettings!
  var localOverrideSettings: LocalOverrideSettings!
  var sdkDefaultSettings: SDKDefaultSettings!
  var sessionSettings: SessionsSettings!

  override func setUp() {
    super.setUp()
    appInfo = MockApplicationInfo()
    cache = SettingsCache()
    cache.removeCache() // just reinstantiating cache isn't enough because of persistence
    downloader = MockSettingsDownloader(successResponse: validSettings)
    remoteSettings = RemoteSettings(appInfo: appInfo, downloader: downloader, cache: cache)
    remoteSettings.updateSettings(currentTime: Date())

    localOverrideSettings = LocalOverrideSettings()
    sdkDefaultSettings = SDKDefaultSettings()

    sessionSettings = SessionsSettings(
      appInfo: appInfo,
      installations: MockInstallationsProtocol(),
      sdkDefaults: sdkDefaultSettings,
      localOverrides: localOverrideSettings,
      remoteSettings: remoteSettings
    )
  }

  func test_RemoteAndDefaultsPresent_RemoteConfigsApplied() {
    XCTAssertFalse(sessionSettings.sessionsEnabled)
    XCTAssertEqual(sessionSettings.samplingRate, 0.5)
    XCTAssertEqual(sessionSettings.sessionTimeout, 10)
  }

  func test_NoRemoteAndDefaultsPresent_DefaultConfigsApply() {
    let emptySettings: [String: Any] = [
      "cache_duration": 10,
      "app_quality": [:] as [String: Any],
    ]

    cache.removeCache()
    downloader = MockSettingsDownloader(successResponse: emptySettings)
    remoteSettings = RemoteSettings(appInfo: appInfo, downloader: downloader, cache: cache)
    remoteSettings.updateSettings(currentTime: Date())

    sessionSettings = SessionsSettings(
      appInfo: appInfo,
      installations: MockInstallationsProtocol(),
      sdkDefaults: sdkDefaultSettings,
      localOverrides: localOverrideSettings,
      remoteSettings: remoteSettings
    )

    XCTAssertTrue(sessionSettings.sessionsEnabled)
    XCTAssertEqual(sessionSettings.samplingRate, 1.0)
    XCTAssertEqual(sessionSettings.sessionTimeout, 30 * 60)
  }

  func test_SomeRemoteAndDefaultsPresent_SomeConfigsApply() {
    let someSettings: [String: Any] = [
      "cache_duration": 10,
      "app_quality": [
        "sampling_rate": 0.8,
        "session_timeout_seconds": 50,
      ],
    ]

    cache.removeCache()
    downloader = MockSettingsDownloader(successResponse: someSettings)
    remoteSettings = RemoteSettings(appInfo: appInfo, downloader: downloader, cache: cache)
    remoteSettings.updateSettings(currentTime: Date())

    sessionSettings = SessionsSettings(
      appInfo: appInfo,
      installations: MockInstallationsProtocol(),
      sdkDefaults: sdkDefaultSettings,
      localOverrides: localOverrideSettings,
      remoteSettings: remoteSettings
    )

    XCTAssertTrue(sessionSettings.sessionsEnabled)
    XCTAssertEqual(sessionSettings.samplingRate, 0.8)
    XCTAssertEqual(sessionSettings.sessionTimeout, 50)
  }
}
