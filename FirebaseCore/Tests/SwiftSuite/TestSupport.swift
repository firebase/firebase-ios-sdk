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

/// Values used in the test GoogleService-Info.plist files.
enum TestValues {
  static let apiKey = "correct_api_key"
  static let bundleID = "com.google.FirebaseSDKTests"
  static let clientID = "correct_client_id"
  static let gcmSenderID = "correct_gcm_sender_id"
  static let projectID = "abc-xyz-123"
  static let googleAppID = "1:123:ios:123abc"
  static let databaseURL = "https://abc-xyz-123.firebaseio.com"
  static let storageBucket = "project-id-123.storage.firebase.com"

  /// The contents of a valid GoogleService-Info.plist.
  static var serviceInfo: [String: Any] {
    [
      "API_KEY": apiKey,
      "BUNDLE_ID": bundleID,
      "CLIENT_ID": clientID,
      "DATABASE_URL": databaseURL,
      "GCM_SENDER_ID": gcmSenderID,
      "GOOGLE_APP_ID": googleAppID,
      "PROJECT_ID": projectID,
      "STORAGE_BUCKET": storageBucket,
    ]
  }
}

/// Keys of the analytics flags in GoogleService-Info.plist and Info.plist. They're public values
/// that must never change.
enum AnalyticsKeys {
  static let measurementEnabled = "IS_MEASUREMENT_ENABLED"
  static let collectionEnabled = "FIREBASE_ANALYTICS_COLLECTION_ENABLED"
  static let collectionDeactivated = "FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED"
}

/// A temporary directory that FirebaseCore searches for GoogleService-Info.plist instead of the
/// app's bundles. This replaces mocking `FIRBundleUtil` with OCMock. Create it with
/// `XCTestCase.makeServiceInfoBundle()`, which removes it after the test.
final class TemporaryServiceInfoBundle {
  let directory: URL

  /// Creates an empty bundle directory.
  fileprivate init() throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FirebaseCoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  var plistURL: URL { directory.appendingPathComponent("GoogleService-Info.plist") }

  /// Writes `contents` as GoogleService-Info.plist.
  func writeServiceInfo(_ contents: [String: Any] = TestValues.serviceInfo) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: contents,
                                                  format: .xml,
                                                  options: 0)
    try data.write(to: plistURL)
  }

  /// Writes a GoogleService-Info.plist that isn't a valid property list.
  func writeInvalidServiceInfo() throws {
    try Data("not a property list".utf8).write(to: plistURL)
  }

  /// Makes FirebaseCore search only this directory for GoogleService-Info.plist.
  func install() throws {
    let bundle = try XCTUnwrap(Bundle(path: directory.path))
    CoreTestHooks.setRelevantBundles([bundle])
  }
}

/// A real bundle in a temporary directory, with an optional Info.plist and empty resource files.
/// This replaces mocking `NSBundle`. Create it with `XCTestCase.makeTemporaryBundle(...)`, which
/// removes it after the test.
final class TemporaryBundle {
  let directory: URL
  let bundle: Bundle

  /// Creates the bundle. `resources` are file names, such as "GoogleService-Info.plist".
  fileprivate init(bundleIdentifier: String?,
                   infoDictionary: [String: Any],
                   resources: [String]) throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("FirebaseCoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var info = infoDictionary
    info["CFBundleIdentifier"] = bundleIdentifier
    if !info.isEmpty {
      let data = try PropertyListSerialization.data(fromPropertyList: info,
                                                    format: .xml,
                                                    options: 0)
      try data.write(to: directory.appendingPathComponent("Info.plist"))
    }
    for resource in resources {
      try Data().write(to: directory.appendingPathComponent(resource))
    }
    // Bundles are cached by path, so the files must exist before the bundle is created.
    bundle = try XCTUnwrap(Bundle(path: directory.path))
  }

  /// The resolved path of a resource in the bundle.
  func resolvedPath(of resource: String) -> String {
    directory.appendingPathComponent(resource).resolvingSymlinksInPath().path
  }
}

extension XCTestCase {
  /// Creates a GoogleService-Info.plist directory that's removed after the test.
  func makeServiceInfoBundle() throws -> TemporaryServiceInfoBundle {
    let serviceInfoBundle = try TemporaryServiceInfoBundle()
    removeAfterTest(serviceInfoBundle.directory)
    return serviceInfoBundle
  }

  /// Creates a bundle that's removed after the test. `resources` are file names, such as
  /// "GoogleService-Info.plist".
  func makeTemporaryBundle(bundleIdentifier: String? = nil,
                           infoDictionary: [String: Any] = [:],
                           resources: [String] = []) throws -> TemporaryBundle {
    let temporaryBundle = try TemporaryBundle(bundleIdentifier: bundleIdentifier,
                                              infoDictionary: infoDictionary,
                                              resources: resources)
    removeAfterTest(temporaryBundle.directory)
    return temporaryBundle
  }

