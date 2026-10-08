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
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class CrashlyticsLogProcessorTests: XCTestCase {
  private var exporter: TestLogRecordExporter!
  private var processor: CrashlyticsLogProcessor!
  private var loggerProvider: LoggerProviderSdk!
  private var logger: Logger!

  override func setUp() {
    super.setUp()
    exporter = TestLogRecordExporter()
    processor = CrashlyticsLogProcessor(logRecordExporter: exporter)
    loggerProvider = LoggerProviderBuilder().with(processors: [processor]).build()
    logger = loggerProvider.get(instrumentationScopeName: "CrashlyticsLogProcessorTests")
  }

  override func tearDown() {
    AttributeStore.setScreenName(CrashlyticsScreen.unknown.name)
    logger = nil
    loggerProvider = nil
    processor = nil
    exporter = nil
    super.tearDown()
  }

  func test_onEmit_whenScreenNameNotSet_attachesDefaultScreenName() async throws {
    logger
      .logRecordBuilder()
      .setEventName("custom.event")
      .setSeverity(.info)
      .emit()

    let records = try await waitForExportedLogs(count: 1)
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(records[0].eventName, "custom.event")
    XCTAssertEqual(
      records[0].attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
  }

  func test_onEmit_overwritesExistingCommonAttributeOnLog() async throws {
    logger
      .logRecordBuilder()
      .setEventName(SemanticConventions.App.crashlyticsNavigationEvent)
      .setSeverity(.info)
      .setAttributes([
        SemanticConventions.App.screenName.rawValue: .string("ExplicitScreen"),
      ])
      .emit()

    let records = try await waitForExportedLogs(count: 1)
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(
      records[0].attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
  }

  func test_onEmit_withUserInteractionTap_includesWidgetAttributesAndScreenName() async throws {
    let interactionInstrumentation = UserInteractionInstrumentation(logger: logger)
    interactionInstrumentation.record(.tap(widgetId: "login_button"))

    let records = try await waitForExportedLogs(count: 1)
    XCTAssertEqual(records.count, 1)

    let record = records[0]
    XCTAssertEqual(record.eventName, SemanticConventions.App.crashlyticsWidgetClickEvent)
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.widgetId.rawValue],
      .string("login_button")
    )
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
  }

  func test_onEmit_capturesScreenNameAtEmitTimeBeforeSubsequentChange() async throws {
    AttributeStore.setScreenName("CheckoutScreen")
    logger
      .logRecordBuilder()
      .setEventName("checkout.submit")
      .setSeverity(.info)
      .emit()
    AttributeStore.setScreenName("ConfirmationScreen")

    let records = try await waitForExportedLogs(count: 1)
    XCTAssertEqual(records.count, 1)
    XCTAssertEqual(
      records[0].attributes[SemanticConventions.App.screenName.rawValue],
      .string("CheckoutScreen")
    )
  }

  func test_forceFlushAndShutdown_returnSuccess() {
    XCTAssertEqual(processor.forceFlush(), .success)
    XCTAssertEqual(processor.shutdown(), .success)
  }

  // MARK: - Private Helpers

  private func waitForExportedLogs(count: Int,
                                   timeout: TimeInterval = 2.0) async throws
    -> [ReadableLogRecord] {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      let records = exporter.getFinishedLogRecords()
      if records.count >= count {
        return records
      }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    let finalRecords = exporter.getFinishedLogRecords()
    if finalRecords.count >= count {
      return finalRecords
    }
    throw XCTTimeoutError()
  }
}
