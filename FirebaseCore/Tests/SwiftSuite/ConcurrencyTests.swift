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

/// Stress tests that call FirebaseCore from many threads at once, then check that the final state
/// is consistent. Run them under ThreadSanitizer (`swift build --sanitize=thread`) to find data
/// races; CI does. A Swift implementation must stay race free under the same load.
///
/// They only expect what the Objective-C implementation guarantees. In particular, configuring
/// the same app name from several threads at once isn't guaranteed to raise for all but one call:
/// `+configureWithName:options:` checks for an existing app and adds the new one under separate
/// locks. See `testConcurrentDuplicateConfigure`.
final class ConcurrencyTests: CoreTestCase {
  private let iterations = 64
  private let heartbeatStorageID = "CoreSwiftUnit-ConcurrencyTests"

  override func setUpWithError() throws {
    try super.setUpWithError()
    registerTestLibraries()
    TestHeartbeatStorage.remove(heartbeatStorageID)
  }

  override func tearDown() {
    TestHeartbeatStorage.remove(heartbeatStorageID)
    super.tearDown()
  }

  func testConcurrentConfigureFindAndDelete() throws {
    let names = (0 ..< iterations).map { "concurrent\($0)" }
    let failures = LockedValue<[String]>([])

    // Configure and look up apps with unique names from many threads.
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      let name = names[index]
      if let exception = CoreTestHooks.exceptionRaised(by: {
        FirebaseApp.configure(name: name, options: makeAppOptions())
      }) {
        failures.modify { $0.append("configure \(name): \(exception)") }
        return
      }
      if FirebaseApp.app(name: name)?.name != name {
        failures.modify { $0.append("app(name: \(name)) didn't find the app") }
      }
      if FirebaseApp.allApps?[name] == nil {
        failures.modify { $0.append("allApps doesn't contain \(name)") }
      }
      // Reading other apps, which other threads may be configuring or deleting.
      _ = FirebaseApp.app(name: names[(index + 1) % names.count])
      _ = FirebaseApp.isDefaultAppConfigured()
    }
    XCTAssertEqual(failures.value, [])
    XCTAssertEqual(try Set(XCTUnwrap(FirebaseApp.allApps).keys), Set(names))

