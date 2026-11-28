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
import FirebaseCoreTestHooks
import Foundation
import XCTest

/// Tests for FIRAnalyticsConfiguration, which forwards the Analytics collection flag to
/// GoogleAppMeasurement. They don't use OCMock, so they run unchanged against the Objective-C and
/// Swift implementations of FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIRAnalyticsConfigurationTest.m. Instead of partially
/// mocking `NSUserDefaults`, the persisted flag is stored in temporary user defaults (see
/// `CoreTestCase`), and the tests check the stored values and the notification.
final class AnalyticsConfigurationTests: CoreTestCase {
  /// Values of FIRAnalyticsEnabledState. GoogleAppMeasurement reads them, so they never change.
  private let enabledStateSetYes: Int64 = 1
  private let enabledStateSetNo: Int64 = 2

  func testSharedInstance() {
    let configuration = FIRAnalyticsConfiguration.sharedInstance()
    XCTAssertTrue(configuration === FIRAnalyticsConfiguration.sharedInstance())
  }

  func testPersistedSettingIsStoredInUserDefaults() {
    let configuration = FIRAnalyticsConfiguration.sharedInstance()
    let standardValue = standardUserDefaultsValue()

    configuration.setAnalyticsCollectionEnabled(true, persistSetting: true)
    XCTAssertEqual(persistedState(), enabledStateSetYes)

    configuration.setAnalyticsCollectionEnabled(false, persistSetting: true)
    XCTAssertEqual(persistedState(), enabledStateSetNo)

    // The test seam kept the standard user defaults untouched.
    XCTAssertEqual(standardUserDefaultsValue(), standardValue)
  }

  func testSettingThatIsNotPersistedLeavesUserDefaultsUnchanged() {
    let configuration = FIRAnalyticsConfiguration.sharedInstance()

    configuration.setAnalyticsCollectionEnabled(true, persistSetting: false)
    configuration.setAnalyticsCollectionEnabled(false, persistSetting: false)
    XCTAssertNil(userDefaults.object(forKey: CoreContract.analyticsPersistedEnabledStateKey))

    // A persisted value isn't overwritten either.
    configuration.setAnalyticsCollectionEnabled(false, persistSetting: true)
    configuration.setAnalyticsCollectionEnabled(true, persistSetting: false)
    XCTAssertEqual(persistedState(), enabledStateSetNo)
  }

  func testSettingPostsNotification() {
    let configuration = FIRAnalyticsConfiguration.sharedInstance()
    let name = CoreContract.analyticsSetEnabledNotification
    let recorder = NotificationRecorder(name: name)

    // The notification is posted whether or not the setting is persisted.
    configuration.setAnalyticsCollectionEnabled(true, persistSetting: true)
    configuration.setAnalyticsCollectionEnabled(false, persistSetting: true)
    configuration.setAnalyticsCollectionEnabled(true, persistSetting: false)
    configuration.setAnalyticsCollectionEnabled(false, persistSetting: false)
    recorder.stop()

    let records = recorder.records
    XCTAssertEqual(records.map { ($0.userInfo[name] as? NSNumber)?.boolValue },
                   [true, false, true, false])
    for record in records {
      XCTAssertTrue(record.object === configuration)
      XCTAssertEqual(record.userInfo.allKeys as? [String], [name])
    }
  }

  // MARK: - Helpers

  /// The FIRAnalyticsEnabledState persisted in the test's user defaults.
  private func persistedState() -> Int64? {
    (userDefaults.object(forKey: CoreContract.analyticsPersistedEnabledStateKey) as? NSNumber)?
      .int64Value
  }

  private func standardUserDefaultsValue() -> NSNumber? {
    UserDefaults.standard.object(forKey: CoreContract.analyticsPersistedEnabledStateKey)
      as? NSNumber
  }
}
