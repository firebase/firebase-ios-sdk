// Copyright 2021 Google LLC
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

import FirebaseCore
@testable import FirebaseRemoteConfig

import XCTest

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
class AsyncAwaitTests: APITestBase {
  func testFetchThenActivate() async throws {
    let status = try await config.fetch()
    XCTAssertEqual(status, RemoteConfigFetchStatus.success)
    let success = try await config.activate()
    XCTAssertTrue(success)
  }

  func testFetchWithExpirationThenActivate() async throws {
    let status = try await config.fetch(withExpirationDuration: 0)
    XCTAssertEqual(status, RemoteConfigFetchStatus.success)
    _ = try await config.activate()
    XCTAssertEqual(config[Constants.key1].stringValue, Constants.value1)
  }

  func testFetchAndActivate() async throws {
    let status = try await config.fetchAndActivate()
    XCTAssertEqual(status, .successFetchedFromRemote)
    XCTAssertEqual(config[Constants.key1].stringValue, Constants.value1)
  }

  func testFetchAndActivateGenericValue() async throws {
    let status = try await config.fetchAndActivate()
    XCTAssertEqual(status, .successFetchedFromRemote)
    XCTAssertEqual(config[Constants.key1].stringValue, Constants.value1)
  }

  // Contrast with testChangedActivateWillNotFlag in FakeConsole.swift.
  func testUnchangedActivateWillFlag() async throws {
    let status = try await config.fetch()
    XCTAssertEqual(status, RemoteConfigFetchStatus.success)
    let changed = try await config.activate()
    XCTAssertEqual(config[Constants.key1].stringValue, Constants.value1)
    XCTAssertTrue(!APITests.useFakeConfig || changed)
    XCTAssertEqual(config[Constants.key1].stringValue, Constants.value1)
  }

  func testFetchAndActivateUnchangedConfig() async throws {
    guard APITests.useFakeConfig == false else { return }

    XCTAssertEqual(config.settings.minimumFetchInterval, 0)

    // Represents pre-fetch occurring sometime in past.
    let status = try await config.fetch()
    XCTAssertEqual(status, .success)

    // Represents a `fetchAndActivate` being made to pull latest changes from Remote Config.
    let status2 = try await config.fetchAndActivate()
    // Since no updates to remote config have occurred we use the `.successUsingPreFetchedData`.
    // The behavior of the next test changed in Firebase 7.0.0.
    // It's an open question which is correct, but it should only
    // be changed in a major release.
    // See https://github.com/firebase/firebase-ios-sdk/pull/8788
    // XCTAssertEqual(status, .successUsingPreFetchedData)
    XCTAssertEqual(status2, .successFetchedFromRemote)
    // The `lastETagUpdateTime` should either be older or the same time as `lastFetchTime`.
    if let lastFetchTime = try? XCTUnwrap(config.lastFetchTime) {
      XCTAssertLessThanOrEqual(Double(config.settings.lastETagUpdateTime),
                               Double(lastFetchTime.timeIntervalSince1970))
    } else {
      XCTFail("Could not unwrap lastFetchTime.")
    }
  }

  // MARK: - RemoteConfigConsole Tests

  func testFetchConfigThenUpdateConsoleThenFetchAgain() async throws {
    guard APITests.useFakeConfig == false else { return }

    _ = try await config.fetchAndActivate()
    let configValue = try? XCTUnwrap(config.configValue(forKey: Constants.jedi).stringValue)
    XCTAssertEqual(configValue, Constants.obiwan)

    // Synchronously update the console.
    console.updateRemoteConfigValue(Constants.yoda, forKey: Constants.jedi)

    _ = try await config.fetchAndActivate()
    let configValue2 = try? XCTUnwrap(config.configValue(forKey: Constants.jedi).stringValue)
    XCTAssertEqual(configValue2, Constants.yoda)
  }

  func testFetchConfigThenAddValueOnConsoleThenFetchAgain() async throws {
    guard APITests.useFakeConfig == false else { return }

    // Ensure no Sith Lord has been written to Remote Config yet.
    _ = try await config.fetchAndActivate()
    XCTAssertTrue(config.configValue(forKey: Constants.sith).dataValue.isEmpty)

    // Synchronously update the console
    console.updateRemoteConfigValue(Constants.darthSidious, forKey: Constants.sith)

    // Verify the Sith Lord can now be fetched from Remote Config
    _ = try await config.fetchAndActivate()
    let configValue = try? XCTUnwrap(config.configValue(forKey: Constants.sith).stringValue)
    XCTAssertEqual(configValue, Constants.darthSidious)
  }

  func testFetchConfigThenDeleteValueOnConsoleThenFetchAgain() async throws {
    guard APITests.useFakeConfig == false else { return }

    _ = try await config.fetchAndActivate()
    let configValue = try? XCTUnwrap(config.configValue(forKey: Constants.jedi).stringValue)
    XCTAssertEqual(configValue, Constants.obiwan)

    // Synchronously delete value on the console.
    console.removeRemoteConfigValue(forKey: Constants.jedi)

    _ = try await config.fetchAndActivate()
    XCTAssertTrue(config.configValue(forKey: Constants.jedi).dataValue.isEmpty,
                  "Remote config should have been deleted.")
  }

  func testSetCustomSignals() async throws {
    let testSignals: [String: CustomSignalValue?] = [
      "signal_1": .integer(5),
      "signal_2": .string("basic"),
      "signal_3": .double(3.14159),
    ]

    let expectedSignals: [String: String] = [
      "signal_1": "5",
      "signal_2": "basic",
      "signal_3": "3.14159",
    ]

    _ = try await config.setCustomSignals(testSignals)
    XCTAssertEqual(config.settings.customSignals, expectedSignals)
  }

  func testSetCustomSignalsMultipleTimes() async throws {
    let testSignals: [String: CustomSignalValue?] = [
      "signal_1": 6,
      "signal_2": "basic",
      "signal_3": 3.14,
    ]

    let expectedSignals: [String: String] = [
      "signal_1": "6",
      "signal_2": "basic",
      "signal_3": "3.14",
    ]

    _ = try await config.setCustomSignals(testSignals)
    XCTAssertEqual(config.settings.customSignals, expectedSignals)

    let testSignals2: [String: CustomSignalValue?] = [
      "signal_4": .integer(100),
      "signal_3": nil,
      "signal_5": .double(3.1234),
    ]

    let expectedSignals2: [String: String] = [
      "signal_1": "6",
      "signal_2": "basic",
      "signal_4": "100",
      "signal_5": "3.1234",
    ]

    _ = try await config.setCustomSignals(testSignals2)
    XCTAssertEqual(config.settings.customSignals, expectedSignals2)
  }
}
