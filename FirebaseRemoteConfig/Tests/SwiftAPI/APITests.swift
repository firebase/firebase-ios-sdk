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
  var console: RemoteConfigConsole!

  override func setUp() {
    super.setUp()
    if APITests.useFakeConfig {
      fakeConsole.config = ["Key1": "Value1"]
    } else {
      console = RemoteConfigConsole()
      console.updateRemoteConfigValue("Obi-Wan", for: "Jedi")
    }
  }

  override func tearDown() {
    super.tearDown()

    // If using RemoteConfigConsole, reset remote config values.
    if !APITests.useFakeConfig {
      console.removeRemoteConfigValue(for: "Sith_Lord")
      console.removeRemoteConfigValue(for: "Jedi")
    }
  }

  func testFetchThenActivate() {
    let expectation = self.expectation(description: #function)
    config.fetch { status, error in
      if let error = error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { _, error in
        XCTAssertNil(error)
        XCTAssertEqual(self.config["Key1"].stringValue, "Value1")
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  func testFetchWithExpirationThenActivate() {
    let expectation = self.expectation(description: #function)
    config.fetch(withExpirationDuration: 0) { status, error in
      if let error = error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { _, error in
        XCTAssertNil(error)
        XCTAssertEqual(self.config["Key1"].stringValue, "Value1")
        expectation.fulfill()
      }
    }
    waitForExpectations()
  }

  func testFetchAndActivate() {
    let expectation = self.expectation(description: #function)
    config.fetchAndActivate { status, error in
      if let error = error {
        XCTFail("Fetch and Activate Error \(error)")
      }
      XCTAssertEqual(self.config["Key1"].stringValue, "Value1")
      expectation.fulfill()
    }
    waitForExpectations()
  }

  // Test old API.
  // Contrast with testChangedActivateWillNotError in FakeConsole.swift.
  func testUnchangedActivateWillError() {
    let expectation = self.expectation(description: #function)
    config.fetch { status, error in
      if let error = error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { error in
        if let error = error {
          print("Activate Error \(error)")
        }
        XCTAssertEqual(self.config["Key1"].stringValue, "Value1")
        expectation.fulfill()
      }
    }
    waitForExpectations()
    let expectation2 = self.expectation(description: #function + "2")
    config.fetch { status, error in
      if let error = error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { error in
        XCTAssertNotNil(error)
        if let error = error {
          XCTAssertEqual((error as NSError).code, RemoteConfigError.internalError.rawValue)
        }
        XCTAssertEqual(self.config["Key1"].stringValue, "Value1")
        expectation2.fulfill()
      }
    }
    waitForExpectations()
  }

  // Test New API.
  // Contrast with testChangedActivateWillNotFlag in FakeConsole.swift.
  func testUnchangedActivateWillFlag() {
    let expectation = self.expectation(description: #function)
    config.fetch { status, error in
      if let error = error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { changed, error in
        XCTAssertTrue(!APITests.useFakeConfig || changed)
        XCTAssertNil(error)
        XCTAssertEqual(self.config["Key1"].stringValue, "Value1")
        expectation.fulfill()
      }
    }
    waitForExpectations()
    let expectation2 = self.expectation(description: #function + "2")
    config.fetch { status, error in
      if let error = error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { changed, error in
        XCTAssertFalse(changed)
        XCTAssertNil(error)
        XCTAssertEqual(self.config["Key1"].stringValue, "Value1")
        expectation2.fulfill()
      }
    }
    waitForExpectations()
  }

  func testFetchAndActivateUnchangedConfig() {
    if APITests.useFakeConfig {
      return
    }

    let expectation = self.expectation(description: #function)

    XCTAssertEqual(config.settings.minimumFetchInterval, 0)

    let serialQueue = DispatchQueue(label: "\(#function)Queue")
    let group = DispatchGroup()
    group.enter()
    serialQueue.async {
      // Represents pre-fetch occuring sometime in past.
      self.config.fetch { status, error in
        XCTAssertNil(error, "Fetch Error \(error!)")
        XCTAssertEqual(status, .success)
        group.leave()
      }
    }

    serialQueue.async {
      group.wait()
      group.enter()
      // Represents a `fetchAndActivate` being made to pull
      // latest changes from remote config.
      self.config.fetchAndActivate { status, error in
        XCTAssertNil(error, "Fetch & Activate Error \(error!)")
        // Since no updates to remote config have occurred
        // we use the `.successUsingPreFetchedData`.
        XCTAssertEqual(status, .successUsingPreFetchedData)
        // The `lastETagUpdateTime` should either be older or
        // the same time as `lastFetchTime`.
        XCTAssertLessThanOrEqual(Double(self.config.settings.lastETagUpdateTime),
                                 Double(self.config.lastFetchTime?.timeIntervalSince1970 ?? 0))
        expectation.fulfill()
      }
    }

    waitForExpectations()
  }

  // MARK: - RemoteConfigConsole Tests

  func testFetchConfigThenUpdateConsoleThenFetchAgain() {
    if APITests.useFakeConfig {
      return
    }

    let expectation = self.expectation(description: #function)

    let jedi = "Jedi"
    let yoda = "Yoda"

    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")

      if let configValue = self.config.configValue(forKey: jedi).stringValue {
        XCTAssertEqual(configValue, "Obi-Wan")
      } else {
        XCTFail("Could not unwrap config value for key: \(jedi)")
      }
      expectation.fulfill()
    }
    waitForExpectations()

    // Synchronously update the console.
    console.updateRemoteConfigValue(yoda, for: jedi)

    let expectation2 = self.expectation(description: #function + "2")
    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")

      if let configValue = self.config.configValue(forKey: jedi).stringValue {
        XCTAssertEqual(configValue, yoda)
      } else {
        XCTFail("Could not unwrap config value for key: \(jedi)")
      }

      expectation2.fulfill()
    }
    waitForExpectations()
  }

  func testFetchConfigThenAddValueOnConsoleThenFetchAgain() {
    if APITests.useFakeConfig {
      return
    }

    let expectation = self.expectation(description: #function)

    let sithLord = "Sith_Lord"
    let palpatine = "Darth Sideous"

    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")

      XCTAssertTrue(self.config.configValue(forKey: sithLord).dataValue.isEmpty)

      expectation.fulfill()
    }
    waitForExpectations()

    // Synchronously update the console
    console.updateRemoteConfigValue(palpatine, for: sithLord)

    let expectation2 = self.expectation(description: #function + "2")
    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")

      if let configValue = self.config.configValue(forKey: sithLord).stringValue {
        XCTAssertEqual(configValue, palpatine)
      } else {
        XCTFail("Could not unwrap config value for key: \(sithLord)")
      }

      expectation2.fulfill()
    }
    waitForExpectations()
  }

  func testFetchConfigThenDeleteValueOnConsoleThenFetchAgain() {
    if APITests.useFakeConfig {
      return
    }

    let expectation = self.expectation(description: #function)

    let jedi = "Jedi"

    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")

      if let configValue = self.config.configValue(forKey: jedi).stringValue {
        XCTAssertEqual(configValue, "Obi-Wan")
      } else {
        XCTFail("Could not unwrap config value for key: \(jedi)")
      }
      expectation.fulfill()
    }
    waitForExpectations()

    // Synchronously delete value on the console.
    console.removeRemoteConfigValue(for: jedi)

    let expectation2 = self.expectation(description: #function + "2")
    config.fetchAndActivate { status, error in
      XCTAssertNil(error, "Fetch & Activate Error \(error!)")

      XCTAssertTrue(self.config.configValue(forKey: jedi).dataValue.isEmpty,
                    "Remote config should have been deleted.")

      expectation2.fulfill()
    }
    waitForExpectations()
  }

  // MARK: - Private Helpers

  private func waitForExpectations() {
    let kFIRStorageIntegrationTestTimeout = 10.0
    waitForExpectations(timeout: kFIRStorageIntegrationTestTimeout,
                        handler: { (error) -> Void in
                          if let error = error {
                            print(error)
                          }
    })
  }
}
