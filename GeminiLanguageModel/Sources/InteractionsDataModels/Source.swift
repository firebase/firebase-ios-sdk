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

/// A source to be mounted into the environment.
package struct Source: Codable, Sendable, Equatable, Hashable {

  /// The inline content if `type` is `INLINE`.
  package let content: String?

  /// Optional encoding for inline content (e.g. `base64`).
  package let encoding: String?

  /// The source of the environment.
  /// For Cloud Storage, this is the Cloud Storage path.
  /// For GitHub, this is the GitHub path.
  package let source: String?

  /// Where the source should appear in the environment.
  package let target: String?

  package let type: `Type`?

  /// Creates a new `Source`.
  ///
  /// - Parameters:
  ///   - content: The inline content if `type` is `INLINE`.
  ///   - encoding: Optional encoding for inline content (e.g. `base64`).
  ///   - source: The source of the environment.
  ///   - target: Where the source should appear in the environment.
  ///   - type: For more details, see ``type``.
  package init(
    content: String? = nil,
    encoding: String? = nil,
    source: String? = nil,
    target: String? = nil,
    type: `Type`? = nil
  ) {
    self.content = content
    self.encoding = encoding
    self.source = source
    self.target = target
    self.type = type
  }
  enum CodingKeys: String, CodingKey {
    case content = "content"
    case encoding = "encoding"
    case source = "source"
    case target = "target"
    case type = "type"
  }
}
