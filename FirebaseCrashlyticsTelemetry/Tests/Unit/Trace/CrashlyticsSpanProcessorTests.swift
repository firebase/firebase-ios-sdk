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

final class CrashlyticsSpanProcessorTests: XCTestCase {
  private var tracerProvider: CrashlyticsTracerProvider!
  private var tracer: Tracer!

  override func setUp() {
    super.setUp()
    tracerProvider = CrashlyticsTracerProviderBuilder().build()
    tracer = tracerProvider.get(
      instrumentationName: "CrashlyticsSpanProcessorTests",
      instrumentationVersion: nil,
      schemaUrl: nil,
      attributes: nil
    )
  }

  override func tearDown() {
    tracer = nil
    tracerProvider = nil
    super.tearDown()
  }

  func test_onStart_attachesCommonSpanAttributesToSpan() async throws {
    let span = tracer.spanBuilder(spanName: "test_operation").startSpan()
    defer { span.end() }

    guard let readableSpan = span as? ReadableSpan else {
      XCTFail("Expected span to conform to ReadableSpan")
      return
    }

    let screenName = try await waitForScreenNameAttribute(on: readableSpan)
    XCTAssertEqual(screenName, .string(CrashlyticsView.unknown.name))
    XCTAssertEqual(
      readableSpan.getAttributes()["gcp.firebase.app_version"],
      .string("1.0")
    )
  }

  func test_onStart_overwritesExistingCommonAttributeOnSpan() async throws {
    let span = tracer
      .spanBuilder(spanName: "custom_screen_operation")
      .setAttribute(
        key: SemanticConventions.App.screenName.rawValue,
        value: .string("CustomScreen")
      )
      .startSpan()
    defer { span.end() }

    guard let readableSpan = span as? ReadableSpan else {
      XCTFail("Expected span to conform to ReadableSpan")
      return
    }

    try await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertEqual(
      readableSpan.getAttributes()[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsView.unknown.name)
    )
  }

  // MARK: - Private Helpers

  private func waitForScreenNameAttribute(on span: ReadableSpan,
                                          timeout: TimeInterval = 2.0) async throws
    -> AttributeValue {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if let value = span.getAttributes()[SemanticConventions.App.screenName.rawValue] {
        return value
      }
      try await Task.sleep(nanoseconds: 10_000_000)
    }

    if let finalValue = span.getAttributes()[SemanticConventions.App.screenName.rawValue] {
      return finalValue
    }
    throw XCTTimeoutError()
  }
}