  /// Removes `directory` when the test ends. Tying the removal to the test rather than to a
  /// `deinit` keeps the files for the whole test: Swift can release a local variable right after
  /// its last use, which may come before FirebaseCore reads the files.
  private func removeAfterTest(_ directory: URL) {
    addTeardownBlock {
      try? FileManager.default.removeItem(at: directory)
    }
  }
}

/// Resolves symbolic links in `path`, such as /var -> /private/var on Apple platforms.
func resolvedPath(_ path: String?) -> String? {
  path.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
}

/// Names and keys that FirebaseCore shares with other code. They must never change.
enum CoreContract {
  static let defaultAppName = "__FIRAPP_DEFAULT"
  static let errorDomain = "com.firebase.core"

  static let appReadyToConfigureSDKNotification = "FIRAppReadyToConfigureSDKNotification"
  static let appDeleteNotification = "FIRAppDeleteNotification"
  static let appNameKey = "FIRAppNameKey"
  static let isDefaultAppKey = "FIRAppIsDefaultAppKey"
  static let googleAppIDKey = "FIRGoogleAppIDKey"

  /// The Info.plist key of the data collection flag.
  static let dataCollectionPlistKey = "FirebaseDataCollectionDefaultEnabled"
  /// The user defaults key of an app's data collection flag.
  static func dataCollectionDefaultsKey(appName: String) -> String {
    "/google/firebase/global_data_collection_enabled:\(appName)"
  }

  /// Posted by FIRAnalyticsConfiguration, and observed by GoogleAppMeasurement, when the analytics
  /// collection flag changes. The `userInfo` value for the same key is the new flag.
  static let analyticsSetEnabledNotification = "FIRAnalyticsConfigurationSetEnabledNotification"
  /// The user defaults key that FIRAnalyticsConfiguration persists the analytics flag in.
  static let analyticsPersistedEnabledStateKey = "/google/measurement/measurement_enabled_state"
}

/// Restores FirebaseCore's global state that the tests change.
func resetCoreTestState() {
  FirebaseApp.resetApps()
  CoreTestHooks.setRelevantBundles(nil)
  CoreTestHooks.setUserDefaults(nil)
  CoreTestHooks.setIsAppExtension(nil)
  CoreTestHooks.setInfoDictionary(nil)
  CoreTestHooks.setHeartbeatLogHandler(nil)
  FirebaseOptions.resetDefaultOptions()
}

/// Valid options for configuring an app.
func makeAppOptions(googleAppID: String = TestValues.googleAppID) -> FirebaseOptions {
  FirebaseOptions(googleAppID: googleAppID, gcmSenderID: TestValues.gcmSenderID)
}

/// User defaults that FirebaseCore uses instead of the standard user defaults: FirebaseApp for the
/// data collection flag, and FIRAnalyticsConfiguration for the persisted Analytics flag. This
/// replaces partial mocks of `NSUserDefaults`.
final class TemporaryUserDefaults {
  let suiteName = "com.google.firebase.CoreSwiftUnit-\(UUID().uuidString)"
  let userDefaults: UserDefaults

  init() throws {
    userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
  }

  /// Makes FirebaseCore use these user defaults.
  func install() {
    CoreTestHooks.setUserDefaults(userDefaults)
  }

  deinit {
    userDefaults.removePersistentDomain(forName: suiteName)
  }
}

/// Runs `block` and fails unless it raises an Objective-C exception in FirebaseCore's domain.
func assertRaisesCoreException(_ message: String = "",
                               file: StaticString = #filePath,
                               line: UInt = #line,
                               _ block: () -> Void) {
  let exception = CoreTestHooks.exceptionRaised(by: block)
  XCTAssertNotNil(exception, "No exception raised. \(message)", file: file, line: line)
  if let exception {
    XCTAssertEqual(exception.name.rawValue, CoreContract.errorDomain, message, file: file,
                   line: line)
  }
}

/// Runs `block` and fails if it raises an Objective-C exception.
func assertNoException(_ message: String = "",
                       file: StaticString = #filePath,
                       line: UInt = #line,
                       _ block: () -> Void) {
  let exception = CoreTestHooks.exceptionRaised(by: block)
  let reason = exception?.reason ?? ""
  XCTAssertNil(exception, "Unexpected exception: \(reason) \(message)", file: file, line: line)
}

/// Records the notifications with the given name that are posted while it's alive.
final class NotificationRecorder: @unchecked Sendable {
  struct Record {
    let object: AnyObject?
    let userInfo: NSDictionary
  }

  private let lock = NSLock()
  private var _records: [Record] = []
  private var observer: NSObjectProtocol?

