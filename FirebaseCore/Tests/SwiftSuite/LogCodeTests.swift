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

/// Characterization tests for the `I-COR` message codes that FirebaseCore logs. Developers and
/// support search for these codes, so a Swift implementation must log the same codes, at the same
/// levels, in the same situations.
///
/// `scenarios` is the inventory: one entry for each code in FirebaseCore/Sources, with how to
/// trigger it and what the message must say. `testInventoryMatchesSources` checks that the
/// inventory and the sources agree. The messages are captured through a DEBUG-only log handler
/// seam, so the tests are skipped in other builds. The data collection messages (I-COR000031 to
/// I-COR000034) are only logged in DEBUG builds anyway.
///
/// I-COR000023, "Invalid logger level", is logged by GoogleUtilities' logger, not by FirebaseCore,
/// so it isn't in the inventory.
final class LogCodeTests: CoreTestCase {
  let recorder = LogRecorder()

  override func setUpWithError() throws {
    try super.setUpWithError()
    try XCTSkipUnless(CoreTestHooks.resetLogger(userDefaults: userDefaults, launchArguments: []),
                      "The logger seams only exist in DEBUG builds")
    // Debug messages are only delivered when the level allows them.
    FirebaseConfiguration.shared.setLoggerLevel(.debug)
    try XCTSkipUnless(recorder.install(), "The logger seams only exist in DEBUG builds")
  }

  override func tearDown() {
    recorder.uninstall()
    CoreTestHooks.resetLogger(userDefaults: nil, launchArguments: nil)
    super.tearDown()
  }

  // MARK: - The inventory

  /// How to trigger a message code, and what FirebaseCore logs.
  struct Scenario {
    let code: String
    let level: FirebaseLoggerLevel
    /// Parts of the message that must appear.
    let fragments: [String]
    /// Triggers the message. It may call `recorder.clear()` after setting up, so only the
    /// messages of the action itself are checked.
    let trigger: (LogCodeTests) throws -> Void
  }

