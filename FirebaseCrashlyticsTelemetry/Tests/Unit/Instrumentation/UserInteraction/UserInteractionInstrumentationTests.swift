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

final class UserInteractionInstrumentationTests: XCTestCase {
  private var mockLogger: MockLogger!
  private var instrumentation: UserInteractionInstrumentation!

  override func setUp() {
    super.setUp()
    mockLogger = MockLogger()
    instrumentation = UserInteractionInstrumentation(logger: mockLogger.logger)
  }

  override func tearDown() {
    instrumentation = nil
    mockLogger = nil
    super.tearDown()
  }

  func test_recordTap_withoutCoordinates_emitsWidgetClickEventWithWidgetIdOnly() async throws {
    instrumentation.record(.tap(widgetId: "submit_button"))

    let records = try await mockLogger.waitForLogCount(1)
    XCTAssertEqual(records.count, 1)

    let record = records[0]
    XCTAssertEqual(record.eventName, SemanticConventions.App.widgetClickEvent)
    XCTAssertEqual(record.severity, .info)
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.widgetId.rawValue],
      .string("submit_button")
    )
    XCTAssertNil(record.attributes[SemanticConventions.App.screenCoordinateX.rawValue])
    XCTAssertNil(record.attributes[SemanticConventions.App.screenCoordinateY.rawValue])
  }

  func test_recordTap_withBothCoordinates_emitsWidgetClickEventWithCoordinates() async throws {
    instrumentation.record(.tap(widgetId: "checkout_button", x: 131, y: 99))

    let records = try await mockLogger.waitForLogCount(1)
    XCTAssertEqual(records.count, 1)

    let record = records[0]
    XCTAssertEqual(record.eventName, SemanticConventions.App.widgetClickEvent)
    XCTAssertEqual(record.severity, .info)
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.widgetId.rawValue],
      .string("checkout_button")
    )
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.screenCoordinateX.rawValue],
      .int(131)
    )
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.screenCoordinateY.rawValue],
      .int(99)
    )
  }

  func test_recordTap_withOnlyXCoordinate_emitsWidgetClickEventWithXOnly() async throws {
    instrumentation.record(.tap(widgetId: "slider_thumb", x: 42, y: nil))

    let records = try await mockLogger.waitForLogCount(1)
    XCTAssertEqual(records.count, 1)

    let record = records[0]
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.widgetId.rawValue],
      .string("slider_thumb")
    )
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.screenCoordinateX.rawValue],
      .int(42)
    )
    XCTAssertNil(record.attributes[SemanticConventions.App.screenCoordinateY.rawValue])
  }

  func test_recordTap_withOnlyYCoordinate_emitsWidgetClickEventWithYOnly() async throws {
    instrumentation.record(.tap(widgetId: "scroll_handle", x: nil, y: 256))

    let records = try await mockLogger.waitForLogCount(1)
    XCTAssertEqual(records.count, 1)

    let record = records[0]
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.widgetId.rawValue],
      .string("scroll_handle")
    )
    XCTAssertNil(record.attributes[SemanticConventions.App.screenCoordinateX.rawValue])
    XCTAssertEqual(
      record.attributes[SemanticConventions.App.screenCoordinateY.rawValue],
      .int(256)
    )
  }
}
