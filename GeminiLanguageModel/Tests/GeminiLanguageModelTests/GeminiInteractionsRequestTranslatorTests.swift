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
  import GeminiTestUtilities
  import InteractionsDataModels
  import Testing

  @testable import GeminiLanguageModel

  @Suite("GeminiInteractionsRequestTranslator Tests", .requireFoundationModels)
  struct GeminiInteractionsRequestTranslatorTests {
    @Generable(description: "A simple user profile")
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct UserProfile {
      var username: String
      var score: Int
    }

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

      let result = try GeminiInteractionsRequestTranslator.translate(
        request,
        modelResource: .gemini38Flash
      )

      #expect(result.systemInstruction == nil)
      #expect(result.model?.rawValue == "gemini-3.8-flash")
      #expect(result.store == false)
      #expect(result.stream == true)
      #expect(result.tools == nil)
      #expect(result.responseFormat == nil)
      guard case .stepList(let steps) = result.input else {
        Issue.record("Expected stepList input")
        return
      }
      #expect(steps.count == 1)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesRequestWithSchema() throws {
      let promptEntry = Transcript.Entry.prompt(
        Transcript.Prompt(
          id: "prompt-1",
          segments: [.text(Transcript.TextSegment(content: "Generate profile"))]
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

      let result = try GeminiInteractionsRequestTranslator.translate(
        request,
        modelResource: .gemini38Flash
      )

      let responseFormat = try #require(result.responseFormat)
      guard case .object(let schemaObject) = responseFormat else {
        Issue.record("Expected responseFormat to be JSONValue.object")
        return
      }
      #expect(schemaObject["type"] == .string("object"))
      #expect(schemaObject["properties"] != nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesRequestWithToolsAndToolCallingMode() throws {
      let toolDefinition = Transcript.ToolDefinition(
        name: "test_tool",
        description: "A test tool",
        parameters: UserProfile.generationSchema
      )
      let promptEntry = Transcript.Entry.prompt(
        Transcript.Prompt(
          id: "prompt-1",
          segments: [.text(Transcript.TextSegment(content: "Call tool"))]
        )
      )
      let transcript = Transcript(
        entries: [
          .instructions(
            Transcript.Instructions(
              segments: [],
              toolDefinitions: [toolDefinition]
            )
          ),
          promptEntry,
        ]
      )
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: transcript,
        enabledTools: [toolDefinition],
        schema: nil,
        generationOptions: GenerationOptions(toolCallingMode: .required),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiInteractionsRequestTranslator.translate(
        request,
        modelResource: .gemini38Flash
      )

      let tools = try #require(result.tools)
      #expect(tools.count == 1)
      guard case .function(let fn) = tools.first else {
        Issue.record("Expected function tool")
        return
      }
      #expect(fn.name == "test_tool")
      #expect(fn.description == "A test tool")
      #expect(result.generationConfig?.toolChoice == JSONValue.string("any"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func usesPayloadResourceNameWhenPrefixedWithPublishers() throws {
      let modelResource = ModelResource(
        modelID: "gemini-3.8-flash",
        urlResourceName: "projects/p/locations/l/publishers/google/models/gemini-3.8-flash",
        payloadResourceName: "publishers/google/models/gemini-3.8-flash"
      )
      let transcript = Transcript(entries: [
        .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hi"))]))
      ])
      let request = LanguageModelExecutorGenerationRequest(
        id: UUID(),
        transcript: transcript,
        enabledTools: [],
        schema: nil,
        generationOptions: GenerationOptions(),
        contextOptions: ContextOptions(),
        metadata: [:]
      )

      let result = try GeminiInteractionsRequestTranslator.translate(
        request,
        modelResource: modelResource
      )

      #expect(result.model?.rawValue == "publishers/google/models/gemini-3.8-flash")
    }
  }
#endif
