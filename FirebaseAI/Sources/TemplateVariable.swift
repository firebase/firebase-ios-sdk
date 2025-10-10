
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

enum TemplateVariable: Encodable, Sendable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case array([TemplateVariable])
  case dictionary([String: TemplateVariable])

  init(value: Any) throws {
    switch value {
    case let value as String:
      self = .string(value)
    case let value as Int:
      self = .int(value)
    case let value as Double:
      self = .double(value)
    case let value as Bool:
      self = .bool(value)
    case let value as [Any]:
      self = try .array(value.map { try TemplateVariable(value: $0) })
    case let value as [String: Any]:
      self = try .dictionary(value.mapValues { try TemplateVariable(value: $0) })
    default:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: [], debugDescription: "Invalid value")
      )
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
