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

class FakeConsoleTests: XCTestCase {
  static var useFakeConfig: Bool!
  var app: FirebaseApp!
  var config: RemoteConfig!
  var fakeConsole: FakeConsole!

  override class func setUp() {
    if !(FirebaseApp.app() != nil) {
      FirebaseApp.configure()
    }
    useFakeConfig = FirebaseApp.app()!.options.projectID == "FakeProject"
  }

  override func setUp() {
    super.setUp()
    app = FirebaseApp.app()
    config = RemoteConfig.remoteConfig(app: app!)
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 0
    config.configSettings = settings
    fakeConsole = FakeConsole(with: ["Key1": "Value1"])
    config.configFetch.fetchSession = URLSessionMock(with: fakeConsole)
    config.configFetch.testWithoutNetwork = true

    // Uncomment for verbose debug logging.
    // FirebaseConfiguration.shared.setLoggerLevel(FirebaseLoggerLevel.debug)
  }

  override func tearDown() {
    app = nil
    config = nil
    fakeConsole.empty()
    super.tearDown()
  }

  // Contrast with testUnchangedActivateWillError in APITests.swift.
  func testChangedActivateWillNotError() {
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

    // Simulate updating console.
    fakeConsole.config = ["Key1": "Value2"]

    let expectation2 = self.expectation(description: #function + "2")
    config.fetch { status, error in
      if let error = error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { error in
        XCTAssertNil(error)
        XCTAssertEqual(self.config["Key1"].stringValue, "Value2")
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
