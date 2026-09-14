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

/// An internal data model for `GoogleSearchCallDelta`.
package struct GoogleSearchCallDelta: Codable, Sendable, Equatable, Hashable {

  package let arguments: GoogleSearchCallArguments?

  /// A signature hash for backend validation.
  package let signature: Data?

  package let type: String?

  /// Creates a new `GoogleSearchCallDelta`.
  ///
  /// - Parameters:
  ///   - arguments: For more details, see ``arguments``.
  ///   - signature: A signature hash for backend validation.
  package init(
    arguments: GoogleSearchCallArguments?,
    signature: Data? = nil
  ) {
    self.arguments = arguments
    self.signature = signature
    self.type = "google_search_call"
  }
  enum CodingKeys: String, CodingKey {
    case arguments = "arguments"
    case signature = "signature"
    case type = "type"
  }
}
