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

import OpenTelemetryApi
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class AttributeStoreTests: XCTestCase {
  override func tearDown() {
    AttributeStore.setScreenName(CrashlyticsScreen.unknown.name)
    AttributeStore.setSessionId(nil)
    super.tearDown()
  }

  func test_commonSpanAttributes_containsScreenNameAppVersionThreadInfoAndOmitsSessionIdWhenNil() {
    let attributes = AttributeStore.commonSpanAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertEqual(
      attributes["gcp.firebase.app_version"],
      .string("1.0")
    )
    XCTAssertNil(attributes[SemanticConventions.Session.id.rawValue])
    if case let .int(threadId) = attributes[SemanticConventions.Thread.id.rawValue] {
      XCTAssertGreaterThan(threadId, 0)
    } else {
      XCTFail("Expected thread.id to be an integer attribute")
    }
    XCTAssertEqual(attributes[SemanticConventions.Thread.name.rawValue], .string("main"))
  }

  func test_commonSpanAttributes_onNamedBackgroundThread_capturesBackgroundThreadInfo() {
    let mainAttributes = AttributeStore.commonSpanAttributes()
    let expectation = expectation(description: "Background thread evaluated attributes")
    let capturedAttributes = LockBox<[String: AttributeValue]>([:])

    let workerThread = Thread {
      capturedAttributes.set(AttributeStore.commonSpanAttributes())
      expectation.fulfill()
    }
    workerThread.name = "crashlytics-worker"
    workerThread.start()

    wait(for: [expectation], timeout: 2.0)

    let workerAttributes = capturedAttributes.get()
    XCTAssertEqual(
      workerAttributes[SemanticConventions.Thread.name.rawValue],
      .string("crashlytics-worker")
    )
    XCTAssertNotEqual(
      workerAttributes[SemanticConventions.Thread.id.rawValue],
      mainAttributes[SemanticConventions.Thread.id.rawValue]
    )
  }

  func test_commonLogAttributes_containsScreenNameAndOmitsSessionIdAndThreadAttributes() {
    let attributes = AttributeStore.commonLogAttributes()

    XCTAssertEqual(
      attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertNil(attributes[SemanticConventions.Session.id.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Thread.id.rawValue])
    XCTAssertNil(attributes[SemanticConventions.Thread.name.rawValue])
  }

  func test_setScreenName_updatesCommonSpanAndLogAttributes() {
    AttributeStore.setScreenName("SettingsScreen")

    XCTAssertEqual(
      AttributeStore.commonSpanAttributes()[SemanticConventions.App.screenName.rawValue],
      .string("SettingsScreen")
    )
    XCTAssertEqual(
      AttributeStore.commonLogAttributes()[SemanticConventions.App.screenName.rawValue],
      .string("SettingsScreen")
    )
  }

  func test_setSessionId_updatesCommonSpanAndLogAttributes() {
    AttributeStore.setSessionId("test-session-123")

    XCTAssertEqual(
      AttributeStore.commonSpanAttributes()[SemanticConventions.Session.id.rawValue],
      .string("test-session-123")
    )
    XCTAssertEqual(
      AttributeStore.commonLogAttributes()[SemanticConventions.Session.id.rawValue],
      .string("test-session-123")
    )
  }
}

private final class LockBox<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Value

  init(_ value: Value) {
    self.value = value
  }

  func set(_ newValue: Value) {
    lock.lock()
    defer { lock.unlock() }
    value = newValue
  }

  func get() -> Value {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}