    // Delete half of them while the other half are read.
    let deleted = Set(names.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element))
    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      let name = names[index]
      guard let app = FirebaseApp.app(name: name) else {
        failures.modify { $0.append("\(name) disappeared") }
        return
      }
      if deleted.contains(name) {
        app.delete { success in
          if !success {
            failures.modify { $0.append("deleting \(name) failed") }
          }
        }
      } else {
        _ = app.options.googleAppID
        _ = FirebaseApp.allApps
      }
    }
    XCTAssertEqual(failures.value, [])
    XCTAssertEqual(try Set(XCTUnwrap(FirebaseApp.allApps).keys), Set(names).subtracting(deleted))
    for name in deleted {
      XCTAssertNil(FirebaseApp.app(name: name), name)
    }
  }

  /// Configures the same app name from many threads at once.
  ///
  /// This only asserts that at least one call wins, because that's all the Objective-C
  /// implementation guarantees. `+configureWithName:options:` checks for an existing app in one
  /// `@synchronized` block and registers the new app in a later one, so two threads can both pass
  /// the check, and the second app then silently replaces the first. The Swift implementation
  /// makes the check and the registration atomic; this test should then assert that exactly one
  /// call wins.
  func testConcurrentDuplicateConfigure() throws {
    let options = UncheckedSendable(makeAppOptions())
    let successes = LockedValue(0)
    let unexpected = LockedValue<[String]>([])

    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      if let exception = CoreTestHooks.exceptionRaised(by: {
        FirebaseApp.configure(name: "duplicate", options: options.value)
      }) {
        if exception.name.rawValue != CoreContract.errorDomain {
          let reason = exception.reason ?? ""
          unexpected.modify { $0.append("\(exception.name.rawValue): \(reason)") }
        }
      } else {
        successes.modify { $0 += 1 }
      }
    }

    // At least one call wins (see above), every other call raises FirebaseCore's exception, and
    // only one app is registered.
    XCTAssertGreaterThanOrEqual(successes.value, 1)
    XCTAssertEqual(unexpected.value, [])
    XCTAssertEqual(FirebaseApp.allApps?.count, 1)
    XCTAssertNotNil(FirebaseApp.app(name: "duplicate"))
  }

  func testConcurrentDataCollectionFlag() throws {
    let app = try configureApp(named: "concurrentDataCollection")
    let otherApp = try configureApp(named: "concurrentDataCollectionOther")
    otherApp.isDataCollectionDefaultEnabled = false
    let apps = UncheckedSendable((app, otherApp))

    DispatchQueue.concurrentPerform(iterations: iterations) { index in
      let (app, otherApp) = apps.value
      if index.isMultiple(of: 2) {
        app.isDataCollectionDefaultEnabled = index.isMultiple(of: 4)
      } else {
        _ = app.isDataCollectionDefaultEnabled
        _ = otherApp.isDataCollectionDefaultEnabled
      }
    }

    // The last write wins, and other apps aren't affected.
    app.isDataCollectionDefaultEnabled = true
    XCTAssertTrue(app.isDataCollectionDefaultEnabled)
    XCTAssertFalse(otherApp.isDataCollectionDefaultEnabled)
  }

  func testConcurrentOptionsReads() throws {
    let options = FirebaseOptions(internalWithOptionsDictionary: TestValues.serviceInfo)
    let app = try configureApp(named: "concurrentOptions", options: options)
    let objects = UncheckedSendable((app: app, shared: app.options, options: options))
    let mismatches = LockedValue(0)

    // Warm both shared instances before going concurrent. `isEqual(_:)` reads
    // `analyticsOptionsDictionary` on both sides, which initializes it. That lazy initialization
    // in `-[FIROptions analyticsOptionsDictionaryWithInfoDictionary:]` is unlocked: when two
    // threads initialize it together, the second strong store frees the first dictionary while
    // another thread is still returning it, a use-after-free. TSan can't see it, because
    // `objc_storeStrong` is in uninstrumented libobjc. It's being fixed separately on main, in
    // #17150. The Swift port must initialize it once, under a lock.
    XCTAssertTrue(objects.value.shared.isEqual(options))

    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      let (app, shared, options) = objects.value
      let copy = app.options
      for current in [shared, copy] where !Self.matchesServiceInfo(current, options) {
        mismatches.modify { $0 += 1 }
      }
      _ = shared.copy()
      _ = shared.hash
    }

    XCTAssertEqual(mismatches.value, 0)
  }

  /// Whether `options` has the values of `TestValues.serviceInfo`, equals `original`, and is
  /// locked, as an app's options are.
  private static func matchesServiceInfo(_ options: FirebaseOptions,
                                         _ original: FirebaseOptions) -> Bool {
    options.googleAppID == TestValues.googleAppID &&
      options.gcmSenderID == TestValues.gcmSenderID &&
      options.apiKey == TestValues.apiKey &&
      options.projectID == TestValues.projectID &&
      options.bundleID == TestValues.bundleID &&
      options.databaseURL == TestValues.databaseURL &&
      options.storageBucket == TestValues.storageBucket &&
      options.clientID == TestValues.clientID &&
      options.isEqual(original) &&
      options.isEditingLocked
  }

  func testConcurrentComponentLookups() throws {
    let app = try configureApp(named: "concurrentComponents")
    let cached = LockedValue<[ObjectIdentifier]>([])
    let uncachedCreations = CoreTestUncachedLibrary.creations.count
    let sharedApp = UncheckedSendable(app)

    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      let app = sharedApp.value
      if let instance = app.cachedTestComponent {
        cached.modify { $0.append(ObjectIdentifier(instance)) }
      }
      _ = app.uncachedTestComponent
      _ = app.eagerTestComponent
      _ = app.unregisteredTestComponent
    }

    // Every lookup of the cached component got the same instance, and every lookup of the
    // uncached component created one.
    XCTAssertEqual(cached.value.count, iterations)
    XCTAssertEqual(Set(cached.value).count, 1)
    XCTAssertEqual(CoreTestUncachedLibrary.creations.count, uncachedCreations + iterations)
  }

  func testConcurrentHeartbeatLogging() throws {
    let logger = FIRHeartbeatLogger(appID: heartbeatStorageID) { "dummy_agent" }

    DispatchQueue.concurrentPerform(iterations: iterations) { _ in
      logger.log()
    }

    // Logging is asynchronous, but flushing waits for it. At most one heartbeat is stored a day.
    let header = logger.headerValue()
    guard TestHeartbeatStorage.isWritable else {
      throw XCTSkip("Heartbeat storage isn't writable here, so no heartbeat can be stored")
    }
    let payload = try decodeHeartbeatsHeader(XCTUnwrap(header))
    let today = TestHeartbeatStorage.dateFormatter.string(from: Date())
    XCTAssertEqual(payload, [
      "version": 2,
      "heartbeats": [["agent": "dummy_agent", "dates": [today]]],
    ] as NSDictionary)
  }
}
