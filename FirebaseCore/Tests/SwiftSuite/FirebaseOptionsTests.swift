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

/// Tests for `FirebaseOptions` that don't use OCMock, so they run unchanged against the
/// Objective-C and Swift implementations of FirebaseCore.
///
/// Ported from FirebaseCore/Tests/Unit/FIROptionsTest.m and
/// FirebaseCore/Tests/SwiftUnit/FirebaseOptionsTests.swift. The tests that depend on the default
/// app's data collection flag move to the FirebaseApp tests.
final class FirebaseOptionsTests: XCTestCase {
  override func setUp() {
    super.setUp()
    resetCoreTestState()
  }

  override func tearDown() {
    resetCoreTestState()
    super.tearDown()
  }

  // MARK: - Default options

  func testDefaultOptionsDictionaryReadsServiceInfo() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeServiceInfo()
    try bundle.install()

    let dictionary = try XCTUnwrap(FirebaseOptions.defaultOptionsDictionary())
    XCTAssertEqual(dictionary as NSDictionary, TestValues.serviceInfo as NSDictionary)

    let options = FirebaseOptions(internalWithOptionsDictionary: dictionary)
    assertOptionsMatchDefaults(options)
    XCTAssertTrue(options.usingOptionsFromDefaultPlist)
  }

  func testDefaultOptionsDictionaryWithMissingFile() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.install()

    XCTAssertNil(FirebaseOptions.defaultOptionsDictionary())
    XCTAssertNil(FirebaseOptions.defaultOptions())
  }

  func testDefaultOptionsDictionaryWithInvalidFile() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeInvalidServiceInfo()
    try bundle.install()

    XCTAssertNil(FirebaseOptions.defaultOptionsDictionary())
    XCTAssertNil(FirebaseOptions.defaultOptions())
  }

  func testDefaultOptions() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeServiceInfo()
    try bundle.install()

    let options = try XCTUnwrap(FirebaseOptions.defaultOptions())
    assertOptionsMatchDefaults(options)
    XCTAssertTrue(options.usingOptionsFromDefaultPlist)
  }

  func testDefaultOptionsAreReadOnce() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeServiceInfo()
    try bundle.install()
    let first = try XCTUnwrap(FirebaseOptions.defaultOptions())

    // Changing the file after the first read has no effect until the options are reset.
    var changed = TestValues.serviceInfo
    changed["PROJECT_ID"] = "changed-project"
    try bundle.writeServiceInfo(changed)

    let second = try XCTUnwrap(FirebaseOptions.defaultOptions())
    XCTAssertTrue(first === second)
    XCTAssertEqual(second.projectID, TestValues.projectID)
  }

  func testDefaultOptionsDictionaryIsReadOnce() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeServiceInfo()
    try bundle.install()
    XCTAssertNotNil(FirebaseOptions.defaultOptionsDictionary())

    try FileManager.default.removeItem(at: bundle.plistURL)
    XCTAssertNotNil(FirebaseOptions.defaultOptionsDictionary())
  }

  func testResetDefaultOptionsRereadsTheFile() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeServiceInfo()
    try bundle.install()
    XCTAssertEqual(FirebaseOptions.defaultOptions()?.projectID, TestValues.projectID)

    var changed = TestValues.serviceInfo
    changed["PROJECT_ID"] = "changed-project"
    let otherBundle = try makeServiceInfoBundle()
    try otherBundle.writeServiceInfo(changed)
    try otherBundle.install()
    FirebaseOptions.resetDefaultOptions()

    XCTAssertEqual(FirebaseOptions.defaultOptions()?.projectID, "changed-project")
  }

  func testDefaultOptionsAreEqual() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeServiceInfo()
    try bundle.install()

    let options1 = try XCTUnwrap(FirebaseOptions.defaultOptions())
    let options2 = try XCTUnwrap(options1.copy() as? FirebaseOptions)
    XCTAssertEqual(options1.hash, options2.hash)
    XCTAssertTrue(options1.isEqual(options2))

    let plainOptions = FirebaseOptions(googleAppID: TestValues.googleAppID,
                                       gcmSenderID: TestValues.gcmSenderID)
    XCTAssertFalse(plainOptions.isEqual(options1))
  }

  // MARK: - Initializers

  func testInitWithContentsOfFile() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeServiceInfo()

    let options = try XCTUnwrap(FirebaseOptions(contentsOfFile: bundle.plistURL.path))
    assertOptionsMatchDefaults(options)
    XCTAssertFalse(options.usingOptionsFromDefaultPlist)
  }

  func testInitWithContentsOfMissingFile() {
    XCTAssertNil(FirebaseOptions(contentsOfFile: "path/to/non-existing/plist"))
  }

  func testInitWithContentsOfInvalidFile() throws {
    let bundle = try makeServiceInfoBundle()
    try bundle.writeInvalidServiceInfo()
    XCTAssertNil(FirebaseOptions(contentsOfFile: bundle.plistURL.path))
  }

  func testInitCustomizedOptions() {
    let options = FirebaseOptions(googleAppID: TestValues.googleAppID,
                                  gcmSenderID: TestValues.gcmSenderID)
    options.apiKey = TestValues.apiKey
    options.bundleID = TestValues.bundleID
    options.clientID = TestValues.clientID
    options.databaseURL = TestValues.databaseURL
    options.projectID = TestValues.projectID
    options.storageBucket = TestValues.storageBucket
    assertOptionsMatchDefaults(options)
    XCTAssertFalse(options.usingOptionsFromDefaultPlist)
  }

  func testInitWithRequiredFieldsLeavesOptionalFieldsEmpty() throws {
    let options = FirebaseOptions(googleAppID: "5:678:ios:678def",
                                  gcmSenderID: "custom_gcm_sender_id")
    XCTAssertEqual(options.googleAppID, "5:678:ios:678def")
    XCTAssertEqual(options.gcmSenderID, "custom_gcm_sender_id")
    XCTAssertNil(options.apiKey)
    XCTAssertNil(options.clientID)
    XCTAssertNil(options.projectID)
    XCTAssertNil(options.databaseURL)
    XCTAssertNil(options.storageBucket)
    XCTAssertNil(options.appGroupID)

    // The bundle ID defaults to the main bundle's identifier.
    let mainBundleID = try XCTUnwrap(Bundle.main.bundleIdentifier,
                                     "The test host has no bundle identifier")
    XCTAssertEqual(options.bundleID, mainBundleID)
  }

  // MARK: - Properties and copying

  func testEditingOptions() {
    let options = FirebaseOptions(googleAppID: TestValues.googleAppID,
                                  gcmSenderID: TestValues.gcmSenderID)
    options.gcmSenderID = "newgcmSenderID"
    XCTAssertEqual(options.gcmSenderID, "newgcmSenderID")
    options.googleAppID = "newGoogleAppID"
    XCTAssertEqual(options.googleAppID, "newGoogleAppID")
    XCTAssertNil(options.appGroupID)
    options.appGroupID = "group.com.example"
    XCTAssertEqual(options.appGroupID, "group.com.example")
  }

  func testPropertiesCopyTheirValues() {
    let options = FirebaseOptions(googleAppID: TestValues.googleAppID,
                                  gcmSenderID: TestValues.gcmSenderID)
    // Bridging an NSMutableString to String copies it, so assigning through the Swift setters
    // can't tell `copy` from `strong`. Key-value coding passes the mutable string to the
    // Objective-C setter as is.
    let properties: [(String, () -> String?)] = [
      ("APIKey", { options.apiKey }),
      ("bundleID", { options.bundleID }),
      ("clientID", { options.clientID }),
      ("GCMSenderID", { options.gcmSenderID }),
      ("projectID", { options.projectID }),
      ("googleAppID", { options.googleAppID }),
      ("databaseURL", { options.databaseURL }),
      ("storageBucket", { options.storageBucket }),
      ("appGroupID", { options.appGroupID }),
    ]
    for (key, get) in properties {
      let value = NSMutableString(string: "1")
      options.setValue(value, forKey: key)
      value.append("2")
      XCTAssertEqual(get(), "1", key)
    }
  }

  func testCopy() throws {
    let options = FirebaseOptions(googleAppID: TestValues.googleAppID,
                                  gcmSenderID: TestValues.gcmSenderID)
    options.apiKey = TestValues.apiKey
    options.projectID = TestValues.projectID
    // The app group ID isn't stored in the options dictionary, so it's copied separately.
    options.appGroupID = "customAppGroupID"

    let copied = try XCTUnwrap(options.copy() as? FirebaseOptions)
    XCTAssertEqual(copied.googleAppID, options.googleAppID)
    XCTAssertEqual(copied.gcmSenderID, options.gcmSenderID)
    XCTAssertEqual(copied.apiKey, options.apiKey)
    XCTAssertEqual(copied.projectID, options.projectID)
    XCTAssertEqual(copied.appGroupID, "customAppGroupID")
    XCTAssertTrue(copied.isEqual(options))

    // The copy is independent of the original.
    options.apiKey = "newApiKey"
    options.appGroupID = "newAppGroupID"
    XCTAssertEqual(copied.apiKey, TestValues.apiKey)
    XCTAssertEqual(copied.appGroupID, "customAppGroupID")
    XCTAssertFalse(copied.isEqual(options))
  }

  func testCopyKeepsEditingLock() throws {
    let options = FirebaseOptions(googleAppID: TestValues.googleAppID,
                                  gcmSenderID: TestValues.gcmSenderID)
    options.isEditingLocked = true
    let copied = try XCTUnwrap(options.copy() as? FirebaseOptions)
    XCTAssertTrue(copied.isEditingLocked)
  }

  func testModifyingLockedOptionsRaises() {
    let options = FirebaseOptions(googleAppID: TestValues.googleAppID,
                                  gcmSenderID: TestValues.gcmSenderID)
    options.isEditingLocked = true

    let setters: [(String, () -> Void)] = [
      ("apiKey", { options.apiKey = "should_throw" }),
      ("bundleID", { options.bundleID = "should_throw" }),
      ("clientID", { options.clientID = "should_throw" }),
      ("databaseURL", { options.databaseURL = "should_throw" }),
      ("gcmSenderID", { options.gcmSenderID = "should_throw" }),
      ("googleAppID", { options.googleAppID = "should_throw" }),
      ("projectID", { options.projectID = "should_throw" }),
      ("storageBucket", { options.storageBucket = "should_throw" }),
      ("appGroupID", { options.appGroupID = "should_throw" }),
    ]
    for (name, set) in setters {
      let exception = CoreTestHooks.exceptionRaised(by: set)
      XCTAssertEqual(exception?.name.rawValue, "com.firebase.core", name)
    }
    XCTAssertEqual(options.googleAppID, TestValues.googleAppID)
  }

  // MARK: - Analytics flags

  func testAnalyticsKeys() {
    // These keys are public values and must never change. Changing them here means the
    // implementation reads different keys than apps set.
    let options = FirebaseOptions(internalWithOptionsDictionary: [
      AnalyticsKeys.collectionEnabled: false,
    ])
    XCTAssertTrue(options.isAnalyticsCollectionExplicitlySet)
    XCTAssertFalse(options.isAnalyticsCollectionEnabled)
    XCTAssertTrue(FirebaseOptions(internalWithOptionsDictionary: [
      AnalyticsKeys.collectionDeactivated: true,
    ]).isAnalyticsCollectionDeactivated)
    XCTAssertFalse(FirebaseOptions(internalWithOptionsDictionary: [
      AnalyticsKeys.measurementEnabled: false,
    ]).isMeasurementEnabled)
  }

  func testAnalyticsOptions() {
    let all: [String: Any] = [
      AnalyticsKeys.collectionDeactivated: true,
      AnalyticsKeys.collectionEnabled: true,
      AnalyticsKeys.measurementEnabled: true,
    ]
    let allOff: [String: Any] = [
      AnalyticsKeys.collectionDeactivated: false,
      AnalyticsKeys.collectionEnabled: false,
      AnalyticsKeys.measurementEnabled: false,
    ]
    // (options dictionary, Info.plist dictionary, expected analytics options)
    let cases: [(String, [String: Any]?, [String: Any]?, [String: Any])] = [
      ("no keys anywhere", nil, nil, [:]),
      ("empty dictionaries", [:], [:], [:]),
      ("Info.plist has no keys", all, [:], all),
      ("Info.plist overrides all keys", all, allOff, allOff),
      ("keys only in Info.plist", [:], all, all),
      (
        "Info.plist overrides deactivated",
        all,
        [AnalyticsKeys.collectionDeactivated: false],
        all.merging([AnalyticsKeys.collectionDeactivated: false]) { $1 }
      ),
      (
        "Info.plist overrides collection enabled",
        all,
        [AnalyticsKeys.collectionEnabled: false],
        all.merging([AnalyticsKeys.collectionEnabled: false]) { $1 }
      ),
      (
        "Info.plist overrides measurement enabled",
        all,
        [AnalyticsKeys.measurementEnabled: false],
        all.merging([AnalyticsKeys.measurementEnabled: false]) { $1 }
      ),
    ]
    for (name, optionsDictionary, infoDictionary, expected) in cases {
      let options = FirebaseOptions(internalWithOptionsDictionary: optionsDictionary)
      let analyticsOptions = options.analyticsOptionsDictionary(withInfoDictionary: infoDictionary)
      XCTAssertEqual(analyticsOptions as NSDictionary, expected as NSDictionary, name)
    }
  }

  func testAnalyticsOptionsCombinations() {
    // Every combination of the three flags being absent, false or true, in both the options
    // dictionary and Info.plist. Values in Info.plist override the options dictionary.
    let keys = [
      AnalyticsKeys.collectionDeactivated,
      AnalyticsKeys.collectionEnabled,
      AnalyticsKeys.measurementEnabled,
    ]
    let values: [Bool?] = [nil, false, true]
    func dictionaries() -> [[String: Any]] {
      var result: [[String: Any]] = [[:]]
      for key in keys {
        result = result.flatMap { partial in
          values.map { value -> [String: Any] in
            var dictionary = partial
            if let value { dictionary[key] = value }
            return dictionary
          }
        }
      }
      return result
    }
    let combinations = dictionaries()
    XCTAssertEqual(combinations.count, 27)

    var count = 0
    for optionsDictionary in combinations {
      for infoDictionary in combinations {
        let options = FirebaseOptions(internalWithOptionsDictionary: optionsDictionary)
        let expected = optionsDictionary.merging(infoDictionary) { $1 }
        XCTAssertEqual(
          options.analyticsOptionsDictionary(withInfoDictionary: infoDictionary) as NSDictionary,
          expected as NSDictionary
        )
        count += 1
      }
    }
    XCTAssertEqual(count, 729)
  }

  func testAnalyticsCollectionExplicitlySet() {
    func explicitlySet(_ optionsDictionary: [String: Any],
                       info infoDictionary: [String: Any] = [:]) -> Bool {
      let options = FirebaseOptions(internalWithOptionsDictionary: optionsDictionary)
      // The analytics options are computed, and then cached, on first use.
      _ = options.analyticsOptionsDictionary(withInfoDictionary: infoDictionary)
      return options.isAnalyticsCollectionExplicitlySet
    }

    XCTAssertFalse(explicitlySet([:]))
    XCTAssertTrue(explicitlySet([AnalyticsKeys.collectionDeactivated: true]))
    // Deactivated == false doesn't explicitly set (or enable) collection.
    XCTAssertFalse(explicitlySet([AnalyticsKeys.collectionDeactivated: false]))
    XCTAssertTrue(explicitlySet([AnalyticsKeys.collectionEnabled: true]))
    XCTAssertTrue(explicitlySet([AnalyticsKeys.collectionEnabled: false]))
    XCTAssertTrue(explicitlySet([:], info: [AnalyticsKeys.measurementEnabled: true]))
    XCTAssertTrue(explicitlySet([:], info: [AnalyticsKeys.measurementEnabled: false]))
    XCTAssertTrue(explicitlySet(
      [AnalyticsKeys.collectionDeactivated: true, AnalyticsKeys.collectionEnabled: true],
      info: [AnalyticsKeys.measurementEnabled: false]
    ))
  }

  // MARK: - Library version

  func testLibraryVersionIDFormat() throws {
    let options = FirebaseOptions(googleAppID: TestValues.googleAppID,
                                  gcmSenderID: TestValues.gcmSenderID)
    let versionID = options.libraryVersionID
    // Stop here if the format is wrong, since the index math below assumes at least six digits.
    _ = try XCTUnwrap(versionID.range(of: "^[0-9]{8,}$", options: .regularExpression),
                      "Unexpected library version ID format: \(versionID)")

    // The first six digits are the major, minor and patch versions, two digits each.
    func number(_ offset: Int) throws -> Int {
      let start = versionID.index(versionID.startIndex, offsetBy: offset)
      let end = versionID.index(start, offsetBy: 2)
      return try XCTUnwrap(Int(versionID[start ..< end]))
    }
    let version = try "\(number(0)).\(number(2)).\(number(4))"
    XCTAssertTrue(FirebaseVersion().hasPrefix(version),
                  "\(version) doesn't match FirebaseVersion() \(FirebaseVersion())")
  }

  // MARK: - Helpers

  private func assertOptionsMatchDefaults(_ options: FirebaseOptions,
                                          file: StaticString = #filePath,
                                          line: UInt = #line) {
    XCTAssertEqual(options.googleAppID, TestValues.googleAppID, file: file, line: line)
    XCTAssertEqual(options.apiKey, TestValues.apiKey, file: file, line: line)
    XCTAssertEqual(options.clientID, TestValues.clientID, file: file, line: line)
    XCTAssertEqual(options.gcmSenderID, TestValues.gcmSenderID, file: file, line: line)
    XCTAssertEqual(options.databaseURL, TestValues.databaseURL, file: file, line: line)
    XCTAssertEqual(options.storageBucket, TestValues.storageBucket, file: file, line: line)
    XCTAssertEqual(options.bundleID, TestValues.bundleID, file: file, line: line)
    XCTAssertEqual(options.projectID, TestValues.projectID, file: file, line: line)
    XCTAssertNil(options.appGroupID, file: file, line: line)
  }
}
