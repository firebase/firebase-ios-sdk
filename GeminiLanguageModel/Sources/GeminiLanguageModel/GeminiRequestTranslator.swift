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

#if compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
  import Foundation
  #if FoundationModelsFake
    import FoundationModelsFake
  #else
    import FoundationModels
  #endif
  import GeminiAPIDataModels

  /// Translates Foundation Models requests into Gemini API data models.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiRequestTranslator {
    /// Translates a `LanguageModelExecutorGenerationRequest` into a `GenerateContentRequest`.
    ///
    /// - Parameters:
    ///   - request: The generation request from the Foundation Models session.
    ///   - isAtToolCallingTurnLimit: Whether the session has reached the maximum number of
    ///     tool-calling turns for the current prompt. If `true`, the request tells Gemini not to
    ///     call functions.
    /// - Returns: A `GenerateContentRequest` configured for the Gemini API.
    /// - Throws: An error if transcript or schema translation fails, or if the request specifies
    ///   an unrecognized tool calling mode.
    static func translate(
      _ request: LanguageModelExecutorGenerationRequest,
      isAtToolCallingTurnLimit: Bool
    ) throws -> GenerateContentRequest {
      let (contents, systemInstruction) = try GeminiTranscriptTranslator.translate(
        request.transcript
      )
      let tools: [GeminiAPIDataModels.Tool]?
      if request.enabledToolDefinitions.isEmpty {
        // Declaring the tools in this case is best effort: function calling is disabled, so skip
        // any tool whose schema can't be translated instead of failing the request. If no tool
        // can be translated, the request is sent without declarations.
        tools = translateToolsBestEffort(toolDefinitionsForRequestWithoutEnabledTools(in: request))
      } else {
        tools = try translateTools(request.enabledToolDefinitions)
      }
      let hasFunctionDeclarations =
        tools?.contains { $0.functionDeclarations?.isEmpty == false } ?? false

      return try GenerateContentRequest {
        $0.systemInstruction = systemInstruction
        $0.contents = contents
        $0.tools = tools
        $0.toolConfig = try translateToolConfig(
          toolCallingMode: request.generationOptions.toolCallingMode,
          hasFunctionDeclarations: hasFunctionDeclarations,
          isFunctionCallingDisabled: isFunctionCallingDisabled(
            for: request,
            isAtToolCallingTurnLimit: isAtToolCallingTurnLimit
          )
        )
        $0.generationConfig = try translateGenerationConfig(schema: request.schema)
      }
    }

    /// Returns whether a request must not call functions.
    ///
    /// Function calling is disabled when the tool calling mode is `disallowed`, when the request
    /// enables no tools (whatever the tool calling mode is), or when the session has reached the
    /// maximum number of tool-calling turns for the current prompt.
    ///
    /// - Parameters:
    ///   - request: The generation request from the Foundation Models session.
    ///   - isAtToolCallingTurnLimit: Whether the session has reached the maximum number of
    ///     tool-calling turns for the current prompt.
    /// - Returns: `true` if the request must not call functions.
    static func isFunctionCallingDisabled(
      for request: LanguageModelExecutorGenerationRequest,
      isAtToolCallingTurnLimit: Bool
    ) -> Bool {
      isAtToolCallingTurnLimit
        || request.enabledToolDefinitions.isEmpty
        || request.generationOptions.toolCallingMode?.kind == .disallowed
    }

    /// Returns the tool definitions to declare as functions in a request that enables no tools.
    ///
    /// A request that enables no tools disables function calling, whatever the tool calling mode
    /// is. The session enables no tools with the `disallowed` tool calling mode, and can also
    /// disable every tool for a request, for example with a `LanguageModelSession.DynamicProfile`.
    /// A transcript with earlier tool calls would then refer to functions that the request
    /// doesn't declare. If the transcript has tool calls, this returns the tool definitions from
    /// the most recent instructions entry that lists tools, so that the request declares them
    /// with function calling disabled, matching the final request after the turn limit is
    /// reached.
    ///
    /// Instructions entries only list the tools whose schema is included in instructions, from
    /// the session's tools when the entry was added. Function calling is disabled, so any
    /// function call is rejected whether or not its function is declared.
    ///
    /// - Parameter request: The generation request from the Foundation Models session.
    /// - Returns: The tool definitions to declare as functions, or an empty array if the request
    ///   shouldn't declare any.
    static func toolDefinitionsForRequestWithoutEnabledTools(
      in request: LanguageModelExecutorGenerationRequest
    ) -> [Transcript.ToolDefinition] {
      guard
        request.enabledToolDefinitions.isEmpty,
        request.transcript.contains(where: { entry in
          guard case .toolCalls(let toolCalls) = entry else { return false }
          return !toolCalls.isEmpty
        })
      else {
        return []
      }
      for entry in request.transcript.reversed() {
        if case .instructions(let instructions) = entry, !instructions.toolDefinitions.isEmpty {
          return instructions.toolDefinitions
        }
      }
      return []
    }

    /// Returns the number of tool-calling turns since the most recent prompt in a transcript.
    ///
    /// A tool-calling turn is a model response that calls one or more tools. The session records
    /// each one as a single `Transcript.Entry.toolCalls` entry, so parallel tool calls count as
    /// one turn. Each prompt starts a new count.
    ///
    /// - Parameter transcript: The transcript of the session.
    /// - Returns: The number of tool-calling turns since the most recent prompt.
    static func toolCallingTurnCount(in transcript: Transcript) -> Int {
      var turnCount = 0
      for entry in transcript.reversed() {
        switch entry {
        case .prompt:
          return turnCount
        case .toolCalls(let toolCalls) where !toolCalls.isEmpty:
          turnCount += 1
        default:
          break
        }
      }
      return turnCount
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

      return try GenerationConfig {
        $0.responseMIMEType = "application/json"
        $0.responseJSONSchema = try schema.toGeminiJSONSchema()
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

      let declarations = try enabledToolDefinitions.map(translateFunctionDeclaration)
      return [GeminiAPIDataModels.Tool { $0.functionDeclarations = declarations }]
    }

    /// Translates tool definitions into a list of Gemini `Tool` objects, skipping any tool whose
    /// definition can't be translated.
    ///
    /// Use this only when declaring the tools is best effort, such as when function calling is
    /// disabled, so that one untranslatable tool doesn't drop the declarations of the others.
    ///
    /// - Parameter toolDefinitions: The tool definitions to declare as functions.
    /// - Returns: A list containing a single `Tool` with the translatable function declarations,
    ///   or `nil` if none of the tool definitions can be translated.
    static func translateToolsBestEffort(
      _ toolDefinitions: [Transcript.ToolDefinition]
    ) -> [GeminiAPIDataModels.Tool]? {
      // A tool's schema can fail to translate, for example with an unsupported generation guide.
      let declarations = toolDefinitions.compactMap { try? translateFunctionDeclaration($0) }
      guard !declarations.isEmpty else { return nil }

      return [GeminiAPIDataModels.Tool { $0.functionDeclarations = declarations }]
    }

    /// Translates a tool definition into a Gemini `FunctionDeclaration`.
    ///
    /// - Parameter toolDefinition: The tool definition to translate.
    /// - Returns: A function declaration with the tool's name, description, and parameters.
    /// - Throws: An error if schema translation fails.
    static func translateFunctionDeclaration(
      _ toolDefinition: Transcript.ToolDefinition
    ) throws -> FunctionDeclaration {
      try FunctionDeclaration {
        $0.name = toolDefinition.name
        $0.description = toolDefinition.description
        $0.parametersJSONSchema = try toolDefinition.parameters.toGeminiJSONSchema()
      }
    }

    /// Translates tool calling options into a Gemini `ToolConfig`.
    ///
    /// - Parameters:
    ///   - toolCallingMode: The tool calling mode from the request. `nil` means the developer
    ///     expressed no preference and is treated as `GenerationOptions.ToolCallingMode.allowed`.
    ///   - hasFunctionDeclarations: Whether the request declares any functions.
    ///     `functionCallingConfig` only governs function calling, so it is omitted entirely when
    ///     there are none.
    ///   - isFunctionCallingDisabled: Whether the request must not call functions (see
    ///     `isFunctionCallingDisabled(for:isAtToolCallingTurnLimit:)`). If `true`, function calling
    ///     is disabled whatever `toolCallingMode` is, so that the model gives a final response.
    /// - Returns: A `ToolConfig`, or `nil` if no configuration is needed.
    /// - Throws: `LanguageModelError.unsupportedCapability` if function calling isn't disabled and
    ///   `toolCallingMode` is a mode that this version of the SDK does not recognize.
    static func translateToolConfig(
      toolCallingMode: GenerationOptions.ToolCallingMode?,
      hasFunctionDeclarations: Bool,
      isFunctionCallingDisabled: Bool
    ) throws -> ToolConfig? {
      // Computed independently of the `ToolConfig` check below to allow future options (such
      // as `includeServerSideToolInvocations`) when built-in tools are present without function
      // declarations.
      let functionCallingConfig: FunctionCallingConfig?
      if hasFunctionDeclarations {
        let callingMode: FunctionCallingConfig.Mode
        if isFunctionCallingDisabled {
          // Disabled function calling (such as at the turn limit) overrides the requested mode,
          // including `required`, which would otherwise keep calling tools indefinitely.
          callingMode = FunctionCallingConfig.Mode.none
        } else if let mode = toolCallingMode {
          switch mode.kind {
          case .allowed:
            callingMode = .validated
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
          // `GenerationOptions.toolCallingMode` is optional and defaults to `nil` unless set by
          // the caller. Omitting `functionCallingConfig` in that case causes the backend to
          // default to `AUTO`, so `nil` maps to the allowed mode.
          callingMode = .validated
        }
        functionCallingConfig = FunctionCallingConfig { $0.mode = callingMode }
      } else {
        functionCallingConfig = nil
      }

      guard let functionCallingConfig else {
        return nil
      }

      return ToolConfig { $0.functionCallingConfig = functionCallingConfig }
    }
  }
#endif  // compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
