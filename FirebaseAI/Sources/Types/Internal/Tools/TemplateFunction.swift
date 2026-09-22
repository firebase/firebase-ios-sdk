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

/// Structured representation of a function declaration as defined by the
/// [OpenAPI 3.0 specification](https://spec.openapis.org/oas/v3.0.3).
///
/// This is a representation of a block of code that can be used as a `Tool` by the model and
/// executed by the client. The name of the function must be listed in the template frontmatter
/// for the model to be able to call it.
struct TemplateFunction: Sendable, Equatable {
  /// The name of the function to call.
  let name: String

  /// Describes the parameters to the function in JSON Schema format.
  ///
  /// The schema must describe an object where the properties are the parameters to the function.
  /// For example:
  ///
  /// ```json
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
  let inputSchema: JSONObject?

  /// Describes the output from this function in JSON Schema format.
  ///
  /// The value specified by the schema is the response value of the function.
  let outputSchema: JSONObject?

  /// Initializes a new `TemplateFunction`.
  ///
  /// - Parameters:
  ///   - name: The name of the function to call.
  ///   - inputSchema: Describes the parameters to the function in JSON Schema format.
  ///   - outputSchema: Describes the output from this function in JSON Schema format.
  init(name: String, inputSchema: JSONObject? = nil, outputSchema: JSONObject? = nil) {
    self.name = name
    self.inputSchema = inputSchema
    self.outputSchema = outputSchema
  }
}

extension TemplateFunction {
  /// Initializes a `TemplateFunction` by converting from a ``FunctionDeclaration``.
  ///
  /// - Parameter functionDeclaration: The ``FunctionDeclaration`` to convert.
  /// - Throws: An error if parameter schema conversion fails.
  init(_ functionDeclaration: FunctionDeclaration) throws {
    guard case .manual = functionDeclaration.kind else {
      throw EncodingError.invalidValue(
        functionDeclaration,
        EncodingError.Context(
          codingPath: [],
          debugDescription: "Server Prompt Templates do not support automatic function calling."
        )
      )
    }

    name = functionDeclaration.name

    if let parameters = functionDeclaration.parameters {
      inputSchema = parameters.toJSONSchema()
    } else if let parametersJSONSchema = functionDeclaration.parametersJSONSchema {
      inputSchema = try parametersJSONSchema.toGeminiJSONSchema()
    } else {
      inputSchema = nil
    }

    outputSchema = functionDeclaration.responseJSONSchema
  }
}

extension TemplateFunction: Encodable {}
