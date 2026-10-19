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
import nanopb
internal import CrashlyticsTelemetryOTelProtos

struct NanopbHelper: UnsafeOperations {}

extension UnsafeMemoryOperations where Base == NanopbHelper {
  /// Allocates a buffer in memory for a given type `T`.
  /// Allocated memory should be released with `pb_free` or `pb_release` later.
  /// - Parameter count: The number of elements of type `T` to allocate.
  /// - Returns: A pointer to the zero-initialized contiguous memory block.
  func allocateBuffer<T>(count: Int) -> UnsafeMutablePointer<T>? {
    guard count > 0 else { return nil }
    let size = MemoryLayout<T>.stride
    guard let rawPtr = calloc(count, size) else {
      LoggingHelper.logger.error(
        "Failed to allocate \(count) elements of size \(size) for type \(T.self)"
      )
      return nil
    }
    return rawPtr.assumingMemoryBound(to: T.self)
  }

  /// Allocates zeroed memory for a C-array of type `TargetProto` and maps a Swift array of
  /// `Element` into it.
  /// Allocated memory should be released with `pb_free` or `pb_release` later.
  /// - Parameters:
  ///   - elements: The source Swift array.
  ///   - transform: Closure mapping the Swift element to the target nanopb C-struct.
  /// - Returns: A tuple containing the typed dynamic buffer pointer and its element count.
  func allocateAndMapArray<Element, TargetProto>(_ elements: [Element],
                                                 transform: (Element) -> TargetProto)
    -> (UnsafeMutablePointer<
      TargetProto
    >?, pb_size_t) {
    let count = elements.count
    guard count > 0 else { return (nil, 0) }

    guard let buffer = allocateBuffer(count: count) as UnsafeMutablePointer<TargetProto>? else {
      return (nil, 0)
    }

    for (i, element) in elements.enumerated() {
      buffer[i] = transform(element)
    }

    return (buffer, pb_size_t(count))
  }

  /// Allocates a zero-initialized nanopb `pb_bytes_array_t` with the given byte count.
  /// Allocated memory should be released with `pb_free` or `pb_release` later.
  /// - Note: Because `pb_size_t` is 4 bytes (`PB_FIELD_32BIT=1`), the buffer passed to `populate`
  ///   is 4-byte aligned, not 8-byte aligned. Use `storeBytes(of:toByteOffset:as:)` or
  ///   `copyMemory(from:)` rather than `bindMemory(to:)` for types requiring 8-byte alignment.
  /// - Parameters:
  ///   - size: The size of the byte payload (e.g. 16 for TraceId, 8 for SpanId).
  ///   - populate: A closure to populate the raw byte buffer.
  /// - Returns: A pointer to the initialized `pb_bytes_array_t` allocated on the heap.
  func allocateProtoBytesArray(size: Int,
                               populate: (UnsafeMutableRawBufferPointer) -> Void)
    -> UnsafeMutablePointer<pb_bytes_array_t>? {
    guard size > 0 else { return nil }

    let allocationSize = MemoryLayout<pb_size_t>.size + size
    guard let rawPtr = calloc(1, allocationSize) else {
      LoggingHelper.logger.error("Failed to allocate pb_bytes_array_t of size: \(size)")
      return nil
    }

    let sizePtr = rawPtr.assumingMemoryBound(to: pb_size_t.self)
    sizePtr.pointee = pb_size_t(size)

    let bytesStartRawPtr = rawPtr.advanced(by: MemoryLayout<pb_size_t>.size)
    let bytesBuffer = UnsafeMutableRawBufferPointer(start: bytesStartRawPtr, count: size)

    populate(bytesBuffer)

    return rawPtr.assumingMemoryBound(to: pb_bytes_array_t.self)
  }

