// Copyright 2026 Google LLC
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
internal import FirebaseCoreExtension
import FirebaseCoreTestHooks
import Foundation
import XCTest

#if canImport(UIKit) && !os(watchOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#elseif os(watchOS)
  import WatchKit
#endif

/// Tests for configuring, finding and deleting `FirebaseApp`s, and for heartbeat logging. They
/// don't use OCMock, so they run unchanged against the Objective-C and Swift implementations of
/// FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRAppTest.m and the CocoaPods-only
/// FirebaseCore/Tests/SwiftUnit/FirebaseAppTests.swift. App ID validation is in
/// FirebaseAppIDTests.swift, and the data collection flag in FirebaseAppDataCollectionTests.swift.
///
/// Intentionally dropped from FIRAppTest.m: its `tearDown` ran the run loop for 0.5 seconds to let
/// background work finish. Nothing these tests check happens in the background.
final class FirebaseAppTests: CoreTestCase {
  private let appName1 = "test_app_name_1"
  private let appName2 = "test-app-name-2"

  // MARK: - Configuring

  func testConfigure() throws {
    registerTestLibraries()
    let bundle = try TemporaryServiceInfoBundle()
    try bundle.writeServiceInfo()
    try bundle.install()
    let notifications = NotificationRecorder(name: CoreContract.appReadyToConfigureSDKNotification)
    let eagerCreations = CoreTestEagerLibrary.creations.count

    assertNoException { FirebaseApp.configure() }

    assertReadyToConfigureNotifications(notifications, [(CoreContract.defaultAppName, true)])
    let app = try XCTUnwrap(FirebaseApp.app())
    XCTAssertEqual(app.name, CoreContract.defaultAppName)
    XCTAssertTrue(app.isDefaultApp)
    XCTAssertEqual(app.options.clientID, TestValues.clientID)
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)

