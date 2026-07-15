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
package import InternalSharedDataModels


extension GeminiDataModels {
  /// An internal data model for `TemplateFunction`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `TemplateFunction`
  /// 
  /// Structured representation of a function declaration as defined by the
  /// [OpenAPI 3.0 specification](https://spec.openapis.org/oas/v3.0.3). This
  /// is a representation of a block of code that can be used as a `Tool` by the
  /// model and executed by the client. The name of the function must be listed in
  /// the template frontmatter for the model to be able to call it.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `TemplateFunction`
  /// 
  /// Structured representation of a function declaration as defined by the
  /// [OpenAPI 3.0 specification](https://spec.openapis.org/oas/v3.0.3). This
  /// is a representation of a block of code that can be used as a `Tool` by the
  /// model and executed by the client. The name of the function must be listed in
  /// the template frontmatter for the model to be able to call it.
  package struct TemplateFunction: Codable, Sendable, Equatable, Hashable {
    /// Required. The name of the function to call.
    package let name: String
    
    /// Optional. Describes the parameters to the function in JSON Schema format. The schema
    /// must describe an object where the properties are the parameters to the
    /// function. For example:
    /// 
    /// ```
    /// {
    ///   "type": "object",
    ///   "properties": {
    ///     "name": { "type": "string" },
    ///     "age": { "type": "integer" }
    ///   },
    ///   "additionalProperties": false,
    ///   "required": ["name", "age"],
    ///   "propertyOrdering": ["name", "age"]
    /// }
    /// ```
    package let inputSchema: [String: JSONValue]?
    
    /// Optional. Describes the output from this function in JSON Schema format. The value
    /// specified by the schema is the response value of the function.
    package let outputSchema: [String: JSONValue]?
    

    /// Creates a new `TemplateFunction`.
    ///
    /// - Parameters:
    ///   - name: Required. The name of the function to call.
    ///   - inputSchema: Optional. Describes the parameters to the function in JSON Schema format. The schema
    ///   - outputSchema: Optional. Describes the output from this function in JSON Schema format. The value
    package init(
      name: String,
      inputSchema: [String: JSONValue]? = nil,
      outputSchema: [String: JSONValue]? = nil
    ) {
      self.name = name
      self.inputSchema = inputSchema
      self.outputSchema = outputSchema
    }
    enum CodingKeys: String, CodingKey {
      case name = "name"
      case inputSchema = "inputSchema"
      case outputSchema = "outputSchema"
    }
  }
}