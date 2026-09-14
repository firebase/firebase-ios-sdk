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

/// An internal data model for `ThoughtSummaryContent`.
package enum ThoughtSummaryContent: Codable, Sendable, Equatable, Hashable {

  /// An image content block.
  case imageContent(ImageContent)

  /// A text content block.
  case textContent(TextContent)

  /// Unrecognized case.
  case unrecognized(JSONValue)

  private enum CodingKeys: String, CodingKey {
    case discriminator = "type"
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let discValue = try container.decode(String.self, forKey: .discriminator)
    switch discValue {
    case "image":
      let val = try ImageContent(from: decoder)
      self = .imageContent(val)
    case "text":
      let val = try TextContent(from: decoder)
      self = .textContent(val)
    default:
      let val = try JSONValue(from: decoder)
      self = .unrecognized(val)
    }
  }

  package func encode(to encoder: any Encoder) throws {
    switch self {
    case .imageContent(let val):
      try val.encode(to: encoder)
    case .textContent(let val):
      try val.encode(to: encoder)
    case .unrecognized(let val):
      try val.encode(to: encoder)
    }
  }
}
