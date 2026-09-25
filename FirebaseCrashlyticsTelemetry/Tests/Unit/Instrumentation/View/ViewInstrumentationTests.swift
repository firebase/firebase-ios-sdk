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

import XCTest
import SwiftUI
import OpenTelemetryApi
import OpenTelemetrySdk

@testable import FirebaseCrashlyticsTelemetry

final class ViewInstrumentationTests: XCTestCase {
  private var mockLogger: MockLogger!
  private var instrumentation: ViewInstrumentation!

  override func setUp() async throws {
    try super.setUpWithError()
    mockLogger = MockLogger()
    instrumentation = ViewInstrumentation(logger: mockLogger.logger)
    // Buffer for listening task to be set up
    try await Task.sleep(nanoseconds: 10_000_000)
  }

  override func tearDown() async throws {
    instrumentation = nil
    mockLogger = nil
    try super.tearDownWithError()
  }

  // MARK: - Initial State

  func test_initialState_activeViewIsUnknownAndNoLogsEmitted() async {
    let active = await instrumentation.activeView
    XCTAssertEqual(active.name, "Unknown")
    XCTAssertEqual(mockLogger.exportedLogs().count, 0)
  }

  // MARK: - Single Screen Transitions

  func test_singleViewAppear_updatesActiveViewAndEmitsLog() async throws {
    let homeID = UUID()
    postViewEvent(id: homeID, name: "HomeScreen", type: .appear)

    let records = try await mockLogger.waitForLogCount(1)

    let active = await instrumentation.activeView
    XCTAssertEqual(active.name, "HomeScreen")
    XCTAssertEqual(active.id, homeID)

    let first = records[0]
    XCTAssertEqual(first.eventName, SemanticConventions.App.navigationEvent)
    XCTAssertEqual(first.severity, .info)
    XCTAssertEqual(
      first.attributes[SemanticConventions.App.screenName.rawValue]?.description,
      "HomeScreen"
    )
    XCTAssertEqual(
      first.attributes[SemanticConventions.App.navigationDestination]?.description,
      "HomeScreen"
    )
  }

  func test_singleViewDisappear_resetsActiveViewToUnknownAndEmitsLog() async throws {
    let homeID = UUID()
    postViewEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    // Trigger disappear
    postViewEvent(id: homeID, name: "HomeScreen", type: .disappear)
    let records = try await mockLogger.waitForLogCount(2)

    let active = await instrumentation.activeView

    XCTAssertEqual(active.name, "Unknown")
    XCTAssertEqual(
      records.last?.attributes[SemanticConventions.App.screenName.rawValue]?.description,
      "Unknown"
    )
  }

  // MARK: - Navigation Stack Order & Unwinding

  func test_nestedNavigation_maintainsLIFOStack() async throws {
    let homeID = UUID()
    let settingsID = UUID()

    // 1. Home appears
    postViewEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    // 2. Settings appears on top
    postViewEvent(id: settingsID, name: "SettingsScreen", type: .appear)
    let recordsAfterPush = try await mockLogger.waitForLogCount(2)

    var active = await instrumentation.activeView
    XCTAssertEqual(active.name, "SettingsScreen")
    XCTAssertEqual(
      recordsAfterPush.last?.attributes[SemanticConventions.App.screenName.rawValue]?.description,
      "SettingsScreen"
    )

    // 3. Settings disappears (pop back to Home)
    postViewEvent(id: settingsID, name: "SettingsScreen", type: .disappear)
    let recordsAfterPop = try await mockLogger.waitForLogCount(3)

    active = await instrumentation.activeView
    XCTAssertEqual(active.name, "HomeScreen")
    XCTAssertEqual(
      recordsAfterPop.last?.attributes[SemanticConventions.App.screenName.rawValue]?.description,
      "HomeScreen"
    )
  }

