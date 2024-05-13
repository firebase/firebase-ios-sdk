//
//  File.swift
//  
//
//  Created by Aashish Patil on 5/9/24.
//

import Foundation
@testable import FirebaseDataConnect
import XCTest


class InstanceTests: XCTestCase {

  var defaultApp: FirebaseApp?
  var appTwo: FirebaseApp?

  var fakeConnectorConfigOne = ConnectorConfig(serviceId: "dataconnect", location: "us-central1", connector: "kitchensink")
  var fakeConnectorConfigTwo = ConnectorConfig(serviceId: "dataconnect", location: "us-central1", connector: "blogs")


  override func setup() {
    defaultApp = FirebaseApp.app()

    //let serviceInfoFile = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
    //var options = FirebaseOptions(contentsOfFile: service)
    //defaultApp?.options = options

    appTwo = FirebaseApp.app(name: "app-two")
    var optionsTwo = FirebaseOptions(googleAppID: "gcm-app-two", gcmSenderID: "00010111")

  }

  func testSameInstance() {
    let dcOne = DataConnect.dataConnect(connectorConfig: fakeConnectorConfigOne)

    let dcTwo = DataConnect.dataConnect(connectorConfig: fakeConnectorConfigOne)

    XCTAssertEqual(dcOne, dcTwo)
  }

}
