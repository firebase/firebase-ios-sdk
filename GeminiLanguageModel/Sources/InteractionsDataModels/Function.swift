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

/// A tool that can be used by the model.
package struct Function: Codable, Sendable, Equatable, Hashable {

  /// A description of the function.
  package let description: String?

  /// The name of the function.
  package let name: String?

  /// The JSON Schema for the function's parameters.
  package let parameters: JSONValue?

  package let type: String?

  /// Creates a new `Function`.
  ///
  /// - Parameters:
  ///   - description: A description of the function.
  ///   - name: The name of the function.
  ///   - parameters: The JSON Schema for the function's parameters.
  package init(
    description: String? = nil,
    name: String? = nil,
    parameters: JSONValue? = nil
  ) {
    self.description = description
    self.name = name
    self.parameters = parameters
    self.type = "function"
  }
  enum CodingKeys: String, CodingKey {
    case description = "description"
    case name = "name"
    case parameters = "parameters"
    case type = "type"
  }
}
