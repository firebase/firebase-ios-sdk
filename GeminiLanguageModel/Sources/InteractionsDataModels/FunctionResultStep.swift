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

/// Result of a function tool call.
package struct FunctionResultStep: Codable, Sendable, Equatable, Hashable {

  /// Required. ID to match the ID from the function call block.
  package let callId: String?

  /// Whether the tool call resulted in an error.
  package let isError: Bool?

  /// The name of the tool that was called.
  package let name: String?

  /// Required. The result of the tool call.
  package let result: JSONValue?

  package let type: String?

  /// Creates a new `FunctionResultStep`.
  ///
  /// - Parameters:
  ///   - callId: Required. ID to match the ID from the function call block.
  ///   - isError: Whether the tool call resulted in an error.
  ///   - name: The name of the tool that was called.
  ///   - result: Required. The result of the tool call.
  package init(
    callId: String?,
    isError: Bool? = nil,
    name: String? = nil,
    result: JSONValue?
  ) {
    self.callId = callId
    self.isError = isError
    self.name = name
    self.result = result
    self.type = "function_result"
  }
  enum CodingKeys: String, CodingKey {
    case callId = "call_id"
    case isError = "is_error"
    case name = "name"
    case result = "result"
    case type = "type"
  }
}
