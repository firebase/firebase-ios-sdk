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
import OpentelemetryProtos

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
}
