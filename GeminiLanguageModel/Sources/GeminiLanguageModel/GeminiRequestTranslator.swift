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
    ///   - thinking: An optional thinking configuration from the model.
    /// - Returns: A `GenerateContentRequest` configured for the Gemini API.
    /// - Throws: An error if transcript or schema translation fails.
    static func translate(
      _ request: LanguageModelExecutorGenerationRequest,
      thinking: GeminiLanguageModel.Thinking? = nil
    ) throws -> GenerateContentRequest {
      var effectiveThinking = thinking
      if let metadataContent = request.metadata[GeminiRequestMetadata.metadataKey] {
        let meta = GeminiRequestMetadata(metadataContent)
        if let summaries = meta.thinkingSummaries {
          effectiveThinking = GeminiLanguageModel.Thinking(summaries: summaries)
        }
      } else {
        for entry in request.transcript.reversed() {
          if case .prompt(let prompt) = entry {
            if let metadataContent = prompt.metadata[GeminiRequestMetadata.metadataKey] {
              let meta = GeminiRequestMetadata(metadataContent)
              if let summaries = meta.thinkingSummaries {
                effectiveThinking = GeminiLanguageModel.Thinking(summaries: summaries)
              }
            }
            break
          }
        }
      }

      let (contents, systemInstruction) = try GeminiTranscriptTranslator.translate(
        request.transcript
      )
      let generationConfig = try translateGenerationConfig(
        schema: request.schema,
        reasoningLevel: request.contextOptions.reasoningLevel,
        thinking: effectiveThinking
      )
      let tools = try translateTools(request.enabledToolDefinitions)
      let toolConfig = translateToolConfig(
        toolCallingMode: request.generationOptions.toolCallingMode
      )

      return GenerateContentRequest(
        systemInstruction: systemInstruction,
        contents: contents,
        tools: tools,
        toolConfig: toolConfig,
        generationConfig: generationConfig
      )
    }

    /// Translates schema and thinking options into a Gemini `GenerationConfig`.
    ///
    /// - Parameters:
    ///   - schema: An optional generation schema specifying structured output constraints.
    ///   - reasoningLevel: An optional reasoning level from the request's context options.
    ///   - thinking: An optional thinking configuration from the model.
    /// - Returns: A `GenerationConfig` configured with response format and thinking options,
    ///   or `nil` if none are specified.
    /// - Throws: An error if encoding the schema fails.
    static func translateGenerationConfig(
      schema: GenerationSchema?,
      reasoningLevel: ContextOptions.ReasoningLevel? = nil,
      thinking: GeminiLanguageModel.Thinking? = nil
    ) throws -> GenerationConfig? {
      let responseFormat: ResponseFormatConfig?
      if let schema {
        let jsonSchema = try schema.toGeminiJSONSchema()
        let textFormat = TextResponseFormat(
          mimeType: .applicationJson,
          schema: .object(jsonSchema)
        )
        responseFormat = ResponseFormatConfig(text: textFormat)
      } else {
        responseFormat = nil
      }

      let thinkingConfig = translateThinkingConfig(
        reasoningLevel: reasoningLevel,
        thinking: thinking
      )

      guard responseFormat != nil || thinkingConfig != nil else { return nil }

      return GenerationConfig(
        thinkingConfig: thinkingConfig,
        responseFormat: responseFormat
      )
    }

    /// Translates context reasoning level and model thinking configuration into a Gemini `ThinkingConfig`.
    ///
    /// - Parameters:
    ///   - reasoningLevel: An optional reasoning level from context options.
    ///   - thinking: An optional thinking configuration from the model.
    /// - Returns: A `ThinkingConfig` configured for the Gemini API, or `nil` if unspecified.
    static func translateThinkingConfig(
      reasoningLevel: ContextOptions.ReasoningLevel?,
      thinking: GeminiLanguageModel.Thinking?
    ) -> ThinkingConfig? {
      let thinkingLevel = reasoningLevel.flatMap(translateThinkingLevel)
      let includeThoughts = thinking?.summaries.flatMap(translateIncludeThoughts)

      guard thinkingLevel != nil || includeThoughts != nil else { return nil }

      return ThinkingConfig(
        includeThoughts: includeThoughts,
        thinkingLevel: thinkingLevel
      )
    }

    /// Translates a FoundationModels `ReasoningLevel` into a Gemini `ThinkingConfig.ThinkingLevel`.
    ///
    /// - Parameter reasoningLevel: The reasoning level to translate.
    /// - Returns: The corresponding Gemini thinking level.
    static func translateThinkingLevel(
      _ reasoningLevel: ContextOptions.ReasoningLevel
    ) -> ThinkingConfig.ThinkingLevel {
      switch reasoningLevel {
      case .light:
        return .low
      case .moderate:
        return .medium
      case .deep:
        return .high
      case .custom(let value):
        if value.caseInsensitiveCompare("MINIMAL") == .orderedSame {
          return .minimal
        }
        if value.caseInsensitiveCompare("LOW") == .orderedSame {
          return .low
        }
        if value.caseInsensitiveCompare("MEDIUM") == .orderedSame {
          return .medium
        }
        if value.caseInsensitiveCompare("HIGH") == .orderedSame {
          return .high
        }
        return .unrecognized(value)
      @unknown default:
        return .unrecognized(String(describing: reasoningLevel))
      }
    }

    /// Translates a `GeminiLanguageModel.Thinking.SummaryMode` into a boolean for `ThinkingConfig.includeThoughts`.
    ///
    /// - Parameter mode: The thinking summaries mode.
    /// - Returns: `true` for `.auto`, `false` for `.off`.
    static func translateIncludeThoughts(
      _ mode: GeminiLanguageModel.Thinking.SummaryMode
    ) -> Bool {
      switch mode {
      case .auto:
        return true
      case .off:
        return false
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

    /// Translates tool calling mode options into a Gemini `ToolConfig`.
    ///
    /// - Parameter toolCallingMode: The tool calling mode options from the request.
    /// - Returns: A `ToolConfig` configured with function calling mode, or `nil` if unspecified.
    static func translateToolConfig(
      toolCallingMode: GenerationOptions.ToolCallingMode?
    ) -> ToolConfig? {
      guard let mode = toolCallingMode else { return nil }

      let callingMode: FunctionCallingConfig.Mode
      switch mode.kind {
      case .allowed:
        // Note: Map to .auto for standard model autonomy. Consider evaluating
        // .validated in the future for constrained decoding against declared functions.
        callingMode = .auto
      case .required:
        callingMode = .any
      case .disallowed:
        callingMode = .none
      @unknown default:
        callingMode = .auto
      }

      return ToolConfig(
        functionCallingConfig: FunctionCallingConfig(mode: callingMode)
      )
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
