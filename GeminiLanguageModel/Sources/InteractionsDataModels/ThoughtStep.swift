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

package import Foundation

/// A thought step.
package struct ThoughtStep: Codable, Sendable, Equatable, Hashable {

  /// A signature hash for backend validation.
  package let signature: Data?

  /// A summary of the thought.
  package let summary: [ThoughtSummaryContent]?

  package let type: String?

  /// Creates a new `ThoughtStep`.
  ///
  /// - Parameters:
  ///   - signature: A signature hash for backend validation.
  ///   - summary: A summary of the thought.
  package init(
    signature: Data? = nil,
    summary: [ThoughtSummaryContent]? = nil
  ) {
    self.signature = signature
    self.summary = summary
    self.type = "thought"
  }
  enum CodingKeys: String, CodingKey {
    case signature = "signature"
    case summary = "summary"
    case type = "type"
  }
}
