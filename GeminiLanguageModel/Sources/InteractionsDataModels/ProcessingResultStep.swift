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

/// The result of a server-initiated media processing step.
package struct ProcessingResultStep: Codable, Sendable, Equatable, Hashable {

  /// Required. ID to match the ID from the function call block.
  package let callId: String?

  /// A signature hash for backend validation.
  package let signature: Data?

  package let type: String?

  /// Creates a new `ProcessingResultStep`.
  ///
  /// - Parameters:
  ///   - callId: Required. ID to match the ID from the function call block.
  ///   - signature: A signature hash for backend validation.
  package init(
    callId: String?,
    signature: Data? = nil
  ) {
    self.callId = callId
    self.signature = signature
    self.type = "processing_result"
  }
  enum CodingKeys: String, CodingKey {
    case callId = "call_id"
    case signature = "signature"
    case type = "type"
  }
}
