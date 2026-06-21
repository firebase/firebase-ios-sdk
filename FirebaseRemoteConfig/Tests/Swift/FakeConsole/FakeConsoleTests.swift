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

class FakeConsoleTests: APITestBase {
  override func setUp() {
    super.setUp()
    fakeConsole.config = ["Key1": "Value1"]
  }

  // Test New API.
  // Contrast with testUnchangedActivateWillFlag in APITests.swift.
  func testChangedActivateWillNotFlag() {
    let expectation = self.expectation(description: #function)
    config.fetch { status, error in
      if let error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { changed, error in
        XCTAssertNil(error)
        XCTAssertTrue(changed)
        XCTAssertEqual(self.config["Key1"].stringValue, "Value1")
        expectation.fulfill()
      }
    }
    waitForExpectations()

    // Simulate updating console.
    fakeConsole.config = ["Key1": "Value2"]

    let expectation2 = self.expectation(description: #function + "2")
    config.fetch { status, error in
      if let error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { changed, error in
        XCTAssertNil(error)
        XCTAssert(changed)
        XCTAssertEqual(self.config["Key1"].stringValue, "Value2")
        expectation2.fulfill()
      }
    }
    waitForExpectations()
  }

  private func waitForExpectations() {
    let kFIRStorageIntegrationTestTimeout = 10.0
    waitForExpectations(timeout: kFIRStorageIntegrationTestTimeout,
                        handler: { error in
                          if let error {
                            print(error)
                          }
                        })
  }
}
