// Copyright 2024 Google LLC
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
@testable import FirebaseDataConnect
import Foundation
import XCTest

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
class InstanceTests: XCTestCase {
  var defaultApp: FirebaseApp?
  var appTwo: FirebaseApp?

  var fakeConnectorConfigOne = ConnectorConfig(
    serviceId: "dataconnect",
    location: "us-central1",
    connector: "kitchensink"
  )
  var fakeConnectorConfigTwo = ConnectorConfig(
    serviceId: "dataconnect",
    location: "us-central1",
    connector: "blogs"
  )

  override func setUp() {
    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "fdc-test"
    FirebaseApp.configure(options: options)
    defaultApp = FirebaseApp.app()

    let optionsTwo = FirebaseOptions(
      googleAppID: "0:0000000000001:ios:0000000000000001",
      gcmSenderID: "00000000000000000-00000000000-000000001"
    )
    optionsTwo.projectID = "fdc-test"
    FirebaseApp.configure(name: "app-two", options: optionsTwo)
    appTwo = FirebaseApp.app(name: "app-two")
  }

  // same connector config, same app, instance returned should be same
  func testSameInstance() throws {
    let dcOne = DataConnect.dataConnect(connectorConfig: fakeConnectorConfigOne)

    let dcTwo = DataConnect.dataConnect(connectorConfig: fakeConnectorConfigOne)

    let isSameInstance = dcOne === dcTwo
    XCTAssertTrue(isSameInstance)
  }

  // same connector config, different apps, instances should be different
  func testDifferentInstanceDifferentApps() throws {
    let dcOne = DataConnect.dataConnect(connectorConfig: fakeConnectorConfigOne)
    let dcTwo = DataConnect.dataConnect(app: appTwo, connectorConfig: fakeConnectorConfigTwo)

    let isDifferent = dcOne !== dcTwo
    XCTAssertTrue(isDifferent)
  }
}
