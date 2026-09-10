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

package import GeminiSharedDataModels

/// The input for the interaction.
package enum InteractionsInput: Codable, Sendable, Equatable, Hashable {

  case string(String)
  case stepList([Step])
  case contentList([Content])
  case content(Content)

  package init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let val = try? container.decode(String.self) {
      self = .string(val)
      return
    }
    if let val = try? container.decode([Step].self) {
      self = .stepList(val)
      return
    }
    if let val = try? container.decode([Content].self) {
      self = .contentList(val)
      return
    }
    if let val = try? container.decode(Content.self) {
      self = .content(val)
      return
    }
    throw DecodingError.typeMismatch(
      InteractionsInput.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "Failed to decode any of the variants for InteractionsInput"
      )
    )
  }

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let val):
      try container.encode(val)
    case .stepList(let val):
      try container.encode(val)
    case .contentList(let val):
      try container.encode(val)
    case .content(let val):
      try container.encode(val)
    }
  }
}
