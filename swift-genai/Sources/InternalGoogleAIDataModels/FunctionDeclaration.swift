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
public import InternalSharedDataModels


extension GoogleAI {
  /// Structured representation of a function declaration as defined by the [OpenAPI 3.03 specification](https://spec.openapis.org/oas/v3.0.3). Included in this declaration are the function name and parameters. This FunctionDeclaration is a representation of a block of code that can be used as a `Tool` by the model and executed by the client.
  public struct FunctionDeclaration: Codable, Sendable, Equatable, Hashable {
    /// Optional. Specifies the function Behavior. Currently only supported by the BidiGenerateContent method.
    public var behavior: Behavior?
    
    /// Required. A brief description of the function.
    public var description: String?
    
    /// Required. The name of the function. Must be a-z, A-Z, 0-9, or contain underscores, colons, dots, and dashes, with a maximum length of 128.
    public var name: String?
    
    /// Optional. Describes the parameters to this function. Reflects the Open API 3.03 Parameter Object string Key: the name of the parameter. Parameter names are case sensitive. Schema Value: the Schema defining the type used for the parameter.
    public var parameters: Schema?
    
    /// Optional. Describes the parameters to the function in JSON Schema format. The schema must describe an object where the properties are the parameters to the function. For example: ``` { "type": "object", "properties": { "name": { "type": "string" }, "age": { "type": "integer" } }, "additionalProperties": false, "required": ["name", "age"], "propertyOrdering": ["name", "age"] } ``` This field is mutually exclusive with `parameters`.
    public var parametersJsonSchema: JSONValue?
    
    /// Optional. Describes the output from this function in JSON Schema format. Reflects the Open API 3.03 Response Object. The Schema defines the type used for the response value of the function.
    public var response: Schema?
    
    /// Optional. Describes the output from this function in JSON Schema format. The value specified by the schema is the response value of the function. This field is mutually exclusive with `response`.
    public var responseJsonSchema: JSONValue?
    
    /// Creates a new `FunctionDeclaration`.
    public init(
      behavior: Behavior? = nil,
      description: String? = nil,
      name: String? = nil,
      parameters: Schema? = nil,
      parametersJsonSchema: JSONValue? = nil,
      response: Schema? = nil,
      responseJsonSchema: JSONValue? = nil
    ) {
      self.behavior = behavior
      self.description = description
      self.name = name
      self.parameters = parameters
      self.parametersJsonSchema = parametersJsonSchema
      self.response = response
      self.responseJsonSchema = responseJsonSchema
    }
    enum CodingKeys: String, CodingKey {
      case behavior = "behavior"
      case description = "description"
      case name = "name"
      case parameters = "parameters"
      case parametersJsonSchema = "parametersJsonSchema"
      case response = "response"
      case responseJsonSchema = "responseJsonSchema"
    }
  }
}