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

class InitiatorTests: XCTestCase {
  // 2021-11-01 @ 00:00:00 (EST)
  let date = Date(timeIntervalSince1970: 1_635_739_200)
  let validSettings: [String: Any] = [:]

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

  func test_beginListening_initiatesColdStart() throws {
    let initiator = SessionInitiator(settings: sessionSettings)
    var initiateCalled = false
    initiator.beginListening {
      initiateCalled = true
    }
    XCTAssert(initiateCalled)
  }

  func test_appForegrounded_initiatesNewSession() throws {
    // Given
    var pausedClock = date
    let initiator = SessionInitiator(
      settings: sessionSettings,
      currentTimeProvider: { pausedClock }
    )
    var sessionCount = 0
    initiator.beginListening {
      sessionCount += 1
    }
    XCTAssert(sessionCount == 1)

    // When
    // Background, advance time by 30 minutes + 1 second, then foreground
    postBackgroundedNotification()
    pausedClock.addTimeInterval(30 * 60 + 1)
    postForegroundedNotification()
    // Then
    // Session count increases because time spent in background > 30 minutes
    XCTAssert(sessionCount == 2)

    // When
    // Background, advance time by exactly 30 minutes, then foreground
    postBackgroundedNotification()
    pausedClock.addTimeInterval(30 * 60)
    postForegroundedNotification()
    // Then
    // Session count doesn't increase because time spent in background <= 30 minutes
    XCTAssert(sessionCount == 2)
  }
}