    // The eager component was created while configuring, and both registered components are
    // available and cached.
    XCTAssertEqual(CoreTestEagerLibrary.creations.count, eagerCreations + 1)
    let eager = try XCTUnwrap(app.eagerTestComponent)
    XCTAssertTrue(eager === app.eagerTestComponent)
    XCTAssertEqual(CoreTestEagerLibrary.creations.count, eagerCreations + 1)
    let cached = try XCTUnwrap(app.cachedTestComponent)
    XCTAssertTrue(cached === app.cachedTestComponent)
    XCTAssertNil(app.unregisteredTestComponent)
  }

  func testConfigureWithoutServiceInfoRaises() throws {
    let bundle = try TemporaryServiceInfoBundle()
    try bundle.install()

    assertRaisesCoreException { FirebaseApp.configure() }
    XCTAssertNil(FirebaseApp.allApps)
    XCTAssertFalse(FirebaseApp.isDefaultAppConfigured())
  }

  func testConfigureWithOptions() throws {
    assertRaisesCoreException("nil options") { CoreTestHooks.configure(withNullableOptions: nil) }
    XCTAssertNil(FirebaseApp.allApps)

    let notifications = NotificationRecorder(name: CoreContract.appReadyToConfigureSDKNotification)
    let options = makeAppOptions()
    options.clientID = TestValues.clientID
    let app = try configureDefaultApp(options: options)

    assertReadyToConfigureNotifications(notifications, [(CoreContract.defaultAppName, true)])
    XCTAssertEqual(app.name, CoreContract.defaultAppName)
    XCTAssertEqual(app.options.googleAppID, TestValues.googleAppID)
    XCTAssertEqual(app.options.gcmSenderID, TestValues.gcmSenderID)
    XCTAssertEqual(app.options.clientID, TestValues.clientID)
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)
  }

  func testConfigureWithNameAndOptions() throws {
    let options = makeAppOptions()
    options.clientID = TestValues.clientID

    assertRaisesCoreException("nil name") {
      CoreTestHooks.configure(withNullableName: nil, options: options)
    }
    assertRaisesCoreException("nil options") {
      CoreTestHooks.configure(withNullableName: appName1, options: nil)
    }
    assertRaisesCoreException("empty name") { FirebaseApp.configure(name: "", options: options) }
    XCTAssertNil(FirebaseApp.allApps)

    let notifications = NotificationRecorder(name: CoreContract.appReadyToConfigureSDKNotification)
    let app = try configureApp(named: appName1, options: options)

    assertReadyToConfigureNotifications(notifications, [(appName1, false)])
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)
    XCTAssertEqual(app.name, appName1)
    XCTAssertFalse(app.isDefaultApp)
    XCTAssertEqual(app.options.clientID, TestValues.clientID)
    XCTAssertNil(FirebaseApp.app())
  }

  func testConfigureMultipleApps() throws {
    let notifications = NotificationRecorder(name: CoreContract.appReadyToConfigureSDKNotification)
    let app1 = try configureApp(named: appName1)
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)

    // Configure a different app with valid customized options.
    let options2 = makeAppOptions()
    options2.bundleID = TestValues.bundleID
    options2.apiKey = "customized_api_key"
    let app2 = try configureApp(named: appName2, options: options2)

    // The notifications are posted in order.
    assertReadyToConfigureNotifications(notifications, [(appName1, false), (appName2, false)])
    XCTAssertEqual(app2.name, appName2)
    XCTAssertEqual(app2.options.googleAppID, TestValues.googleAppID)
    XCTAssertEqual(app2.options.bundleID, TestValues.bundleID)
    XCTAssertEqual(app2.options.apiKey, "customized_api_key")

    let apps = try XCTUnwrap(FirebaseApp.allApps)
    XCTAssertEqual(Set(apps.keys), [appName1, appName2])
    XCTAssertTrue(apps[appName1] === app1)
    XCTAssertTrue(apps[appName2] === app2)
  }

  func testConfiguringTwiceRaises() throws {
    CoreTestHooks.setIsAppExtension(false)
    let options = makeAppOptions()

    _ = try configureDefaultApp(options: options)
    assertRaisesCoreException("default app") { FirebaseApp.configure(options: options) }

    _ = try configureApp(named: appName1, options: options)
    assertRaisesCoreException("named app") {
      FirebaseApp.configure(name: appName1, options: options)
    }

    XCTAssertEqual(FirebaseApp.allApps?.count, 2)
  }

  func testConfiguringDefaultAppTwiceInExtension() throws {
    CoreTestHooks.setIsAppExtension(true)
    let options = makeAppOptions()
    _ = try configureDefaultApp(options: options)
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)

    // An extension's entry point can run more than once, so the same options are allowed again.
    assertNoException { FirebaseApp.configure(options: options) }
    assertNoException { FirebaseApp.configure(options: makeAppOptions()) }
    XCTAssertNotNil(FirebaseApp.app())
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)

    // Different options still raise.
    assertRaisesCoreException {
      FirebaseApp.configure(options: makeAppOptions(googleAppID: "1:789:ios:789XYZ"))
    }
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)
  }

  func testConfiguringNamedAppTwiceInExtension() throws {
    CoreTestHooks.setIsAppExtension(true)
    let options = makeAppOptions()
    _ = try configureApp(named: appName1, options: options)
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)

    assertNoException { FirebaseApp.configure(name: appName1, options: options) }
    XCTAssertNotNil(FirebaseApp.app(name: appName1))
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)

    assertRaisesCoreException {
      FirebaseApp.configure(name: appName1,
                            options: makeAppOptions(googleAppID: "1:789:ios:789XYZ"))
    }
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)
  }

  func testAppNameValidation() {
    // Letters (including non-ASCII ones), digits, "-" and "_" are allowed.
    for name in ["aA1_", "aA1-", "aAē1_"] {
      assertNoException(name) { FirebaseApp.configure(name: name, options: makeAppOptions()) }
      XCTAssertNotNil(FirebaseApp.app(name: name), name)
    }
    for name in ["aA1%", "aA1?", "aA1!", "a b"] {
      assertRaisesCoreException(name) {
        FirebaseApp.configure(name: name, options: makeAppOptions())
      }
      XCTAssertNil(FirebaseApp.app(name: name), name)
    }
    XCTAssertEqual(FirebaseApp.allApps?.count, 3)
  }

  func testOptionsAreCopiedAndLocked() throws {
    let options = makeAppOptions()
    options.projectID = TestValues.projectID
    options.databaseURL = TestValues.databaseURL
    // Options aren't locked before they're used to configure an app.
    XCTAssertFalse(options.isEditingLocked)

    let app = try configureApp(named: "testOptionsLocking", options: options)

    // The app's options are locked.
    XCTAssertTrue(app.options.isEditingLocked)
    // The app keeps a copy, so the options passed in can still be changed without affecting it.
    XCTAssertFalse(options.isEditingLocked)
    options.projectID = "changed-project"
    XCTAssertEqual(app.options.projectID, TestValues.projectID)
  }

  // MARK: - Finding apps

  func testDefaultApp() throws {
    XCTAssertNil(FirebaseApp.app())

    let bundle = try TemporaryServiceInfoBundle()
    try bundle.writeServiceInfo()
    try bundle.install()
    assertNoException { FirebaseApp.configure() }

    let app = try XCTUnwrap(FirebaseApp.app())
    XCTAssertEqual(app.name, CoreContract.defaultAppName)
    XCTAssertEqual(app.options.clientID, TestValues.clientID)
    XCTAssertEqual(app.options, FirebaseOptions.defaultOptions())
    XCTAssertTrue(FirebaseApp.app(name: CoreContract.defaultAppName) === app)
  }

  func testAppNamed() throws {
    XCTAssertNil(FirebaseApp.app(name: appName1))

    let options = makeAppOptions()
    options.clientID = TestValues.clientID
    _ = try configureApp(named: appName1, options: options)

    let app = try XCTUnwrap(FirebaseApp.app(name: appName1))
    XCTAssertEqual(app.name, appName1)
    XCTAssertEqual(app.options.clientID, TestValues.clientID)
    XCTAssertNil(FirebaseApp.app(name: "The Missing App"))
  }

  func testAllApps() throws {
    XCTAssertNil(FirebaseApp.allApps)

    let defaultApp = try configureDefaultApp()
    let app1 = try configureApp(named: appName1)

    let apps = try XCTUnwrap(FirebaseApp.allApps)
    XCTAssertEqual(apps.count, 2)
    XCTAssertTrue(apps[CoreContract.defaultAppName] === defaultApp)
    XCTAssertTrue(apps[appName1] === app1)
  }

  func testIsDefaultAppConfigured() throws {
    XCTAssertFalse(FirebaseApp.isDefaultAppConfigured())

    // Named apps don't count.
    _ = try configureApp(named: appName1)
    XCTAssertFalse(FirebaseApp.isDefaultAppConfigured())

    _ = try configureDefaultApp()
    XCTAssertTrue(FirebaseApp.isDefaultAppConfigured())

    FirebaseApp.resetApps()
    XCTAssertFalse(FirebaseApp.isDefaultAppConfigured())
    XCTAssertNil(FirebaseApp.app())
    XCTAssertNil(FirebaseApp.allApps)
  }

  // MARK: - Deleting apps

  func testDeleteApp() throws {
    registerTestLibraries()
    let name = "testDeleteApp"
    let app = try configureApp(named: name)
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)
    XCTAssertNotNil(app.cachedTestComponent)
    XCTAssertNotNil(app.eagerTestComponent)
    XCTAssertNil(app.unregisteredTestComponent)

    let deletions = NotificationRecorder(name: CoreContract.appDeleteNotification)
    let deleted = expectation(description: "The app is deleted")
    app.delete { success in
      XCTAssertTrue(success)
      deleted.fulfill()
    }
    wait(for: [deleted], timeout: 1)

    let records = deletions.records
    XCTAssertEqual(records.count, 1)
    XCTAssertTrue(records.first?.object === (FirebaseApp.self as AnyObject))
    XCTAssertEqual(records.first?.userInfo, [CoreContract.appNameKey: name] as NSDictionary)
    XCTAssertNil(FirebaseApp.app(name: name))
    XCTAssertEqual(FirebaseApp.allApps?.count, 0)

    // The container no longer creates or returns component instances.
    XCTAssertNil(app.cachedTestComponent)
    XCTAssertNil(app.eagerTestComponent)

    // Deleting an app that no longer exists fails.
    let deletedAgain = expectation(description: "Deleting the app again fails")
    app.delete { success in
      XCTAssertFalse(success)
      deletedAgain.fulfill()
    }
    wait(for: [deletedAgain], timeout: 1)
    XCTAssertEqual(deletions.records.count, 1)
  }

  // MARK: - User agent

  func testUserAgent() {
    FirebaseApp.registerLibrary("core-swift-unit-agent", withVersion: "1.2.3")
    // Libraries with characters other than letters, digits, "-", "_" and "." are ignored.
    FirebaseApp.registerLibrary("core swift unit", withVersion: "1.0")

    // `fire-ios` isn't checked: `resetApps`, which runs before each test, also removes the
    // registered libraries from the user agent, including `fire-ios`.
    let agent = FirebaseApp.firebaseUserAgent()
    for component in ["apple-platform/", "appstore/", "deploy/", "device/", "os-version/",
                      "core-swift-unit-agent/1.2.3"] {
      XCTAssertTrue(agent.contains(component), "\(component) is missing from \(agent)")
    }
    XCTAssertFalse(agent.contains("core swift unit"), agent)
    // These come from the host's Info.plist, which only has them when Xcode built it.
    if Bundle.main.object(forInfoDictionaryKey: "DTXcodeBuild") != nil {
      XCTAssertTrue(agent.contains("xcode/"), agent)
    }
    if Bundle.main.object(forInfoDictionaryKey: "DTSDKBuild") != nil {
      XCTAssertTrue(agent.contains("apple-sdk/"), agent)
    }
  }

  // MARK: - Heartbeats

  func testHeartbeatIsLoggedWhenAppBecomesActive() throws {
    // Replaces stubbing +[FIRHeartbeatLogger alloc] with OCMock, which can't intercept Swift.
    let recorder = HeartbeatLogRecorder()
    recorder.install()
    let googleAppID = "1:456:ios:456def"
    _ = try configureApp(named: "testHeartbeat", options: makeAppOptions(googleAppID: googleAppID))
    XCTAssertEqual(recorder.appIDs, [])

    postAppDidBecomeActive()

    XCTAssertEqual(recorder.appIDs, [googleAppID])
  }

  func testHeartbeatIsNotLoggedWhenDataCollectionIsDisabled() throws {
    // FIRAppTest.m's testGlobalDataCollectionNoDiagnosticsSent set no expectations on its
    // heartbeat logger mock, so it couldn't fail. This checks what it meant to.
    let recorder = HeartbeatLogRecorder()
    recorder.install()
    let googleAppID = "1:456:ios:456def"
    let app = try configureApp(named: "testNoHeartbeat",
                               options: makeAppOptions(googleAppID: googleAppID))
    app.isDataCollectionDefaultEnabled = false

    postAppDidBecomeActive()
    XCTAssertEqual(recorder.appIDs, [])

    app.isDataCollectionDefaultEnabled = true
    postAppDidBecomeActive()
    XCTAssertEqual(recorder.appIDs, [googleAppID])
  }

  // MARK: - Helpers

  private func assertReadyToConfigureNotifications(_ recorder: NotificationRecorder,
                                                   _ expected: [(name: String, isDefault: Bool)],
                                                   file: StaticString = #filePath,
                                                   line: UInt = #line) {
    let records = recorder.records
    XCTAssertEqual(records.count, expected.count, file: file, line: line)
    for (record, app) in zip(records, expected) {
      XCTAssertTrue(record.object === (FirebaseApp.self as AnyObject), file: file, line: line)
      let expectedUserInfo: NSDictionary = [
        CoreContract.appNameKey: app.name,
        CoreContract.isDefaultAppKey: NSNumber(value: app.isDefault),
        CoreContract.googleAppIDKey: TestValues.googleAppID,
      ]
      XCTAssertEqual(record.userInfo, expectedUserInfo, file: file, line: line)
    }
  }

  private func postAppDidBecomeActive() {
    #if canImport(UIKit) && !os(watchOS)
      let name = UIApplication.didBecomeActiveNotification
    #elseif os(macOS)
      let name = NSApplication.didBecomeActiveNotification
    #elseif os(watchOS)
      let name = WKApplication.didBecomeActiveNotification
    #endif
    NotificationCenter.default.post(name: name, object: nil)
  }
}
