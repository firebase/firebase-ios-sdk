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

/// This enum is a modification of https://github.com/open-telemetry/opentelemetry-swift/blob/main/Sources/Exporters/OpenTelemetryProtocolCommon/common/CommonAdapter.swift
internal enum CommonAdapter: UnsafeOperations {}

extension UnsafeMemoryOperations where Base == CommonAdapter {

  nonisolated func toProtoAttribute(
    key: String,
    attributeValue: AttributeValue
  ) -> opentelemetry_proto_common_v1_KeyValue {
    var keyValue = opentelemetry_proto_common_v1_KeyValue()

    keyValue.key = NanopbHelper.unsafe.allocateProtoString(key)
    keyValue.value = toProtoAnyValue(attributeValue: attributeValue)

    return keyValue
  }

  nonisolated func toProtoAnyValue(
    attributeValue: AttributeValue
  ) -> opentelemetry_proto_common_v1_AnyValue {
    var anyValue = opentelemetry_proto_common_v1_AnyValue()
    switch attributeValue {
    case .string(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_string_value_tag)
      anyValue.string_value = NanopbHelper.unsafe.allocateProtoString(value)
    case .bool(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_bool_value_tag)
      anyValue.bool_value = value
    case .int(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_int_value_tag)
      anyValue.int_value = Int64(value)
    case .double(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_double_value_tag)
      anyValue.double_value = value
    case .set(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_kvlist_value_tag)
      let labelsArray = Array(value.labels)
      let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(labelsArray) { (key, val) in
        return toProtoAttribute(key: key, attributeValue: val)
      }
      anyValue.kvlist_value.values = buffer
      anyValue.kvlist_value.values_count = count
    case .array(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_array_value_tag)
      let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(value.values) { element in
        return toProtoAnyValue(attributeValue: element)
      }
      anyValue.array_value.values = buffer
      anyValue.array_value.values_count = count
    case .stringArray(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_array_value_tag)
      let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(value) { element in
        return toProtoAnyValue(attributeValue: .string(element))
      }
      anyValue.array_value.values = buffer
      anyValue.array_value.values_count = count
    case .boolArray(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_array_value_tag)
      let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(value) { element in
        return toProtoAnyValue(attributeValue: .bool(element))
      }
      anyValue.array_value.values = buffer
      anyValue.array_value.values_count = count
    case .intArray(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_array_value_tag)
      let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(value) { element in
        return toProtoAnyValue(attributeValue: .int(element))
      }
      anyValue.array_value.values = buffer
      anyValue.array_value.values_count = count
    case .doubleArray(let value):
      anyValue.which_value = pb_size_t(opentelemetry_proto_common_v1_AnyValue_array_value_tag)
      let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(value) { element in
        return toProtoAnyValue(attributeValue: .double(element))
      }
      anyValue.array_value.values = buffer
      anyValue.array_value.values_count = count
    }

    return anyValue
  }

  nonisolated func toProtoResource(
    resource: Resource
  ) -> opentelemetry_proto_resource_v1_Resource {
    var outputResource = opentelemetry_proto_resource_v1_Resource()

    let attributesArray = Array(resource.attributes)
    let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(attributesArray) { attr in
      return toProtoAttribute(key: attr.key, attributeValue: attr.value)
    }

    outputResource.attributes = buffer
    outputResource.attributes_count = count

    return outputResource
  }

  nonisolated func toProtoInstrumentationScope(
    instrumentationScopeInfo: InstrumentationScopeInfo
  ) -> opentelemetry_proto_common_v1_InstrumentationScope {
    var instrumentationScope = opentelemetry_proto_common_v1_InstrumentationScope()
    instrumentationScope.name = NanopbHelper.unsafe.allocateProtoString(
      instrumentationScopeInfo.name)

    if let version = instrumentationScopeInfo.version {
      instrumentationScope.version = NanopbHelper.unsafe.allocateProtoString(version)
    }

    if let attributes = instrumentationScopeInfo.attributes {
      let attributesArray = Array(attributes)
      let (buffer, count) = NanopbHelper.unsafe.allocateAndMapArray(attributesArray) { attr in
        return toProtoAttribute(key: attr.key, attributeValue: attr.value)
      }

      instrumentationScope.attributes = buffer
      instrumentationScope.attributes_count = count
    }

    return instrumentationScope
  }

}
