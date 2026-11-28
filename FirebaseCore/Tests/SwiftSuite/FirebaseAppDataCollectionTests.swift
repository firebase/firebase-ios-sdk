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

/// Tests for the data collection flag and how it controls Analytics. Ported from
/// FirebaseCore/Tests/Unit/FIRAppTest.m, the four analytics global switch tests of
/// FirebaseCore/Tests/Unit/FIROptionsTest.m, and testFirebaseDataCollectionDefaultEnabled of the
/// CocoaPods-only FirebaseCore/Tests/SwiftUnit/FirebaseAppTests.swift.
///
/// Instead of OCMock, the flag is stored in temporary user defaults (see `CoreTestCase`), the
/// Info.plist value is set through `CoreTestHooks.setInfoDictionary(_:)`, and the Analytics flag
/// is observed through the notification that FIRAnalyticsConfiguration posts.
final class FirebaseAppDataCollectionTests: CoreTestCase {
  // MARK: - Data collection flag

  /// Replaces the seven testGlobalDataCollection{NoFlags,PlistSet*,UserSpecified*,UserOverridden*}
  /// tests, which stubbed the methods that read user defaults and Info.plist.
  func testDataCollectionFlagPrecedence() {
    // (description, user defaults value, Info.plist value, expected flag)
    let cases: [(String, Any?, Any?, Bool)] = [
      ("no flags", nil, nil, true),
      ("Info.plist enabled", nil, true, true),
      ("Info.plist disabled", nil, false, false),
      ("user enabled", true, nil, true),
      ("user disabled", false, nil, false),
      ("user enabled overrides Info.plist", true, false, true),
      ("user disabled overrides Info.plist", false, true, false),
      ("values that aren't numbers are ignored", "NO", "NO", true),
    ]
    for (index, (description, defaultsValue, plistValue, expected)) in cases.enumerated() {
      let name = "testDataCollection\(index)"
      let app = FirebaseApp(instanceWithName: name, options: makeAppOptions())
      let key = CoreContract.dataCollectionDefaultsKey(appName: name)
      if let defaultsValue {
        userDefaults.set(defaultsValue, forKey: key)
      }
      var infoDictionary: [String: Any] = [:]
      infoDictionary[CoreContract.dataCollectionPlistKey] = plistValue
      CoreTestHooks.setInfoDictionary(infoDictionary)

      XCTAssertEqual(app.isDataCollectionDefaultEnabled, expected, description)
    }
  }

  func testDataCollectionFlagDefaultsToEnabled() throws {
    // Without the Info.plist override, the flag comes from the main bundle's Info.plist.
    let plistValue = Bundle.main.object(forInfoDictionaryKey: CoreContract.dataCollectionPlistKey)
    try XCTSkipIf(plistValue != nil, "The test host's Info.plist sets the data collection flag")
    let app = FirebaseApp(instanceWithName: "testDataCollectionDefault", options: makeAppOptions())
    XCTAssertTrue(app.isDataCollectionDefaultEnabled)
  }

  func testDataCollectionFlagIsStoredInUserDefaults() throws {
    let name = "testDataCollectionStored"
    let app = try configureApp(named: name)
    let key = CoreContract.dataCollectionDefaultsKey(appName: name)
    XCTAssertNil(userDefaults.object(forKey: key))
    XCTAssertTrue(app.isDataCollectionDefaultEnabled)

    app.isDataCollectionDefaultEnabled = false
    XCTAssertEqual(userDefaults.object(forKey: key) as? NSNumber, false)
    XCTAssertFalse(app.isDataCollectionDefaultEnabled)

    app.isDataCollectionDefaultEnabled = true
    XCTAssertEqual(userDefaults.object(forKey: key) as? NSNumber, true)
    XCTAssertTrue(app.isDataCollectionDefaultEnabled)

    // Each app has its own flag.
    let otherApp = try configureApp(named: "testDataCollectionOther")
    otherApp.isDataCollectionDefaultEnabled = false
    XCTAssertTrue(app.isDataCollectionDefaultEnabled)

    // The test seam kept the standard user defaults untouched.
    XCTAssertNil(UserDefaults.standard.object(forKey: key))
  }

  func testDataCollectionFlagIsClearedAfterDelete() throws {
    let name = "testDataCollectionCleared"
    let app = try configureApp(named: name)
    app.isDataCollectionDefaultEnabled = false
    XCTAssertFalse(app.isDataCollectionDefaultEnabled)

    let deleted = expectation(description: "The app is deleted")
    app.delete { success in
      XCTAssertTrue(success)
      deleted.fulfill()
    }
    wait(for: [deleted], timeout: 1)
    XCTAssertNil(userDefaults.object(forKey: CoreContract.dataCollectionDefaultsKey(appName: name)))

    // An app configured again with the same name starts with the default flag.
    let newApp = try configureApp(named: name)
    XCTAssertTrue(newApp.isDataCollectionDefaultEnabled)
  }

  // MARK: - Analytics flag

