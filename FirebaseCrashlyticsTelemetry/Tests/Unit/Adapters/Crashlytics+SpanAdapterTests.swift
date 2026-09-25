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

import nanopb
import OpenTelemetryApi
import OpentelemetryProtos
import OpenTelemetrySdk
import PersistenceWrapper
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class CrashlyticsSpanAdapterTests: XCTestCase {
  // MARK: - Memory Deallocation Helpers

  private func releaseProtoSpan(_ span: inout opentelemetry_proto_trace_v1_Span) {
    withUnsafePointer(to: opentelemetry_proto_trace_v1_Span_fields) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &span)
    }
  }

  private func releaseExportRequest(_ request: inout opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest) {
    withUnsafePointer(to: opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest_fields) {
      fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &request)
    }
  }

  private func stringFromProtoBytes(_ pointer: UnsafeMutablePointer<pb_bytes_array_t>?) -> String? {
    guard let pointer = pointer else { return nil }
    let size = Int(pointer.pointee.size)
    let rawBase = UnsafeRawPointer(pointer)
    let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
    let typedBytes = bytesStart.assumingMemoryBound(to: UInt8.self)
    let data = Data(bytes: typedBytes, count: size)
    return String(data: data, encoding: .utf8)
  }

  // MARK: - toPersistedSpan Tests

  func test_toPersistedSpan_withValidSpanData_mapsFieldsAndAttributesCorrectly() {
    let spanData = MockTrace.mockSpan(
      name: "swift_otel_to_persisted",
      kind: .client,
      startTime: Date(timeIntervalSince1970: 1000.0),
      duration: 2.5,
      attributes: [
        "sdk_layer": .string("swift"),
        "network_calls": .int(1),
      ]
    )

    let persistedSpan = SpanAdapter.toPersistedSpan(spanData: spanData)

    XCTAssertEqual(persistedSpan.traceIdHi, spanData.traceId.idHi)
    XCTAssertEqual(persistedSpan.traceIdLo, spanData.traceId.idLo)
    XCTAssertEqual(persistedSpan.spanId, spanData.spanId.rawValue)
    XCTAssertEqual(persistedSpan.parentSpanId, spanData.parentSpanId?.rawValue ?? 0)
    XCTAssertEqual(persistedSpan.name, "swift_otel_to_persisted")
    XCTAssertEqual(persistedSpan.startTimeNano, 1_000_000_000_000)
    XCTAssertEqual(persistedSpan.endTimeNano, 1_002_500_000_000)
    XCTAssertEqual(persistedSpan.attributes.count, 2)
    XCTAssertEqual(persistedSpan.attributes["sdk_layer"], "swift")
    XCTAssertEqual(persistedSpan.attributes["network_calls"], "1")
  }

  // MARK: - toRecoveredSpan Tests

  func test_toRecoveredSpan_withValidPersistedSpan_reconstructsSwiftNativeRecoveredSpan() {
    let inputSpan = PersistenceSpan(
      traceIdHi: 0x5555_5555_5555_5555,
      traceIdLo: 0x6666_6666_6666_6666,
      spanId: 0x7777_7777_7777_7777,
      parentSpanId: 0x8888_8888_8888_8888,
      startTimeNano: 2_000_000_000_000,
      endTimeNano: 2_003_500_000_000,
      name: "recovered_operation",
      attributes: [
        "device_model": "iPhone15,3",
        "app_version": "1.2.3",
      ]
    )

    let recoveredSpan = SpanAdapter.toRecoveredSpan(spanData: inputSpan)

    XCTAssertEqual(recoveredSpan.traceID.idHi, 0x5555_5555_5555_5555)
    XCTAssertEqual(recoveredSpan.traceID.idLo, 0x6666_6666_6666_6666)
    XCTAssertEqual(recoveredSpan.spanID.rawValue, 0x7777_7777_7777_7777)
    XCTAssertEqual(recoveredSpan.parentSpanID?.rawValue, 0x8888_8888_8888_8888)
    XCTAssertEqual(recoveredSpan.startTime.timeIntervalSince1970, 2000.0)
    XCTAssertEqual(recoveredSpan.endTime?.timeIntervalSince1970, 2003.5)
    XCTAssertEqual(recoveredSpan.name, "recovered_operation")
    XCTAssertEqual(recoveredSpan.attributes["device_model"]?.description, "iPhone15,3")
    XCTAssertEqual(recoveredSpan.attributes["app_version"]?.description, "1.2.3")
  }

  // MARK: - toProtoSpan Tests

  func test_toProtoSpan_withRecoveredSpan_mapsFieldsAndDeallocatesCleanly() {
    let errorSpanData = MockTrace.mockErrorSpan(errorMessage: "Recovered Crash Event")
    let recoveredSpan = SpanAdapter.toRecoveredSpan(
      spanData: SpanAdapter.toPersistedSpan(spanData: errorSpanData)
    )

    var protoSpan = SpanAdapter.unsafe.toProtoSpan(spanData: recoveredSpan)

    XCTAssertNotNil(protoSpan.trace_id)
    XCTAssertNotNil(protoSpan.span_id)
    XCTAssertEqual(stringFromProtoBytes(protoSpan.name), "fetch_network_configuration")
    XCTAssertEqual(
      protoSpan.start_time_unix_nano,
      UInt64(recoveredSpan.startTime.timeIntervalSince1970 * 1_000_000_000)
    )
    XCTAssertEqual(
      protoSpan.end_time_unix_nano,
      UInt64(recoveredSpan.endTime!.timeIntervalSince1970 * 1_000_000_000)
    )

    releaseProtoSpan(&protoSpan)

    XCTAssertNil(protoSpan.trace_id)
    XCTAssertNil(protoSpan.span_id)
    XCTAssertNil(protoSpan.name)
  }

  // MARK: - toProtoTraceExportRequest Tests

  func test_toProtoTraceExportRequest_withRecoveredSpans_constructsValidRequestHierarchy() {
    let (_, childSpanData) = MockTrace.mockParentChildTrace()
    let span = SpanAdapter.toRecoveredSpan(
      spanData: SpanAdapter.toPersistedSpan(spanData: childSpanData)
    )

    let scope = InstrumentationScopeInfo(
      name: "CrashlyticsSyncScope",
      version: "1.0.0",
      schemaUrl: nil,
      attributes: nil
    )

    let resource = Resource(attributes: [
      "service.name": .string("CrashlyticsOTelDaemon"),
    ])

    var request = SpanAdapter.unsafe.toProtoTraceExportRequest(
      spans: [span],
      scope: scope,
      resource: resource
    )

    XCTAssertEqual(request.resource_spans_count, 1)
    XCTAssertNotNil(request.resource_spans)

    if let resourceSpans = request.resource_spans {
      XCTAssertEqual(
        stringFromProtoBytes(resourceSpans[0].resource.attributes?[0].key), "service.name"
      )
      XCTAssertEqual(resourceSpans[0].scope_spans_count, 1)

      if let scopeSpans = resourceSpans[0].scope_spans {
        XCTAssertEqual(stringFromProtoBytes(scopeSpans[0].scope.name), "CrashlyticsSyncScope")
        XCTAssertEqual(stringFromProtoBytes(scopeSpans[0].scope.version), "1.0.0")
        XCTAssertEqual(scopeSpans[0].spans_count, 1)

        if let spans = scopeSpans[0].spans {
          XCTAssertEqual(stringFromProtoBytes(spans[0].name), "database_query_users")
          XCTAssertEqual(
            spans[0].start_time_unix_nano,
            UInt64(span.startTime.timeIntervalSince1970 * 1_000_000_000)
          )
        }
      }
    }

    releaseExportRequest(&request)
    XCTAssertNil(request.resource_spans)
  }
}
