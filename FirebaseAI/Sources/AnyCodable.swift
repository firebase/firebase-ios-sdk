
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

struct AnyCodable: Encodable {
  let value: Any

  init(_ value: Any) {
    self.value = value
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch value {
    case let value as String:
      try container.encode(value)
    case let value as Int:
      try container.encode(value)
    case let value as Double:
      try container.encode(value)
    case let value as Bool:
      try container.encode(value)
    case let value as [Any]:
      try container.encode(value.map { AnyCodable($0) })
    case let value as [String: Any]:
      try container.encode(value.mapValues { AnyCodable($0) })
    default:
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(codingPath: [], debugDescription: "Invalid value")
      )
    }
  }
}
