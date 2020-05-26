// Copyright 2019 Google
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

private extension FirebaseTestConstants.App {
  static let testAppName1: String = "test_app_name_1"
  static let testAppName2: String = "test_app_name_2"
}

class FirebaseAppTests: XCTestCase {
  let testApp = FirebaseTestConstants.App.self
  let testOptions = FirebaseTestConstants.Options.self

  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
    FirebaseApp.resetApps()
  }

  func testSwiftFlagWithSwift() {
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("swift"))
  }

  func testConfigure() {
    let expectedUserInfo = expectedUserInfoForApp(named: testApp.firebaseDefaultAppName,
                                                  isDefaultApp: true)
    expectAppConfigurationNotification(with: expectedUserInfo)
    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure()
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let app = FirebaseApp.app() else {
      return XCTFail("Failed to unwrap default app")
    }
    XCTAssertEqual(app.name, FirebaseTestConstants.App.firebaseDefaultAppName)
    XCTAssertEqual(app.options.clientID, FirebaseTestConstants.Options.clientID)
    XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    // TODO: check registered libraries instances available

    waitForExpectations()
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

  func testConfigureWithOptions() {
    let expectedUserInfo = expectedUserInfoForApp(named: testApp.firebaseDefaultAppName,
                                                  isDefaultApp: true)
    expectAppConfigurationNotification(with: expectedUserInfo)

    let options = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                  gcmSenderID: testOptions.gcmSenderID)
    options.clientID = testOptions.clientID
    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(options: options)
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let app = FirebaseApp.app() else {
      return XCTFail("Failed to unwrap default app")
    }
    XCTAssertEqual(app.name, testApp.firebaseDefaultAppName)
    XCTAssertEqual(app.options.googleAppID, testOptions.googleAppID)
    XCTAssertEqual(app.options.gcmSenderID, testOptions.gcmSenderID)
    XCTAssertEqual(app.options.clientID, testOptions.clientID)
    XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    waitForExpectations()
  }

  func testConfigureWithNameAndOptions() {
    let expectedUserInfo = expectedUserInfoForApp(named: testApp.testAppName1,
                                                  isDefaultApp: false)
    expectAppConfigurationNotification(with: expectedUserInfo)

    let options = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                  gcmSenderID: testOptions.gcmSenderID)
    options.clientID = testOptions.clientID

    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: self.testApp.testAppName1, options: options)
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    guard let app = FirebaseApp.app(name: testApp.testAppName1) else {
      return XCTFail("Failed to unwrap default app")
    }
    XCTAssertEqual(app.name, testApp.testAppName1)
    XCTAssertEqual(app.options.googleAppID, testOptions.googleAppID)
    XCTAssertEqual(app.options.gcmSenderID, testOptions.gcmSenderID)
    XCTAssertEqual(app.options.clientID, testOptions.clientID)
    XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    let configureAppAgain = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: self.testApp.testAppName1, options: options)
      }
    }

    XCTAssertThrowsError(try configureAppAgain())

    waitForExpectations()
  }

  func testConfigureMultipleApps() {
    let options1 = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                   gcmSenderID: testOptions.gcmSenderID)
    options1.deepLinkURLScheme = testOptions.deepLinkURLScheme

    let expectedUserInfo = expectedUserInfoForApp(named: testApp.testAppName1,
                                                  isDefaultApp: false)
    expectAppConfigurationNotification(with: expectedUserInfo)

    XCTAssertNoThrow(FirebaseApp.configure(name: testApp.testAppName1, options: options1))

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let app1 = FirebaseApp.app(name: testApp.testAppName1) else {
      return XCTFail("Failed to unwrap app1")
    }
    XCTAssertEqual(app1.name, testApp.testAppName1)
    XCTAssertEqual(app1.options.googleAppID, testOptions.googleAppID)
    XCTAssertEqual(app1.options.gcmSenderID, testOptions.gcmSenderID)
    XCTAssertEqual(app1.options.deepLinkURLScheme, testOptions.deepLinkURLScheme)
    XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    // Configure a different app with valid customized options.
    let options2 = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                   gcmSenderID: testOptions.gcmSenderID)
    options2.bundleID = testOptions.bundleID
    options2.apiKey = testOptions.customizedAPIKey

    let expectedUserInfo2 = expectedUserInfoForApp(named: testApp.testAppName2,
                                                   isDefaultApp: false)
    expectAppConfigurationNotification(with: expectedUserInfo2)

    let configureApp2Attempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: self.testApp.testAppName2, options: options2)
      }
    }
    XCTAssertNoThrow(try configureApp2Attempt())

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let app2 = FirebaseApp.app(name: testApp.testAppName2) else {
      return XCTFail("Failed to unwrap app")
    }
    XCTAssertEqual(app2.name, testApp.testAppName2)
    XCTAssertEqual(app2.options.googleAppID, testOptions.googleAppID)
    XCTAssertEqual(app2.options.gcmSenderID, testOptions.gcmSenderID)
    XCTAssertEqual(app2.options.bundleID, testOptions.bundleID)
    XCTAssertEqual(app2.options.apiKey, testOptions.customizedAPIKey)
    XCTAssertTrue(FirebaseApp.allApps?.count == 2)

    waitForExpectations()
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

  func testGetExistingAppWithName() {
    // Configure a different app with valid customized options.
    guard let options = FirebaseOptions.defaultOptions() else {
      return XCTFail("Could not load default options.")
    }
    FirebaseApp.configure(name: testApp.testAppName1, options: options)
    let app = FirebaseApp.app(name: testApp.testAppName1)
    XCTAssertNotNil(app, "Failed to get app")
  }

  func testAttemptToGetNonExistingAppWithName() {
    let unknownAppName = "The Missing App"
    let app = FirebaseApp.app(name: unknownAppName)
    XCTAssertNil(app)
  }

  func testAllApps() {
    XCTAssertNil(FirebaseApp.allApps)

    let options1 = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                   gcmSenderID: testOptions.gcmSenderID)
    FirebaseApp.configure(name: testApp.testAppName1, options: options1)
    guard let app1 = FirebaseApp.app(name: testApp.testAppName1) else {
      return XCTFail("App1 could not be unwrapped")
    }
    let options2 = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                   gcmSenderID: testOptions.gcmSenderID)
    FirebaseApp.configure(name: testApp.testAppName2, options: options2)
    guard let app2 = FirebaseApp.app(name: testApp.testAppName2) else {
      return XCTFail("App2 could not be unwrapped")
    }

    guard let apps = FirebaseApp.allApps else {
      return XCTFail("Could not retrieve apps")
    }

    XCTAssertEqual(apps.count, 2)
    XCTAssertTrue(apps.keys.contains(testApp.testAppName1))
    XCTAssertEqual(apps[testApp.testAppName1], app1)
    XCTAssertTrue(apps.keys.contains(testApp.testAppName2))
    XCTAssertEqual(apps[testApp.testAppName2], app2)
  }

  func testDeleteApp() {
    XCTAssertNil(FirebaseApp.app(name: testApp.testAppName1))
    XCTAssertNil(FirebaseApp.allApps)

    let expectedUserInfo = expectedUserInfoForApp(named: testApp.testAppName1,
                                                  isDefaultApp: false)
    expectAppConfigurationNotification(with: expectedUserInfo)

    let options = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                  gcmSenderID: testOptions.gcmSenderID)
    FirebaseApp.configure(name: testApp.testAppName1, options: options)

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let app = FirebaseApp.app(name: testApp.testAppName1) else {
      return XCTFail("Could not unwrap app")
    }
    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let apps = FirebaseApp.allApps else {
      return XCTFail("Could not retrieve app dictionary")
    }
    XCTAssertTrue(apps.keys.contains(app.name))
    let appDeletedExpectation = expectation(description: #function)
    app.delete { success in
      XCTAssertTrue(success)
      XCTAssertFalse(FirebaseApp.allApps?.keys.contains(self.testApp.testAppName1) ?? false)
      appDeletedExpectation.fulfill()
    }

    waitForExpectations()
  }

  func testGetNameOfDefaultApp() {
    FirebaseApp.configure()

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let defaultApp = FirebaseApp.app() else {
      return XCTFail("Could not unwrap default app")
    }
    XCTAssertEqual(defaultApp.name, testApp.firebaseDefaultAppName)
  }

  func testGetNameOfApp() throws {
    XCTAssertNil(FirebaseApp.app(name: testApp.testAppName1))

    let options = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                  gcmSenderID: testOptions.gcmSenderID)
    FirebaseApp.configure(name: testApp.testAppName1, options: options)

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let app = FirebaseApp.app(name: testApp.testAppName1) else {
      return XCTFail("Could not unwrap app")
    }
    XCTAssertEqual(app.name, testApp.testAppName1)
  }

  func testOptionsForApp() {
    FirebaseApp.configure()
    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let defaultApp = FirebaseApp.app() else {
      return XCTFail("Could not unwrap default app")
    }
    let defaultOptions = FirebaseOptions.defaultOptions()
    XCTAssertEqual(defaultApp.options, defaultOptions)

    let options = FirebaseOptions(googleAppID: testOptions.googleAppID,
                                  gcmSenderID: testOptions.gcmSenderID)
    let superSecretURLScheme = "com.supersecret.googledeeplinkurl"
    options.deepLinkURLScheme = superSecretURLScheme
    FirebaseApp.configure(name: testApp.testAppName1, options: options)

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let app = FirebaseApp.app(name: testApp.testAppName1) else {
      return XCTFail("Could not unwrap app")
    }
    XCTAssertEqual(app.name, testApp.testAppName1)
    XCTAssertEqual(app.options.googleAppID, testOptions.googleAppID)
    XCTAssertEqual(app.options.gcmSenderID, testOptions.gcmSenderID)
    XCTAssertEqual(app.options.deepLinkURLScheme, superSecretURLScheme)
    XCTAssertNil(app.options.androidClientID)
  }

  func testFirebaseDataCollectionDefaultEnabled() {
    FirebaseApp.configure()

    // TODO: Use XCTUnwrap after dropping support for Xcode 10
    guard let app = FirebaseApp.app() else {
      return XCTFail("Could not unwrap default app")
    }

    // defaults to true unless otherwise set to no in app's Info.plist
    XCTAssertTrue(app.isDataCollectionDefaultEnabled)

    app.isDataCollectionDefaultEnabled = false
    XCTAssertFalse(app.isDataCollectionDefaultEnabled)

    // reset to defautl true since it will persist across runs of the app/tests
    app.isDataCollectionDefaultEnabled = true
  }

  // MARK: - Helpers

  private func expectedUserInfoForApp(named name: String, isDefaultApp: Bool) -> NSDictionary {
    return [
      "FIRAppNameKey": name,
      "FIRAppIsDefaultAppKey": NSNumber(value: isDefaultApp),
      "FIRGoogleAppIDKey": testOptions.googleAppID,
    ]
  }

  private func expectAppConfigurationNotification(with expectedUserInfo: NSDictionary) {
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

  private func waitForExpectations() {
    let kFIRStorageIntegrationTestTimeout = 60.0
    waitForExpectations(timeout: kFIRStorageIntegrationTestTimeout,
                        handler: { (error) -> Void in
                          if let error = error {
                            print(error)
                          }
    })
  }
}
