// Copyright 2024 Google LLC
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

/// A predicted function call returned from the model.
public struct FunctionCall: Equatable, Encodable {
  /// The name of the function to call.
  public let name: String

  /// The function parameters and values.
  public let args: JSONObject
}

/// A `Schema` object allows the definition of input and output data types.
///
/// These types can be objects, but also primitives and arrays. Represents a select subset of an
/// [OpenAPI 3.0 schema object](https://spec.openapis.org/oas/v3.0.3#schema).
public class Schema: Encodable {
  /// The data type.
  let type: DataType

  /// The format of the data.
  let format: String?

  /// A brief description of the parameter.
  let description: String?

  /// Indicates if the value may be null.
  let nullable: Bool?

  /// Possible values of the element of type ``DataType/string`` with "enum" format.
  let enumValues: [String]?

  /// Schema of the elements of type ``DataType/array``.
  let items: Schema?

  /// Properties of type ``DataType/object``.
  let properties: [String: Schema]?

  /// Required properties of type ``DataType/object``.
  let requiredProperties: [String]?

  enum CodingKeys: String, CodingKey {
    case type
    case format
    case description
    case nullable
    case enumValues = "enum"
    case items
    case properties
    case requiredProperties = "required"
  }

  /// Constructs a new `Schema`.
  ///
  /// - Parameters:
  ///   - type: The data type.
  ///   - format: The format of the data; used only for primitive datatypes.
  ///     Supported formats:
  ///     - ``DataType/integer``: int32, int64
  ///     - ``DataType/number``: float, double
  ///     - ``DataType/string``: enum
  ///   - description: A brief description of the parameter; may be formatted as Markdown.
  ///   - nullable: Indicates if the value may be null.
  ///   - enumValues: Possible values of the element of type ``DataType/string`` with "enum" format.
  ///     For example, an enum `Direction` may be defined as `["EAST", NORTH", "SOUTH", "WEST"]`.
  ///   - items: Schema of the elements of type ``DataType/array``.
  ///   - properties: Properties of type ``DataType/object``.
  ///   - requiredProperties: Required properties of type ``DataType/object``.
  public init(type: DataType, format: String? = nil, description: String? = nil,
              nullable: Bool? = nil,
              enumValues: [String]? = nil, items: Schema? = nil,
              properties: [String: Schema]? = nil,
              requiredProperties: [String]? = nil) {
    self.type = type
    self.format = format
    self.description = description
    self.nullable = nullable
    self.enumValues = enumValues
    self.items = items
    self.properties = properties
    self.requiredProperties = requiredProperties
  }
}

/// A data type.
///
/// Contains the set of OpenAPI [data types](https://spec.openapis.org/oas/v3.0.3#data-types).
public enum DataType: String, Encodable {
  /// A `String` type.
  case string = "STRING"

  /// A floating-point number type.
  case number = "NUMBER"

  /// An integer type.
  case integer = "INTEGER"

  /// A boolean type.
  case boolean = "BOOLEAN"

  /// An array type.
  case array = "ARRAY"

  /// An object type.
  case object = "OBJECT"
}

/// Structured representation of a function declaration.
///
/// This `FunctionDeclaration` is a representation of a block of code that can be used as a ``Tool``
/// by the model and executed by the client.
public struct FunctionDeclaration {
  /// The name of the function.
  let name: String

  /// A brief description of the function.
  let description: String

  /// Describes the parameters to this function; must be of type ``DataType/object``.
  let parameters: Schema?

  /// Constructs a new `FunctionDeclaration`.
  ///
  /// - Parameters:
  ///   - name: The name of the function; must be a-z, A-Z, 0-9, or contain underscores and dashes,
  ///   with a maximum length of 63.
  ///   - description: A brief description of the function.
  ///   - parameters: Describes the parameters to this function; the keys are parameter names and
  ///   the values are ``Schema`` objects describing them.
  ///   - requiredParameters: A list of required parameters by name.
  public init(name: String, description: String, parameters: [String: Schema]?,
              requiredParameters: [String]?) {
    self.name = name
    self.description = description
    self.parameters = Schema(
      type: .object,
      properties: parameters,
      requiredProperties: requiredParameters
    )
  }
}

/// Helper tools that the model may use to generate response.
///
/// A `Tool` is a piece of code that enables the system to interact with external systems to
/// perform an action, or set of actions, outside of knowledge and scope of the model.
public struct Tool: Encodable {
  /// A list of `FunctionDeclarations` available to the model.
  let functionDeclarations: [FunctionDeclaration]?

  /// Constructs a new `Tool`.
  ///
  /// - Parameters:
  ///   - functionDeclarations: A list of `FunctionDeclarations` available to the model that can be
  ///   used for function calling.
  ///   The model or system does not execute the function. Instead the defined function may be
  ///   returned as a ``FunctionCall`` in ``ModelContent/Part/functionCall(_:)`` with arguments to
  ///   the client side for execution. The model may decide to call a subset of these functions by
  ///   populating ``FunctionCall`` in the response. The next conversation turn may contain a
  ///   ``FunctionResponse`` in ``ModelContent/Part/functionResponse(_:)`` with the
  ///   ``ModelContent/role`` "function", providing generation context for the next model turn.
  public init(functionDeclarations: [FunctionDeclaration]?) {
    self.functionDeclarations = functionDeclarations
  }
}

/// Result output from a ``FunctionCall``.
///
/// Contains a string representing the `FunctionDeclaration.name` and a structured JSON object
/// containing any output from the function is used as context to the model. This should contain the
/// result of a ``FunctionCall`` made based on model prediction.
public struct FunctionResponse: Equatable, Encodable {
  /// The name of the function that was called.
  let name: String

  /// The function's response.
  let response: JSONObject

  /// Constructs a new `FunctionResponse`.
  ///
  /// - Parameters:
  ///   - name: The name of the function that was called.
  ///   - response: The function's response.
  public init(name: String, response: JSONObject) {
    self.name = name
    self.response = response
  }
}

// MARK: - Codable Conformance

extension FunctionCall: Decodable {
  enum CodingKeys: CodingKey {
    case name
    case args
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    name = try container.decode(String.self, forKey: .name)
    if let args = try container.decodeIfPresent(JSONObject.self, forKey: .args) {
      self.args = args
    } else {
      args = JSONObject()
    }
  }
}

extension FunctionDeclaration: Encodable {
  enum CodingKeys: String, CodingKey {
    case name
    case description
    case parameters
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(description, forKey: .description)
    try container.encode(parameters, forKey: .parameters)
  }
}