  func testDataCollectionFlagSetsAnalyticsForDefaultApp() {
    // Analytics only works with the default app, so it's the only one that sets the flag.
    let app = FirebaseApp(instanceWithName: CoreContract.defaultAppName, options: makeAppOptions())
    XCTAssertTrue(app.isDefaultApp)
    XCTAssertFalse(app.options.isAnalyticsCollectionExplicitlySet)
    let persistedState = persistedAnalyticsState()

    let analyticsFlags = recordAnalyticsFlags {
      app.isDataCollectionDefaultEnabled = true
      app.isDataCollectionDefaultEnabled = false
    }

    XCTAssertEqual(analyticsFlags, [true, false])
    // The Analytics flag isn't persisted.
    XCTAssertEqual(persistedAnalyticsState(), persistedState)
  }

  func testDataCollectionFlagDoesNotOverrideExplicitAnalyticsFlag() {
    var serviceInfo = TestValues.serviceInfo
    serviceInfo[AnalyticsKeys.collectionEnabled] = true
    let options = FirebaseOptions(internalWithOptionsDictionary: serviceInfo)
    let app = FirebaseApp(instanceWithName: CoreContract.defaultAppName, options: options)
    XCTAssertTrue(app.options.isAnalyticsCollectionExplicitlySet)

    let analyticsFlags = recordAnalyticsFlags {
      app.isDataCollectionDefaultEnabled = true
      app.isDataCollectionDefaultEnabled = false
    }

    XCTAssertEqual(analyticsFlags, [])
    XCTAssertFalse(app.isDataCollectionDefaultEnabled)
  }

  func testDataCollectionFlagDoesNotSetAnalyticsForOtherApps() {
    let app = FirebaseApp(instanceWithName: "testAnalyticsNotSet", options: makeAppOptions())
    XCTAssertFalse(app.options.isAnalyticsCollectionExplicitlySet)

    let analyticsFlags = recordAnalyticsFlags {
      app.isDataCollectionDefaultEnabled = true
      app.isDataCollectionDefaultEnabled = false
    }

    XCTAssertEqual(analyticsFlags, [])
    XCTAssertFalse(app.isDataCollectionDefaultEnabled)
  }

  // MARK: - Analytics options and the default app's flag (from FIROptionsTest.m)

  func testAnalyticsCollectionGlobalSwitchEnabled() throws {
    let app = try configureDefaultApp()
    app.isDataCollectionDefaultEnabled = true

    // With no other settings, Analytics collection follows the default app's flag.
    let options = FirebaseOptions(internalWithOptionsDictionary: [:])
    XCTAssertTrue(options.isAnalyticsCollectionEnabled)
    XCTAssertTrue(options.isMeasurementEnabled)
  }

  func testAnalyticsCollectionGlobalSwitchDisabled() throws {
    let app = try configureDefaultApp()
    app.isDataCollectionDefaultEnabled = false

    let options = FirebaseOptions(internalWithOptionsDictionary: [:])
    XCTAssertFalse(options.isAnalyticsCollectionEnabled)
    XCTAssertFalse(options.isMeasurementEnabled)
  }

  func testAnalyticsCollectionGlobalSwitchOverrideToDisable() throws {
    let app = try configureDefaultApp()
    app.isDataCollectionDefaultEnabled = true

    // The three Analytics flags that disable collection, whatever the default app's flag is.
    let disablingFlags: [[String: Any]] = [
      [AnalyticsKeys.collectionEnabled: false],
      [AnalyticsKeys.collectionDeactivated: true],
      [AnalyticsKeys.measurementEnabled: false],
    ]
    for flags in disablingFlags {
      let options = FirebaseOptions(internalWithOptionsDictionary: flags)
      XCTAssertFalse(options.isAnalyticsCollectionEnabled, "\(flags)")
    }
  }

  func testAnalyticsCollectionGlobalSwitchOverrideToEnable() throws {
    let app = try configureDefaultApp()
    app.isDataCollectionDefaultEnabled = false

    // The two Analytics flags that enable collection, whatever the default app's flag is.
    let enablingFlags: [[String: Any]] = [
      [AnalyticsKeys.collectionEnabled: true],
      [AnalyticsKeys.measurementEnabled: true],
    ]
    for flags in enablingFlags {
      let options = FirebaseOptions(internalWithOptionsDictionary: flags)
      XCTAssertTrue(options.isAnalyticsCollectionEnabled, "\(flags)")
    }
  }

  func testAnalyticsCollectionIsDisabledWithoutDefaultApp() throws {
    // Only the default app's flag counts.
    _ = try configureApp(named: "testAnalyticsNoDefaultApp")
    XCTAssertFalse(FirebaseApp.isDefaultAppConfigured())

    let options = FirebaseOptions(internalWithOptionsDictionary: [:])
    XCTAssertFalse(options.isAnalyticsCollectionEnabled)
    XCTAssertFalse(options.isMeasurementEnabled)
  }

  // MARK: - Helpers

  /// Runs `block` and returns the Analytics flags that FIRAnalyticsConfiguration posted, in order.
  private func recordAnalyticsFlags(during block: () -> Void) -> [Bool?] {
    let name = CoreContract.analyticsSetEnabledNotification
    let recorder = NotificationRecorder(name: name)
    block()
    recorder.stop()
    return recorder.records.map { ($0.userInfo[name] as? NSNumber)?.boolValue }
  }

  /// The Analytics flag that FIRAnalyticsConfiguration persisted, if any.
  private func persistedAnalyticsState() -> NSNumber? {
    UserDefaults.standard.object(forKey: CoreContract.analyticsPersistedEnabledStateKey)
      as? NSNumber
  }
}
