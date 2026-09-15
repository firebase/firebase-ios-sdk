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
    ///   - compatibilityOptions: Options for configuring compatibility with the Gemini API.
    /// - Returns: A `GenerateContentRequest` configured for the Gemini API.
    /// - Throws: An error if transcript or schema translation fails.
    static func translate(
      _ request: LanguageModelExecutorGenerationRequest,
      compatibilityOptions: GeminiLanguageModel.CompatibilityOptions
    ) throws -> GenerateContentRequest {
      let (contents, systemInstruction) = try GeminiTranscriptTranslator.translate(
        request.transcript
      )
      let generationConfig = try translateGenerationConfig(
        schema: request.schema,
        compatibilityOptions: compatibilityOptions
      )
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
    /// - Parameters:
    ///   - schema: An optional generation schema specifying structured output constraints.
    ///   - compatibilityOptions: Options for configuring compatibility with the Gemini API.
    /// - Returns: A `GenerationConfig` configured with response schema, or `nil` if `schema`
    ///   is `nil`.
    /// - Throws: An error if encoding the schema fails or if an unsupported generation guide is
    ///   detected.
    static func translateGenerationConfig(
      schema: GenerationSchema?,
      compatibilityOptions: GeminiLanguageModel.CompatibilityOptions
    ) throws -> GenerationConfig? {
      guard let schema else { return nil }

      let jsonSchema = try schema.toGeminiJSONSchema()
      switch compatibilityOptions.guidedGeneration.schemaFormat {
      case .responseJsonSchema:
        return GenerationConfig(
          responseMimeType: "application/json",
          responseJsonSchema: .object(jsonSchema)
        )
      case .responseFormat:
        let textFormat = TextResponseFormat(
          mimeType: .applicationJson,
          schema: .object(jsonSchema)
        )
        return GenerationConfig(responseFormat: ResponseFormatConfig(text: textFormat))
      }
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
    ///   - toolCallingMode: The tool calling mode from the request. `nil` means the developer
    ///     expressed no preference and is treated as `GenerationOptions.ToolCallingMode.allowed`.
    ///   - hasFunctionDeclarations: Whether the request declares any functions.
    ///     `functionCallingConfig` only governs function calling, so it is omitted entirely when
    ///     there are none.
    ///   - compatibilityOptions: Options for configuring compatibility with the Gemini API.
    /// - Returns: A `ToolConfig`, or `nil` if no configuration is needed.
    static func translateToolConfig(
      toolCallingMode: GenerationOptions.ToolCallingMode?,
      hasFunctionDeclarations: Bool,
      compatibilityOptions: GeminiLanguageModel.CompatibilityOptions
    ) -> ToolConfig? {
      // Computed independently of the `ToolConfig` check below to allow future options (such
      // as `includeServerSideToolInvocations`) when built-in tools are present without function
      // declarations.
      let functionCallingConfig: FunctionCallingConfig?
      if hasFunctionDeclarations {
        // `GenerationOptions.toolCallingMode` is optional and defaults to `nil` unless set by the
        // caller. Omitting `functionCallingConfig` in that case causes the backend to default to
        // `AUTO`, so `nil` maps to the allowed mode.
        let allowedMode = geminiMode(for: compatibilityOptions.toolCalling.allowedMode)
        let callingMode: FunctionCallingConfig.Mode
        if let mode = toolCallingMode {
          switch mode.kind {
          case .allowed:
            callingMode = allowedMode
          case .required:
            callingMode = .any
          case .disallowed:
            callingMode = FunctionCallingConfig.Mode.none
          @unknown default:
            callingMode = allowedMode
          }
        } else {
          callingMode = allowedMode
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
