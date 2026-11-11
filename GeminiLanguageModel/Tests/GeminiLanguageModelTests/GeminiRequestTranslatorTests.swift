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
  import GeminiTestUtilities
  import Testing

  @testable import GeminiLanguageModel

  @Suite("GeminiRequestTranslator Tests", .requireFoundationModels)
  struct GeminiRequestTranslatorTests {
    @Generable(description: "A simple user profile")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct UserProfile {
      var username: String
      var score: Int
    }

    @Generable(description: "A data model with a pattern guide")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct DataModelWithPattern {
      @Guide(description: "A postal code", .pattern(#/^\d{5}$/#))
      var postalCode: String
    }

    @Generable(description: "A city location argument")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct LocationArguments {
      var city: String
    }

    @Generable(
      description: "Postal code arguments with a pattern guide that Gemini doesn't support")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct PostalCodeArguments {
      @Guide(description: "A postal code", .pattern(#/^\d{5}$/#))
      var postalCode: String
    }

    @Generable(description: "Empty arguments")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct EmptyArguments {}

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)

    func translatesRequestWithoutSchema() throws {
      let promptEntry = Transcript.Entry.prompt(
        Transcript.Prompt(
          id: "prompt-1",
          segments: [.text(Transcript.TextSegment(content: "Hello"))]
        )
      )
      let transcript = Transcript(entries: [promptEntry])
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: transcript,
        enabledTools: [],
        schema: nil,
        generationOptions: GenerationOptions(),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: false)

      #expect(result.systemInstruction == nil)
      #expect(result.contents?.count == 1)
      #expect(result.contents?.first?.parts?.first?.data == Part.PartData.text("Hello"))
      #expect(result.generationConfig == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesRequestWithSchema() throws {
      let promptEntry = Transcript.Entry.prompt(
        Transcript.Prompt(
          id: "prompt-1",
          segments: [.text(Transcript.TextSegment(content: "Generate a profile"))]
        )
      )
      let transcript = Transcript(entries: [promptEntry])
      let schema = UserProfile.generationSchema
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: transcript,
        enabledTools: [],
        schema: schema,
        generationOptions: GenerationOptions(),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: false)

      #expect(result.contents?.count == 1)
      let generationConfig = try #require(result.generationConfig)
      #expect(generationConfig.responseMIMEType == "application/json")
      let schemaObject = try #require(generationConfig.responseJSONSchema)
      #expect(schemaObject["x-order"] == nil)
      let ordering = try #require(schemaObject["propertyOrdering"])
      #expect(ordering == JSONValue.array([.string("username"), .string("score")]))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationConfigWithNilSchemaReturnsNil() throws {
      let config = try GeminiRequestTranslator.translateGenerationConfig(schema: nil)

      #expect(config == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationConfigWithSchemaReturnsConfig() throws {
      let schema = UserProfile.generationSchema

      let config = try GeminiRequestTranslator.translateGenerationConfig(schema: schema)

      let generationConfig = try #require(config)
      #expect(generationConfig.responseMIMEType == "application/json")
      let schemaObject = try #require(generationConfig.responseJSONSchema)
      #expect(schemaObject["x-order"] == nil)
      #expect(schemaObject["propertyOrdering"] != nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationConfigWithPatternGuideThrowsUnsupportedGenerationGuide() throws {
      let schema = DataModelWithPattern.generationSchema

      do {
        _ = try GeminiRequestTranslator.translateGenerationConfig(schema: schema)
        Issue.record("Expected unsupportedGenerationGuide error.")
      } catch LanguageModelError.unsupportedGenerationGuide(let error) {
        #expect(error.debugDescription.contains("pattern"))
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesEnabledToolDefinitionsIntoFunctionDeclarations() throws {
      let toolDefinition = Transcript.ToolDefinition(
        name: "get_current_weather",
        description: "Get the current weather for a city.",
        parameters: LocationArguments.generationSchema
      )

      let tools = try GeminiRequestTranslator.translateTools([toolDefinition])

      let unwrappedTools = try #require(tools)
      #expect(unwrappedTools.count == 1)
      let declarations = try #require(unwrappedTools[0].functionDeclarations)
      #expect(declarations.count == 1)
      #expect(declarations[0].name == "get_current_weather")
      #expect(declarations[0].description == "Get the current weather for a city.")
      let dict = try #require(declarations[0].parametersJSONSchema)
      #expect(dict["type"] == .string("object"))
      guard case .object(let properties) = dict["properties"] else {
        Issue.record("Expected properties object in schema")
        return
      }
      guard case .object(let cityProperty) = properties["city"] else {
        Issue.record("Expected city property in properties")
        return
      }
      #expect(cityProperty["type"] == .string("string"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolWithEmptyArguments() throws {
      let toolDefinition = Transcript.ToolDefinition(
        name: "get_current_time",
        description: "Get the current time.",
        parameters: EmptyArguments.generationSchema
      )

      let tools = try GeminiRequestTranslator.translateTools([toolDefinition])

      let unwrappedTools = try #require(tools)
      #expect(unwrappedTools.count == 1)
      let declarations = try #require(unwrappedTools[0].functionDeclarations)
      #expect(declarations.count == 1)
      #expect(declarations[0].name == "get_current_time")
      #expect(declarations[0].description == "Get the current time.")
      let dict = try #require(declarations[0].parametersJSONSchema)
      #expect(dict["type"] == .string("object"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func emptyEnabledToolDefinitionsResultsInNilTools() throws {
      let tools = try GeminiRequestTranslator.translateTools([])

      #expect(tools == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolCallingModes() throws {
      let allowedConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .allowed,
        hasFunctionDeclarations: true,
        isAtToolCallingTurnLimit: false
      )
      let requiredConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .required,
        hasFunctionDeclarations: true,
        isAtToolCallingTurnLimit: false
      )
      let disallowedConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .disallowed,
        hasFunctionDeclarations: true,
        isAtToolCallingTurnLimit: false
      )
      let unsetConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: nil,
        hasFunctionDeclarations: true,
        isAtToolCallingTurnLimit: false
      )

      #expect(allowedConfig?.functionCallingConfig?.mode == .validated)
      #expect(requiredConfig?.functionCallingConfig?.mode == .any)
      #expect(disallowedConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
      #expect(unsetConfig?.functionCallingConfig?.mode == .validated)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolCallingModesWithoutDeclarationsReturnsNil() throws {
      let allowedConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .allowed,
        hasFunctionDeclarations: false,
        isAtToolCallingTurnLimit: false
      )
      let requiredConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .required,
        hasFunctionDeclarations: false,
        isAtToolCallingTurnLimit: false
      )
      let disallowedConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .disallowed,
        hasFunctionDeclarations: false,
        isAtToolCallingTurnLimit: false
      )
      let nilConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: nil,
        hasFunctionDeclarations: false,
        isAtToolCallingTurnLimit: false
      )

      #expect(allowedConfig == nil)
      #expect(requiredConfig == nil)
      #expect(disallowedConfig == nil)
      #expect(nilConfig == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesRequestEndToEndWithToolCallingMode() throws {
      let promptEntry = Transcript.Entry.prompt(
        Transcript.Prompt(
          id: "prompt-1",
          segments: [.text(Transcript.TextSegment(content: "What is the weather in Boston?"))]
        )
      )
      let transcript = Transcript(entries: [promptEntry])
      let toolDefinition = Transcript.ToolDefinition(
        name: "get_current_weather",
        description: "Get the current weather for a city.",
        parameters: LocationArguments.generationSchema
      )
      let requestWithTool = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: transcript,
        enabledTools: [toolDefinition],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .allowed),
        contextOptions: ContextOptions(),
        metadata: [:]
      )
      let requestWithoutTools = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: transcript,
        enabledTools: [],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .allowed),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let resultWithTool = try GeminiRequestTranslator.translate(
        requestWithTool, isAtToolCallingTurnLimit: false)
      let resultWithoutTools = try GeminiRequestTranslator.translate(
        requestWithoutTools, isAtToolCallingTurnLimit: false)

      let unwrappedToolConfig = try #require(resultWithTool.toolConfig)
      let functionCallingConfig = try #require(unwrappedToolConfig.functionCallingConfig)
      #expect(functionCallingConfig.mode == FunctionCallingConfig.Mode.validated)
      #expect(resultWithoutTools.toolConfig == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesRequestEndToEndWithUnsetToolCallingMode() throws {
      let promptEntry = Transcript.Entry.prompt(
        Transcript.Prompt(
          id: "prompt-1",
          segments: [.text(Transcript.TextSegment(content: "What is the weather in Boston?"))]
        )
      )
      let transcript = Transcript(entries: [promptEntry])
      let toolDefinition = Transcript.ToolDefinition(
        name: "get_current_weather",
        description: "Get the current weather for a city.",
        parameters: LocationArguments.generationSchema
      )
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: transcript,
        enabledTools: [toolDefinition],
        schema: nil,
        generationOptions: GenerationOptions(),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: false)

      let toolConfig = try #require(result.toolConfig)
      let functionCallingConfig = try #require(toolConfig.functionCallingConfig)
      #expect(functionCallingConfig.mode == FunctionCallingConfig.Mode.validated)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func toolCallingTurnCountCountsToolCallsSinceMostRecentPrompt() throws {
      let parisCall = try Self.makeToolCall(id: "call-1", city: "Paris")
      let londonCall = try Self.makeToolCall(id: "call-2", city: "London")
      let tokyoCall = try Self.makeToolCall(id: "call-3", city: "Tokyo")
      let romeCall = try Self.makeToolCall(id: "call-4", city: "Rome")
      let transcript = Transcript(
        entries: [
          .instructions(
            Transcript.Instructions(
              segments: [.text(Transcript.TextSegment(content: "Be brief."))],
              toolDefinitions: []
            )
          ),
          .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Paris?"))])),
          .toolCalls(Transcript.ToolCalls(id: "calls-1", [parisCall])),
          .toolOutput(Self.makeToolOutput(id: "call-1")),
          .response(
            Transcript.Response(segments: [.text(Transcript.TextSegment(content: "Sunny."))])),
          .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Others?"))])),
          .reasoning(
            Transcript.Reasoning(
              segments: [.text(Transcript.TextSegment(content: "Check two cities."))])
          ),
          .response(
            Transcript.Response(segments: [.text(Transcript.TextSegment(content: "Checking."))])),
          .toolCalls(Transcript.ToolCalls(id: "calls-2", [londonCall, tokyoCall])),
          .toolOutput(Self.makeToolOutput(id: "call-2")),
          .toolOutput(Self.makeToolOutput(id: "call-3")),
          .toolCalls(Transcript.ToolCalls(id: "calls-3", [])),
          .toolCalls(Transcript.ToolCalls(id: "calls-4", [romeCall])),
          .toolOutput(Self.makeToolOutput(id: "call-4")),
        ]
      )

      let turnCount = GeminiRequestTranslator.toolCallingTurnCount(in: transcript)

      #expect(turnCount == 2)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func toolCallingTurnCountInEmptyTranscriptIsZero() {
      let turnCount = GeminiRequestTranslator.toolCallingTurnCount(in: Transcript(entries: []))

      #expect(turnCount == 0)
    }

    @Test(arguments: [
      GenerationOptions.ToolCallingMode?.none,
      .allowed,
      .required,
      .disallowed,
    ])
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolConfigAtToolCallingTurnLimitToNone(
      toolCallingMode: GenerationOptions.ToolCallingMode?
    ) throws {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .sortedKeys

      let toolConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: toolCallingMode,
        hasFunctionDeclarations: true,
        isAtToolCallingTurnLimit: true
      )

      let mode = try #require(toolConfig?.functionCallingConfig?.mode)
      #expect(mode == FunctionCallingConfig.Mode.none)
      let json = String(decoding: try encoder.encode(toolConfig), as: UTF8.self)
      #expect(json == #"{"functionCallingConfig":{"mode":"NONE"}}"#)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesRequestAtToolCallingTurnLimitKeepsToolDeclarations() throws {
      let toolDefinition = Transcript.ToolDefinition(
        name: "get_current_weather",
        description: "Get the current weather for a city.",
        parameters: LocationArguments.generationSchema
      )
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: Transcript(
          entries: [
            .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Paris?"))]))
          ]
        ),
        enabledTools: [toolDefinition],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .required),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: true)

      let functionDeclarations = try #require(result.tools?.first?.functionDeclarations)
      #expect(functionDeclarations.map(\.name) == ["get_current_weather"])
      #expect(result.toolConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolConfigAtToolCallingTurnLimitWithoutDeclarationsReturnsNil() throws {
      let toolConfig = try GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .required,
        hasFunctionDeclarations: false,
        isAtToolCallingTurnLimit: true
      )

      #expect(toolConfig == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesDisallowedRequestAfterToolCallsDeclaresInstructionsToolsWithNone() throws {
      let toolDefinition = Self.makeWeatherToolDefinition()
      let parisCall = try Self.makeToolCall(id: "call-1", city: "Paris")
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: Transcript(
          entries: [
            .instructions(Transcript.Instructions(segments: [], toolDefinitions: [toolDefinition])),
            .prompt(
              Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Paris?"))])),
            .toolCalls(Transcript.ToolCalls(id: "calls-1", [parisCall])),
            .toolOutput(Self.makeToolOutput(id: "call-1")),
          ]
        ),
        enabledTools: [],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .disallowed),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: false)

      let functionDeclarations = try #require(result.tools?.first?.functionDeclarations)
      #expect(functionDeclarations.map(\.name) == ["getWeather"])
      #expect(result.toolConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesRequestWithoutEnabledToolsAtToolCallingTurnLimitDeclaresInstructionsTools()
      throws
    {
      let toolDefinition = Self.makeWeatherToolDefinition()
      let parisCall = try Self.makeToolCall(id: "call-1", city: "Paris")
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: Transcript(
          entries: [
            .instructions(Transcript.Instructions(segments: [], toolDefinitions: [toolDefinition])),
            .prompt(
              Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Paris?"))])),
            .toolCalls(Transcript.ToolCalls(id: "calls-1", [parisCall])),
            .toolOutput(Self.makeToolOutput(id: "call-1")),
          ]
        ),
        enabledTools: [],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .required),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: true)

      let functionDeclarations = try #require(result.tools?.first?.functionDeclarations)
      #expect(functionDeclarations.map(\.name) == ["getWeather"])
      #expect(result.toolConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesDisallowedRequestWithUntranslatableInstructionsToolOmitsTools() throws {
      let toolDefinition = Transcript.ToolDefinition(
        name: "lookUpPostalCode",
        description: "Look up a postal code.",
        parameters: PostalCodeArguments.generationSchema
      )
      let lookUpCall = Transcript.ToolCall(
        id: "call-1",
        toolName: "lookUpPostalCode",
        arguments: try GeneratedContent(json: #"{"postalCode": "94043"}"#)
      )
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: Transcript(
          entries: [
            .instructions(Transcript.Instructions(segments: [], toolDefinitions: [toolDefinition])),
            .prompt(
              Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "94043?"))])),
            .toolCalls(Transcript.ToolCalls(id: "calls-1", [lookUpCall])),
          ]
        ),
        enabledTools: [],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .disallowed),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: false)

      #expect(result.tools == nil)
      #expect(result.toolConfig == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesDisallowedRequestWithoutToolCallsOmitsTools() throws {
      let toolDefinition = Self.makeWeatherToolDefinition()
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: Transcript(
          entries: [
            .instructions(Transcript.Instructions(segments: [], toolDefinitions: [toolDefinition])),
            .prompt(
              Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Paris?"))])),
          ]
        ),
        enabledTools: [],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .disallowed),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: false)

      #expect(result.tools == nil)
      #expect(result.toolConfig == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesRequestWithoutEnabledToolsAfterToolCallsOmitsTools() throws {
      let toolDefinition = Self.makeWeatherToolDefinition()
      let parisCall = try Self.makeToolCall(id: "call-1", city: "Paris")
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: Transcript(
          entries: [
            .instructions(Transcript.Instructions(segments: [], toolDefinitions: [toolDefinition])),
            .prompt(
              Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Paris?"))])),
            .toolCalls(Transcript.ToolCalls(id: "calls-1", [parisCall])),
            .toolOutput(Self.makeToolOutput(id: "call-1")),
          ]
        ),
        enabledTools: [],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .allowed),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiRequestTranslator.translate(request, isAtToolCallingTurnLimit: false)

      #expect(result.tools == nil)
      #expect(result.toolConfig == nil)
    }

    // MARK: - Helper Methods

    /// Returns a `getWeather` tool call for a city.
    ///
    /// - Parameters:
    ///   - id: The identifier of the tool call.
    ///   - city: The city argument of the tool call.
    /// - Returns: A tool call to `getWeather`.
    /// - Throws: An error if the arguments can't be parsed.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private static func makeToolCall(id: String, city: String) throws -> Transcript.ToolCall {
      Transcript.ToolCall(
        id: id,
        toolName: "getWeather",
        arguments: try GeneratedContent(json: #"{"city": "\#(city)"}"#)
      )
    }

    /// Returns the definition of a tool that gets the current weather for a city.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private static func makeWeatherToolDefinition() -> Transcript.ToolDefinition {
      Transcript.ToolDefinition(
        name: "getWeather",
        description: "Get the current weather for a city.",
        parameters: LocationArguments.generationSchema
      )
    }

    /// Returns the output of a `getWeather` tool call.
    ///
    /// - Parameter id: The identifier of the tool call that produced the output.
    /// - Returns: The tool output.
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    private static func makeToolOutput(id: String) -> Transcript.ToolOutput {
      Transcript.ToolOutput(
        id: id,
        toolName: "getWeather",
        segments: [.text(Transcript.TextSegment(content: "22°C and sunny"))]
      )
    }
  }
#endif  // compiler(>=6.4) && (FoundationModelsFake || canImport(FoundationModels))
