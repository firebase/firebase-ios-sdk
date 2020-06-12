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
  override func setUp() {
    super.setUp()
    if APITests.useFakeConfig {
      fakeConsole.config = ["Key1": "Value1"]
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
