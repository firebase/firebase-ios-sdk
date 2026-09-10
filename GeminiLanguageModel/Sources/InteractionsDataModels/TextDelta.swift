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

/// An internal data model for `TextDelta`.
package struct TextDelta: Codable, Sendable, Equatable, Hashable {

  package let text: String?

  package let type: String?

  /// Creates a new `TextDelta`.
  ///
  /// - Parameters:
  ///   - text: For more details, see ``text``.
  package init(
    text: String?
  ) {
    self.text = text
    self.type = "text"
  }
  enum CodingKeys: String, CodingKey {
    case text = "text"
    case type = "type"
  }
}
