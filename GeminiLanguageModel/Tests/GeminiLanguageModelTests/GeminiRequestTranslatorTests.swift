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

      let result = try GeminiRequestTranslator.translate(
        request,
        compatibilityOptions: GeminiLanguageModel.CompatibilityOptions()
      )

      #expect(result.systemInstruction == nil)
      #expect(result.contents.count == 1)
      #expect(result.contents.first?.parts?.first?.data == Part.PartData.text("Hello"))
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

      let result = try GeminiRequestTranslator.translate(
        request,
        compatibilityOptions: GeminiLanguageModel.CompatibilityOptions()
      )

      #expect(result.contents.count == 1)
      let generationConfig = try #require(result.generationConfig)
      #expect(generationConfig.responseMimeType == "application/json")
      guard case .object(let schemaObject) = generationConfig.responseJsonSchema else {
        Issue.record("Expected responseJsonSchema to be a JSON object.")
        return
      }
      #expect(schemaObject["x-order"] == nil)
      let ordering = try #require(schemaObject["propertyOrdering"])
      #expect(ordering == JSONValue.array([.string("username"), .string("score")]))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationRequestWithResponseFormatReturnsConfig() throws {
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
      var options = GeminiLanguageModel.CompatibilityOptions()
      options.guidedGeneration.schemaFormat = .responseFormat

      let result = try GeminiRequestTranslator.translate(
        request,
        compatibilityOptions: options
      )

      #expect(result.contents.count == 1)
      let generationConfig = try #require(result.generationConfig)
      #expect(generationConfig.responseMimeType == nil)
      #expect(generationConfig.responseJsonSchema == nil)
      let responseFormat = try #require(generationConfig.responseFormat)
      let textFormat = try #require(responseFormat.text)
      #expect(textFormat.mimeType == TextResponseFormat.MimeType.applicationJson)
      guard case .object(let schemaObject) = textFormat.schema else {
        Issue.record("Expected schema to be a JSON object.")
        return
      }
      #expect(schemaObject["x-order"] == nil)
      let ordering = try #require(schemaObject["propertyOrdering"])
      #expect(ordering == JSONValue.array([.string("username"), .string("score")]))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationConfigWithNilSchemaReturnsNil() throws {
      let config = try GeminiRequestTranslator.translateGenerationConfig(
        schema: nil,
        compatibilityOptions: GeminiLanguageModel.CompatibilityOptions()
      )

      #expect(config == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationConfigWithSchemaReturnsConfig() throws {
      let schema = UserProfile.generationSchema

      let config = try GeminiRequestTranslator.translateGenerationConfig(
        schema: schema,
        compatibilityOptions: GeminiLanguageModel.CompatibilityOptions()
      )

      let generationConfig = try #require(config)
      #expect(generationConfig.responseMimeType == "application/json")
      guard case .object(let schemaObject) = generationConfig.responseJsonSchema else {
        Issue.record("Expected responseJsonSchema to be a JSON object.")
        return
      }
      #expect(schemaObject["x-order"] == nil)
      #expect(schemaObject["propertyOrdering"] != nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationConfigWithResponseFormatSchemaReturnsConfig() throws {
      let schema = UserProfile.generationSchema
      var options = GeminiLanguageModel.CompatibilityOptions()
      options.guidedGeneration.schemaFormat = .responseFormat

      let config = try GeminiRequestTranslator.translateGenerationConfig(
        schema: schema,
        compatibilityOptions: options
      )

      let generationConfig = try #require(config)
      #expect(generationConfig.responseMimeType == nil)
      #expect(generationConfig.responseJsonSchema == nil)
      let responseFormat = try #require(generationConfig.responseFormat)
      let textFormat = try #require(responseFormat.text)
      #expect(textFormat.mimeType == TextResponseFormat.MimeType.applicationJson)
      guard case .object(let schemaObject) = textFormat.schema else {
        Issue.record("Expected schema to be a JSON object.")
        return
      }
      #expect(schemaObject["x-order"] == nil)
      #expect(schemaObject["propertyOrdering"] != nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationConfigWithPatternGuideThrowsUnsupportedGenerationGuide() throws {
      let schema = DataModelWithPattern.generationSchema

      do {
        _ = try GeminiRequestTranslator.translateGenerationConfig(
          schema: schema,
          compatibilityOptions: GeminiLanguageModel.CompatibilityOptions()
        )
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
      let parameters = try #require(declarations[0].parametersJsonSchema)
      guard case .object(let dict) = parameters else {
        Issue.record("Expected .object, got \(parameters)")
        return
      }
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
      let parameters = try #require(declarations[0].parametersJsonSchema)
      guard case .object(let dict) = parameters else {
        Issue.record("Expected .object, got \(parameters)")
        return
      }
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
    func translatesToolCallingModes() {
      let options = GeminiLanguageModel.CompatibilityOptions()

      let allowedConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .allowed,
        hasFunctionDeclarations: true,
        compatibilityOptions: options
      )
      let requiredConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .required,
        hasFunctionDeclarations: true,
        compatibilityOptions: options
      )
      let disallowedConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .disallowed,
        hasFunctionDeclarations: true,
        compatibilityOptions: options
      )
      let unsetConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: nil,
        hasFunctionDeclarations: true,
        compatibilityOptions: options
      )

      #expect(allowedConfig?.functionCallingConfig?.mode == .validated)
      #expect(requiredConfig?.functionCallingConfig?.mode == .any)
      #expect(disallowedConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
      #expect(unsetConfig?.functionCallingConfig?.mode == .validated)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolCallingModesWithoutDeclarationsReturnsNil() {
      let options = GeminiLanguageModel.CompatibilityOptions()

      let allowedConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .allowed,
        hasFunctionDeclarations: false,
        compatibilityOptions: options
      )
      let requiredConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .required,
        hasFunctionDeclarations: false,
        compatibilityOptions: options
      )
      let disallowedConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .disallowed,
        hasFunctionDeclarations: false,
        compatibilityOptions: options
      )
      let nilConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: nil,
        hasFunctionDeclarations: false,
        compatibilityOptions: options
      )

      #expect(allowedConfig == nil)
      #expect(requiredConfig == nil)
      #expect(disallowedConfig == nil)
      #expect(nilConfig == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolCallingModesWithCompatibilityAutoOverride() {
      var compatibilityOptions = GeminiLanguageModel.CompatibilityOptions()
      compatibilityOptions.toolCalling.allowedMode = .auto

      let allowedConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .allowed,
        hasFunctionDeclarations: true,
        compatibilityOptions: compatibilityOptions
      )
      let requiredConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .required,
        hasFunctionDeclarations: true,
        compatibilityOptions: compatibilityOptions
      )
      let unsetConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: nil,
        hasFunctionDeclarations: true,
        compatibilityOptions: compatibilityOptions
      )

      #expect(allowedConfig?.functionCallingConfig?.mode == .auto)
      #expect(requiredConfig?.functionCallingConfig?.mode == .any)
      #expect(unsetConfig?.functionCallingConfig?.mode == .auto)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func defaultCompatibilityOptionsHasValidatedAllowedMode() {
      let options = GeminiLanguageModel.CompatibilityOptions()

      #expect(options.toolCalling.allowedMode == .validated)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func defaultCompatibilityOptionsHasResponseJsonSchemaFormat() {
      let options = GeminiLanguageModel.CompatibilityOptions()

      #expect(options.guidedGeneration.schemaFormat == .responseJsonSchema)
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
        requestWithTool,
        compatibilityOptions: GeminiLanguageModel.CompatibilityOptions()
      )
      let resultWithoutTools = try GeminiRequestTranslator.translate(
        requestWithoutTools,
        compatibilityOptions: GeminiLanguageModel.CompatibilityOptions()
      )

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

      let result = try GeminiRequestTranslator.translate(
        request,
        compatibilityOptions: GeminiLanguageModel.CompatibilityOptions()
      )

      let toolConfig = try #require(result.toolConfig)
      let functionCallingConfig = try #require(toolConfig.functionCallingConfig)
      #expect(functionCallingConfig.mode == FunctionCallingConfig.Mode.validated)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
