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

/// A text content block.
package struct TextContent: Codable, Sendable, Equatable, Hashable {

  /// Citation information for model-generated content.
  package let annotations: [Annotation]?

  /// Required. The text content.
  package let text: String?

  package let type: String?

  /// Creates a new `TextContent`.
  ///
  /// - Parameters:
  ///   - annotations: Citation information for model-generated content.
  ///   - text: Required. The text content.
  package init(
    annotations: [Annotation]? = nil,
    text: String?
  ) {
    self.annotations = annotations
    self.text = text
    self.type = "text"
  }
  enum CodingKeys: String, CodingKey {
    case annotations = "annotations"
    case text = "text"
    case type = "type"
  }
}
