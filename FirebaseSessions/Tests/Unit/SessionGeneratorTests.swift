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

class SessionGeneratorTests: XCTestCase {
  var generator: SessionGenerator!

  let validSettings: [String: Any] = [:]

  var cache: SettingsCacheClient!
  var appInfo: MockApplicationInfo!
  var downloader: MockSettingsDownloader!
  var remoteSettings: RemoteSettings!
  var localOverrideSettings: LocalOverrideSettings!
  var sdkDefaultSettings: SDKDefaultSettings!
  var sessionSettings: SessionsSettings!

  override func setUp() {
    // Clear all UserDefaults
    if let appDomain = Bundle.main.bundleIdentifier {
      UserDefaults.standard.removePersistentDomain(forName: appDomain)
    }

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
    generator = SessionGenerator(settings: sessionSettings)
  }

  func isValidSessionID(_ sessionID: String) -> Bool {
    if sessionID.count != 32 {
      assertionFailure("Session ID isn't 32 characters long")
      return false
    }
    if sessionID.contains("-") {
      assertionFailure("Session ID contains a dash")
      return false
    }
    if sessionID.lowercased().compare(sessionID) != ComparisonResult.orderedSame {
      assertionFailure("Session ID is not lowercase")
      return false
    }
    return true
  }

  // This test case isn't important behavior. When Crash and Perf integrate
  // with the Sessions SDK, we may want to move to a lazy solution where
  // sessionID can never be empty
  func test_sessionID_beforeGenerateReturnsNothing() throws {
    XCTAssertNil(generator.currentSession)
  }

  func test_generateNewSessionID_generatesValidID() throws {
    let sessionInfo = generator.generateNewSession()
    XCTAssert(isValidSessionID(sessionInfo.sessionId))
    XCTAssertNil(sessionInfo.previousSessionId)
  }

  /// Ensures that generating a Session ID multiple times results in the last Session ID being set in the previousSessionID field
  func test_generateNewSessionID_rotatesPreviousID() throws {
    let firstSessionInfo = generator.generateNewSession()

    let firstSessionID = firstSessionInfo.sessionId
    XCTAssert(isValidSessionID(firstSessionInfo.sessionId))
    XCTAssertNil(firstSessionInfo.previousSessionId)

    let secondSessionInfo = generator.generateNewSession()

    XCTAssert(isValidSessionID(secondSessionInfo.sessionId))
    XCTAssert(isValidSessionID(secondSessionInfo.previousSessionId!))

    // Ensure the new lastSessionID is equal to the sessionID from earlier
    XCTAssertEqual(secondSessionInfo.previousSessionId, firstSessionID)
  }

  func test_sessionsNotSampled_AllEventsAllowed() throws {
    let someSettings: [String: Any] = [
      "cache_duration": 10,
      "app_quality": [
        "sampling_rate": 1.0,
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

    let sessionInfo = generator.generateNewSession()
    XCTAssertTrue(sessionInfo.shouldDispatchEvents)
  }

  func test_sessionsSampled_NoEventsAllowed() throws {
    let someSettings: [String: Any] = [
      "cache_duration": 10,
      "app_quality": [
        "sampling_rate": 0.0,
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

    let sessionInfo = generator.generateNewSession()
    XCTAssertFalse(sessionInfo.shouldDispatchEvents)
  }
}
