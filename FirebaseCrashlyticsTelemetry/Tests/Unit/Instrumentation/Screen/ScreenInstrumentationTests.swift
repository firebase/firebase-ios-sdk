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
import OpenTelemetrySdk
import SwiftUI
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class ScreenInstrumentationTests: XCTestCase {
  private var mockLogger: MockLogger!
  private var instrumentation: ScreenInstrumentation!

  override func setUp() async throws {
    try super.setUpWithError()
    mockLogger = MockLogger()
    instrumentation = ScreenInstrumentation(logger: mockLogger.logger)
    // Buffer for listening task to be set up
    try await Task.sleep(nanoseconds: 10_000_000)
  }

  override func tearDown() async throws {
    instrumentation = nil
    mockLogger = nil
    try super.tearDownWithError()
  }

  // MARK: - Initial State

  func test_initialState_activeScreenIsUnknownAndNoLogsEmitted() async {
    let active = await instrumentation.activeScreen
    XCTAssertEqual(active.name, "Unknown")
    XCTAssertEqual(mockLogger.exportedLogs().count, 0)
  }

  // MARK: - Single Screen Transitions

  func test_singleScreenAppear_updatesActiveScreenAndEmitsLog() async throws {
    let homeID = UUID()
    postScreenEvent(id: homeID, name: "HomeScreen", type: .appear)

    let records = try await mockLogger.waitForLogCount(1)

    let active = await instrumentation.activeScreen
    XCTAssertEqual(active.name, "HomeScreen")
    XCTAssertEqual(active.id, homeID)

    let first = records[0]
    XCTAssertEqual(first.eventName, SemanticConventions.App.crashlyticsNavigationEvent)
    XCTAssertEqual(first.severity, .info)
    XCTAssertEqual(
      first.attributes[SemanticConventions.App.crashlyticsNavigationDestination]?.description,
      "HomeScreen"
    )
  }

  func test_singleScreenDisappear_resetsActiveScreenToUnknownAndEmitsLog() async throws {
    let homeID = UUID()
    postScreenEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    // Trigger disappear
    postScreenEvent(id: homeID, name: "HomeScreen", type: .disappear)
    let records = try await mockLogger.waitForLogCount(2)

    let active = await instrumentation.activeScreen

    XCTAssertEqual(active.name, "Unknown")
    XCTAssertEqual(
      records.last?
        .attributes[SemanticConventions.App.crashlyticsNavigationDestination]?.description,
      "Unknown"
    )
  }

  // MARK: - Navigation Stack Order & Unwinding

  func test_nestedNavigation_maintainsLIFOStack() async throws {
    let homeID = UUID()
    let settingsID = UUID()

    // 1. Home appears
    postScreenEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    // 2. Settings appears on top
    postScreenEvent(id: settingsID, name: "SettingsScreen", type: .appear)
    let recordsAfterPush = try await mockLogger.waitForLogCount(2)
    _ = recordsAfterPush

    var active = await instrumentation.activeScreen
    XCTAssertEqual(active.name, "SettingsScreen")

    // 3. Settings disappears (pop back to Home)
    postScreenEvent(id: settingsID, name: "SettingsScreen", type: .disappear)
    let recordsAfterPop = try await mockLogger.waitForLogCount(3)
    _ = recordsAfterPop

    active = await instrumentation.activeScreen
    XCTAssertEqual(active.name, "HomeScreen")
  }

  func test_stackUnwind_popToExistingScreen_truncatesStack() async throws {
    let screenAID = UUID()
    let screenBID = UUID()
    let screenCID = UUID()

    // Push A -> B -> C
    postScreenEvent(id: screenAID, name: "ScreenA", type: .appear)
    postScreenEvent(id: screenBID, name: "ScreenB", type: .appear)
    postScreenEvent(id: screenCID, name: "ScreenC", type: .appear)

    _ = try await mockLogger.waitForLogCount(1) // intermediate screens coalesced to ScreenC

    var active = await instrumentation.activeScreen
    XCTAssertEqual(active.name, "ScreenC")

    // Unwind back to ScreenA directly (pop-to-root)
    postScreenEvent(id: screenAID, name: "ScreenA", type: .appear)

    let records = try await mockLogger.waitForLogCount(2)
    _ = records
    active = await instrumentation.activeScreen

    XCTAssertEqual(active.name, "ScreenA")
  }

  func test_disappearNonExistentScreen_doesNotAffectStack() async throws {
    let homeID = UUID()
    postScreenEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    postScreenEvent(id: UUID(), name: "PhantomScreen", type: .disappear)

    let active = await instrumentation.activeScreen
    XCTAssertEqual(active.name, "HomeScreen")
  }

  // MARK: - Debouncing & Deduplication

  func test_debouncing_rapidSequentialEvents_onlyEmitsFinalSettledScreen() async throws {
    let id1 = UUID()
    let id2 = UUID()
    let id3 = UUID()

    // 3 events posted in rapid succession (< 50ms)
    postScreenEvent(id: id1, name: "Screen1", type: .appear)
    postScreenEvent(id: id2, name: "Screen2", type: .appear)
    postScreenEvent(id: id3, name: "Screen3", type: .appear)

    let records = try await mockLogger.waitForLogCount(1)
    XCTAssertEqual(records.count, 1)

    let active = await instrumentation.activeScreen
    XCTAssertEqual(active.name, "Screen3")
  }

  func test_debouncing_transientScreenCancelled_emitsNoNewLog() async throws {
    let homeID = UUID()
    let modalID = UUID()

    postScreenEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    // Modal appears and immediately disappears within 10ms
    postScreenEvent(id: modalID, name: "ModalScreen", type: .appear)
    try await Task.sleep(nanoseconds: 10_000_000)
    postScreenEvent(id: modalID, name: "ModalScreen", type: .disappear)

    // Wait out the debounce period
    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(mockLogger.exportedLogs().count, 1)

    let active = await instrumentation.activeScreen
    XCTAssertEqual(active.name, "HomeScreen")
  }

  func test_deduplication_sameScreenDoesNotEmitDuplicateLog() async throws {
    let homeID = UUID()

    postScreenEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    // Post identical appear event after settling
    postScreenEvent(id: homeID, name: "HomeScreen", type: .appear)

    XCTAssertEqual(mockLogger.exportedLogs().count, 1)
  }

  // MARK: - onChange Callback

  func test_onChangeCallback_isInvokedWhenSettledScreenChanges() async throws {
    let expectation = expectation(description: "onChange called for CallbackScreen")
    let localLogger = MockLogger()
    let customInstrumentation = ScreenInstrumentation(logger: localLogger.logger) { screenName in
      if screenName == "CallbackScreen" {
        expectation.fulfill()
      }
    }
    _ = customInstrumentation
    try await Task.sleep(nanoseconds: 10_000_000)

    postScreenEvent(id: UUID(), name: "CallbackScreen", type: .appear)
    await fulfillment(of: [expectation], timeout: 2.0)
  }

  // MARK: - End-to-End Test with ViewLifecycleHarness

  @MainActor
  func test_endToEnd_withViewLifecycleHarness() async throws {
    let screenName = "DashboardView"
    let harness = ViewLifecycleHarness(
      view: Text("Telemetry Test").modifier(ScreenTrackingModifier(screenName: screenName))
    )

    // 1. Appear
    harness.appear()
    let appearRecords = try await mockLogger.waitForLogCount(1)
    _ = appearRecords

    // 2. Disappear
    harness.disappear()
    let disappearRecords = try await mockLogger.waitForLogCount(2)
    _ = disappearRecords

    harness.cleanup()
  }

  // MARK: - Private Helpers

  private func postScreenEvent(id: UUID, name: String, type: ScreenEventType) {
    NotificationCenter.default.post(
      name: .screenTrackingEvent,
      object: nil,
      userInfo: [
        "id": id,
        "screenName": name,
        "type": type,
      ]
    )
  }
}
