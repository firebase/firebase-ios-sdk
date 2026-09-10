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

/// The content of the response.
package enum Content: Codable, Sendable, Equatable, Hashable {

  /// An audio content block.
  case audioContent(AudioContent)

  /// A document content block.
  case documentContent(DocumentContent)

  /// An image content block.
  case imageContent(ImageContent)

  /// A text content block.
  case textContent(TextContent)

  /// A video content block.
  case videoContent(VideoContent)

  /// Unrecognized case.
  case unrecognized(JSONValue)

  private enum CodingKeys: String, CodingKey {
    case discriminator = "type"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let discValue = try container.decode(String.self, forKey: .discriminator)
    switch discValue {
    case "audio":
      let val = try AudioContent(from: decoder)
      self = .audioContent(val)
    case "document":
      let val = try DocumentContent(from: decoder)
      self = .documentContent(val)
    case "image":
      let val = try ImageContent(from: decoder)
      self = .imageContent(val)
    case "text":
      let val = try TextContent(from: decoder)
      self = .textContent(val)
    case "video":
      let val = try VideoContent(from: decoder)
      self = .videoContent(val)
    default:
      let val = try JSONValue(from: decoder)
      self = .unrecognized(val)
    }
  }

  package func encode(to encoder: any Encoder) throws {
    switch self {
    case .audioContent(let val):
      try val.encode(to: encoder)
    case .documentContent(let val):
      try val.encode(to: encoder)
    case .imageContent(let val):
      try val.encode(to: encoder)
    case .textContent(let val):
      try val.encode(to: encoder)
    case .videoContent(let val):
      try val.encode(to: encoder)
    case .unrecognized(let val):
      try val.encode(to: encoder)
    }
  }
}
