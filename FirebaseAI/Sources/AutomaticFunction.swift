// Copyright 2025 Google LLC
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

/// A wrapper for a function declaration and its executable logic.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct AutomaticFunction: Sendable {
  /// The declaration of the function, describing it to the model.
  public let declaration: FunctionDeclaration

  /// The closure to execute when the function is called.
  public let execute: @Sendable ([String: JSONValue]) async throws -> JSONObject

  /// Creates a new `AutomaticFunction`.
  /// - Parameters:
  ///   - declaration: The function declaration.
  ///   - execute: The execution logic.
  public init(declaration: FunctionDeclaration,
              execute: @escaping @Sendable ([String: JSONValue]) async throws -> JSONObject) {
    self.declaration = declaration
    self.execute = execute
  }

  /// Creates a new `AutomaticFunction` with a simplified declaration.
  /// - Parameters:
  ///   - name: The name of the function.
  ///   - description: A brief description of the function.
  ///   - parameters: Describes the parameters to this function.
  ///   - optionalParameters: The names of parameters that may be omitted by the model.
  ///   - execute: The execution logic.
  public init(name: String,
              description: String,
              parameters: [String: Schema] = [:],
              optionalParameters: [String] = [],
              execute: @escaping @Sendable ([String: JSONValue]) async throws -> JSONObject) {
    declaration = FunctionDeclaration(name: name,
                                      description: description,
                                      parameters: parameters,
                                      optionalParameters: optionalParameters)
    self.execute = execute
  }
}

#if canImport(FoundationModels)
  import FoundationModels

  @available(iOS 26.0, macOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  public extension AutomaticFunction {
    /// Creates an `AutomaticFunction` from a `FoundationModels.Tool`.
    ///
    /// - Parameter tool: The `FoundationModels.Tool` instance to wrap.
    init<T: FoundationModels.Tool>(_ tool: T) throws {
      // Convert FoundationModels.GenerationSchema to FirebaseAI.Schema (via JSONSchema)
      // Tool.parameters is a GenerationSchema instance.
      // We encode it to JSON and decode it as our JSONSchema type.
      let data = try JSONEncoder().encode(tool.parameters)
      let jsonSchema = try JSONDecoder().decode(JSONSchema.self, from: data)
      let firebaseSchema = try jsonSchema.asSchema()

      // Extract parameter properties
      let properties = firebaseSchema.properties ?? [:]
      let required = firebaseSchema.requiredProperties ?? []

      self.init(
        name: tool.name,
        description: tool.description,
        parameters: properties,
        optionalParameters: properties.keys.filter { !required.contains($0) }
      ) { args in
        // Convert [String: JSONValue] -> JSONObject (ModelOutput) -> GeneratedContent ->
        // T.Arguments
        let orderedKeys = args.keys.sorted()
        let properties = args.mapValues { ModelOutput(jsonValue: $0) }
        let modelOutput = ModelOutput(kind: .structure(
          properties: properties,
          orderedKeys: orderedKeys
        ))

        let generatedContent = modelOutput.generatedContent
        let toolArgs = try T.Arguments(generatedContent)

        // Execute the tool
        let result = try await tool.call(arguments: toolArgs)

        // Convert result -> JSON
        // We assume the output is Encodable (common for Generable/PromptRepresentable types that
        // are data).
        // If it's just a String, we wrap it.
        if let encodableResult = result as? Encodable {
          let encoder = JSONEncoder()
          let data = try encoder.encode(encodableResult)
          let jsonValue = try JSONDecoder().decode(JSONValue.self, from: data)
          if case let .object(jsonObject) = jsonValue {
            return jsonObject
          } else {
            return ["result": jsonValue]
          }
        }

        // Fallback for non-Encodable or other types: String description
        return ["result": .string(String(describing: result))]
      }
    }
  }
#endif
