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

/// An internal data model for `FunctionResultDelta`.
package struct FunctionResultDelta: Codable, Sendable, Equatable, Hashable {

  /// Required. ID to match the ID from the function call block.
  package let callId: String?

  package let isError: Bool?

  package let name: String?

  package let result: JSONValue?

  package let type: String?

  /// Creates a new `FunctionResultDelta`.
  ///
  /// - Parameters:
  ///   - callId: Required. ID to match the ID from the function call block.
  ///   - isError: For more details, see ``isError``.
  ///   - name: For more details, see ``name``.
  ///   - result: For more details, see ``result``.
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