  /// Allocates and initializes a C `pb_bytes_array_t` from a Swift String.
  /// Allocated memory should be released with `pb_free` or `pb_release` later.
  /// - Parameter string: The Swift string to convert.
  /// - Returns: A pointer to the allocated C structure containing the UTF-8 representation of the
  /// string,
  ///            suitable for direct assignment to nanopb fields.
  func allocateProtoString(_ string: String) -> UnsafeMutablePointer<
    pb_bytes_array_t
  >? {
    let utf8Bytes = Array(string.utf8)
    let length = utf8Bytes.count
    let totalSize = length + 1

    guard
      let bytesArrayPointer = allocateProtoBytesArray(
        size: totalSize,
        populate: { buffer in
          if length > 0 {
            utf8Bytes.withUnsafeBytes { rawBufferPointer in
              if let baseAddress = rawBufferPointer.baseAddress {
                buffer.copyMemory(from: UnsafeRawBufferPointer(start: baseAddress, count: length))
              }
            }
          }

          buffer.storeBytes(of: UInt8(0), toByteOffset: length, as: UInt8.self)
        }
      )
    else {
      LoggingHelper.logger.error("Failed to allocate proto string")
      return nil
    }

    // Memory is allocated for string length + 1 to account for the null terminator,
    // and size is set to that initially. Size should not include the null terminator
    // so it has to be updated to length.
    bytesArrayPointer.pointee.size = pb_size_t(length)

    return bytesArrayPointer
  }

  /// Serializes an `ExportTraceServiceRequest` to binary `Data` and automatically releases all heap
  /// memory.
  /// - Parameter request: The nanopb request to serialize and deallocate.
  /// - Returns: The serialized binary Protobuf payload, or `nil` if serialization fails.
  func serializeAndRelease(_ request: inout opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest)
    -> Data? {
    return withUnsafePointer(
      to: opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest_fields
    ) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)

      defer {
        // Recursively free every single pointer allocated on
        // the heap after serializing the request.
        pb_release(fields, &request)
      }

      var size = 0

      // Dummy stream to calculate the size.
      var sizeStream = pb_ostream_t()
      sizeStream.callback = nil
      sizeStream.state = nil
      sizeStream.max_size = Int.max
      sizeStream.bytes_written = 0

      if pb_encode(&sizeStream, fields, &request) {
        size = sizeStream.bytes_written
      } else {
        LoggingHelper.logger.error("Failed to calculate serialization size for export request.")
        return nil
      }

      guard size > 0 else { return Data() }

      var outputData = Data(count: size)

      let success = outputData.withUnsafeMutableBytes {
        (bufferPointer: UnsafeMutableRawBufferPointer) -> Bool in
        guard let baseAddress = bufferPointer.baseAddress else { return false }
        var stream = pb_ostream_from_buffer(
          baseAddress.assumingMemoryBound(to: pb_byte_t.self), bufferPointer.count
        )
        return pb_encode(&stream, fields, &request)
      }

      guard success else {
        LoggingHelper.logger.error("Failed to encode nanopb ExportTraceServiceRequest.")
        return nil
      }

