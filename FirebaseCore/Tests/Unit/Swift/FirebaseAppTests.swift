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

struct TestApp {
  static let androidClientID = "correct_android_client_id"
  static let apiKey = "correct_api_key"
  static let customizedAPIKey = "customized_api_key"
  static let clientID = "correct_client_id"
  static let trackingID = "correct_tracking_id"
  static let gcmSenderID = "correct_gcm_sender_id"
  static let googleAppID = "1:123:ios:123abc"
  static let databaseURL = "https://abc-xyz-123.firebaseio.com"
  static let storageBucket = "project-id-123.storage.firebase.com"
  static let deepLinkURLScheme = "comgoogledeeplinkurl"
  static let newDeepLinkURLScheme = "newdeeplinkurlfortest"
  static let bundleID = "com.google.FirebaseSDKTests"
  static let projectID = "abc-xyz-123"
}

let testAppName1 = "test_app_name_1"
let testAppName2 = "test_app_name_2"

let firebaseDefaultAppName = "__FIRAPP_DEFAULT"
let googleAppIDKey = "FIRGoogleAppIDKey"
let firebaseAppNameKey = "FIRAppNameKey"
let firebaseAppIsDefaultAppKey = "FIRAppIsDefaultAppKey"

class FirebaseAppTests: XCTestCase {
  override func setUp() {
    super.setUp()
    FirebaseApp.resetApps()
  }

  override class func tearDown() {
    super.tearDown()
  }

  func testSwiftFlagWithSwift() {
    XCTAssertTrue(FirebaseApp.firebaseUserAgent().contains("swift"))
  }

  func testConfigure() {
    let expectedUserInfo = expectedUserInfoForApp(named: firebaseDefaultAppName,
                                                  isDefaultApp: true)
    expectAppConfigurationNotification(with: expectedUserInfo)

    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure()
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    do {
      let app = try XCTUnwrap(FirebaseApp.app(), "Failed to unwrap default app")
      XCTAssertEqual(app.name, firebaseDefaultAppName)
      XCTAssertEqual(app.options.clientID, TestApp.clientID)
      XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    } catch {
      XCTFail("The default app does not exist")
    }

    // MARK: Should we check the registered libraries instances available?

    waitForExpectations()
  }

