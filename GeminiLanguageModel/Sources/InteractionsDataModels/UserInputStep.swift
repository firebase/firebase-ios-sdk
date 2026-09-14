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

/// Input provided by the user.
package struct UserInputStep: Codable, Sendable, Equatable, Hashable {

  package let content: [Content]?

  package let type: String?

  /// Creates a new `UserInputStep`.
  ///
  /// - Parameters:
  ///   - content: For more details, see ``content``.
  package init(
    content: [Content]? = nil
  ) {
    self.content = content
    self.type = "user_input"
  }
  enum CodingKeys: String, CodingKey {
    case content = "content"
    case type = "type"
  }
}
