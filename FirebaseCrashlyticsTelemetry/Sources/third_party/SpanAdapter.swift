/*
 * @license
 * Copyright The OpenTelemetry Authors
 * Copyright 2025 Google LLC
 *
 * This file has been modified by Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpentelemetryProtos

/// This enum is a modification of https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/Exporters/OpenTelemetryProtocolCommon/trace/SpanAdapter.swift
internal enum SpanAdapter: UnsafeOperations {}

extension UnsafeMemoryOperations where Base == SpanAdapter {
  nonisolated func toProtoSpan(spanData: SpanData)
    -> opentelemetry_proto_trace_v1_Span
  {
    var protoSpan = opentelemetry_proto_trace_v1_Span()
    protoSpan.trace_id = toProtoTraceId(traceId: spanData.traceId)
    protoSpan.span_id = toProtoSpanId(spanId: spanData.spanId)
    if let parentId = spanData.parentSpanId {
      protoSpan.parent_span_id = toProtoSpanId(spanId: parentId)
    }
    protoSpan.name = NanopbHelper.unsafe.allocateProtoString(spanData.name)
    protoSpan.kind = toProtoSpanKind(kind: spanData.kind)
    protoSpan.status = toStatusProto(status: spanData.status)
    protoSpan.start_time_unix_nano = UInt64(spanData.startTime.timeIntervalSince1970.toNanoseconds)
    protoSpan.end_time_unix_nano = UInt64(spanData.endTime.timeIntervalSince1970.toNanoseconds)

    // Attributes
    let attributesArray = Array(spanData.attributes)
    let (attrBuffer, attrCount) = NanopbHelper.unsafe.allocateAndMapArray(attributesArray) { attr in
      return CommonAdapter.unsafe.toProtoAttribute(key: attr.key, attributeValue: attr.value)
    }
    protoSpan.attributes = attrBuffer
    protoSpan.attributes_count = attrCount
    protoSpan.dropped_attributes_count = UInt32(
      spanData.totalAttributeCount - spanData.attributes.count)

    // Events
    let (eventsBuffer, eventsCount) = NanopbHelper.unsafe.allocateAndMapArray(spanData.events) {
      event in
      return toProtoSpanEvent(event: event)
    }
    protoSpan.events = eventsBuffer
    protoSpan.events_count = eventsCount
    protoSpan.dropped_events_count = UInt32(spanData.totalRecordedEvents - spanData.events.count)

    // Links
    let (linksBuffer, linksCount) = NanopbHelper.unsafe.allocateAndMapArray(spanData.links) {
      link in
      return toProtoSpanLink(link: link)
    }
    protoSpan.links = linksBuffer
    protoSpan.links_count = linksCount
    protoSpan.dropped_links_count = UInt32(spanData.totalRecordedLinks - spanData.links.count)

    return protoSpan
  }

  nonisolated func toProtoTraceId(
    traceId: TraceId
  ) -> UnsafeMutablePointer<pb_bytes_array_t>? {
    guard traceId.isValid else { return nil }

    return NanopbHelper.unsafe.allocateProtoBytesArray(size: TraceId.size) { destBuffer in
      let typedBuffer = destBuffer.bindMemory(to: UInt64.self)
      typedBuffer[0] = traceId.idHi.bigEndian
      typedBuffer[1] = traceId.idLo.bigEndian
    }
  }

  nonisolated func toProtoSpanId(
    spanId: SpanId
  ) -> UnsafeMutablePointer<pb_bytes_array_t>? {
    guard spanId.isValid else { return nil }

    return NanopbHelper.unsafe.allocateProtoBytesArray(size: SpanId.size) { destBuffer in
      let typedBuffer = destBuffer.bindMemory(to: UInt64.self)
      typedBuffer[0] = spanId.rawValue.bigEndian
    }
  }

  nonisolated func toProtoSpanKind(kind: SpanKind)
    -> opentelemetry_proto_trace_v1_Span_SpanKind
  {
    switch kind {
    case .internal:
      return opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_INTERNAL
    case .server:
      return opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_SERVER
    case .client:
      return opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_CLIENT
    case .producer:
      return opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_PRODUCER
    case .consumer:
      return opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_CONSUMER
    }
  }

  nonisolated func toProtoSpanEvent(event: SpanData.Event)
    -> opentelemetry_proto_trace_v1_Span_Event
  {
    var protoEvent = opentelemetry_proto_trace_v1_Span_Event()
    protoEvent.name = NanopbHelper.unsafe.allocateProtoString(event.name)
    protoEvent.time_unix_nano = UInt64(event.timestamp.timeIntervalSince1970.toNanoseconds)

    let attributesArray = Array(event.attributes)
    let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(attributesArray) { attr in
      return CommonAdapter.unsafe.toProtoAttribute(key: attr.key, attributeValue: attr.value)
    }
    protoEvent.attributes = buffer
    protoEvent.attributes_count = count

    return protoEvent
  }

  nonisolated func toProtoSpanLink(link: SpanData.Link)
    -> opentelemetry_proto_trace_v1_Span_Link
  {
    var protoLink = opentelemetry_proto_trace_v1_Span_Link()
    protoLink.trace_id = toProtoTraceId(traceId: link.context.traceId)
    protoLink.span_id = toProtoSpanId(spanId: link.context.spanId)

    let attributesArray = Array(link.attributes)
    let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(attributesArray) { attr in
      CommonAdapter.unsafe.toProtoAttribute(key: attr.key, attributeValue: attr.value)
    }
    protoLink.attributes = buffer
    protoLink.attributes_count = count

    return protoLink
  }

  nonisolated func toStatusProto(status: Status)
    -> opentelemetry_proto_trace_v1_Status
  {
    var statusProto = opentelemetry_proto_trace_v1_Status()
    switch status {
    case .ok:
      statusProto.code = opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_OK
    case .unset:
      statusProto.code = opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_UNSET
    case .error(let description):
      statusProto.code = opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_ERROR
      statusProto.message = NanopbHelper.unsafe.allocateProtoString(description)
    }
    return statusProto
  }
}