  func testConfigureDefaultAppTwice() {
    FirebaseApp.configure()

    let secondConfigurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure()
      }
    }

    XCTAssertThrowsError(try secondConfigurationAttempt())
  }

  func testConfigureWithOptions() {
    let expectedUserInfo = expectedUserInfoForApp(named: firebaseDefaultAppName,
                                                  isDefaultApp: true)
    expectAppConfigurationNotification(with: expectedUserInfo)

    let options = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                  gcmSenderID: TestApp.gcmSenderID)
    options.clientID = TestApp.clientID
    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(options: options)
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    do {
      let app = try XCTUnwrap(FirebaseApp.app(), "Failed to unwrap default app")
      XCTAssertEqual(app.name, firebaseDefaultAppName)
      XCTAssertEqual(app.options.googleAppID, TestApp.googleAppID)
      XCTAssertEqual(app.options.gcmSenderID, TestApp.gcmSenderID)
      XCTAssertEqual(app.options.clientID, TestApp.clientID)
      XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    } catch {
      XCTFail("The default app does not exist")
    }

    waitForExpectations()
  }

  func testConfigureWithNameAndOptions() {
    let expectedUserInfo = expectedUserInfoForApp(named: testAppName1,
                                                  isDefaultApp: false)
    expectAppConfigurationNotification(with: expectedUserInfo)

    let options = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                  gcmSenderID: TestApp.gcmSenderID)
    options.clientID = TestApp.clientID

    let configurationAttempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: testAppName1, options: options)
      }
    }
    XCTAssertNoThrow(try configurationAttempt())

    do {
      let app = try XCTUnwrap(FirebaseApp.app(name: testAppName1), "Failed to unwrap default app")
      XCTAssertEqual(app.name, testAppName1)
      XCTAssertEqual(app.options.googleAppID, TestApp.googleAppID)
      XCTAssertEqual(app.options.gcmSenderID, TestApp.gcmSenderID)
      XCTAssertEqual(app.options.clientID, TestApp.clientID)
      XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    } catch {
      XCTFail("Failed to retrieve app1")
    }

    let configureAppAgain = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: testAppName1, options: options)
      }
    }

    XCTAssertThrowsError(try configureAppAgain())

    waitForExpectations()
  }

  func testConfigureMultipleApps() {
    let appsConfiguredSuccessfullyExpectation = expectation(description: #function)
    appsConfiguredSuccessfullyExpectation.expectedFulfillmentCount = 2

    let expectedAppNames = [testAppName1, testAppName2]
    expectation(forNotification: NSNotification.Name.firAppReadyToConfigureSDK,
                object: FirebaseApp.self, handler: { (notification) -> Bool in
                  if let userInfo = notification.userInfo as? [String: Any] {
                    XCTAssertTrue(expectedAppNames
                      .contains(userInfo[firebaseAppNameKey] as? String ?? ""))
                    appsConfiguredSuccessfullyExpectation.fulfill()
                  } else {
                    XCTFail("Failed to unwrap notification user info")
                  }
                  return true
    })

    let options1 = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                   gcmSenderID: TestApp.gcmSenderID)
    options1.deepLinkURLScheme = TestApp.deepLinkURLScheme

    XCTAssertNoThrow(FirebaseApp.configure(name: testAppName1,
                                           options: options1))

    do {
      let app1 = try XCTUnwrap(FirebaseApp.app(name: testAppName1), "Failed to unwrap app1")
      XCTAssertEqual(app1.name, testAppName1)
      XCTAssertEqual(app1.options.googleAppID, TestApp.googleAppID)
      XCTAssertEqual(app1.options.gcmSenderID, TestApp.gcmSenderID)
      XCTAssertEqual(app1.options.deepLinkURLScheme, TestApp.deepLinkURLScheme)
      XCTAssertTrue(FirebaseApp.allApps?.count == 1)

    } catch {
      XCTFail("Failed to retrieve app1")
    }

    // Configure a different app with valid customized options.
    let options2 = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                   gcmSenderID: TestApp.gcmSenderID)
    options2.bundleID = TestApp.bundleID
    options2.apiKey = TestApp.customizedAPIKey

    let configureApp2Attempt = {
      try ExceptionCatcher.catchException {
        FirebaseApp.configure(name: testAppName2, options: options2)
      }
    }
    XCTAssertNoThrow(try configureApp2Attempt())

    do {
      let app2 = try XCTUnwrap(FirebaseApp.app(name: testAppName2), "Failed to unwrap app")
      XCTAssertEqual(app2.name, testAppName2)
      XCTAssertEqual(app2.options.googleAppID, TestApp.googleAppID)
      XCTAssertEqual(app2.options.gcmSenderID, TestApp.gcmSenderID)
      XCTAssertEqual(app2.options.bundleID, TestApp.bundleID)
      XCTAssertEqual(app2.options.apiKey, TestApp.customizedAPIKey)
      XCTAssertTrue(FirebaseApp.allApps?.count == 2)

    } catch {
      XCTFail("Failed to retrieve app2")
    }

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
    do {
      let options = try XCTUnwrap(FirebaseOptions.defaultOptions(),
                                  "Could not load default options.")
      FirebaseApp.configure(name: testAppName1, options: options)
      let app = FirebaseApp.app(name: testAppName1)
      XCTAssertNotNil(app, "Failed to get app")
    } catch {
      XCTFail()
    }
  }

  func testAttemptToGetNonExistingAppWithName() {
    let unknownAppName = "The Missing App"
    let app = FirebaseApp.app(name: unknownAppName)
    XCTAssertNil(app)
  }

  func testAllApps() {
    XCTAssertNil(FirebaseApp.allApps)

    let options1 = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                   gcmSenderID: TestApp.gcmSenderID)
    FirebaseApp.configure(name: testAppName1, options: options1)
    guard let app1 = FirebaseApp.app(name: testAppName1) else {
      return XCTFail("App1 could not be unwrapped")
    }
    let options2 = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                   gcmSenderID: TestApp.gcmSenderID)
    FirebaseApp.configure(name: testAppName2, options: options2)
    guard let app2 = FirebaseApp.app(name: testAppName2) else {
      return XCTFail("App2 could not be unwrapped")
    }

    guard let apps = FirebaseApp.allApps else {
      return XCTFail("Could not retrieve apps")
    }

    XCTAssertEqual(apps.count, 2)
    XCTAssertTrue(apps.keys.contains(testAppName1))
    XCTAssertEqual(apps[testAppName1], app1)
    XCTAssertTrue(apps.keys.contains(testAppName2))
    XCTAssertEqual(apps[testAppName2], app2)
  }

  func testDeleteApp() {
    XCTAssertNil(FirebaseApp.app(name: testAppName1))
    XCTAssertNil(FirebaseApp.allApps)

    let expectedUserInfo = expectedUserInfoForApp(named: testAppName1,
                                                  isDefaultApp: false)
    expectAppConfigurationNotification(with: expectedUserInfo)

    let options = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                  gcmSenderID: TestApp.gcmSenderID)
    FirebaseApp.configure(name: testAppName1, options: options)

    do {
      let app = try XCTUnwrap(FirebaseApp.app(name: testAppName1), "Could not unwrap app")
      let apps = try XCTUnwrap(FirebaseApp.allApps, "Could not retrieve app dictionary")
      XCTAssertTrue(apps.keys.contains(app.name))
      let appDeletedExpectation = expectation(description: #function)
      app.delete { success in
        XCTAssertTrue(success)
        XCTAssertFalse(FirebaseApp.allApps?.keys.contains(testAppName1) ?? false)
        appDeletedExpectation.fulfill()
      }

    } catch {
      XCTFail("Could not delete app")
    }

    waitForExpectations()
  }

  func testGetNameOfDefaultApp() {
    FirebaseApp.configure()
    do {
      let defaultApp = try XCTUnwrap(FirebaseApp.app(), "Could not unwrap default app")
      XCTAssertEqual(defaultApp.name, firebaseDefaultAppName)
    } catch {
      XCTFail("Could not get default app")
    }
  }

  func testGetNameOfApp() {
    XCTAssertNil(FirebaseApp.app(name: testAppName1))

    let options = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                  gcmSenderID: TestApp.gcmSenderID)
    FirebaseApp.configure(name: testAppName1, options: options)
    do {
      let app = try XCTUnwrap(FirebaseApp.app(name: testAppName1), "Could not unwrap app")
      XCTAssertEqual(app.name, testAppName1)
    } catch {
      XCTFail("Could not get app")
    }
  }

  func testOptionsForApp() {
    FirebaseApp.configure()
    do {
      let app = try XCTUnwrap(FirebaseApp.app(), "Could not unwrap default app")
      let defaultOptions = FirebaseOptions.defaultOptions()
      XCTAssertEqual(app.options, defaultOptions)
    } catch {
      XCTFail()
    }

    let options = FirebaseOptions(googleAppID: TestApp.googleAppID,
                                  gcmSenderID: TestApp.gcmSenderID)
    let superSecretURLScheme = "com.supersecret.googledeeplinkurl"
    options.deepLinkURLScheme = superSecretURLScheme
    FirebaseApp.configure(name: testAppName1, options: options)

    do {
      let app = try XCTUnwrap(FirebaseApp.app(name: testAppName1), "Could not unwrap app")
      XCTAssertEqual(app.name, testAppName1)
      XCTAssertEqual(app.options.googleAppID, TestApp.googleAppID)
      XCTAssertEqual(app.options.gcmSenderID, TestApp.gcmSenderID)
      XCTAssertEqual(app.options.deepLinkURLScheme, superSecretURLScheme)
      XCTAssertNil(app.options.androidClientID)
    } catch {
      XCTFail()
    }
  }

  func testFirebaseDataCollectionDefaultEnabled() {
    FirebaseApp.configure()
    do {
      let app = try XCTUnwrap(FirebaseApp.app(), "Could not unwrap default app")

      // defaults to true unless otherwise set to no in app's Info.plist
      XCTAssertTrue(app.isDataCollectionDefaultEnabled)

      app.isDataCollectionDefaultEnabled = false
      XCTAssertFalse(app.isDataCollectionDefaultEnabled)

      // reset to defautl true since it will persist across runs of the app/tests
      app.isDataCollectionDefaultEnabled = true

    } catch {
      XCTFail()
    }
  }

  private func expectedUserInfoForApp(named name: String, isDefaultApp: Bool) -> NSDictionary {
    return [
      firebaseAppNameKey: name,
      firebaseAppIsDefaultAppKey: NSNumber(value: isDefaultApp),
      googleAppIDKey: TestApp.googleAppID,
    ]
  }

  private func expectAppConfigurationNotification(with expectedUserInfo: NSDictionary) {
    expectation(forNotification: NSNotification.Name.firAppReadyToConfigureSDK,
                object: FirebaseApp.self, handler: { (notification) -> Bool in
                  if let userInfo = notification.userInfo {
                    XCTAssertTrue(expectedUserInfo.isEqual(to: userInfo))
                  } else {
                    XCTFail("Failed to unwrap notification user info")
                  }
                  return true
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
