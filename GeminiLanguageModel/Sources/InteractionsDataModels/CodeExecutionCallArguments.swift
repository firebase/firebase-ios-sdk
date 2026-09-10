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

/// The arguments to pass to the code execution.
package struct CodeExecutionCallArguments: Codable, Sendable, Equatable, Hashable {

  /// The code to be executed.
  package let code: String?

  /// Programming language of the `code`.
  package let language: String?

  /// Creates a new `CodeExecutionCallArguments`.
  ///
  /// - Parameters:
  ///   - code: The code to be executed.
  package init(
    code: String? = nil
  ) {
    self.code = code
    self.language = "python"
  }
  enum CodingKeys: String, CodingKey {
    case code = "code"
    case language = "language"
  }
}