  private var scenarios: [Scenario] {
    [
      Scenario(code: "I-COR000001", level: .debug,
               fragments: ["Configuring the default app."]) { test in
        _ = try test.configureDefaultApp()
      },
      Scenario(code: "I-COR000002", level: .debug,
               fragments: ["Configuring app named testLogNamedApp"]) { test in
        _ = try test.configureApp(named: "testLogNamedApp")
      },
      Scenario(code: "I-COR000003", level: .error,
               fragments: ["The default Firebase app has not yet been configured.",
                           "FirebaseApp.configure()"]) { _ in
        XCTAssertNil(FirebaseApp.app())
      },
      Scenario(code: "I-COR000004", level: .error,
               fragments: ["App with name missingApp does not exist."]) { _ in
        XCTAssertNil(FirebaseApp.app(name: "missingApp"))
      },
      Scenario(code: "I-COR000005", level: .error,
               fragments: ["No app has been configured yet."]) { _ in
        XCTAssertNil(FirebaseApp.allApps)
      },
      Scenario(code: "I-COR000006", level: .debug,
               fragments: ["Deleting app named testLogDeletedApp"]) { test in
        let app = try test.configureApp(named: "testLogDeletedApp")
        test.recorder.clear()
        test.delete(app, expectingSuccess: true)
      },
      Scenario(code: "I-COR000007", level: .error, fragments: ["App does not exist."]) { test in
        let app = try test.configureApp(named: "testLogDeletedTwice")
        test.delete(app, expectingSuccess: true)
        test.recorder.clear()
        test.delete(app, expectingSuccess: false)
      },
      Scenario(code: "I-COR000008", level: .error,
               fragments: ["The project's Bundle ID is inconsistent",
                           "'GoogleService-Info.plist'",
                           "'com.example.mismatch'"]) { test in
        let options = makeAppOptions()
        options.bundleID = "com.example.mismatch"
        _ = try test.configureApp(named: "testLogBundleIDMismatch", options: options)
      },
      Scenario(code: "I-COR000009", level: .error,
               fragments: ["The GOOGLE_APP_ID either in the plist file 'GoogleService-Info.plist'",
                           "is invalid"]) { _ in
        assertRaisesCoreException {
          FirebaseApp.configure(name: "testLogInvalidAppID",
                                options: makeAppOptions(googleAppID: "1:1337:android:deadbeef"))
        }
      },
      Scenario(code: "I-COR000010", level: .info,
               fragments: ["Unknown GOOGLE_APP_ID version: 2"]) { _ in
        XCTAssertTrue(FirebaseApp.validateAppID("2:1337:ios:deadbeef"))
      },
      Scenario(code: "I-COR000011", level: .error,
               fragments: ["The configuration file is not a dictionary: " +
                 "'GoogleService-Info.plist'."]) { test in
        let bundle = try test.makeServiceInfoBundle()
        try bundle.writeInvalidServiceInfo()
        try bundle.install()
        XCTAssertNil(FirebaseOptions.defaultOptionsDictionary())
      },
      Scenario(code: "I-COR000012", level: .error,
               fragments: ["Could not locate configuration file: " +
                 "'GoogleService-Info.plist'."]) { test in
        try test.makeServiceInfoBundle().install()
        XCTAssertNil(FirebaseOptions.defaultOptionsDictionary())
      },
      Scenario(code: "I-COR000013", level: .error,
               fragments: ["The plist file path is nil."]) { _ in
        XCTAssertNil(CoreTestHooks.options(withContentsOfNullableFile: nil))
      },
      Scenario(code: "I-COR000014", level: .error,
               fragments: ["does not exist or is not a well-formed plist file."]) { test in
        let bundle = try test.makeServiceInfoBundle()
        try bundle.writeInvalidServiceInfo()
        XCTAssertNil(FirebaseOptions(contentsOfFile: bundle.plistURL.path))
      },
      Scenario(code: "I-COR000027", level: .error,
               fragments: ["The library name (Oops>) or version number (1.0) contain invalid " +
                 "characters."]) { _ in
        FirebaseApp.registerLibrary("Oops>", withVersion: "1.0")
      },
      Scenario(code: "I-COR000029", level: .error,
               fragments: ["Attempted to register protocol " +
                 NSStringFromProtocol(CoreTestUncachedComponent.self),
                 "but it already has an implementation."]) { test in
        test.hostApp = test.makeApp(registrants: [CoreTestUncachedLibrary.self,
                                                  CoreTestDuplicateLibrary.self])
      },
      Scenario(code: "I-COR000030", level: .error,
               fragments: ["An instance conforming to " +
                 NSStringFromProtocol(CoreTestMisimplementedComponent.self) +
                 " was requested, but the instance provided does not conform to the " +
                 "protocol"]) { test in
        let app = test.makeApp(registrants: [CoreTestMisimplementedLibrary.self])
        test.hostApp = app
        XCTAssertNotNil(app.container.instance(for: CoreTestMisimplementedComponent.self))
      },
      Scenario(code: "I-COR000031", level: .debug,
               fragments: ["Data Collection flag is disabled in user defaults."]) { test in
        let app = FirebaseApp(instanceWithName: "testLogDefaults", options: makeAppOptions())
        test.userDefaults.set(false, forKey: CoreContract.dataCollectionDefaultsKey(
          appName: "testLogDefaults"
        ))
        XCTAssertFalse(app.isDataCollectionDefaultEnabled)
        // It's only logged the first time.
        XCTAssertFalse(app.isDataCollectionDefaultEnabled)
      },
      Scenario(code: "I-COR000032", level: .debug,
               fragments: ["Data Collection flag is disabled in plist."]) { _ in
        CoreTestHooks.setInfoDictionary([CoreContract.dataCollectionPlistKey: false])
        let app = FirebaseApp(instanceWithName: "testLogPlist", options: makeAppOptions())
        XCTAssertFalse(app.isDataCollectionDefaultEnabled)
        XCTAssertFalse(app.isDataCollectionDefaultEnabled)
      },
      Scenario(code: "I-COR000033", level: .debug,
               fragments: ["Data Collection flag is not set."]) { _ in
        CoreTestHooks.setInfoDictionary([:])
        let app = FirebaseApp(instanceWithName: "testLogNotSet", options: makeAppOptions())
        XCTAssertTrue(app.isDataCollectionDefaultEnabled)
        XCTAssertTrue(app.isDataCollectionDefaultEnabled)
      },
      Scenario(code: "I-COR000034", level: .debug,
               fragments: ["Explicitly disabled data collection flag."]) { _ in
        let app = FirebaseApp(instanceWithName: "testLogExplicit", options: makeAppOptions())
        app.isDataCollectionDefaultEnabled = false
      },
      Scenario(code: "I-COR000035", level: .debug,
               fragments: ["Ignoring second `configure` call in an extension."]) { test in
        CoreTestHooks.setIsAppExtension(true)
        let options = makeAppOptions()
        _ = try test.configureDefaultApp(options: options)
        test.recorder.clear()
        assertNoException { FirebaseApp.configure(options: options) }
      },
    ]
  }

