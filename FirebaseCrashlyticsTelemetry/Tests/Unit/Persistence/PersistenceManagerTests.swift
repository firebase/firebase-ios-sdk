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

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import PersistenceWrapper
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class PersistenceManagerTests: XCTestCase {
  private var mockBuffer: MockPersistenceBuffer!
  private var mockRecoveryManager: MockRecoveryManager!
  private var tempDirectoryURL: URL!

  override func setUp() async throws {
    try await super.setUp()
    mockBuffer = MockPersistenceBuffer()
    mockRecoveryManager = MockRecoveryManager()

    CrashlyticsTelemetry.shared.recoveryManager = mockRecoveryManager

    tempDirectoryURL = URL(fileURLWithPath: "/tmp/crashlytics_test_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)

    PersistenceWrapperFactory.reset()
  }

  override func tearDown() async throws {
    PersistenceWrapperFactory.reset()
    CrashlyticsTelemetry.shared.recoveryManager = nil

    if let url = tempDirectoryURL {
      try? FileManager.default.removeItem(at: url)
    }

    await mockRecoveryManager.reset()
    mockBuffer = nil
    mockRecoveryManager = nil
    tempDirectoryURL = nil
    try await super.tearDown()
  }

  // MARK: - Test Helpers

  private func makeSamplePersistenceSpan(name: String = "test_recovered_span",
                                         traceIdHi: UInt64 = 0x1111_2222_3333_4444,
                                         traceIdLo: UInt64 = 0x5555_6666_7777_8888,
                                         spanId: UInt64 = 0x9999_AAAA_BBBB_CCCC,
                                         parentSpanId: UInt64 = 0x0000_1111_2222_3333,
                                         startTimeNano: UInt64 = 1_000_000_000_000,
                                         endTimeNano: UInt64 = 1_002_500_000_000,
                                         attributes: [String: String] = [
                                           "crash.signal": "SIGSEGV",
                                           "app.version": "2.4.0",
                                         ]) -> PersistenceSpan {
    return PersistenceSpan(
      traceIdHi: traceIdHi,
      traceIdLo: traceIdLo,
      spanId: spanId,
      parentSpanId: parentSpanId,
      startTimeNano: startTimeNano,
      endTimeNano: endTimeNano,
      name: name,
      attributes: attributes
    )
  }

  // MARK: - 1. Initialization & Factory Configuration Tests

  func test_init_successfulBufferCreation_verifiesFactoryArgumentsAndActiveBuffer() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    PersistenceWrapperFactory.mockRecoveredSpans = []

    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let expectedFilePath = tempDirectoryURL
      .appendingPathComponent("crashlytics_persistence.clsrecord").path
    XCTAssertEqual(PersistenceWrapperFactory.captureInitFilePath, expectedFilePath)
    XCTAssertEqual(PersistenceWrapperFactory.captureInitBufferSize, .small)

    let spanData = MockTrace.mockSpan(name: "boot_span")
    await manager.onSpanStart(span: spanData)

    XCTAssertEqual(mockBuffer.addedSpans.count, 1)
    XCTAssertEqual(mockBuffer.addedSpans[0].name, "boot_span")
  }

  // MARK: - 2. Recovery & Upload Pipeline Tests

  func test_init_whenRecoveredSpansPresent_convertsAndUploadsAllFields() async {
    let sampleSpan = makeSamplePersistenceSpan(
      name: "crash_in_flight_operation",
      traceIdHi: 0xAAAA_BBBB_CCCC_DDDD,
      traceIdLo: 0x1111_2222_3333_4444,
      spanId: 0xDEAD_BEEF_CAFE_FEED,
      parentSpanId: 0x0123_4567_89AB_CDEF,
      startTimeNano: 2_000_000_000_000,
      endTimeNano: 2_001_500_000_000,
      attributes: ["thread.name": "main", "is_fatal": "true"]
    )

    let uploadExpectation = expectation(description: "Upload recovered spans")
    await mockRecoveryManager.setUploadExpectation(uploadExpectation)

    PersistenceWrapperFactory.mockBuffer = mockBuffer
    PersistenceWrapperFactory.mockRecoveredSpans = [sampleSpan]

    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await fulfillment(of: [uploadExpectation], timeout: 2.0)

    let batches = await mockRecoveryManager.uploadedBatches
    XCTAssertEqual(batches.count, 1)
    guard let uploadedSpans = batches.first, uploadedSpans.count == 1 else {
      XCTFail("Expected 1 recovered span uploaded")
      return
    }

    let recovered = uploadedSpans[0]
    XCTAssertEqual(recovered.name, "crash_in_flight_operation")
    XCTAssertEqual(recovered.traceID.idHi, 0xAAAA_BBBB_CCCC_DDDD)
    XCTAssertEqual(recovered.traceID.idLo, 0x1111_2222_3333_4444)
    XCTAssertEqual(recovered.spanID.rawValue, 0xDEAD_BEEF_CAFE_FEED)
    XCTAssertEqual(recovered.parentSpanID?.rawValue, 0x0123_4567_89AB_CDEF)
    XCTAssertEqual(recovered.startTime.timeIntervalSince1970, 2000.0)
    XCTAssertEqual(recovered.endTime?.timeIntervalSince1970, 2001.5)
    XCTAssertEqual(recovered.attributes["thread.name"]?.description, "main")
    XCTAssertEqual(recovered.attributes["is_fatal"]?.description, "true")

    await manager.onSpanEnd(spanId: 0x9999)
    XCTAssertEqual(mockBuffer.removedSpanIds, [0x9999])
  }

  func test_init_whenMultipleRecoveredSpansPresent_uploadsAllSpansInSingleBatch() async {
    let spanOne = makeSamplePersistenceSpan(name: "span_one", spanId: 0x101)
    let spanTwo = makeSamplePersistenceSpan(name: "span_two", spanId: 0x202)

    let uploadExpectation = expectation(description: "Upload multi-span batch")
    await mockRecoveryManager.setUploadExpectation(uploadExpectation)

    PersistenceWrapperFactory.mockBuffer = mockBuffer
    PersistenceWrapperFactory.mockRecoveredSpans = [spanOne, spanTwo]

    _ = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await fulfillment(of: [uploadExpectation], timeout: 2.0)

    let batches = await mockRecoveryManager.uploadedBatches
    XCTAssertEqual(batches.count, 1)
    let batch = batches.first ?? []
    XCTAssertEqual(batch.count, 2)
    XCTAssertEqual(batch[0].name, "span_one")
    XCTAssertEqual(batch[1].name, "span_two")
  }

  func test_init_whenRecoveredSpanHasZeroParentSpanId_mapsParentSpanIdToNil() async {
    let rootSpan = makeSamplePersistenceSpan(name: "root_span", parentSpanId: 0)

    let uploadExpectation = expectation(description: "Upload root span")
    await mockRecoveryManager.setUploadExpectation(uploadExpectation)

    PersistenceWrapperFactory.mockBuffer = mockBuffer
    PersistenceWrapperFactory.mockRecoveredSpans = [rootSpan]

    _ = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await fulfillment(of: [uploadExpectation], timeout: 2.0)

    let batches = await mockRecoveryManager.uploadedBatches
    let recovered = batches.first?.first
    XCTAssertNil(recovered?.parentSpanID)
  }

  func test_init_whenRecoveredSpansListIsEmpty_doesNotTriggerUpload() async {
    let invertedExpectation = expectation(description: "No upload triggered for empty spans")
    invertedExpectation.isInverted = true
    await mockRecoveryManager.setUploadExpectation(invertedExpectation)

    PersistenceWrapperFactory.mockBuffer = mockBuffer
    PersistenceWrapperFactory.mockRecoveredSpans = []

    _ = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await fulfillment(of: [invertedExpectation], timeout: 0.2)
    let batches = await mockRecoveryManager.uploadedBatches
    XCTAssertEqual(batches.count, 0)
  }

  func test_init_whenBufferFactoryReturnsNil_stillUploadsRecoveredSpans() async {
    let recoveredSpan = makeSamplePersistenceSpan(name: "salvaged_crash_span")

    let uploadExpectation = expectation(description: "Upload spans when live buffer fails")
    await mockRecoveryManager.setUploadExpectation(uploadExpectation)

    PersistenceWrapperFactory.mockBuffer = nil
    PersistenceWrapperFactory.simulateBufferFailure = true
    PersistenceWrapperFactory.mockRecoveredSpans = [recoveredSpan]

    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await fulfillment(of: [uploadExpectation], timeout: 2.0)

    let batches = await mockRecoveryManager.uploadedBatches
    XCTAssertEqual(batches.count, 1)
    XCTAssertEqual(batches.first?.first?.name, "salvaged_crash_span")

    await manager.onSpanEnd(spanId: 0x1234)
    XCTAssertEqual(mockBuffer.removedSpanIds.count, 0)
  }

  func test_init_whenBufferFactoryReturnsNilAndNoRecoveredSpans_handlesFailureGracefully() async {
    let invertedExpectation = expectation(description: "No upload on total failure")
    invertedExpectation.isInverted = true
    await mockRecoveryManager.setUploadExpectation(invertedExpectation)

    PersistenceWrapperFactory.mockBuffer = nil
    PersistenceWrapperFactory.simulateBufferFailure = true
    PersistenceWrapperFactory.mockRecoveredSpans = []

    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await fulfillment(of: [invertedExpectation], timeout: 0.2)

    let batches = await mockRecoveryManager.uploadedBatches
    XCTAssertEqual(batches.count, 0)

    let spanData = MockTrace.mockSpan()
    await manager.onSpanStart(span: spanData)
    await manager.onSpanAddAttribute(spanId: 100, key: "key", value: "value")
    await manager.onSpanEnd(spanId: 100)

    XCTAssertEqual(mockBuffer.addedSpans.count, 0)
    XCTAssertEqual(mockBuffer.setAttributeCalls.count, 0)
    XCTAssertEqual(mockBuffer.removedSpanIds.count, 0)
  }

  func test_init_whenRecoveryManagerIsNil_doesNotCrashDuringUpload() async {
    CrashlyticsTelemetry.shared.recoveryManager = nil

    let sampleSpan = makeSamplePersistenceSpan(name: "unhandled_span")
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    PersistenceWrapperFactory.mockRecoveredSpans = [sampleSpan]

    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)
    await manager.onSpanEnd(spanId: 0x1111)
    XCTAssertEqual(mockBuffer.removedSpanIds, [0x1111])
  }

  // MARK: - 3. SpanProcessor Operations (Active Buffer)

  func test_onSpanStart_withActiveBuffer_convertsAndForwardsAllFields() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let startTime = Date(timeIntervalSince1970: 5000.0)
    let spanData = MockTrace.mockSpan(
      name: "checkout_completed",
      startTime: startTime,
      duration: 1.5,
      attributes: [
        "cart.total": .string("$99.99"),
        "cart.items": .int(4),
      ]
    )

    await manager.onSpanStart(span: spanData)

    XCTAssertEqual(mockBuffer.addedSpans.count, 1)
    let persisted = mockBuffer.addedSpans[0]
    XCTAssertEqual(persisted.name, "checkout_completed")
    XCTAssertEqual(persisted.traceIdHi, spanData.traceId.idHi)
    XCTAssertEqual(persisted.traceIdLo, spanData.traceId.idLo)
    XCTAssertEqual(persisted.spanId, spanData.spanId.rawValue)
    XCTAssertEqual(persisted.startTimeNano, 5_000_000_000_000)
    XCTAssertEqual(persisted.endTimeNano, 5_001_500_000_000)
    XCTAssertEqual(persisted.attributes["cart.total"], "$99.99")
    XCTAssertEqual(persisted.attributes["cart.items"], "4")
  }

  func test_onSpanStart_withParentSpan_mapsParentSpanIdCorrectly() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let (parent, child) = MockTrace.mockParentChildTrace()

    await manager.onSpanStart(span: child)

    XCTAssertEqual(mockBuffer.addedSpans.count, 1)
    let persistedChild = mockBuffer.addedSpans[0]
    XCTAssertEqual(persistedChild.parentSpanId, parent.spanId.rawValue)
    XCTAssertNotEqual(persistedChild.parentSpanId, 0)
  }

  func test_onSpanStart_withoutParentSpan_defaultsParentSpanIdToZero() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let rootSpan = MockTrace.mockSpan(name: "root_task", parentContext: nil)

    await manager.onSpanStart(span: rootSpan)

    XCTAssertEqual(mockBuffer.addedSpans.count, 1)
    XCTAssertEqual(mockBuffer.addedSpans[0].parentSpanId, 0)
  }

  func test_onSpanAddAttribute_withValidValue_forwardsToBuffer() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let spanId: UInt64 = 0xFEED_BEEF
    await manager.onSpanAddAttribute(spanId: spanId, key: "session.foreground", value: "true")

    XCTAssertEqual(mockBuffer.setAttributeCalls.count, 1)
    XCTAssertEqual(mockBuffer.setAttributeCalls[0].spanId, spanId)
    XCTAssertEqual(mockBuffer.setAttributeCalls[0].key, "session.foreground")
    XCTAssertEqual(mockBuffer.setAttributeCalls[0].value, "true")
  }

  func test_onSpanAddAttribute_withEmptyStringValue_forwardsToBuffer() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let spanId: UInt64 = 0xFEED_BEEF
    await manager.onSpanAddAttribute(spanId: spanId, key: "empty_key", value: "")

    XCTAssertEqual(mockBuffer.setAttributeCalls.count, 1)
    XCTAssertEqual(mockBuffer.setAttributeCalls[0].key, "empty_key")
    XCTAssertEqual(mockBuffer.setAttributeCalls[0].value, "")
  }

  func test_onSpanAddAttribute_withNilValue_doesNotForwardToBuffer() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await manager.onSpanAddAttribute(spanId: 0xFEED_BEEF, key: "session.foreground", value: nil)

    XCTAssertTrue(mockBuffer.setAttributeCalls.isEmpty)
  }

  func test_onSpanEnd_forwardsRemoveSpanIdToBuffer() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let spanId: UInt64 = 0xCAFE_BABE
    await manager.onSpanEnd(spanId: spanId)

    XCTAssertEqual(mockBuffer.removedSpanIds.count, 1)
    XCTAssertEqual(mockBuffer.removedSpanIds[0], spanId)
  }

  // MARK: - 4. Nil Buffer Operations (Graceful No-Op Safety)

  func test_onSpanStart_whenBufferIsNil_safelyNoOpsWithoutCrashing() async {
    PersistenceWrapperFactory.simulateBufferFailure = true
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let spanData = MockTrace.mockSpan(name: "unbuffered_span")
    await manager.onSpanStart(span: spanData)

    XCTAssertEqual(mockBuffer.addedSpans.count, 0)
  }

  func test_onSpanAddAttribute_whenBufferIsNil_safelyNoOpsWithoutCrashing() async {
    PersistenceWrapperFactory.simulateBufferFailure = true
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await manager.onSpanAddAttribute(spanId: 0x1111, key: "key", value: "value")
    await manager.onSpanAddAttribute(spanId: 0x1111, key: "key", value: nil)

    XCTAssertEqual(mockBuffer.setAttributeCalls.count, 0)
  }

  func test_onSpanEnd_whenBufferIsNil_safelyNoOpsWithoutCrashing() async {
    PersistenceWrapperFactory.simulateBufferFailure = true
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    await manager.onSpanEnd(spanId: 0x2222)

    XCTAssertEqual(mockBuffer.removedSpanIds.count, 0)
  }

  // MARK: - 5. Sequential Execution & Concurrency

  func test_spanLifecycle_startAddAttributesAndEnd_executesInOrder() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let spanId: UInt64 = 0x5555
    let spanData = MockTrace.mockSpan(name: "lifecycle_span")

    await manager.onSpanStart(span: spanData)
    await manager.onSpanAddAttribute(spanId: spanId, key: "step", value: "1")
    await manager.onSpanAddAttribute(spanId: spanId, key: "step", value: "2")
    await manager.onSpanEnd(spanId: spanId)

    XCTAssertEqual(mockBuffer.addedSpans.count, 1)
    XCTAssertEqual(mockBuffer.setAttributeCalls.count, 2)
    XCTAssertEqual(mockBuffer.setAttributeCalls[0].value, "1")
    XCTAssertEqual(mockBuffer.setAttributeCalls[1].value, "2")
    XCTAssertEqual(mockBuffer.removedSpanIds, [spanId])
  }

  func test_concurrentSpanOperations_serializeSafelyOnActor() async {
    PersistenceWrapperFactory.mockBuffer = mockBuffer
    let manager = PersistenceManager(sessionDirectory: tempDirectoryURL)

    let operationCount = 100

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< operationCount {
        let spanId = UInt64(i + 1)
        group.addTask {
          let span = MockTrace.mockSpan(name: "concurrent_span_\(spanId)")
          await manager.onSpanStart(span: span)
          await manager.onSpanAddAttribute(spanId: spanId, key: "iteration", value: "\(i)")
          await manager.onSpanEnd(spanId: spanId)
        }
      }
    }

    XCTAssertEqual(mockBuffer.addedSpans.count, operationCount)
    XCTAssertEqual(mockBuffer.setAttributeCalls.count, operationCount)
    XCTAssertEqual(mockBuffer.removedSpanIds.count, operationCount)
  }
}
