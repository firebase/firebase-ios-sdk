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
import OpentelemetryProtos
import XCTest

@testable import FirebaseCrashlyticsTelemetry

final class NanopbHelperTests: XCTestCase {
  private struct DummyTarget {
    var value: Int64
    var flag: Bool
  }

  // MARK: - allocateZeroed

  func test_allocateZeroed_withValidCount_allocatesContiguousZeroedMemory() {
    let count = 5
    let stride = MemoryLayout<DummyTarget>.stride

    let pointer =
      NanopbHelper.unsafe.allocateBuffer(count: count) as UnsafeMutablePointer<DummyTarget>?

    XCTAssertNotNil(pointer)

    if let pointer = pointer {
      let totalBytes = count * stride
      pointer.withMemoryRebound(to: UInt8.self, capacity: totalBytes) { bytePointer in
        for i in 0 ..< totalBytes {
          XCTAssertEqual(bytePointer[i], 0, "Byte at index \(i) was not zero-initialized.")
        }
      }
      free(pointer)
    }
  }

  func test_allocateZeroed_withZeroOrNegativeCount_returnsNil() {
    let zeroResult =
      NanopbHelper.unsafe.allocateBuffer(count: 0) as UnsafeMutablePointer<DummyTarget>?
    let negativeResult =
      NanopbHelper.unsafe.allocateBuffer(count: -10) as UnsafeMutablePointer<DummyTarget>?

    XCTAssertNil(zeroResult, "Allocation of 0 elements should return nil")
    XCTAssertNil(negativeResult, "Allocation of negative elements should return nil")
  }

  // MARK: - allocateAndMapArray

  func test_allocateAndMapArray_withEmptyArray_returnsNilAndZero() {
    let emptySource: [Int] = []

    let (pointer, count) = NanopbHelper.unsafe.allocateAndMapArray(emptySource) {
      (element: Int) -> DummyTarget in
      return DummyTarget(value: Int64(element), flag: true)
    }

    XCTAssertNil(pointer)
    XCTAssertEqual(count, 0)
  }

  func test_allocateAndMapArray_withPopulatedArray_mapsToContiguousMemory() {
    let source = [10, 20, 30]

    let (pointer, count) = NanopbHelper.unsafe.allocateAndMapArray(source) {
      (element: Int) -> DummyTarget in
      return DummyTarget(value: Int64(element), flag: element % 20 == 0)
    }

    XCTAssertNotNil(pointer)
    XCTAssertEqual(count, pb_size_t(source.count))

    if let pointer = pointer {
      // Verify order and contents
      XCTAssertEqual(pointer[0].value, 10)
      XCTAssertFalse(pointer[0].flag)

      XCTAssertEqual(pointer[1].value, 20)
      XCTAssertTrue(pointer[1].flag)

      XCTAssertEqual(pointer[2].value, 30)
      XCTAssertFalse(pointer[2].flag)

      free(pointer)
    }
  }

  // MARK: - allocateProtoBytesArray

  func test_allocateProtoBytesArray_withValidSize_populatesAndReturnsPointer() {
    let mockBytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
    let size = mockBytes.count

    let pointer = NanopbHelper.unsafe.allocateProtoBytesArray(size: size) { rawBuffer in
      mockBytes.withUnsafeBytes { sourceBuffer in
        if let sourceBase = sourceBuffer.baseAddress {
          rawBuffer.copyMemory(from: UnsafeRawBufferPointer(start: sourceBase, count: size))
        }
      }
    }

    XCTAssertNotNil(pointer)

    if let pointer = pointer {
      XCTAssertEqual(pointer.pointee.size, pb_size_t(size))

      // Extract the bytes starting past the size header
      let rawBase = UnsafeRawPointer(pointer)
      let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
      let typedBytes = bytesStart.assumingMemoryBound(to: UInt8.self)

      for i in 0 ..< size {
        XCTAssertEqual(typedBytes[i], mockBytes[i], "Byte mismatch at offset \(i)")
      }

      free(pointer)
    }
  }