  func test_stackUnwind_popToExistingView_truncatesStack() async throws {
    let viewAID = UUID()
    let viewBID = UUID()
    let viewCID = UUID()

    // Push A -> B -> C
    postViewEvent(id: viewAID, name: "ViewA", type: .appear)
    postViewEvent(id: viewBID, name: "ViewB", type: .appear)
    postViewEvent(id: viewCID, name: "ViewC", type: .appear)

    _ = try await mockLogger.waitForLogCount(1) // intermediate views coalesced to ViewC

    var active = await instrumentation.activeView
    XCTAssertEqual(active.name, "ViewC")

    // Unwind back to ViewA directly (pop-to-root)
    postViewEvent(id: viewAID, name: "ViewA", type: .appear)

    let records = try await mockLogger.waitForLogCount(2)
    active = await instrumentation.activeView

    XCTAssertEqual(active.name, "ViewA")
    XCTAssertEqual(
      records.last?.attributes[SemanticConventions.App.screenName.rawValue]?.description,
      "ViewA"
    )
  }

  func test_disappearNonExistentView_doesNotAffectStack() async throws {
    let homeID = UUID()
    postViewEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    postViewEvent(id: UUID(), name: "PhantomScreen", type: .disappear)

    let active = await instrumentation.activeView
    XCTAssertEqual(active.name, "HomeScreen")
  }

  // MARK: - Debouncing & Deduplication

  func test_debouncing_rapidSequentialEvents_onlyEmitsFinalSettledScreen() async throws {
    let id1 = UUID()
    let id2 = UUID()
    let id3 = UUID()

    // 3 events posted in rapid succession (< 50ms)
    postViewEvent(id: id1, name: "Screen1", type: .appear)
    postViewEvent(id: id2, name: "Screen2", type: .appear)
    postViewEvent(id: id3, name: "Screen3", type: .appear)

    let records = try await mockLogger.waitForLogCount(1)
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(
      records[0].attributes[SemanticConventions.App.screenName.rawValue]?.description,
      "Screen3"
    )

    let active = await instrumentation.activeView
    XCTAssertEqual(active.name, "Screen3")
  }

  func test_debouncing_transientScreenCancelled_emitsNoNewLog() async throws {
    let homeID = UUID()
    let modalID = UUID()

    postViewEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    // Modal appears and immediately disappears within 10ms
    postViewEvent(id: modalID, name: "ModalScreen", type: .appear)
    try await Task.sleep(nanoseconds: 10_000_000)
    postViewEvent(id: modalID, name: "ModalScreen", type: .disappear)

    // Wait out the debounce period
    try await Task.sleep(nanoseconds: 50_000_000)
    XCTAssertEqual(mockLogger.exportedLogs().count, 1)

    let active = await instrumentation.activeView
    XCTAssertEqual(active.name, "HomeScreen")
  }

  func test_deduplication_sameViewDoesNotEmitDuplicateLog() async throws {
    let homeID = UUID()

    postViewEvent(id: homeID, name: "HomeScreen", type: .appear)
    _ = try await mockLogger.waitForLogCount(1)

    // Post identical appear event after settling
    postViewEvent(id: homeID, name: "HomeScreen", type: .appear)

    XCTAssertEqual(mockLogger.exportedLogs().count, 1)
  }

  // MARK: - End-to-End Test with ViewLifecycleHarness

  @MainActor
  func test_endToEnd_withViewLifecycleHarness() async throws {
    let screenName = "DashboardView"
    let harness = ViewLifecycleHarness(
      view: Text("Telemetry Test").modifier(ViewTrackingModifier(screenName: screenName))
    )

    // 1. Appear
    harness.appear()
    let appearRecords = try await mockLogger.waitForLogCount(1)
    XCTAssertEqual(
      appearRecords.last?.attributes[SemanticConventions.App.screenName.rawValue]?.description,
      screenName
    )

    // 2. Disappear
    harness.disappear()
    let disappearRecords = try await mockLogger.waitForLogCount(2)
    XCTAssertEqual(
      disappearRecords.last?.attributes[SemanticConventions.App.screenName.rawValue]?.description,
      "Unknown"
    )

    harness.cleanup()
  }

  // MARK: - Private Helpers

  private func postViewEvent(id: UUID, name: String, type: ViewEventType) {
    NotificationCenter.default.post(
      name: .viewTrackingEvent,
      object: nil,
      userInfo: [
        "id": id,
        "screenName": name,
        "type": type
      ]
    )
  }
}
