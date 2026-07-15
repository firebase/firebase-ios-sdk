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
  /// An internal data model for `FunctionDeclaration`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaFunctionDeclaration`
  /// 
  /// Structured representation of a function declaration as defined by the
  /// [OpenAPI 3.03 specification](https://spec.openapis.org/oas/v3.0.3). Included
  /// in this declaration are the function name and parameters. This
  /// FunctionDeclaration is a representation of a block of code that can be used
  /// as a `Tool` by the model and executed by the client.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1FunctionDeclaration`
  /// 
  /// Structured representation of a function declaration as defined by the
  /// [OpenAPI 3.0 specification](https://spec.openapis.org/oas/v3.0.3). Included
  /// in this declaration are the function name, description, parameters and
  /// response type. This FunctionDeclaration is a representation of a block of
  /// code that can be used as a `Tool` by the model and executed by the client.
  package struct FunctionDeclaration: Codable, Sendable, Equatable, Hashable {
    /// Required. The name of the function.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. The name of the function.
    /// Must be a-z, A-Z, 0-9, or contain underscores, colons, dots, and dashes,
    /// with a maximum length of 128.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Required. The name of the function to call.
    /// Must start with a letter or an underscore.
    /// Must be a-z, A-Z, 0-9, or contain underscores, dots, colons and dashes,
    /// with a maximum length of 128.
    package let name: String
    
    /// Required. A brief description of the function.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Required. A brief description of the function.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Description and purpose of the function.
    /// Model uses it to decide how and whether to call the function.
    package let description: String
    
    /// Optional. Describes the parameters to this function. Reflects the Open API 3.03
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Describes the parameters to this function. Reflects the Open API 3.03
    /// Parameter Object string Key: the name of the parameter. Parameter names are
    /// case sensitive. Schema Value: the Schema defining the type used for the
    /// parameter.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Describes the parameters to this function in JSON Schema Object format.
    /// Reflects the Open API 3.03 Parameter Object. string Key: the name of the
    /// parameter. Parameter names are case sensitive. Schema Value: the Schema
    /// defining the type used for the parameter. For function with no parameters,
    /// this can be left unset.
    /// Parameter names must start with a letter or an underscore and must only
    /// contain chars a-z, A-Z, 0-9, or underscores with a maximum length of 64.
    /// Example with 1 required and 1 optional parameter:
    /// type: OBJECT
    /// properties:
    ///  param1:
    ///    type: STRING
    ///  param2:
    ///    type: INTEGER
    /// required:
    ///  - param1
    package let parameters: Schema?
    
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
    /// 
    /// This field is mutually exclusive with `parameters`.
    package let parametersJsonSchema: JSONValue?
    
    /// Optional. Describes the output from this function in JSON Schema format. Reflects the
    /// Open API 3.03 Response Object. The Schema defines the type used for the
    /// response value of the function.
    package let response: Schema?
    
    /// Optional. Describes the output from this function in JSON Schema format. The value
    /// specified by the schema is the response value of the function.
    /// 
    /// This field is mutually exclusive with `response`.
    package let responseJsonSchema: JSONValue?
    
    /// Optional. Specifies the function Behavior.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Specifies the function Behavior.
    /// Currently only supported by the BidiGenerateContent method.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Specifies the function Behavior.
    /// If not specified, the system keeps the current function call behavior.
    /// This field is currently only supported by the BidiGenerateContent method.
    package let behavior: Behavior?
    

    /// Creates a new `FunctionDeclaration`.
    ///
    /// - Parameters:
    ///   - name: Required. The name of the function. (behavior varies by backend). For more details, see ``name``.
    ///   - description: Required. A brief description of the function. (behavior varies by backend). For more details, see ``description``.
    ///   - parameters: Optional. Describes the parameters to this function. Reflects the Open API 3.03 (behavior varies by backend). For more details, see ``parameters``.
    ///   - parametersJsonSchema: Optional. Describes the parameters to the function in JSON Schema format. The schema
    ///   - response: Optional. Describes the output from this function in JSON Schema format. Reflects the
    ///   - responseJsonSchema: Optional. Describes the output from this function in JSON Schema format. The value
    ///   - behavior: Optional. Specifies the function Behavior. (behavior varies by backend). For more details, see ``behavior``.
    package init(
      name: String,
      description: String,
      parameters: Schema? = nil,
      parametersJsonSchema: JSONValue? = nil,
      response: Schema? = nil,
      responseJsonSchema: JSONValue? = nil,
      behavior: Behavior? = nil
    ) {
      self.name = name
      self.description = description
      self.parameters = parameters
      self.parametersJsonSchema = parametersJsonSchema
      self.response = response
      self.responseJsonSchema = responseJsonSchema
      self.behavior = behavior
    }
    enum CodingKeys: String, CodingKey {
      case name = "name"
      case description = "description"
      case parameters = "parameters"
      case parametersJsonSchema = "parametersJsonSchema"
      case response = "response"
      case responseJsonSchema = "responseJsonSchema"
      case behavior = "behavior"
    }
  }
}