  init(name: String) {
    observer = NotificationCenter.default.addObserver(
      forName: Notification.Name(name),
      object: nil,
      queue: nil
    ) { [weak self] notification in
      let record = Record(object: notification.object as AnyObject?,
                          userInfo: (notification.userInfo ?? [:]) as NSDictionary)
      self?.append(record)
    }
  }

  var records: [Record] {
    lock.lock()
    defer { lock.unlock() }
    return _records
  }

  private func append(_ record: Record) {
    lock.lock()
    defer { lock.unlock() }
    _records.append(record)
  }

  /// Stops recording.
  func stop() {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
  }

  deinit {
    stop()
  }
}

/// Records the heartbeats that apps log. Apps initialized while it's installed report to it.
final class HeartbeatLogRecorder: @unchecked Sendable {
  private let lock = NSLock()
  private var _appIDs: [String] = []

  /// The GOOGLE_APP_IDs of the apps that logged a heartbeat, in order.
  var appIDs: [String] {
    lock.lock()
    defer { lock.unlock() }
    return _appIDs
  }

  /// Makes apps initialized from now on report their heartbeats to this recorder.
  func install() {
    CoreTestHooks.setHeartbeatLogHandler { [weak self] appID in
      self?.record(appID)
    }
  }

  private func record(_ appID: String) {
    lock.lock()
    defer { lock.unlock() }
    _appIDs.append(appID)
  }
}

/// Base class for tests that configure apps. It resets FirebaseCore's global state around each
/// test, and makes FirebaseCore use temporary user defaults.
class CoreTestCase: XCTestCase {
  private var temporaryUserDefaults: TemporaryUserDefaults?

  /// The user defaults that FirebaseCore uses during the test.
  var userDefaults: UserDefaults {
    guard let temporaryUserDefaults else {
      preconditionFailure("userDefaults is only available while a test runs")
    }
    return temporaryUserDefaults.userDefaults
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    resetCoreTestState()
    // Never depend on the real environment: `+[GULAppEnvironmentUtil isAppExtension]` returns an
    // undefined value on visionOS. Tests of extension behavior set this to true.
    CoreTestHooks.setIsAppExtension(false)
    let temporaryUserDefaults = try TemporaryUserDefaults()
    temporaryUserDefaults.install()
    self.temporaryUserDefaults = temporaryUserDefaults
  }

  override func tearDown() {
    resetCoreTestState()
    temporaryUserDefaults = nil
    super.tearDown()
  }

  /// Configures the default app with valid options and returns it.
  func configureDefaultApp(options: FirebaseOptions = makeAppOptions(),
                           file: StaticString = #filePath,
                           line: UInt = #line) throws -> FirebaseApp {
    assertNoException(file: file, line: line) { FirebaseApp.configure(options: options) }
    return try XCTUnwrap(FirebaseApp.app(), file: file, line: line)
  }

  /// Configures an app with the given name and valid options and returns it.
  func configureApp(named name: String,
                    options: FirebaseOptions = makeAppOptions(),
                    file: StaticString = #filePath,
                    line: UInt = #line) throws -> FirebaseApp {
    assertNoException(file: file, line: line) {
      FirebaseApp.configure(name: name, options: options)
    }
    return try XCTUnwrap(FirebaseApp.app(name: name), file: file, line: line)
  }
}

/// Base class for tests that change the logger. It resets the logger to its state at launch around
/// each test, with temporary user defaults for the persisted debug mode and no launch arguments.
///
/// The reset seam only exists in DEBUG builds, so the tests are skipped in other builds.
class LoggerTestCase: XCTestCase {
  private var temporaryUserDefaults: TemporaryUserDefaults?

  /// The user defaults that the logger reads the persisted debug mode from during the test.
  var userDefaults: UserDefaults {
    guard let temporaryUserDefaults else {
      preconditionFailure("userDefaults is only available while a test runs")
    }
    return temporaryUserDefaults.userDefaults
  }

  override func setUpWithError() throws {
    try super.setUpWithError()
    let temporaryUserDefaults = try TemporaryUserDefaults()
    self.temporaryUserDefaults = temporaryUserDefaults
    try XCTSkipUnless(resetLogger(launchArguments: []),
                      "The logger reset seam only exists in DEBUG builds")
  }

  override func tearDown() {
    // Restore the standard user defaults and the process's launch arguments.
    CoreTestHooks.resetLogger(userDefaults: nil, launchArguments: nil)
    temporaryUserDefaults = nil
    super.tearDown()
  }

  /// Resets the logger, which initializes again on its next use with `launchArguments` and the
  /// test's user defaults. Returns false if the seam isn't available.
  @discardableResult
  func resetLogger(launchArguments: [String]) -> Bool {
    CoreTestHooks.resetLogger(userDefaults: temporaryUserDefaults?.userDefaults,
                              launchArguments: launchArguments)
  }
}
