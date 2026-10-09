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

/// Tool details that the model may use to generate response. A `Tool` is a piece of code that
/// enables the system to interact with external systems to perform an action, or set of actions,
/// outside of knowledge and scope of the model. A Tool object should contain exactly one type of
/// Tool (e.g FunctionDeclaration, Retrieval or GoogleSearchRetrieval).
package struct Tool: Codable, Sendable, Equatable, Hashable, Buildable {
  /// CodeExecution tool type. Enables the model to execute code as part of generation.
  package var codeExecution: CodeExecution?

  /// Function tool type. One or more function declarations to be passed to the model along with the
  /// current user query. Model may decide to call a subset of these functions by populating
  /// FunctionCall in the response. User should provide a FunctionResponse for each function call in
  /// the next turn. Based on the function responses, Model will generate the final response back to
  /// the user. Maximum 512 function declarations can be provided.
  package var functionDeclarations: [FunctionDeclaration]?

  /// GoogleMaps tool type. Tool to support Google Maps in Model.
  package var googleMaps: GoogleMaps?

  /// GoogleSearch tool type. Tool to support Google Search in Model. Powered by Google.
  package var googleSearch: GoogleSearch?

  /// A list of user-provided functions for function calling. For functions whose names are listed
  /// in the template frontmatter, the model may decide to call a subset of these functions by
  /// populating `FunctionCall` in the response. User should provide a `FunctionResponse` for each
  /// function call in the next turn.
  package var templateFunctions: [TemplateFunction]?

  /// Tool to support URL context retrieval.
  package var urlContext: URLContext?

  /// Initializes a new `Tool`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case codeExecution
    case functionDeclarations
    case googleMaps
    case googleSearch
    case templateFunctions
    case urlContext
  }
}
