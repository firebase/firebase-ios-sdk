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
    /// - Parameter request: The generation request from the Foundation Models session.
    /// - Returns: A `GenerateContentRequest` configured for the Gemini API.
    /// - Throws: An error if transcript or schema translation fails, or if the request specifies
    ///   an unrecognized tool calling mode.
    static func translate(
      _ request: LanguageModelExecutorGenerationRequest
    ) throws -> GenerateContentRequest {
      let (contents, systemInstruction) = try GeminiTranscriptTranslator.translate(
        request.transcript
      )
      let generationConfig = try translateGenerationConfig(schema: request.schema)
      let tools = try translateTools(request.enabledToolDefinitions)
      let hasFunctionDeclarations =
        tools?.contains { $0.functionDeclarations?.isEmpty == false } ?? false
      let toolConfig = try translateToolConfig(
        toolCallingMode: request.generationOptions.toolCallingMode,
        hasFunctionDeclarations: hasFunctionDeclarations
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
    static func translateGenerationConfig(schema: GenerationSchema?) throws -> GenerationConfig? {
      guard let schema else { return nil }

      let jsonSchema = try schema.toGeminiJSONSchema()
      return GenerationConfig(
        responseMimeType: "application/json",
        responseJsonSchema: .object(jsonSchema)
      )
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
    /// - Returns: A `ToolConfig`, or `nil` if no configuration is needed.
    /// - Throws: `LanguageModelError.unsupportedCapability` if `toolCallingMode` is a mode that
    ///   this version of the SDK does not recognize.
    static func translateToolConfig(
      toolCallingMode: GenerationOptions.ToolCallingMode?,
      hasFunctionDeclarations: Bool
    ) throws -> ToolConfig? {
      // Computed independently of the `ToolConfig` check below to allow future options (such
      // as `includeServerSideToolInvocations`) when built-in tools are present without function
      // declarations.
      let functionCallingConfig: FunctionCallingConfig?
      if hasFunctionDeclarations {
        // `GenerationOptions.toolCallingMode` is optional and defaults to `nil` unless set by the
        // caller. Omitting `functionCallingConfig` in that case causes the backend to default to
        // `AUTO`, so `nil` maps to the allowed mode.
        let allowedMode = FunctionCallingConfig.Mode.validated
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
            // A mode added in a later OS release; its semantics are unknown, so approximating it
            // with the allowed mode could silently diverge from what the caller requested.
            throw LanguageModelError.unsupportedCapability(
              LanguageModelError.UnsupportedCapability(
                capability: .toolCalling,
                debugDescription: "Unsupported tool calling mode: \(mode)."
              )
            )
          }
        } else {
          callingMode = allowedMode
        }
        functionCallingConfig = FunctionCallingConfig(mode: callingMode)
      } else {
        functionCallingConfig = nil
      }

      guard let functionCallingConfig else {
        return nil
      }

      return ToolConfig(
        functionCallingConfig: functionCallingConfig
      )
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
