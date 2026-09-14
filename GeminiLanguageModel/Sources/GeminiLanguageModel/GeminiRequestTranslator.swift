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
  import GeminiAPIDataModels

  /// Translates Foundation Models requests into Gemini API data models.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiRequestTranslator {
    /// Translates a `LanguageModelExecutorGenerationRequest` into a `GenerateContentRequest`.
    ///
    /// - Parameters:
    ///   - request: The generation request from the Foundation Models session.
    ///   - compatibilityOptions: Overrides for backend-dependent behavior. Defaults to the recommended
    ///     values.
    /// - Returns: A `GenerateContentRequest` configured for the Gemini API.
    /// - Throws: An error if transcript or schema translation fails.
    static func translate(
      _ request: LanguageModelExecutorGenerationRequest,
      compatibilityOptions: GeminiLanguageModel.CompatibilityOptions =
        GeminiLanguageModel.CompatibilityOptions()
    ) throws -> GenerateContentRequest {
      let (contents, systemInstruction) = try GeminiTranscriptTranslator.translate(
        request.transcript
      )
      let generationConfig = try translateGenerationConfig(schema: request.schema)
      let tools = try translateTools(request.enabledToolDefinitions)
      let hasFunctionDeclarations =
        tools?.contains { !($0.functionDeclarations ?? []).isEmpty } ?? false
      let toolConfig = translateToolConfig(
        toolCallingMode: request.generationOptions.toolCallingMode,
        hasFunctionDeclarations: hasFunctionDeclarations,
        compatibilityOptions: compatibilityOptions
      )

      return GenerateContentRequest(
        systemInstruction: systemInstruction,
        contents: contents,
        tools: tools,
        toolConfig: toolConfig,
        generationConfig: generationConfig
      )
    }

    /// Translates an optional `GenerationSchema` into a Gemini `GenerationConfig`.
    ///
    /// - Parameter schema: An optional generation schema specifying structured output constraints.
    /// - Returns: A `GenerationConfig` configured with response schema, or `nil` if `schema`
    ///   is `nil`.
    /// - Throws: An error if encoding the schema fails or if an unsupported generation guide is
    ///   detected.
    static func translateGenerationConfig(
      schema: GenerationSchema?
    ) throws -> GenerationConfig? {
      guard let schema else { return nil }

      let jsonSchema = try schema.toGeminiJSONSchema()
      let textFormat = TextResponseFormat(
        mimeType: .applicationJson,
        schema: .object(jsonSchema)
      )
      return GenerationConfig(responseFormat: ResponseFormatConfig(text: textFormat))
    }

    /// Translates enabled tool definitions into a list of Gemini `Tool` objects.
    ///
    /// - Parameter enabledToolDefinitions: Tool definitions registered for the request.
    /// - Returns: A list containing a single `Tool` with function declarations, or `nil` if empty.
    /// - Throws: An error if schema translation fails.
    static func translateTools(
      _ enabledToolDefinitions: [Transcript.ToolDefinition]
    ) throws -> [GeminiAPIDataModels.Tool]? {
      guard !enabledToolDefinitions.isEmpty else { return nil }

      let declarations = try enabledToolDefinitions.map { toolDefinition in
        let parameters = try toolDefinition.parameters.toGeminiJSONValue()
        return FunctionDeclaration(
          name: toolDefinition.name,
          description: toolDefinition.description,
          parametersJsonSchema: parameters
        )
      }
      return [GeminiAPIDataModels.Tool(functionDeclarations: declarations)]
    }

    /// Translates tool calling options into a Gemini `ToolConfig`.
    ///
    /// - Parameters:
    ///   - toolCallingMode: The tool calling mode from the request.
    ///   - hasFunctionDeclarations: Whether the request declares any functions.
    ///     `function_calling_config` only governs function calling, so it is
    ///     omitted entirely when there are none.
    ///   - compatibilityOptions: Overrides for backend-dependent behavior. Defaults to the recommended
    ///     values.
    /// - Returns: A `ToolConfig`, or `nil` if it would carry no fields.
    static func translateToolConfig(
      toolCallingMode: GenerationOptions.ToolCallingMode?,
      hasFunctionDeclarations: Bool,
      compatibilityOptions: GeminiLanguageModel.CompatibilityOptions =
        GeminiLanguageModel.CompatibilityOptions()
    ) -> ToolConfig? {
      let functionCallingConfig: FunctionCallingConfig?
      if hasFunctionDeclarations, let mode = toolCallingMode {
        let callingMode: FunctionCallingConfig.Mode
        switch mode.kind {
        case .allowed:
          callingMode = geminiMode(for: compatibilityOptions.toolCalling.allowedMode)
        case .required:
          callingMode = .any
        case .disallowed:
          callingMode = FunctionCallingConfig.Mode.none
        @unknown default:
          callingMode = geminiMode(for: compatibilityOptions.toolCalling.allowedMode)
        }
        functionCallingConfig = FunctionCallingConfig(mode: callingMode)
      } else {
        functionCallingConfig = nil
      }

      guard functionCallingConfig != nil else {
        return nil
      }

      return ToolConfig(
        functionCallingConfig: functionCallingConfig
      )
    }

    private static func geminiMode(
      for allowedMode: GeminiLanguageModel.CompatibilityOptions.AllowedMode
    ) -> FunctionCallingConfig.Mode {
      switch allowedMode {
      case .validated:
        .validated
      case .auto:
        .auto
      @unknown default:
        .validated
      }
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
