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

      let result = try GeminiRequestTranslator.translate(request)

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

      let result = try GeminiRequestTranslator.translate(request)

      #expect(result.contents.count == 1)
      let generationConfig = try #require(result.generationConfig)
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
      let config = try GeminiRequestTranslator.translateGenerationConfig(schema: nil)

      #expect(config == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesGenerationConfigWithSchemaReturnsConfig() throws {
      let schema = UserProfile.generationSchema

      let config = try GeminiRequestTranslator.translateGenerationConfig(schema: schema)

      let generationConfig = try #require(config)
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
      let allowedConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .allowed
      )
      let requiredConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .required
      )
      let disallowedConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: .disallowed
      )
      let nilConfig = GeminiRequestTranslator.translateToolConfig(
        toolCallingMode: nil
      )

      #expect(allowedConfig?.functionCallingConfig?.mode == .auto)
      #expect(requiredConfig?.functionCallingConfig?.mode == .any)
      #expect(disallowedConfig?.functionCallingConfig?.mode == FunctionCallingConfig.Mode.none)
      #expect(nilConfig == nil)
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
