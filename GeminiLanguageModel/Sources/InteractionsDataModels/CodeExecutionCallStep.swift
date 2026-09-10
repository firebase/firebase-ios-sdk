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

/// Code execution call step.
package struct CodeExecutionCallStep: Codable, Sendable, Equatable, Hashable {

  /// Required. The arguments to pass to the code execution.
  package let arguments: CodeExecutionCallArguments?

  /// Required. A unique ID for this specific tool call.
  package let id: String?

  /// A signature hash for backend validation.
  package let signature: Data?

  package let type: String?

  /// Creates a new `CodeExecutionCallStep`.
  ///
  /// - Parameters:
  ///   - arguments: Required. The arguments to pass to the code execution.
  ///   - id: Required. A unique ID for this specific tool call.
  ///   - signature: A signature hash for backend validation.
  package init(
    arguments: CodeExecutionCallArguments?,
    id: String?,
    signature: Data? = nil
  ) {
    self.arguments = arguments
    self.id = id
    self.signature = signature
    self.type = "code_execution_call"
  }
  enum CodingKeys: String, CodingKey {
    case arguments = "arguments"
    case id = "id"
    case signature = "signature"
    case type = "type"
  }
}
