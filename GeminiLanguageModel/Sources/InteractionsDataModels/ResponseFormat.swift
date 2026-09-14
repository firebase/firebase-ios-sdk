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

/// An internal data model for `ResponseFormat`.
package enum ResponseFormat: Codable, Sendable, Equatable, Hashable {

  case audioResponseFormat(AudioResponseFormat)
  case textResponseFormat(TextResponseFormat)
  case imageResponseFormat(ImageResponseFormat)
  case videoResponseFormat(VideoResponseFormat)
  case custom([String: JSONValue])

  package init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let val = try? container.decode(AudioResponseFormat.self) {
      self = .audioResponseFormat(val)
      return
    }
    if let val = try? container.decode(TextResponseFormat.self) {
      self = .textResponseFormat(val)
      return
    }
    if let val = try? container.decode(ImageResponseFormat.self) {
      self = .imageResponseFormat(val)
      return
    }
    if let val = try? container.decode(VideoResponseFormat.self) {
      self = .videoResponseFormat(val)
      return
    }
    if let val = try? container.decode([String: JSONValue].self) {
      self = .custom(val)
      return
    }
    throw DecodingError.typeMismatch(
      ResponseFormat.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "Failed to decode any of the variants for ResponseFormat"
      )
    )
  }

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .audioResponseFormat(let val):
      try container.encode(val)
    case .textResponseFormat(let val):
      try container.encode(val)
    case .imageResponseFormat(let val):
      try container.encode(val)
    case .videoResponseFormat(let val):
      try container.encode(val)
    case .custom(let val):
      try container.encode(val)
    }
  }
}
