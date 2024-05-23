//
//  InstanceTests.swift
//
//
//  Created by Aashish Patil on 5/9/24.
//

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
