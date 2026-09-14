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

/// The number of grounding tool counts.
package struct GroundingToolCount: Codable, Sendable, Equatable, Hashable {

  /// The number of grounding tool counts.
  package let count: Int?

  /// The grounding tool type associated with the count.
  package let type: `Type`?

  /// Creates a new `GroundingToolCount`.
  ///
  /// - Parameters:
  ///   - count: The number of grounding tool counts.
  ///   - type: The grounding tool type associated with the count.
  package init(
    count: Int? = nil,
    type: `Type`? = nil
  ) {
    self.count = count
    self.type = type
  }
  enum CodingKeys: String, CodingKey {
    case count = "count"
    case type = "type"
  }
}
