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
import FirebaseRemoteConfig
import XCTest

class APITests: XCTestCase {
  var app: FirebaseApp!
  var config: RemoteConfig!

  override class func setUp() {
    FirebaseApp.configure()
  }

  override func setUp() {
    super.setUp()
    app = FirebaseApp.app()
    config = RemoteConfig.remoteConfig(app: app!)
    let settings = RemoteConfigSettings()
    settings.minimumFetchInterval = 0
    config.configSettings = settings

    FirebaseConfiguration.shared.setLoggerLevel(FirebaseLoggerLevel.debug)
  }

  override func tearDown() {
    app = nil
    config = nil
    super.tearDown()
  }

  func testFetchThenActivate() {
    let expectation = self.expectation(description: #function)
    config.fetch { status, error in
      if let error = error {
        XCTFail("Fetch Error \(error)")
      }
      XCTAssertEqual(status, RemoteConfigFetchStatus.success)
      self.config.activate { error in
        if let error = error {
          // This API returns an error if the config was unchanged.
          print("Activate Error \(error)")
        }
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
      self.config.activate { error in
        if let error = error {
          // This API returns an error if the config was unchanged.
          print("Activate Error \(error)")
        }
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
