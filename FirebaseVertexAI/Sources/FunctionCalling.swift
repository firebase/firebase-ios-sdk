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

/// Structured representation of a function declaration.
///
/// This `FunctionDeclaration` is a representation of a block of code that can be used as a ``Tool``
/// by the model and executed by the client.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FunctionDeclaration {
  /// The name of the function.
  let name: String

  /// A brief description of the function.
  let description: String

  /// Describes the parameters to this function; must be of type `DataType.object`.
  let parameters: Schema?

  /// Constructs a new `FunctionDeclaration`.
  ///
  /// - Parameters:
  ///   - name: The name of the function; must be a-z, A-Z, 0-9, or contain underscores and dashes,
  ///   with a maximum length of 63.
  ///   - description: A brief description of the function.
  ///   - parameters: Describes the parameters to this function.
  ///   - optionalParameters: The names of parameters that may be omitted by the model in function
  ///   calls; by default, all parameters are considered required.
  public init(name: String, description: String, parameters: [String: Schema],
              optionalParameters: [String] = []) {
    self.name = name
    self.description = description
    self.parameters = Schema.object(
      properties: parameters,
      optionalProperties: optionalParameters,
      nullable: false
    )
  }
}

/// A helper tool that the model may use when generating responses.
///
/// A `Tool` is a piece of code that enables the system to interact with external systems to perform
/// an action, or set of actions, outside of knowledge and scope of the model.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct Tool {
  /// A list of `FunctionDeclarations` available to the model.
  let functionDeclarations: [FunctionDeclaration]?

  init(functionDeclarations: [FunctionDeclaration]?) {
    self.functionDeclarations = functionDeclarations
  }

  /// Creates a tool that allows the model to perform function calling.
  ///
  /// Function calling can be used to provide data to the model that was not known at the time it
  /// was trained (for example, the current date or weather conditions) or to allow it to interact
  /// with external systems (for example, making an API request or querying/updating a database).
  /// For more details and use cases, see [Introduction to function
  /// calling](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling).
  ///
  /// - Parameters:
  ///   - functionDeclarations: A list of `FunctionDeclarations` available to the model that can be
  ///   used for function calling.
  ///   The model or system does not execute the function. Instead the defined function may be
  ///   returned as a ``FunctionCallPart`` with arguments to the client side for execution. The
  ///   model may decide to call none, some or all of the declared functions; this behavior may be
  ///   configured by specifying a ``ToolConfig`` when instantiating the model. When a
  ///   ``FunctionCallPart`` is received, the next conversation turn may contain a
  ///   ``FunctionResponsePart`` in ``ModelContent/parts`` with a ``ModelContent/role`` of
  ///   `"function"`; this response contains the result of executing the function on the client,
  ///   providing generation context for the model's next turn.
  public static func functionDeclarations(_ functionDeclarations: [FunctionDeclaration]) -> Tool {
    return self.init(functionDeclarations: functionDeclarations)
  }
}

/// Configuration for specifying function calling behavior.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct FunctionCallingConfig {
  /// Defines the execution behavior for function calling by defining the execution mode.
  enum Mode: String {
    case auto = "AUTO"
    case any = "ANY"
    case none = "NONE"
  }

  /// Specifies the mode in which function calling should execute.
  let mode: Mode?

  /// A set of function names that, when provided, limits the functions the model will call.
  let allowedFunctionNames: [String]?

  init(mode: FunctionCallingConfig.Mode? = nil, allowedFunctionNames: [String]? = nil) {
    self.mode = mode
    self.allowedFunctionNames = allowedFunctionNames
  }

  /// Creates a function calling config where the model calls functions at its discretion.
  ///
  /// > Note: This is the default behavior.
  public static func auto() -> FunctionCallingConfig {
    return FunctionCallingConfig(mode: .auto)
  }

  /// Creates a function calling config where the model will always call a provided function.
  ///
  ///  - Parameters:
  ///    - allowedFunctionNames: A set of function names that, when provided, limits the functions
  ///    that the model will call.
  public static func any(allowedFunctionNames: [String]? = nil) -> FunctionCallingConfig {
    return FunctionCallingConfig(mode: .any, allowedFunctionNames: allowedFunctionNames)
  }

  /// Creates a function calling config where the model will never call a function.
  ///
  /// > Note: This can also be achieved by not passing any ``FunctionDeclaration`` tools when
  /// > instantiating the model.
  public static func none() -> FunctionCallingConfig {
    return FunctionCallingConfig(mode: FunctionCallingConfig.Mode.none)
  }
}

/// Tool configuration for any `Tool` specified in the request.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ToolConfig {
  let functionCallingConfig: FunctionCallingConfig?

  public init(functionCallingConfig: FunctionCallingConfig? = nil) {
    self.functionCallingConfig = functionCallingConfig
  }
}

// MARK: - Codable Conformance

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension Tool: Encodable {}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FunctionCallingConfig: Encodable {}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension FunctionCallingConfig.Mode: Encodable {}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension ToolConfig: Encodable {}
