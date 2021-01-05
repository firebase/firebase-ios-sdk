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

import XCTest
@testable import FirebaseCore

private extension Constants {
  static let testAppName1 = "test_app_name_1"
  static let testAppName2 = "test_app_name_2"
}

class FirebaseAppTests: XCTestCase {
  override func setUp() {
    super.setUp()
    FIROptionsMock.mockFIROptions()
  }

  override func tearDown() {
    super.tearDown()
    FirebaseApp.resetApps()
  }

  func testSwiftFlagWithSwift() {
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("swift"))
  }

  func testConfigure() throws {
    expectAppConfigurationNotification(appName: Constants.App.defaultName, isDefaultApp: true)

    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure()
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    let app = try XCTUnwrap(FirebaseApp.app(), "Failed to unwrap default app")
    XCTAssertEqual(app.name, Constants.App.defaultName)
    XCTAssertEqual(app.options.clientID, Constants.Options.clientID)
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)

    // TODO: check registered libraries instances available

    waitForExpectations(timeout: 1)
  }

  func testIsDefaultAppConfigured() {
    XCTAssertFalse(FirebaseApp.isDefaultAppConfigured())

    expectAppConfigurationNotification(appName: Constants.App.defaultName, isDefaultApp: true)

    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure()
      }
    }
    XCTAssertNoThrow(try configurationAttempt())
    XCTAssertTrue(FirebaseApp.isDefaultAppConfigured())

    waitForExpectations(timeout: 1)
  }

  func testConfigureDefaultAppTwice() {
    let firstConfigurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure()
      }
    }
    XCTAssertNoThrow(try firstConfigurationAttempt())

    let secondConfigurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure()
      }
    }
    XCTAssertThrowsError(try secondConfigurationAttempt())
  }

  func testConfigureWithOptions() throws {
    expectAppConfigurationNotification(appName: Constants.App.defaultName, isDefaultApp: true)

    let options = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                  gcmSenderID: Constants.Options.gcmSenderID)
    options.clientID = Constants.Options.clientID
    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(options: options)
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    let app = try XCTUnwrap(FirebaseApp.app(), "Failed to unwrap default app")
    XCTAssertEqual(app.name, Constants.App.defaultName)
    XCTAssertEqual(app.options.googleAppID, Constants.Options.googleAppID)
    XCTAssertEqual(app.options.gcmSenderID, Constants.Options.gcmSenderID)
    XCTAssertEqual(app.options.clientID, Constants.Options.clientID)
    XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    waitForExpectations(timeout: 1)
  }

  func testConfigureWithNameAndOptions() throws {
    expectAppConfigurationNotification(appName: Constants.testAppName1, isDefaultApp: false)

    let options = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                  gcmSenderID: Constants.Options.gcmSenderID)
    options.clientID = Constants.Options.clientID

    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: Constants.testAppName1, options: options)
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    let app = try XCTUnwrap(
      FirebaseApp.app(name: Constants.testAppName1),
      "Failed to unwrap custom named app"
    )
    XCTAssertEqual(app.name, Constants.testAppName1)
    XCTAssertEqual(app.options.googleAppID, Constants.Options.googleAppID)
    XCTAssertEqual(app.options.gcmSenderID, Constants.Options.gcmSenderID)
    XCTAssertEqual(app.options.clientID, Constants.Options.clientID)
    XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    let configureAppAgain = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: Constants.testAppName1, options: options)
      }
    }

    XCTAssertThrowsError(try configureAppAgain())

    waitForExpectations(timeout: 1)
  }

  func testConfigureMultipleApps() throws {
    let options1 = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                   gcmSenderID: Constants.Options.gcmSenderID)
    options1.deepLinkURLScheme = Constants.Options.deepLinkURLScheme

    expectAppConfigurationNotification(appName: Constants.testAppName1, isDefaultApp: false)

    XCTAssertNoThrow(FirebaseApp.configure(name: Constants.testAppName1, options: options1))

    let app1 = try XCTUnwrap(FirebaseApp.app(name: Constants.testAppName1), "Failed to unwrap app1")
    XCTAssertEqual(app1.name, Constants.testAppName1)
    XCTAssertEqual(app1.options.googleAppID, Constants.Options.googleAppID)
    XCTAssertEqual(app1.options.gcmSenderID, Constants.Options.gcmSenderID)
    XCTAssertEqual(app1.options.deepLinkURLScheme, Constants.Options.deepLinkURLScheme)
    XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    // Configure a different app with valid customized options.
    let options2 = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                   gcmSenderID: Constants.Options.gcmSenderID)
    options2.bundleID = Constants.Options.bundleID
    options2.apiKey = Constants.Options.apiKey

    expectAppConfigurationNotification(appName: Constants.testAppName2, isDefaultApp: false)

    let configureApp2Attempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: Constants.testAppName2, options: options2)
      }
    }
    XCTAssertNoThrow(try configureApp2Attempt())

    let app2 = try XCTUnwrap(FirebaseApp.app(name: Constants.testAppName2), "Failed to unwrap app2")
    XCTAssertEqual(app2.name, Constants.testAppName2)
    XCTAssertEqual(app2.options.googleAppID, Constants.Options.googleAppID)
    XCTAssertEqual(app2.options.gcmSenderID, Constants.Options.gcmSenderID)
    XCTAssertEqual(app2.options.bundleID, Constants.Options.bundleID)
    XCTAssertEqual(app2.options.apiKey, Constants.Options.apiKey)
    XCTAssertTrue(FirebaseApp.allApps?.count == 2)

    waitForExpectations(timeout: 1)
  }

  func testGetUnitializedDefaultApp() {
    let app = FirebaseApp.app()
    XCTAssertNil(app)
  }

  func testGetInitializedDefaultApp() {
    FirebaseApp.configure()
    let app = FirebaseApp.app()
    XCTAssertNotNil(app)
  }

  func testGetExistingAppWithName() throws {
    // Configure a different app with valid customized options.
    let options = try XCTUnwrap(FirebaseOptions.defaultOptions(), "Could not load default options")
    FirebaseApp.configure(name: Constants.testAppName1, options: options)
    let app = FirebaseApp.app(name: Constants.testAppName1)
    XCTAssertNotNil(app, "Failed to get app")
  }

  func testAttemptToGetNonExistingAppWithName() {
    let unknownAppName = "The Missing App"
    let app = FirebaseApp.app(name: unknownAppName)
    XCTAssertNil(app)
  }

  func testAllApps() throws {
    XCTAssertNil(FirebaseApp.allApps)

    let options1 = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                   gcmSenderID: Constants.Options.gcmSenderID)
    FirebaseApp.configure(name: Constants.testAppName1, options: options1)
    let app1 = try XCTUnwrap(
      FirebaseApp.app(name: Constants.testAppName1),
      "App1 could not be unwrapped"
    )

    let options2 = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                   gcmSenderID: Constants.Options.gcmSenderID)
    FirebaseApp.configure(name: Constants.testAppName2, options: options2)
    let app2 = try XCTUnwrap(
      FirebaseApp.app(name: Constants.testAppName2),
      "App2 could not be unwrapped"
    )

    let apps = try XCTUnwrap(FirebaseApp.allApps, "Could not retrieve apps")

    XCTAssertEqual(apps.count, 2)
    XCTAssertTrue(apps.keys.contains(Constants.testAppName1))
    XCTAssertEqual(apps[Constants.testAppName1], app1)
    XCTAssertTrue(apps.keys.contains(Constants.testAppName2))
    XCTAssertEqual(apps[Constants.testAppName2], app2)
  }

  func testDeleteApp() throws {
    XCTAssertNil(FirebaseApp.app(name: Constants.testAppName1))
    XCTAssertNil(FirebaseApp.allApps)

    expectAppConfigurationNotification(appName: Constants.testAppName1, isDefaultApp: false)

    let options = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                  gcmSenderID: Constants.Options.gcmSenderID)
    FirebaseApp.configure(name: Constants.testAppName1, options: options)

    let app = try XCTUnwrap(FirebaseApp.app(name: Constants.testAppName1), "Could not unwrap app")
    let apps = try XCTUnwrap(FirebaseApp.allApps, "Could not retrieve app dictionary")
    XCTAssertTrue(apps.keys.contains(app.name))
    let appDeletedExpectation = expectation(description: #function)
    app.delete { success in
      XCTAssertTrue(success)
      XCTAssertFalse(FirebaseApp.allApps?.keys.contains(Constants.testAppName1) ?? false)
      appDeletedExpectation.fulfill()
    }

    waitForExpectations(timeout: 1)
  }

  func testGetNameOfDefaultApp() throws {
    FirebaseApp.configure()

    let defaultApp = try XCTUnwrap(FirebaseApp.app(), "Could not unwrap default app")
    XCTAssertEqual(defaultApp.name, Constants.App.defaultName)
  }

  func testGetNameOfApp() throws {
    XCTAssertNil(FirebaseApp.app(name: Constants.testAppName1))

    let options = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                  gcmSenderID: Constants.Options.gcmSenderID)
    FirebaseApp.configure(name: Constants.testAppName1, options: options)

    let app = try XCTUnwrap(
      FirebaseApp.app(name: Constants.testAppName1),
      "Failed to unwrap custom named app"
    )
    XCTAssertEqual(app.name, Constants.testAppName1)
  }

  func testOptionsForApp() throws {
    FirebaseApp.configure()
    let defaultApp = try XCTUnwrap(FirebaseApp.app(), "Could not unwrap default app")
    let defaultOptions = FirebaseOptions.defaultOptions()
    XCTAssertEqual(defaultApp.options, defaultOptions)

    let options = FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                  gcmSenderID: Constants.Options.gcmSenderID)
    let superSecretURLScheme = "com.supersecret.googledeeplinkurl"
    options.deepLinkURLScheme = superSecretURLScheme
    FirebaseApp.configure(name: Constants.testAppName1, options: options)

    let app = try XCTUnwrap(
      FirebaseApp.app(name: Constants.testAppName1),
      "Could not unwrap custom named app"
    )
    XCTAssertEqual(app.name, Constants.testAppName1)
    XCTAssertEqual(app.options.googleAppID, Constants.Options.googleAppID)
    XCTAssertEqual(app.options.gcmSenderID, Constants.Options.gcmSenderID)
    XCTAssertEqual(app.options.deepLinkURLScheme, superSecretURLScheme)
    XCTAssertNil(app.options.androidClientID)
  }

  func testFirebaseDataCollectionDefaultEnabled() throws {
    let app = FirebaseApp(instanceWithName: "emptyApp",
                          options: FirebaseOptions(googleAppID: Constants.Options.googleAppID,
                                                   gcmSenderID: Constants.Options.gcmSenderID))

    // defaults to true unless otherwise set to no in app's Info.plist
    XCTAssertTrue(app.isDataCollectionDefaultEnabled)

    app.isDataCollectionDefaultEnabled = false
    XCTAssertFalse(app.isDataCollectionDefaultEnabled)

    // Cleanup
    app.isDataCollectionDefaultEnabled = true

    let expecation = expectation(description: #function)
    app.delete { success in
      expecation.fulfill()
    }

    waitForExpectations(timeout: 1)
  }

  // MARK: - Firebase User Agent

  func testFirebaseUserAgent_SwiftRuntime() {
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("swift/true"))
  }

  // MARK: - Helpers

  private func expectAppConfigurationNotification(appName: String, isDefaultApp: Bool) {
    let expectedUserInfo: NSDictionary = [
      "FIRAppNameKey": appName,
      "FIRAppIsDefaultAppKey": NSNumber(value: isDefaultApp),
      "FIRGoogleAppIDKey": Constants.Options.googleAppID,
    ]

    expectation(forNotification: NSNotification.Name.firAppReadyToConfigureSDK,
                object: FirebaseApp.self, handler: { (notification) -> Bool in
                  if let userInfo = notification.userInfo {
                    if expectedUserInfo.isEqual(to: userInfo) {
                      return true
                    }
                  } else {
                    XCTFail("Failed to unwrap notification user info")
                  }
                  return false
                })
  }
}
