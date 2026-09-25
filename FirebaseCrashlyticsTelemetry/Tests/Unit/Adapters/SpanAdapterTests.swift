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
import OpentelemetryProtos
import XCTest
import nanopb

@testable import FirebaseCrashlyticsTelemetry

final class SpanAdapterTests: XCTestCase {

  // MARK: - Helpers

  /// Safely releases dynamic memory allocated for a proto span using nanopb field metadata.
  private func releaseProtoSpan(_ span: inout opentelemetry_proto_trace_v1_Span) {
    withUnsafePointer(to: opentelemetry_proto_trace_v1_Span_fields) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &span)
    }
  }

  // MARK: - toProtoTraceId

  func test_toProtoTraceId_withValidTraceId_mapsToCorrectBigEndianBytes() {
    let traceId = MockTrace.randomTraceId()

    let pointer = SpanAdapter.unsafe.toProtoTraceId(traceId: traceId)

    XCTAssertNotNil(pointer)
    if let pointer = pointer {
      XCTAssertEqual(pointer.pointee.size, pb_size_t(TraceId.size))

      let rawBase = UnsafeRawPointer(pointer)
      let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
      let typedBuffer = bytesStart.assumingMemoryBound(to: UInt64.self)

      // Big-endian validation
      XCTAssertEqual(typedBuffer[0], traceId.idHi.bigEndian)
      XCTAssertEqual(typedBuffer[1], traceId.idLo.bigEndian)

      free(pointer)
    }
  }

  func test_toProtoTraceId_withInvalidTraceId_returnsNil() {
    let pointer = SpanAdapter.unsafe.toProtoTraceId(traceId: TraceId.invalid)
    XCTAssertNil(pointer)
  }

  // MARK: - toProtoSpanId
  func test_toProtoSpanId_withValidSpanId_mapsToCorrectBigEndianBytes() {
    let spanId = MockTrace.randomSpanId()

    let pointer = SpanAdapter.unsafe.toProtoSpanId(spanId: spanId)

    XCTAssertNotNil(pointer)
    if let pointer = pointer {
      XCTAssertEqual(pointer.pointee.size, pb_size_t(SpanId.size))

      let rawBase = UnsafeRawPointer(pointer)
      let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
      let typedBuffer = bytesStart.assumingMemoryBound(to: UInt64.self)

      // Big-endian validation
      XCTAssertEqual(typedBuffer[0], spanId.rawValue.bigEndian)

      free(pointer)
    }
  }

  func test_toProtoSpanId_withInvalidSpanId_returnsNil() {
    let pointer = SpanAdapter.unsafe.toProtoSpanId(spanId: SpanId.invalid)
    XCTAssertNil(pointer)
  }

  // MARK: - toProtoSpanKind

  func test_toProtoSpanKind_mapsCorrectly() {
    XCTAssertEqual(
      SpanAdapter.unsafe.toProtoSpanKind(kind: .internal),
      opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_INTERNAL)
    XCTAssertEqual(
      SpanAdapter.unsafe.toProtoSpanKind(kind: .server),
      opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_SERVER)
    XCTAssertEqual(
      SpanAdapter.unsafe.toProtoSpanKind(kind: .client),
      opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_CLIENT)
    XCTAssertEqual(
      SpanAdapter.unsafe.toProtoSpanKind(kind: .producer),
      opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_PRODUCER)
    XCTAssertEqual(
      SpanAdapter.unsafe.toProtoSpanKind(kind: .consumer),
      opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_CONSUMER)
  }

  // MARK: - toStatusProto

  func test_toStatusProto_withUnset_returnsUnsetStatusCode() {
    let proto = SpanAdapter.unsafe.toStatusProto(status: .unset)

    XCTAssertEqual(proto.code, opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_UNSET)
    XCTAssertNil(proto.message)
  }

  func test_toStatusProto_withOk_returnsOkStatusCode() {
    let proto = SpanAdapter.unsafe.toStatusProto(status: .ok)

    XCTAssertEqual(proto.code, opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_OK)
    XCTAssertNil(proto.message)
  }

  func test_toStatusProto_withError_returnsErrorStatusCodeAndAllocatesMessage() {
    let errorDescription = "Critical Database Failure"
    let status = Status.error(description: errorDescription)
    let proto = SpanAdapter.unsafe.toStatusProto(status: status)

    XCTAssertEqual(proto.code, opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_ERROR)
    XCTAssertNotNil(proto.message)

    if let messagePtr = proto.message {
      let size = Int(messagePtr.pointee.size)
      let rawBase = UnsafeRawPointer(messagePtr)
      let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
      let messageBytes = bytesStart.assumingMemoryBound(to: UInt8.self)

      let messageData = Data(bytes: messageBytes, count: size)
      let messageString = String(data: messageData, encoding: .utf8)

      XCTAssertEqual(messageString, errorDescription)

      free(messagePtr)
    }
  }

  // MARK: - toProtoSpanEvent

  func test_toProtoSpanEvent_mapsEventAndAttributes() {
    let timestamp = Date(timeIntervalSince1970: 2000)
    let event = SpanData.Event(
      name: "cache_miss",
      timestamp: timestamp,
      attributes: ["retry_count": .int(3)]
    )

    var protoEvent = SpanAdapter.unsafe.toProtoSpanEvent(event: event)

    XCTAssertNotNil(protoEvent.name)
    XCTAssertEqual(protoEvent.time_unix_nano, UInt64(timestamp.timeIntervalSince1970.toNanoseconds))
    XCTAssertEqual(protoEvent.attributes_count, 1)
    XCTAssertNotNil(protoEvent.attributes)

    if let attributes = protoEvent.attributes {
      XCTAssertEqual(
        attributes[0].value.which_value,
        pb_size_t(opentelemetry_proto_common_v1_AnyValue_int_value_tag))
      XCTAssertEqual(attributes[0].value.int_value, 3)
    }

    // Dynamic memory cleanup
    withUnsafePointer(to: opentelemetry_proto_trace_v1_Span_Event_fields) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &protoEvent)
    }
  }

  // MARK: - toProtoSpanLink

  func test_toProtoSpanLink_mapsLinkContextAndAttributes() {
    let traceId = MockTrace.randomTraceId()
    let spanId = MockTrace.randomSpanId()
    let context = SpanContext.create(
      traceId: traceId,
      spanId: spanId,
      traceFlags: TraceFlags(),
      traceState: TraceState()
    )
    let link = SpanData.Link(context: context, attributes: ["associated": .bool(true)])

    var protoLink = SpanAdapter.unsafe.toProtoSpanLink(link: link)

    XCTAssertNotNil(protoLink.trace_id)
    XCTAssertNotNil(protoLink.span_id)
    XCTAssertEqual(protoLink.attributes_count, 1)
    XCTAssertNotNil(protoLink.attributes)

    if let attributes = protoLink.attributes {
      XCTAssertEqual(
        attributes[0].value.which_value,
        pb_size_t(opentelemetry_proto_common_v1_AnyValue_bool_value_tag))
      XCTAssertTrue(attributes[0].value.bool_value)
    }

    // Dynamic memory cleanup
    withUnsafePointer(to: opentelemetry_proto_trace_v1_Span_Link_fields) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &protoLink)
    }
  }

  // MARK: - toProtoSpan

  func test_toProtoSpan_withParentChildScenario_mapsCorrectIdentifiers() {
    let (parent, child) = MockTrace.mockParentChildTrace()

    var protoParent = SpanAdapter.unsafe.toProtoSpan(spanData: parent)
    var protoChild = SpanAdapter.unsafe.toProtoSpan(spanData: child)

    // Verify Parent Spans
    XCTAssertNotNil(protoParent.trace_id)
    XCTAssertNotNil(protoParent.span_id)
    XCTAssertNil(parent.parentSpanId, "Parent span is root; parentSpanId should be nil")
    XCTAssertEqual(protoParent.kind, opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_SERVER)
    XCTAssertEqual(protoParent.attributes_count, 2)

    // Verify Child Spans
    XCTAssertNotNil(protoChild.trace_id)
    XCTAssertNotNil(protoChild.span_id)
    XCTAssertNotNil(
      protoChild.parent_span_id, "Child span must retain parent trace relationship ID")
    XCTAssertEqual(protoChild.kind, opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_CLIENT)
    XCTAssertEqual(protoChild.attributes_count, 2)

    // Verify shared Trace ID linkage
    XCTAssertEqual(
      parent.traceId, child.traceId, "Root Trace ID must be propagated down to child span context")

    // Clean up both allocations cleanly
    releaseProtoSpan(&protoParent)
    releaseProtoSpan(&protoChild)
  }

  func test_toProtoSpan_withErrorScenario_mapsFailureDetailsAndEvents() {
    let errorSpan = MockTrace.mockErrorSpan(errorMessage: "Network Timeout Failure")

    var protoSpan = SpanAdapter.unsafe.toProtoSpan(spanData: errorSpan)

    XCTAssertEqual(
      protoSpan.status.code, opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_ERROR)
    XCTAssertEqual(protoSpan.events_count, 1)
    XCTAssertEqual(protoSpan.attributes_count, 2)

    if let events = protoSpan.events {
      XCTAssertNotNil(events[0].name)
      XCTAssertEqual(events[0].attributes_count, 2)
    }

    // Safe deallocation
    releaseProtoSpan(&protoSpan)
  }

  func test_toProtoSpan_withComplexTelemetryScenario_mapsArrayTypesCleanly() {
    let complexSpan = MockTrace.mockComplexTelemetrySpan()

    var protoSpan = SpanAdapter.unsafe.toProtoSpan(spanData: complexSpan)

    XCTAssertEqual(protoSpan.attributes_count, 5)
    XCTAssertEqual(protoSpan.links_count, 1)

    if let attributes = protoSpan.attributes {
      let count = Int(protoSpan.attributes_count)

      // Wrap the raw C pointer in an UnsafeBufferPointer to enable Swift Collection methods
      let attributesBuffer = UnsafeBufferPointer(start: attributes, count: count)

      let arrayAttr = attributesBuffer.first { attr in
        guard let keyPtr = attr.key else { return false }

        let size = Int(keyPtr.pointee.size)
        let rawBase = UnsafeRawPointer(keyPtr)
        let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
        let keyBytes = bytesStart.assumingMemoryBound(to: UInt8.self)

        let keyString = String(
          bytes: UnsafeBufferPointer(start: keyBytes, count: size),
          encoding: .utf8
        )

        return keyString == "experimental.features"
      }

      XCTAssertNotNil(arrayAttr)
      XCTAssertEqual(
        arrayAttr?.value.which_value,
        pb_size_t(opentelemetry_proto_common_v1_AnyValue_array_value_tag))
      XCTAssertEqual(arrayAttr?.value.array_value.values_count, 2)
    }

    // Safe deallocation
    releaseProtoSpan(&protoSpan)
  }
}
