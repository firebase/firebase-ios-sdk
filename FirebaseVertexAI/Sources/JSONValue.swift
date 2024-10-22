// Copyright 2024 Google LLC
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

/// A collection of name-value pairs representing a JSON object.
///
/// This may be decoded from, or encoded to, a
/// [`google.protobuf.Struct`](https://protobuf.dev/reference/protobuf/google.protobuf/#struct).
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public typealias JSONObject = [String: JSONValue]

/// Represents a value in one of JSON's data types.
///
/// This may be decoded from, or encoded to, a
/// [`google.protobuf.Value`](https://protobuf.dev/reference/protobuf/google.protobuf/#value).
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public enum JSONValue: Sendable {
  /// A `null` value.
  case null

  /// A numeric value.
  case number(Double)

  /// A string value.
  case string(String)

  /// A boolean value.
  case bool(Bool)

  /// A JSON object.
  case object(JSONObject)

  /// An array of `JSONValue`s.
  case array([JSONValue])
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONValue: Decodable {
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let numberValue = try? container.decode(Double.self) {
      self = .number(numberValue)
    } else if let stringValue = try? container.decode(String.self) {
      self = .string(stringValue)
    } else if let boolValue = try? container.decode(Bool.self) {
      self = .bool(boolValue)
    } else if let objectValue = try? container.decode(JSONObject.self) {
      self = .object(objectValue)
    } else if let arrayValue = try? container.decode([JSONValue].self) {
      self = .array(arrayValue)
    } else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Failed to decode JSON value."
      )
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONValue: Encodable {
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case let .number(numberValue):
      // Convert to `Decimal` before encoding for consistent floating-point serialization across
      // platforms. E.g., `Double` serializes 3.14159 as 3.1415899999999999 in some cases and
      // 3.14159 in others. See
      // https://forums.swift.org/t/jsonencoder-encodable-floating-point-rounding-error/41390/4 for
      // more details.
      try container.encode(Decimal(numberValue))
    case let .string(stringValue):
      try container.encode(stringValue)
    case let .bool(boolValue):
      try container.encode(boolValue)
    case let .object(objectValue):
      try container.encode(objectValue)
    case let .array(arrayValue):
      try container.encode(arrayValue)
    }
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension JSONValue: Equatable {}
