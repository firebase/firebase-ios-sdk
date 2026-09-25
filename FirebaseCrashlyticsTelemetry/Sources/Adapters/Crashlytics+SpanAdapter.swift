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
import OpentelemetryProtos
import PersistenceWrapper

/// Adds Crashlytics-specific conversions to the OpenTelemetry span adapter.
///
/// This extension isolates custom data translations from the standard OpenTelemetry
/// Protobuf pipeline, handling conversions for all Crashlytics-specific formats.
extension SpanAdapter {

  /// Converts standard OpenTelemetry span data into an ObjC persisted span.
  ///
  /// - Parameter spanData: The Swift OpenTelemetry span to be converted.
  /// - Returns: A ObjC native `PersistenceSpan`.
  nonisolated static func toPersistedSpan(spanData: SpanData) -> PersistenceSpan {
    var attributesMap: [String: String] = [:]
    for (key, value) in spanData.attributes {
      attributesMap[key] = value.description
    }

    let startTimeNanoseconds = UInt64(spanData.startTime.timeIntervalSince1970 * 1_000_000_000)
    let endTimeNanoseconds = UInt64(spanData.endTime.timeIntervalSince1970 * 1_000_000_000)

    return PersistenceSpan(
      traceIdHi: spanData.traceId.idHi,
      traceIdLo: spanData.traceId.idLo,
      spanId: spanData.spanId.rawValue,
      parentSpanId: spanData.parentSpanId?.rawValue ?? 0,
      startTimeNano: startTimeNanoseconds,
      endTimeNano: endTimeNanoseconds,
      name: spanData.name,
      attributes: attributesMap
    )
  }

  /// Converts an ObjC persisted span into a Swift `RecoveredSpan`.
  ///
  /// - Parameter spanData: The recovered span to be converted.
  /// - Returns: A Swift native `RecoveredSpan`.
  nonisolated static func toRecoveredSpan(spanData: PersistenceSpan) -> RecoveredSpan {
    let traceID = TraceId(idHi: spanData.traceIdHi, idLo: spanData.traceIdLo)
    let spanID = SpanId(id: spanData.spanId)
    let parentSpanID = spanData.parentSpanId == 0 ? nil : SpanId(id: spanData.parentSpanId)
    let startTime = Date(timeIntervalSince1970: TimeInterval(spanData.startTimeNano) / 1_000_000_000)
    let endTime = Date(timeIntervalSince1970: TimeInterval(spanData.endTimeNano) / 1_000_000_000)

    var swiftAttributes: [String: AttributeValue] = [:]
    for (key, value) in spanData.attributes {
      swiftAttributes[key] = AttributeValue(value)
    }

    return RecoveredSpan(
      traceID: traceID,
      spanID: spanID,
      parentSpanID: parentSpanID,
      startTime: startTime,
      endTime: endTime,
      name: spanData.name,
      attributes: swiftAttributes
    )
  }

  nonisolated static func toTraceExportRequestPayload(
    spans: [RecoveredSpan],
    scope: InstrumentationScopeInfo?,
    resource: Resource?
  ) -> Data? {
    var proto = unsafe.toProtoTraceExportRequest(
      spans: spans, scope: scope, resource: resource
    )
    return NanopbHelper.unsafe.serializeAndRelease(&proto)
  }
}

extension UnsafeMemoryOperations where Base == SpanAdapter {
  /// Converts a Crashlytics RecoveredSpan in to an OpenTelemetry span proto.
  ///
  /// - Parameter spanData: The recovered span to be converted.
  /// - Returns: An OpenTelemetry span proto.
  nonisolated func toProtoSpan(
    spanData: RecoveredSpan
  ) -> opentelemetry_proto_trace_v1_Span {
    var protoSpan = opentelemetry_proto_trace_v1_Span()
    protoSpan.trace_id = toProtoTraceId(traceId: spanData.traceID)
    protoSpan.span_id = toProtoSpanId(spanId: spanData.spanID)
    if let parentID = spanData.parentSpanID {
      protoSpan.parent_span_id = toProtoSpanId(spanId: parentID)
    }
    protoSpan.name = NanopbHelper.unsafe.allocateProtoString(spanData.name)
    protoSpan.kind = toProtoSpanKind(kind: spanData.kind)
    protoSpan.start_time_unix_nano = spanData.startTime.timeIntervalSince1970.toNanoseconds
    protoSpan.status = toStatusProto(status: spanData.status)

    // TODO: Add logic to specify a correct endTimestamp.
    if let endTime = spanData.endTime {
      protoSpan.end_time_unix_nano = endTime.timeIntervalSince1970.toNanoseconds
    } else {
      protoSpan.end_time_unix_nano = Date().timeIntervalSince1970.toNanoseconds
    }

    let attributesArray = Array(spanData.attributes)
    let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(attributesArray) { attr in
      CommonAdapter.unsafe.toProtoAttribute(key: attr.key, attributeValue: attr.value)
    }
    protoSpan.attributes = buffer
    protoSpan.attributes_count = count

    return protoSpan
  }

  /// Creates a trace export request proto.
  ///
  /// - Parameters:
  ///   - spans: The spans to be included in the export request.
  ///   - scope: The scope associated with the spans.
  ///   - resource: The resource associated with the spans.
  /// - Returns: An export trace service request proto.
  nonisolated func toProtoTraceExportRequest(
    spans: [RecoveredSpan],
    scope: InstrumentationScopeInfo?,
    resource: Resource?
  ) -> opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest {
    // Scope Spans
    var scopeSpans = opentelemetry_proto_trace_v1_ScopeSpans()
    if let scope = scope {
      scopeSpans.scope = CommonAdapter.unsafe.toProtoInstrumentationScope(
        instrumentationScopeInfo: scope
      )
    }
    let (spansBuffer, spansCount) = NanopbHelper.unsafe.allocateAndMapArray(spans) { span in
      return toProtoSpan(spanData: span)
    }
    scopeSpans.spans = spansBuffer
    scopeSpans.spans_count = spansCount

    // Resource Spans
    var resourceSpans = opentelemetry_proto_trace_v1_ResourceSpans()
    if let resource = resource {
      resourceSpans.resource = CommonAdapter.unsafe.toProtoResource(resource: resource)
    }
    let (scopeSpansBuffer, scopeSpansCount) = NanopbHelper.unsafe.allocateAndMapArray([scopeSpans])
    { $0 }
    resourceSpans.scope_spans = scopeSpansBuffer
    resourceSpans.scope_spans_count = scopeSpansCount

    // Export Trace Service Request
    var request = opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest()
    let (resourceSpansBuffer, resourceSpansCount) = NanopbHelper.unsafe.allocateAndMapArray([
      resourceSpans
    ]
    ) { $0 }
    request.resource_spans = resourceSpansBuffer
    request.resource_spans_count = resourceSpansCount

    return request
  }
}