  func test_allocateProtoBytesArray_withInvalidSize_returnsNil() {
    let pointer = NanopbHelper.unsafe.allocateProtoBytesArray(size: 0) { _ in }
    XCTAssertNil(pointer, "An allocation size of 0 should return nil")
  }

  // MARK: - allocateProtoString

  func test_allocateProtoString_withEmptyString_returnsZeroSizeNullTerminated() {
    let pointer = NanopbHelper.unsafe.allocateProtoString("")

    XCTAssertNotNil(pointer)

    if let pointer = pointer {
      XCTAssertEqual(pointer.pointee.size, 0)

      let rawBase = UnsafeRawPointer(pointer)
      let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
      let firstByte = bytesStart.load(as: UInt8.self)

      XCTAssertEqual(firstByte, 0, "Empty protoString must be null-terminated")

      free(pointer)
    }
  }

  func test_allocateProtoString_withASCIIString_allocatesAndNullTerminates() {
    let testString = "Hello"
    let expectedBytes = Array(testString.utf8)

    let pointer = NanopbHelper.unsafe.allocateProtoString(testString)

    XCTAssertNotNil(pointer)

    if let pointer = pointer {
      XCTAssertEqual(pointer.pointee.size, pb_size_t(expectedBytes.count))

      let rawBase = UnsafeRawPointer(pointer)
      let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
      let typedBytes = bytesStart.assumingMemoryBound(to: UInt8.self)

      // Verify payload
      for i in 0 ..< expectedBytes.count {
        XCTAssertEqual(typedBytes[i], expectedBytes[i])
      }

      // Verify null terminator
      XCTAssertEqual(
        typedBytes[expectedBytes.count], 0, "String payload must end with a null terminator"
      )

      free(pointer)
    }
  }

  func test_allocateProtoString_withUnicodeString_calculatesSizeBasedOnBytes() {
    let testString = "Telemetry🚀" // "🚀" takes up 4 UTF-8 bytes
    let expectedBytes = Array(testString.utf8)

    let pointer = NanopbHelper.unsafe.allocateProtoString(testString)

    XCTAssertNotNil(pointer)

    if let pointer = pointer {
      XCTAssertEqual(pointer.pointee.size, pb_size_t(expectedBytes.count))

      let rawBase = UnsafeRawPointer(pointer)
      let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
      let typedBytes = bytesStart.assumingMemoryBound(to: UInt8.self)

      for i in 0 ..< expectedBytes.count {
        XCTAssertEqual(typedBytes[i], expectedBytes[i])
      }

      XCTAssertEqual(typedBytes[expectedBytes.count], 0)

      free(pointer)
    }
  }

  // MARK: - serializeAndRelease

  func test_serializeAndRelease_withEmptyRequest_succeedsSilently() {
    var request = opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest()

    let data = NanopbHelper.unsafe.serializeAndRelease(&request)

    XCTAssertNotNil(data, "Serialization should succeed even on zeroed request struct")
  }

  func test_serializeAndRelease_withNestedAllocations_encodesAndSafelyReleasesMemory() {
    var request = opentelemetry_proto_collector_trace_v1_ExportTraceServiceRequest()

    // Populate nested heap pointers to test standard deallocation via pb_release
    let (spansBuffer, spansCount) = NanopbHelper.unsafe.allocateAndMapArray([1]) {
      _ -> opentelemetry_proto_trace_v1_ResourceSpans in
      var resourceSpan = opentelemetry_proto_trace_v1_ResourceSpans()
      resourceSpan.schema_url = NanopbHelper.unsafe.allocateProtoString(
        "https://opentelemetry.io/schemas/1.20.0"
      )
      return resourceSpan
    }

    request.resource_spans = spansBuffer
    request.resource_spans_count = spansCount

    // Run serialization
    let data = NanopbHelper.unsafe.serializeAndRelease(&request)

    XCTAssertNotNil(data, "Data encoding failed")
    XCTAssertGreaterThan(data?.count ?? 0, 0, "Serialization should contain encoded protobuf bytes")
    XCTAssertNil(
      request.resource_spans,
      "serializeAndRelease must trigger pb_release, resetting heap pointers to nil"
    )
  }
}
