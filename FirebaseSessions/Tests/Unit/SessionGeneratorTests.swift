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
    generator = SessionGenerator(collectEvents: Sessions
      .shouldCollectEvents(settings: sessionSettings))
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
    XCTAssert(isValidSessionID(sessionInfo.firstSessionId))
    XCTAssertEqual(sessionInfo.firstSessionId, sessionInfo.sessionId)
  }

  /// Ensures that generating a Session ID multiple times results in the fist Session ID being set
  /// in the firstSessionId field
  func test_generateNewSessionID_rotatesPreviousID() throws {
    let firstSessionInfo = generator.generateNewSession()

    XCTAssert(isValidSessionID(firstSessionInfo.sessionId))
    XCTAssert(isValidSessionID(firstSessionInfo.firstSessionId))
    XCTAssertEqual(firstSessionInfo.firstSessionId, firstSessionInfo.sessionId)
    XCTAssertEqual(firstSessionInfo.sessionIndex, 0)

    let secondSessionInfo = generator.generateNewSession()

    XCTAssert(isValidSessionID(secondSessionInfo.sessionId))
    XCTAssert(isValidSessionID(secondSessionInfo.firstSessionId))
    // Ensure the new firstSessionId is equal to the first Session ID from earlier
    XCTAssertEqual(secondSessionInfo.firstSessionId, firstSessionInfo.sessionId)
    // Session Index should increase
    XCTAssertEqual(secondSessionInfo.sessionIndex, 1)

    // Do a third round just in case
    let thirdSessionInfo = generator.generateNewSession()

    XCTAssert(isValidSessionID(thirdSessionInfo.sessionId))
    XCTAssert(isValidSessionID(thirdSessionInfo.firstSessionId))
    // Ensure the new firstSessionId is equal to the first Session ID from earlier
    XCTAssertEqual(thirdSessionInfo.firstSessionId, firstSessionInfo.sessionId)
    // Session Index should increase
    XCTAssertEqual(thirdSessionInfo.sessionIndex, 2)
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

    // Rebuild the SessionGenerator with the new settings
    generator = SessionGenerator(collectEvents: Sessions
      .shouldCollectEvents(settings: sessionSettings))

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

    // Rebuild the SessionGenerator with the new settings
    generator = SessionGenerator(collectEvents: Sessions
      .shouldCollectEvents(settings: sessionSettings))

    let sessionInfo = generator.generateNewSession()
    XCTAssertFalse(sessionInfo.shouldDispatchEvents)
  }

  func test_sessionsSampling_persistsPerRun() throws {
    let mockSettings = MockSettingsProtocol()
    mockSettings.samplingRate = 0

    // Rebuild the SessionGenerator with the new settings
    generator = SessionGenerator(collectEvents: Sessions
      .shouldCollectEvents(settings: mockSettings))

    let sessionInfo = generator.generateNewSession()
    XCTAssertFalse(sessionInfo.shouldDispatchEvents)

    // Try again
    let sessionInfo2 = generator.generateNewSession()
    XCTAssertFalse(sessionInfo2.shouldDispatchEvents)

    // Start returning true from the calculator
    mockSettings.samplingRate = 1

    // Try again after the calculator starts returning true.
    // It should still be false in the sessionInfo because the
    // sampling rate is calculated per-run
    let sessionInfo3 = generator.generateNewSession()
    XCTAssertFalse(sessionInfo3.shouldDispatchEvents)
  }
}
