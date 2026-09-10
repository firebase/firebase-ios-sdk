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

#if canImport(FoundationModels) && compiler(>=6.4)
  import Foundation
  import FoundationModels
  import GeminiAPIClient
  import GeminiSharedDataModels
  import InteractionsDataModels

  /// Translates Foundation Models requests into Gemini Interactions API data models.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiInteractionsRequestTranslator {
    /// Translates a `LanguageModelExecutorGenerationRequest` into a `CreateModelInteraction`.
    ///
    /// - Parameters:
    ///   - request: The generation request from the Foundation Models session.
    ///   - modelResource: The model resource specifying identifiers.
    /// - Returns: A `CreateModelInteraction` configured for the Gemini Interactions API.
    /// - Throws: An error if transcript, schema, or tool translation fails.
    static func translate(
      _ request: LanguageModelExecutorGenerationRequest,
      modelResource: ModelResource
    ) throws -> CreateModelInteraction {
      let (steps, systemInstruction) = try GeminiInteractionsTranscriptTranslator.translate(
        request.transcript
      )
      let modelIdentifier =
        modelResource.payloadResourceName.hasPrefix("publishers/")
        ? modelResource.payloadResourceName
        : modelResource.modelID

      let tools = try translateTools(request.enabledToolDefinitions)
      let responseFormat = try translateResponseFormat(schema: request.schema)
      let generationConfig = translateGenerationConfig(
        toolCallingMode: request.generationOptions.toolCallingMode
      )

      return CreateModelInteraction(
        generationConfig: generationConfig,
        input: .stepList(steps),
        model: Model(rawValue: modelIdentifier),
        responseFormat: responseFormat,
        store: false,
        stream: true,
        systemInstruction: systemInstruction,
        tools: tools
      )
    }

    /// Translates an optional `GenerationSchema` into a `JSONValue` representing the JSON Schema.
    ///
    /// - Parameter schema: An optional generation schema specifying structured output constraints.
    /// - Returns: A `JSONValue` representation of the schema, or `nil` if `schema` is `nil`.
    /// - Throws: An error if encoding the schema fails.
    static func translateResponseFormat(
      schema: GenerationSchema?
    ) throws -> JSONValue? {
      guard let schema else { return nil }
      let jsonSchema = try schema.toGeminiJSONSchema()
      let data = try JSONEncoder().encode(jsonSchema)
      return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    /// Translates enabled tool definitions into a list of Gemini Interactions `Tool` objects.
    ///
    /// - Parameter enabledToolDefinitions: Tool definitions registered for the request.
    /// - Returns: A list of `Tool` objects, or `nil` if empty.
    /// - Throws: An error if schema translation fails.
    static func translateTools(
      _ enabledToolDefinitions: [Transcript.ToolDefinition]
    ) throws -> [InteractionsDataModels.Tool]? {
      guard !enabledToolDefinitions.isEmpty else { return nil }

      return try enabledToolDefinitions.map { toolDefinition in
        let parameters = try toolDefinition.parameters.toGeminiJSONValue()
        let function = Function(
          description: toolDefinition.description,
          name: toolDefinition.name,
          parameters: parameters
        )
        return .function(function)
      }
    }

    /// Translates tool calling mode options into an Interactions `GenerationConfig`.
    ///
    /// - Parameter toolCallingMode: The tool calling mode options from the request.
    /// - Returns: A `GenerationConfig` configured with `toolChoice`, or `nil` if unspecified.
    static func translateGenerationConfig(
      toolCallingMode: GenerationOptions.ToolCallingMode?
    ) -> GenerationConfig? {
      guard let mode = toolCallingMode else { return nil }

      let choice: String
      switch mode.kind {
      case .allowed:
        choice = "auto"
      case .required:
        choice = "any"
      case .disallowed:
        choice = "none"
      @unknown default:
        choice = "auto"
      }

      return GenerationConfig(toolChoice: .string(choice))
    }
  }
#endif
