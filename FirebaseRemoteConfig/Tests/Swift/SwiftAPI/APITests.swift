// Copyright 2020 Google LLC
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

class APITests: APITestBase {
  func testFetchThenActivate() {
    let expectation = self.expectation(description: #function)
    config.fetch { status, error in
      if let error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { _, error in
        XCTAssertNil(error)
        XCTAssertEqual(self.config[Constants.key1].stringValue, Constants.value1)
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  func testFetchWithExpirationThenActivate() {
    let expectation = self.expectation(description: #function)
    config.fetch(withExpirationDuration: 0) { status, error in
      if let error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { _, error in
        XCTAssertNil(error)
        XCTAssertEqual(self.config[Constants.key1].stringValue, Constants.value1)
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  func testFetchAndActivate() {
    let expectation = self.expectation(description: #function)
    config.fetchAndActivate { status, error in
      XCTAssertEqual(status, .successFetchedFromRemote)
      if let error {
        XCTFail("Fetch and Activate Error \(error)")
      }
      XCTAssertEqual(self.config[Constants.key1].stringValue, Constants.value1)
      expectation.fulfill()
    }
    waitForExpectations()
  }

  // Test New API.
  // Contrast with testChangedActivateWillNotFlag in FakeConsole.swift.
  func testUnchangedActivateWillFlag() {
    let expectation = self.expectation(description: #function)
    config.fetch { status, error in
      if let error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { changed, error in
        XCTAssertTrue(!APITests.useFakeConfig || changed)
        XCTAssertNil(error)
        XCTAssertEqual(self.config[Constants.key1].stringValue, Constants.value1)
        expectation.fulfill()
      }
    }
    waitForExpectations()
    let expectation2 = self.expectation(description: #function + "2")
    config.fetch { status, error in
      if let error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { changed, error in
        XCTAssertFalse(changed)
        XCTAssertNil(error)
        XCTAssertEqual(self.config[Constants.key1].stringValue, Constants.value1)
        expectation2.fulfill()
      }
    }
    waitForExpectations()
  }

  func testFetchAndActivateUnchangedConfig() throws {
    guard APITests.useFakeConfig == false else { return }

    let expectation = self.expectation(description: #function)

    XCTAssertEqual(config.settings.minimumFetchInterval, 0)

    let serialQueue = DispatchQueue(label: "\(#function)Queue")
    let group = DispatchGroup()
    group.enter()
    serialQueue.async {
      // Represents pre-fetch occurring sometime in past.
      self.config.fetch { status, error in
        XCTAssertNil(error, "Fetch Error \(error!)")
        XCTAssertEqual(status, .success)
        group.leave()
      }
    }

    serialQueue.async {
      group.wait()
      group.enter()
      // Represents a `fetchAndActivate` being made to pull latest changes from Remote Config.
      self.config.fetchAndActivate { status, error in
        XCTAssertNil(error, "Fetch & Activate Error \(error!)")
        // Since no updates to remote config have occurred we use the `.successUsingPreFetchedData`.
        // The behavior of the next test changed in Firebase 7.0.0.
        // It's an open question which is correct, but it should only
        // be changed in a major release.
        // See https://github.com/firebase/firebase-ios-sdk/pull/8788
        // XCTAssertEqual(status, .successUsingPreFetchedData)
        XCTAssertEqual(status, .successFetchedFromRemote)
        // The `lastETagUpdateTime` should either be older or the same time as `lastFetchTime`.
        if let lastFetchTime = try? XCTUnwrap(self.config.lastFetchTime) {
          XCTAssertLessThanOrEqual(Double(self.config.settings.lastETagUpdateTime),
                                   Double(lastFetchTime.timeIntervalSince1970))
        } else {
          XCTFail("Could not unwrap lastFetchTime.")
        }

        expectation.fulfill()
      }
    }

    waitForExpectations()
  }

  // MARK: - RemoteConfigRealtime Tests

  func testRealtimeRemoteConfigFakeConsole() {
    guard APITests.useFakeConfig == true else { return }

    let expectation = self.expectation(description: #function)

    let registration = config.addOnConfigUpdateListener { RemoteConfigUpdate, Error in
      XCTAssertNil(Error, "Realtime error \(Error!)")
      XCTAssertNotNil(RemoteConfigUpdate)

      expectation.fulfill()
    }

    waitForExpectations()
    registration.remove()
  }

  func testRealtimeRemoteConfigRealConsole() {
    guard APITests.useFakeConfig == false else { return }

    let expectation = self.expectation(description: #function)

    let registration = config.addOnConfigUpdateListener { RemoteConfigUpdate, Error in
      XCTAssertNil(Error, "Realtime error \(Error!)")
      XCTAssertNotNil(RemoteConfigUpdate)
      XCTAssertNotNil(RemoteConfigUpdate?.updatedKeys.contains(Constants.jedi))
      expectation.fulfill()
    }

    console.updateRemoteConfigValue(Constants.yoda, forKey: Constants.jedi)

    waitForExpectations()
    registration.remove()
  }

  // MARK: - RemoteConfigConsole Tests

  func testFetchConfigThenUpdateConsoleThenFetchAgain() {
    guard APITests.useFakeConfig == false else { return }

    let expectation = self.expectation(description: #function)

    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")
      XCTAssertEqual(self.config.configValue(forKey: Constants.jedi).stringValue, Constants.obiwan)
      expectation.fulfill()
    }
    waitForExpectations()

    // Synchronously update the console.
    console.updateRemoteConfigValue(Constants.yoda, forKey: Constants.jedi)

    let expectation2 = self.expectation(description: #function + "2")
    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")
      XCTAssertEqual(self.config.configValue(forKey: Constants.jedi).stringValue, Constants.yoda)
      expectation2.fulfill()
    }
    waitForExpectations()
  }

  func testFetchConfigThenAddValueOnConsoleThenFetchAgain() {
    guard APITests.useFakeConfig == false else { return }

    // Ensure no Sith Lord has been written to Remote Config yet.
    let expectation = self.expectation(description: #function)

    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")

      XCTAssertTrue(self.config.configValue(forKey: Constants.sith).dataValue.isEmpty)

      expectation.fulfill()
    }
    waitForExpectations()

    // Synchronously update the console
    console.updateRemoteConfigValue(Constants.darthSidious, forKey: Constants.sith)

    // Verify the Sith Lord can now be fetched from Remote Config.
    let expectation2 = self.expectation(description: #function + "2")

    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")
      XCTAssertEqual(
        self.config.configValue(forKey: Constants.sith).stringValue,
        Constants.darthSidious
      )
      expectation2.fulfill()
    }
    waitForExpectations()
  }

  func testFetchConfigThenDeleteValueOnConsoleThenFetchAgain() {
    guard APITests.useFakeConfig == false else { return }

    let expectation = self.expectation(description: #function)

    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")
      XCTAssertEqual(self.config.configValue(forKey: Constants.jedi).stringValue, Constants.obiwan)
      expectation.fulfill()
    }
    waitForExpectations()

    // Synchronously delete value on the console.
    console.removeRemoteConfigValue(forKey: Constants.jedi)

    let expectation2 = self.expectation(description: #function + "2")
    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")

      XCTAssertTrue(self.config.configValue(forKey: Constants.jedi).dataValue.isEmpty,
                    "Remote config should have been deleted.")

      expectation2.fulfill()
    }
    waitForExpectations()
  }

  // MARK: - Private Helpers

  private func waitForExpectations() {
    let kTestTimeout = 10.0
    waitForExpectations(timeout: kTestTimeout,
                        handler: { error in
                          if let error {
                            print(error)
                          }
                        })
  }
}
