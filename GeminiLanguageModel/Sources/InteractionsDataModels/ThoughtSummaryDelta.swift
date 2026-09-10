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

/// An internal data model for `ThoughtSummaryDelta`.
package struct ThoughtSummaryDelta: Codable, Sendable, Equatable, Hashable {

  /// A new summary item to be added to the thought.
  package let content: Content?

  package let type: String?

  /// Creates a new `ThoughtSummaryDelta`.
  ///
  /// - Parameters:
  ///   - content: A new summary item to be added to the thought.
  package init(
    content: Content? = nil
  ) {
    self.content = content
    self.type = "thought_summary"
  }
  enum CodingKeys: String, CodingKey {
    case content = "content"
    case type = "type"
  }
}
