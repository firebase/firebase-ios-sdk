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
public struct FunctionCall: Equatable {
  /// The name of the function to call.
  public let name: String

  /// The function parameters and values.
  public let args: JSONObject
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
              requiredParameters: [String]? = nil) {
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
public struct Tool {
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

/// Configuration for specifying function calling behavior.
public struct FunctionCallingConfig {
  /// Defines the execution behavior for function calling by defining the
  /// execution mode.
  public enum Mode: String {
    /// The default behavior for function calling. The model calls functions to answer queries at
    /// its discretion.
    case auto = "AUTO"

    /// The model always predicts a provided function call to answer every query.
    case any = "ANY"

    /// The model will never predict a function call to answer a query. This can also be achieved by
    /// not passing any tools to the model.
    case none = "NONE"
  }

  /// Specifies the mode in which function calling should execute. If
  /// unspecified, the default value will be set to AUTO.
  let mode: Mode?

  /// A set of function names that, when provided, limits the functions the model
  /// will call.
  ///
  /// This should only be set when the Mode is ANY. Function names
  /// should match [FunctionDeclaration.name]. With mode set to ANY, model will
  /// predict a function call from the set of function names provided.
  let allowedFunctionNames: [String]?

  public init(mode: FunctionCallingConfig.Mode? = nil, allowedFunctionNames: [String]? = nil) {
    self.mode = mode
    self.allowedFunctionNames = allowedFunctionNames
  }
}

/// Tool configuration for any `Tool` specified in the request.
public struct ToolConfig {
  let functionCallingConfig: FunctionCallingConfig?

  public init(functionCallingConfig: FunctionCallingConfig? = nil) {
    self.functionCallingConfig = functionCallingConfig
  }
}

/// Result output from a ``FunctionCall``.
///
/// Contains a string representing the `FunctionDeclaration.name` and a structured JSON object
/// containing any output from the function is used as context to the model. This should contain the
/// result of a ``FunctionCall`` made based on model prediction.
public struct FunctionResponse: Equatable {
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

extension FunctionCall: Encodable {}

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

extension Tool: Encodable {}

extension FunctionCallingConfig: Encodable {}

extension FunctionCallingConfig.Mode: Encodable {}

extension ToolConfig: Encodable {}

extension FunctionResponse: Encodable {}
