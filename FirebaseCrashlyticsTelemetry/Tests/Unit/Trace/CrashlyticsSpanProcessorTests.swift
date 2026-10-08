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
  private var mockBuffer: MockPersistenceBuffer!
  private var mockRecoveryManager: MockRecoveryManager!
  private var persistenceManager: PersistenceManager!
  private var tracerProvider: CrashlyticsTracerProvider!
  private var tracer: Tracer!

  override func setUp() {
    super.setUp()
    PersistenceWrapperFactory.reset()
    mockBuffer = MockPersistenceBuffer()
    mockRecoveryManager = MockRecoveryManager()
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    PersistenceWrapperFactory.mockRecoveredSpans = []

    let manager = PersistenceManager()
    let recoveryManager = mockRecoveryManager!
    let configured = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
      manager.configure(recoveryManager: recoveryManager)
      configured.signal()
    }
    configured.wait()

    persistenceManager = manager
    tracerProvider = CrashlyticsTracerProviderBuilder(persistenceManager: manager).build()
    tracer = tracerProvider.get(
      instrumentationName: "CrashlyticsSpanProcessorTests",
      instrumentationVersion: nil,
      schemaUrl: nil,
      attributes: nil
    )
  }

  override func tearDown() {
    AttributeStore.setScreenName(CrashlyticsScreen.unknown.name)
    PersistenceWrapperFactory.reset()
    tracer = nil
    tracerProvider = nil
    persistenceManager = nil
    mockRecoveryManager = nil
    mockBuffer = nil
    super.tearDown()
  }

  func test_onStart_attachesCommonSpanAttributesToSpan() {
    let span = tracer.spanBuilder(spanName: "test_operation").startSpan()
    defer { span.end() }

    guard let readableSpan = span as? ReadableSpan else {
      XCTFail("Expected span to conform to ReadableSpan")
      return
    }

    XCTAssertEqual(
      readableSpan.getAttributes()[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
    XCTAssertEqual(
      readableSpan.getAttributes()["gcp.firebase.app_version"],
      .string("1.0")
    )
  }

  func test_onStart_overwritesExistingCommonAttributeOnSpan() {
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

    XCTAssertEqual(
      readableSpan.getAttributes()[SemanticConventions.App.screenName.rawValue],
      .string(CrashlyticsScreen.unknown.name)
    )
  }

  func test_onStart_capturesScreenNameAtStartTimeBeforeSubsequentChange() {
    AttributeStore.setScreenName("HomeScreen")
    let span = tracer.spanBuilder(spanName: "navigation_operation").startSpan()
    AttributeStore.setScreenName("DetailScreen")
    defer { span.end() }

    guard let readableSpan = span as? ReadableSpan else {
      XCTFail("Expected span to conform to ReadableSpan")
      return
    }

    XCTAssertEqual(
      readableSpan.getAttributes()[SemanticConventions.App.screenName.rawValue],
      .string("HomeScreen")
    )
  }

  func test_onStart_persistsSpanSynchronouslyWithoutPreStartSetAttributeCalls() {
    AttributeStore.setScreenName("CheckoutScreen")
    let span = tracer
      .spanBuilder(spanName: "checkout_operation")
      .setAttribute(key: "custom.init_key", value: .string("init_val"))
      .startSpan()
    let spanId = span.context.spanId.rawValue

    // Immediately after startSpan() returns on the calling thread, the span must already be in the
    // persistence buffer with no pre-start setAttribute calls.
    XCTAssertEqual(mockBuffer.addedSpans.count, 1)
    XCTAssertTrue(mockBuffer.setAttributeCalls.isEmpty)
    XCTAssertEqual(mockBuffer.recordedOperations, [.addSpan(spanId)])
    XCTAssertEqual(mockBuffer.addedSpans[0].attributes["custom.init_key"], "init_val")
    XCTAssertEqual(
      mockBuffer.addedSpans[0].attributes[SemanticConventions.App.screenName.rawValue],
      "CheckoutScreen"
    )

    span.end()
  }

  func test_spanLifecycle_persistsStartSetAttributesAndEndInStrictFIFOOrderSynchronously() {
    let span = tracer.spanBuilder(spanName: "ordered_span").startSpan()
    let spanId = span.context.spanId.rawValue

    span.setAttribute(key: "step", value: .string("1"))
    span.setAttribute(key: "step", value: .string("2"))
    span.setAttribute(key: "step", value: .string("3"))

    let endDate = Date(timeIntervalSince1970: 1_700_000_000)
    let expectedEndNano = UInt64(endDate.timeIntervalSince1970 * 1_000_000_000)
    span.end(time: endDate)

    XCTAssertEqual(
      mockBuffer.recordedOperations,
      [
        .addSpan(spanId),
        .setAttribute(.init(spanId: spanId, key: "step", value: "1")),
        .setAttribute(.init(spanId: spanId, key: "step", value: "2")),
        .setAttribute(.init(spanId: spanId, key: "step", value: "3")),
        .endSpan(.init(spanId: spanId, endTime: expectedEndNano)),
      ]
    )
  }
}
