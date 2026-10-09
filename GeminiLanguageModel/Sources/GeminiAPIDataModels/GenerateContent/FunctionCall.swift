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

import Foundation

/// A predicted FunctionCall returned from the model that contains a string representing the
/// FunctionDeclaration.name and a structured JSON object containing the parameters and their
/// values.
package struct FunctionCall: Codable, Sendable, Equatable, Hashable, Buildable {
  /// The function parameters and values in JSON object format. See FunctionDeclaration.parameters
  /// for parameter details.
  package var args: JSONObject?

  /// The unique id of the function call. If populated, the client to execute the `function_call`
  /// and return the response with the matching `id`.
  package var id: String?

  /// The name of the function to call. Matches FunctionDeclaration.name.
  package var name: String?

  /// Whether this is the last part of the FunctionCall. If true, another partial message for the
  /// current FunctionCall is expected to follow.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var willContinue: Bool?

  /// Initializes a new `FunctionCall`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case args
    case id
    case name
    case willContinue
  }
}