  // MARK: - The inventory contract

  func testInventoryIsUniqueAndWellFormed() {
    let codes = scenarios.map(\.code)
    XCTAssertEqual(Set(codes).count, codes.count, "Duplicate codes in the inventory")
    for code in codes {
      XCTAssertNotNil(code.range(of: "^I-COR[0-9]{6}$", options: .regularExpression), code)
    }
    XCTAssertEqual(codes, codes.sorted())
  }

  func testInventoryMatchesSources() throws {
    // FirebaseCore/Tests/SwiftSuite/LogCodeTests.swift -> FirebaseCore/Sources.
    let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .appendingPathComponent("../../Sources").standardizedFileURL
    try XCTSkipUnless(FileManager.default.fileExists(atPath: sources.path),
                      "The FirebaseCore sources aren't available at \(sources.path)")

    var callSites: [String: Int] = [:]
    let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: sources,
                                                                  includingPropertiesForKeys: nil))
    for case let file as URL in enumerator
      where ["m", "mm", "c", "h", "swift"].contains(file.pathExtension) {
      let contents = try String(contentsOf: file, encoding: .utf8)
      for line in contents.components(separatedBy: .newlines) {
        // Skip comments, which show example calls.
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("*") || trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") {
          continue
        }
        for code in matches(of: "\"I-COR[0-9]{6}\"", in: line) {
          callSites[code.trimmingCharacters(in: CharacterSet(charactersIn: "\"")), default: 0] += 1
        }
      }
    }

    XCTAssertEqual(Set(callSites.keys), Set(scenarios.map(\.code)),
                   "The inventory doesn't match the codes in FirebaseCore/Sources")
    for (code, count) in callSites.sorted(by: { $0.key < $1.key }) {
      XCTAssertEqual(count, 1, "\(code) is logged in \(count) places")
    }
  }

  // MARK: - One test per code

  func testCOR000001ConfiguringTheDefaultApp() throws { try run("I-COR000001") }
  func testCOR000002ConfiguringANamedApp() throws { try run("I-COR000002") }
  func testCOR000003DefaultAppNotConfigured() throws { try run("I-COR000003") }
  func testCOR000004AppNamedDoesNotExist() throws { try run("I-COR000004") }
  func testCOR000005NoAppConfigured() throws { try run("I-COR000005") }
  func testCOR000006DeletingAnApp() throws { try run("I-COR000006") }
  func testCOR000007DeletingAnAppThatDoesNotExist() throws { try run("I-COR000007") }
  func testCOR000008BundleIDMismatch() throws { try run("I-COR000008") }
  func testCOR000009InvalidAppID() throws { try run("I-COR000009") }
  func testCOR000010UnknownAppIDVersion() throws { try run("I-COR000010") }
  func testCOR000011ServiceInfoIsNotADictionary() throws { try run("I-COR000011") }
  func testCOR000012ServiceInfoIsMissing() throws { try run("I-COR000012") }
  func testCOR000013NilPlistPath() throws { try run("I-COR000013") }
  func testCOR000014MalformedPlistFile() throws { try run("I-COR000014") }
  func testCOR000027InvalidLibraryName() throws { try run("I-COR000027") }
  func testCOR000029DuplicateComponent() throws { try run("I-COR000029") }
  func testCOR000030NonConformingInstance() throws { try run("I-COR000030") }
  func testCOR000031DataCollectionFlagInUserDefaults() throws { try run("I-COR000031") }
  func testCOR000032DataCollectionFlagInPlist() throws { try run("I-COR000032") }
  func testCOR000033DataCollectionFlagNotSet() throws { try run("I-COR000033") }
  func testCOR000034DataCollectionFlagSet() throws { try run("I-COR000034") }
  func testCOR000035DuplicateConfigureInExtension() throws { try run("I-COR000035") }

  func testEveryScenarioHasATest() {
    let testNames = Set(Self.defaultTestSuite.tests.map(\.name))
    for scenario in scenarios {
      let number = scenario.code.dropFirst("I-".count)
      XCTAssertTrue(testNames.contains { $0.contains("test\(number)") },
                    "No test runs \(scenario.code)")
    }
  }

  // MARK: - Related behavior

  func testDebugMessagesAreFilteredByLevel() throws {
    FirebaseConfiguration.shared.setLoggerLevel(.notice)
    _ = try configureApp(named: "testLogFiltered")
    XCTAssertEqual(recorder.records(withCode: "I-COR000002").count, 0)

    XCTAssertNil(FirebaseApp.app(name: "missingApp"))
    XCTAssertEqual(recorder.records(withCode: "I-COR000004").count, 1)
  }

  func testNoBundleIDMessageWhenBundleIDMatches() throws {
    _ = try configureApp(named: "testLogBundleIDMatches")
    XCTAssertEqual(recorder.records(withCode: "I-COR000008").count, 0)
  }

  func testDataCollectionMessagesAreLoggedOncePerApp() {
    CoreTestHooks.setInfoDictionary([:])
    let app = FirebaseApp(instanceWithName: "testLogOnce", options: makeAppOptions())
    app.isDataCollectionDefaultEnabled = true
    // After the flag is set explicitly, reading it doesn't log where it came from.
    XCTAssertTrue(app.isDataCollectionDefaultEnabled)
    XCTAssertEqual(recorder.records(withCode: "I-COR000034").count, 1)
    XCTAssertEqual(recorder.records(withCode: "I-COR000031").count, 0)
    XCTAssertEqual(recorder.records(withCode: "I-COR000033").count, 0)
  }

  // MARK: - Helpers

  /// Keeps an app with a test container alive while the test runs.
  var hostApp: FirebaseApp?

  private func run(_ code: String, file: StaticString = #filePath, line: UInt = #line) throws {
    let scenario = try XCTUnwrap(scenarios.first { $0.code == code }, "No scenario for \(code)",
                                 file: file, line: line)
    recorder.clear()
    try scenario.trigger(self)

    let records = recorder.records(withCode: code)
    XCTAssertEqual(records.count, 1, "Expected one \(code) message, got \(recorder.records)",
                   file: file, line: line)
    guard let record = records.first else { return }
    XCTAssertEqual(record.level, scenario.level, "\(code) level", file: file, line: line)
    XCTAssertEqual(record.service, kFIRLoggerCore, "\(code) service", file: file, line: line)
    for fragment in scenario.fragments {
      XCTAssertTrue(record.message.contains(fragment),
                    "\(code) message \"\(record.message)\" doesn't contain \"\(fragment)\"",
                    file: file, line: line)
    }
  }

  fileprivate func delete(_ app: FirebaseApp, expectingSuccess: Bool) {
    let deleted = expectation(description: "delete")
    app.delete { success in
      XCTAssertEqual(success, expectingSuccess)
      deleted.fulfill()
    }
    wait(for: [deleted], timeout: 1)
  }

  /// Creates an app whose container has the given registrants, as FIRApp does.
  fileprivate func makeApp(registrants: [Library.Type]) -> FirebaseApp {
    let app = FirebaseApp(instanceWithName: "testLogContainer", options: makeAppOptions())
    let allRegistrants = NSMutableSet()
    for registrant in registrants {
      FirebaseComponentContainer.registerAsComponentRegistrant(registrant, in: allRegistrants)
    }
    app.container = FirebaseComponentContainer(app: app, registrants: allRegistrants)
    return app
  }

  private func matches(of pattern: String, in line: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(line.startIndex ..< line.endIndex, in: line)
    return regex.matches(in: line, range: range).compactMap {
      Range($0.range, in: line).map { String(line[$0]) }
    }
  }
}
