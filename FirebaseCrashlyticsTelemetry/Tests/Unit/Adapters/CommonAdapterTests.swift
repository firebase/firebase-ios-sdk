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

final class CommonAdapterTests: XCTestCase {

  // MARK: - Helpers

  /// Safely releases dynamic memory allocated for a proto KeyValue.
  private func releaseKeyValue(_ keyValue: inout opentelemetry_proto_common_v1_KeyValue) {
    withUnsafePointer(to: opentelemetry_proto_common_v1_KeyValue_fields) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &keyValue)
    }
  }

  /// Safely releases dynamic memory allocated for a proto AnyValue.
  private func releaseAnyValue(_ anyValue: inout opentelemetry_proto_common_v1_AnyValue) {
    withUnsafePointer(to: opentelemetry_proto_common_v1_AnyValue_fields) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &anyValue)
    }
  }

  /// Safely releases dynamic memory allocated for a proto Resource.
  private func releaseResource(_ resource: inout opentelemetry_proto_resource_v1_Resource) {
    withUnsafePointer(to: opentelemetry_proto_resource_v1_Resource_fields) { fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &resource)
    }
  }

  /// Safely releases dynamic memory allocated for a proto InstrumentationScope.
  private func releaseScope(_ scope: inout opentelemetry_proto_common_v1_InstrumentationScope) {
    withUnsafePointer(to: opentelemetry_proto_common_v1_InstrumentationScope_fields) {
      fieldsTuplePointer in
      let fields = UnsafeRawPointer(fieldsTuplePointer).assumingMemoryBound(to: pb_field_t.self)
      pb_release(fields, &scope)
    }
  }

  /// Decodes a Swift string out of a dynamically allocated `pb_bytes_array_t` pointer.
  private func stringFromProtoBytes(_ pointer: UnsafeMutablePointer<pb_bytes_array_t>?) -> String? {
    guard let pointer = pointer else { return nil }
    let size = Int(pointer.pointee.size)
    let rawBase = UnsafeRawPointer(pointer)
    let bytesStart = rawBase.advanced(by: MemoryLayout<pb_size_t>.size)
    let typedBytes = bytesStart.assumingMemoryBound(to: UInt8.self)
    let data = Data(bytes: typedBytes, count: size)
    return String(data: data, encoding: .utf8)
  }

  // MARK: - toProtoAttribute

  func test_toProtoAttribute_mapsBasicTypesCorrectly() {
    var stringAttr = CommonAdapter.unsafe.toProtoAttribute(
      key: "env", attributeValue: .string("staging"))
    XCTAssertEqual(stringFromProtoBytes(stringAttr.key), "env")
    XCTAssertEqual(
      stringAttr.value.which_value,
      pb_size_t(opentelemetry_proto_common_v1_AnyValue_string_value_tag))
    XCTAssertEqual(stringFromProtoBytes(stringAttr.value.string_value), "staging")
    releaseKeyValue(&stringAttr)

    var boolAttr = CommonAdapter.unsafe.toProtoAttribute(key: "debug", attributeValue: .bool(true))
    XCTAssertEqual(stringFromProtoBytes(boolAttr.key), "debug")
    XCTAssertEqual(
      boolAttr.value.which_value, pb_size_t(opentelemetry_proto_common_v1_AnyValue_bool_value_tag))
    XCTAssertTrue(boolAttr.value.bool_value)
    releaseKeyValue(&boolAttr)

    var intAttr = CommonAdapter.unsafe.toProtoAttribute(key: "port", attributeValue: .int(8080))
    XCTAssertEqual(
      intAttr.value.which_value, pb_size_t(opentelemetry_proto_common_v1_AnyValue_int_value_tag))
    XCTAssertEqual(intAttr.value.int_value, 8080)
    releaseKeyValue(&intAttr)

    var doubleAttr = CommonAdapter.unsafe.toProtoAttribute(
      key: "pi", attributeValue: .double(3.14159))
    XCTAssertEqual(
      doubleAttr.value.which_value,
      pb_size_t(opentelemetry_proto_common_v1_AnyValue_double_value_tag))
    XCTAssertEqual(doubleAttr.value.double_value, 3.14159)
    releaseKeyValue(&doubleAttr)
  }

  // MARK: - toProtoAnyValue

  func test_toProtoAnyValue_withSet_mapsKeyValueList() {
    let nestedAttributes: [String: AttributeValue] = [
      "nested_key": .string("nested_val")
    ]
    let attributeValueSet = AttributeValue.set(AttributeSet(labels: nestedAttributes))

    var protoAny = CommonAdapter.unsafe.toProtoAnyValue(attributeValue: attributeValueSet)

    XCTAssertEqual(
      protoAny.which_value, pb_size_t(opentelemetry_proto_common_v1_AnyValue_kvlist_value_tag))
    XCTAssertEqual(protoAny.kvlist_value.values_count, 1)
    XCTAssertNotNil(protoAny.kvlist_value.values)

    if let values = protoAny.kvlist_value.values {
      XCTAssertEqual(stringFromProtoBytes(values[0].key), "nested_key")
      XCTAssertEqual(stringFromProtoBytes(values[0].value.string_value), "nested_val")
    }

    releaseAnyValue(&protoAny)
  }

  func test_toProtoAnyValue_withArray_mapsAnyValueArray() {
    let values: [AttributeValue] = [.string("one"), .int(2)]
    let attributeValueArray = AttributeValue.array(AttributeArray(values: values))

    var protoAny = CommonAdapter.unsafe.toProtoAnyValue(attributeValue: attributeValueArray)

    XCTAssertEqual(
      protoAny.which_value, pb_size_t(opentelemetry_proto_common_v1_AnyValue_array_value_tag))
    XCTAssertEqual(protoAny.array_value.values_count, 2)
    XCTAssertNotNil(protoAny.array_value.values)

    if let elements = protoAny.array_value.values {
      XCTAssertEqual(
        elements[0].which_value, pb_size_t(opentelemetry_proto_common_v1_AnyValue_string_value_tag))
      XCTAssertEqual(stringFromProtoBytes(elements[0].string_value), "one")

      XCTAssertEqual(
        elements[1].which_value, pb_size_t(opentelemetry_proto_common_v1_AnyValue_int_value_tag))
      XCTAssertEqual(elements[1].int_value, 2)
    }

    releaseAnyValue(&protoAny)
  }

  func test_toProtoAnyValue_withSpecializedArrays_mapsCorrectTypes() {
    var stringArrayProto = CommonAdapter.unsafe.toProtoAnyValue(
      attributeValue: .array(
        AttributeArray(values: [AttributeValue("apple"), AttributeValue("banana")])
      )
    )
    XCTAssertEqual(
      stringArrayProto.which_value,
      pb_size_t(opentelemetry_proto_common_v1_AnyValue_array_value_tag))
    XCTAssertEqual(stringArrayProto.array_value.values_count, 2)
    XCTAssertEqual(
      stringFromProtoBytes(stringArrayProto.array_value.values?[0].string_value), "apple")
    XCTAssertEqual(
      stringFromProtoBytes(stringArrayProto.array_value.values?[1].string_value), "banana")
    releaseAnyValue(&stringArrayProto)

    var boolArrayProto = CommonAdapter.unsafe.toProtoAnyValue(
      attributeValue: .array(
        AttributeArray(values: [AttributeValue(true), AttributeValue(false)])
      )
    )
    XCTAssertEqual(boolArrayProto.array_value.values_count, 2)
    XCTAssertEqual(boolArrayProto.array_value.values?[0].bool_value, true)
    XCTAssertEqual(boolArrayProto.array_value.values?[1].bool_value, false)
    releaseAnyValue(&boolArrayProto)

    var intArrayProto = CommonAdapter.unsafe.toProtoAnyValue(
      attributeValue: .array(
        AttributeArray(values: [AttributeValue(42), AttributeValue(84)])
      )
    )
    XCTAssertEqual(intArrayProto.array_value.values_count, 2)
    XCTAssertEqual(intArrayProto.array_value.values?[0].int_value, 42)
    XCTAssertEqual(intArrayProto.array_value.values?[1].int_value, 84)
    releaseAnyValue(&intArrayProto)

    var doubleArrayProto = CommonAdapter.unsafe.toProtoAnyValue(
      attributeValue: .array(
        AttributeArray(values: [AttributeValue(1.11), AttributeValue(2.22)])
      )
    )
    XCTAssertEqual(doubleArrayProto.array_value.values_count, 2)
    XCTAssertEqual(doubleArrayProto.array_value.values?[0].double_value, 1.11)
    XCTAssertEqual(doubleArrayProto.array_value.values?[1].double_value, 2.22)
    releaseAnyValue(&doubleArrayProto)
  }

  // MARK: - toProtoResource

  func test_toProtoResource_mapsResourceAttributes() {
    let resource = Resource(attributes: [
      "service.name": .string("CrashlyticsService"),
      "service.version": .string("1.0.0"),
    ])

    var protoResource = CommonAdapter.unsafe.toProtoResource(resource: resource)

    XCTAssertEqual(protoResource.attributes_count, 2)
    XCTAssertNotNil(protoResource.attributes)

    if let attributes = protoResource.attributes {
      let buffer = UnsafeBufferPointer(
        start: attributes, count: Int(protoResource.attributes_count))
      let names = buffer.compactMap { stringFromProtoBytes($0.key) }
      XCTAssertTrue(names.contains("service.name"))
      XCTAssertTrue(names.contains("service.version"))
    }

    releaseResource(&protoResource)
  }

  // MARK: - toProtoInstrumentationScope

  func test_toProtoInstrumentationScope_mapsDetailsAndAttributes() {
    let scopeInfo = InstrumentationScopeInfo(
      name: "firebase-crashlytics-otel",
      version: "2.1.0",
      schemaUrl: nil,
      attributes: ["scope_priority": .int(1)]
    )

    var protoScope = CommonAdapter.unsafe.toProtoInstrumentationScope(
      instrumentationScopeInfo: scopeInfo)

    XCTAssertEqual(stringFromProtoBytes(protoScope.name), "firebase-crashlytics-otel")
    XCTAssertEqual(stringFromProtoBytes(protoScope.version), "2.1.0")
    XCTAssertEqual(protoScope.attributes_count, 1)
    XCTAssertNotNil(protoScope.attributes)

    if let attributes = protoScope.attributes {
      XCTAssertEqual(stringFromProtoBytes(attributes[0].key), "scope_priority")
      XCTAssertEqual(
        attributes[0].value.which_value,
        pb_size_t(opentelemetry_proto_common_v1_AnyValue_int_value_tag))
      XCTAssertEqual(attributes[0].value.int_value, 1)
    }

    releaseScope(&protoScope)
  }
}
