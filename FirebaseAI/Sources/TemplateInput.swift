// Copyright 2025 Google LLC
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

enum TemplateInput: Encodable, Equatable, Sendable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case array([TemplateInput])
  case dictionary([String: TemplateInput])

  init(value: Any) throws {
    switch value {
    // `NSNumber` bridges to both `Bool` and `Int`, so booleans and integers originating from
    // Foundation containers (for example, `JSONSerialization` output) are indistinguishable by
    // `as?` alone: `NSNumber(value: true) as? Int` is `1` and `NSNumber(value: 1) as? Bool` is
    // `true`. Check the underlying CoreFoundation type first to disambiguate.
    case let value as NSNumber where CFGetTypeID(value) == CFBooleanGetTypeID():
      self = .bool(value.boolValue)
    case let value as String:
      self = .string(value)
    case let value as Int:
      self = .int(value)
    case let value as Double:
      self = .double(value)
    case let value as Float:
      self = .double(Double(value))
    case let value as Bool:
      self = .bool(value)
    case let value as [Any]:
      self = try .array(value.map { try TemplateInput(value: $0) })
    case let value as [String: Any]:
      self = try .dictionary(value.mapValues { try TemplateInput(value: $0) })
    default:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: [], debugDescription: """
        Unsupported template input of type \(type(of: value)); supported types are String, Int, \
        Double, Float, Bool, arrays of these types, and dictionaries keyed by String.
        """)
      )
    }
  }

  /// Converts a dictionary of raw template input values into ``TemplateInput`` values.
  ///
  /// - Parameter values: Template variable names mapped to their values.
  /// - Returns: The converted template inputs.
  /// - Throws: An `EncodingError.invalidValue` identifying the offending variable name if a value
  ///   is not a supported template input type.
  static func inputs(from values: [String: Any]) throws -> [String: TemplateInput] {
    return try values.reduce(into: [String: TemplateInput]()) { inputs, element in
      do {
        inputs[element.key] = try TemplateInput(value: element.value)
      } catch {
        throw EncodingError.invalidValue(
          element.value,
          EncodingError.Context(
            codingPath: [TemplateInputCodingKey(stringValue: element.key)],
            debugDescription: """
            Unsupported value of type \(type(of: element.value)) for template input \
            "\(element.key)"; supported types are String, Int, Double, Float, Bool, arrays of \
            these types, and dictionaries keyed by String.
            """,
            underlyingError: error
          )
        )
      }
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .string(value):
      try container.encode(value)
    case let .int(value):
      try container.encode(value)
    case let .double(value):
      try container.encode(value)
    case let .bool(value):
      try container.encode(value)
    case let .array(value):
      try container.encode(value)
    case let .dictionary(value):
      try container.encode(value)
    }
  }
}

/// Identifies a template variable name in an `EncodingError`'s coding path.
private struct TemplateInputCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int? = nil

  init(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue: Int) {
    assertionFailure("Unexpected \(Self.self) with integer value: \(intValue)")
    return nil
  }
}
