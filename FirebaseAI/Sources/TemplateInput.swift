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

public struct TemplateInput: Sendable {
  let kind: Kind

  public init(_ input: some TemplateInputRepresentable) {
    self = .init(kind: input.templateInputRepresentation.kind)
  }

  init(kind: Kind) {
    self.kind = kind
  }

  enum Kind: Encodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([Kind])
    case dictionary([String: Kind])

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
}

extension TemplateInput: TemplateInputRepresentable {
  public var templateInputRepresentation: TemplateInput { self }
}