      return outputData
    }
  }

  // MARK: - Debug Formatting

  /// Generates a human-readable debug description of an `ExportTraceServiceRequest` nanopb struct,
  /// dereferencing all nested pointers, byte arrays, strings, and attributes.
  func debugDescription(for request: opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest)
    -> String {
    var lines: [String] = []
    lines.append("ExportTraceServiceRequest {")
    lines.append("  resource_spans_count: \(request.resource_spans_count)")

    if let resourceSpansPtr = request.resource_spans {
      for i in 0 ..< Int(request.resource_spans_count) {
        let rs = resourceSpansPtr[i]
        lines.append("  resource_spans[\(i)] {")
        lines.append("    schema_url: \(stringFromProtoBytes(rs.schema_url))")
        lines.append("    resource {")
        lines.append("      dropped_attributes_count: \(rs.resource.dropped_attributes_count)")
        lines.append("      entity_refs_count: \(rs.resource.entity_refs_count)")
        appendAttributes(
          rs.resource.attributes,
          count: rs.resource.attributes_count,
          indent: "      ",
          to: &lines
        )
        lines.append("    }")
        lines.append("    scope_spans_count: \(rs.scope_spans_count)")

        if let scopeSpansPtr = rs.scope_spans {
          for j in 0 ..< Int(rs.scope_spans_count) {
            let ss = scopeSpansPtr[j]
            lines.append("    scope_spans[\(j)] {")
            lines.append("      schema_url: \(stringFromProtoBytes(ss.schema_url))")
            lines.append("      scope {")
            lines.append("        name: \(stringFromProtoBytes(ss.scope.name))")
            lines.append("        version: \(stringFromProtoBytes(ss.scope.version))")
            lines.append("        dropped_attributes_count: \(ss.scope.dropped_attributes_count)")
            appendAttributes(
              ss.scope.attributes,
              count: ss.scope.attributes_count,
              indent: "        ",
              to: &lines
            )
            lines.append("      }")
            lines.append("      spans_count: \(ss.spans_count)")

            if let spansPtr = ss.spans {
              for k in 0 ..< Int(ss.spans_count) {
                appendSpan(spansPtr[k], index: k, indent: "      ", to: &lines)
              }
            }
            lines.append("    }")
          }
        }
        lines.append("  }")
      }
    }
    lines.append("}")
    return lines.joined(separator: "\n")
  }

  private func appendSpan(_ span: opentelemetry_proto_trace_v1_Span,
                          index: Int,
                          indent: String,
                          to lines: inout [String]) {
    lines.append("\(indent)spans[\(index)] {")
    lines.append("\(indent)  name: \(stringFromProtoBytes(span.name))")
    lines.append("\(indent)  trace_id: \(hexFromProtoBytes(span.trace_id))")
    lines.append("\(indent)  span_id: \(hexFromProtoBytes(span.span_id))")
    lines.append("\(indent)  parent_span_id: \(hexFromProtoBytes(span.parent_span_id))")
    lines.append("\(indent)  kind: \(formatSpanKind(span.kind))")
    lines.append("\(indent)  start_time_unix_nano: \(formatTimestamp(span.start_time_unix_nano))")
    lines.append("\(indent)  end_time_unix_nano: \(formatTimestamp(span.end_time_unix_nano))")
    lines.append(
      "\(indent)  status: { code: \(formatStatusCode(span.status.code)), message: \(stringFromProtoBytes(span.status.message)) }"
    )
    lines.append("\(indent)  flags: \(span.flags)")
    lines.append("\(indent)  dropped_attributes_count: \(span.dropped_attributes_count)")
    appendAttributes(
      span.attributes,
      count: span.attributes_count,
      indent: "\(indent)  ",
      to: &lines
    )

    lines.append("\(indent)  dropped_events_count: \(span.dropped_events_count)")
    lines.append("\(indent)  events_count: \(span.events_count)")
    if let eventsPtr = span.events {
      for eIdx in 0 ..< Int(span.events_count) {
        let event = eventsPtr[eIdx]
        lines.append("\(indent)  events[\(eIdx)] {")
        lines.append("\(indent)    name: \(stringFromProtoBytes(event.name))")
        lines.append("\(indent)    time_unix_nano: \(formatTimestamp(event.time_unix_nano))")
        lines.append("\(indent)    dropped_attributes_count: \(event.dropped_attributes_count)")
        appendAttributes(
          event.attributes,
          count: event.attributes_count,
          indent: "\(indent)    ",
          to: &lines
        )
        lines.append("\(indent)  }")
      }
    }

    lines.append("\(indent)  dropped_links_count: \(span.dropped_links_count)")
    lines.append("\(indent)  links_count: \(span.links_count)")
    if let linksPtr = span.links {
      for lIdx in 0 ..< Int(span.links_count) {
        let link = linksPtr[lIdx]
        lines.append("\(indent)  links[\(lIdx)] {")
        lines.append("\(indent)    trace_id: \(hexFromProtoBytes(link.trace_id))")
        lines.append("\(indent)    span_id: \(hexFromProtoBytes(link.span_id))")
        lines.append("\(indent)    flags: \(link.flags)")
        lines.append("\(indent)    dropped_attributes_count: \(link.dropped_attributes_count)")
        appendAttributes(
          link.attributes,
          count: link.attributes_count,
          indent: "\(indent)    ",
          to: &lines
        )
        lines.append("\(indent)  }")
      }
    }
    lines.append("\(indent)}")
  }

  private func appendAttributes(_ attributesPtr: UnsafeMutablePointer<
    opentelemetry_proto_common_v1_KeyValue
  >?,
  count: pb_size_t,
  indent: String,
  to lines: inout [String]) {
    lines.append("\(indent)attributes_count: \(count)")
    guard let attributesPtr, count > 0 else { return }
    for i in 0 ..< Int(count) {
      let kv = attributesPtr[i]
      let keyStr = stringFromProtoBytes(kv.key)
      let valStr = formatAnyValue(kv.value)
      lines.append("\(indent)attributes[\(i)]: \(keyStr) = \(valStr)")
    }
  }

  private func formatAnyValue(_ value: opentelemetry_proto_common_v1_AnyValue) -> String {
    switch Int32(value.which_value) {
    case opentelemetry_proto_common_v1_AnyValue_string_value_tag:
      return "string(\(stringFromProtoBytes(value.string_value)))"
    case opentelemetry_proto_common_v1_AnyValue_bool_value_tag:
      return "bool(\(value.bool_value))"
    case opentelemetry_proto_common_v1_AnyValue_int_value_tag:
      return "int(\(value.int_value))"
    case opentelemetry_proto_common_v1_AnyValue_double_value_tag:
      return "double(\(value.double_value))"
    case opentelemetry_proto_common_v1_AnyValue_bytes_value_tag:
      return "bytes(\(hexFromProtoBytes(value.bytes_value)))"
    case opentelemetry_proto_common_v1_AnyValue_array_value_tag:
      var items: [String] = []
      if let valuesPtr = value.array_value.values {
        for i in 0 ..< Int(value.array_value.values_count) {
          items.append(formatAnyValue(valuesPtr[i]))
        }
      }
      return "array([\(items.joined(separator: ", "))])"
    case opentelemetry_proto_common_v1_AnyValue_kvlist_value_tag:
      var pairs: [String] = []
      if let valuesPtr = value.kvlist_value.values {
        for i in 0 ..< Int(value.kvlist_value.values_count) {
          let kv = valuesPtr[i]
          pairs.append("\(stringFromProtoBytes(kv.key)): \(formatAnyValue(kv.value))")
        }
      }
      return "kvlist({\(pairs.joined(separator: ", "))})"
    case opentelemetry_proto_common_v1_AnyValue_string_value_strindex_tag:
      return "string_strindex(\(value.string_value_strindex))"
    default:
      return "<unset (which_value=\(value.which_value))>"
    }
  }

  private func stringFromProtoBytes(_ pointer: UnsafeMutablePointer<pb_bytes_array_t>?) -> String {
    guard let pointer else { return "nil" }
    let size = Int(pointer.pointee.size)
    let rawBase = UnsafeRawPointer(pointer)
    let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
    let typedBytes = bytesStart.assumingMemoryBound(to: UInt8.self)
    let data = Data(bytes: typedBytes, count: size)
    if let str = String(data: data, encoding: .utf8) {
      return "\"\(str)\""
    }
    return "<non-utf8 \(hexFromProtoBytes(pointer))>"
  }

  private func hexFromProtoBytes(_ pointer: UnsafeMutablePointer<pb_bytes_array_t>?) -> String {
    guard let pointer else { return "nil" }
    let size = Int(pointer.pointee.size)
    let rawBase = UnsafeRawPointer(pointer)
    let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
    let buffer = UnsafeBufferPointer(
      start: bytesStart.assumingMemoryBound(to: UInt8.self),
      count: size
    )
    let hex = buffer.map { String(format: "%02x", $0) }.joined()
    return "\(hex) (\(size) bytes)"
  }

  private func formatTimestamp(_ unixNano: UInt64) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(unixNano) / 1_000_000_000)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return "\(unixNano) (\(formatter.string(from: date)))"
  }

  private func formatSpanKind(_ kind: opentelemetry_proto_trace_v1_Span_SpanKind) -> String {
    switch kind {
    case opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_UNSPECIFIED:
      return "SPAN_KIND_UNSPECIFIED (0)"
    case opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_INTERNAL:
      return "SPAN_KIND_INTERNAL (1)"
    case opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_SERVER:
      return "SPAN_KIND_SERVER (2)"
    case opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_CLIENT:
      return "SPAN_KIND_CLIENT (3)"
    case opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_PRODUCER:
      return "SPAN_KIND_PRODUCER (4)"
    case opentelemetry_proto_trace_v1_Span_SpanKind_SPAN_KIND_CONSUMER:
      return "SPAN_KIND_CONSUMER (5)"
    default:
      return "UNKNOWN (\(kind.rawValue))"
    }
  }

  private func formatStatusCode(_ code: opentelemetry_proto_trace_v1_Status_StatusCode) -> String {
    switch code {
    case opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_UNSET:
      return "STATUS_CODE_UNSET (0)"
    case opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_OK:
      return "STATUS_CODE_OK (1)"
    case opentelemetry_proto_trace_v1_Status_StatusCode_STATUS_CODE_ERROR:
      return "STATUS_CODE_ERROR (2)"
    default:
      return "UNKNOWN (\(code.rawValue))"
    }
  }
}
