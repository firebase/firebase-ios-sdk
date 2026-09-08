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

  @Suite("GeminiTranscriptTranslator Tests", .requireFoundationModels)
  struct GeminiTranscriptTranslatorTests {
    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesInstructionsAndPrompt() throws {
      let transcript = Transcript(
        entries: [
          .instructions(
            Transcript.Instructions(
              segments: [.text(Transcript.TextSegment(content: "You are a helpful assistant."))],
              toolDefinitions: []
            )
          ),
          .prompt(
            Transcript.Prompt(
              segments: [.text(Transcript.TextSegment(content: "Hello!"))]
            )
          ),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      let systemInstruction = try #require(result.systemInstruction)
      #expect(
        systemInstruction.parts?.first?.data == .text("You are a helpful assistant."))
      #expect(result.contents.count == 1)
      #expect(result.contents.first?.role == "user")
      #expect(result.contents.first?.parts?.first?.data == .text("Hello!"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func coalescesReasoningAndResponseIntoSingleModelTurn() throws {
      let signatureData = Data("test-sig".utf8)
      let transcript = Transcript(
        entries: [
          .prompt(
            Transcript.Prompt(
              segments: [.text(Transcript.TextSegment(content: "Explain 2+2."))]
            )
          ),
          .reasoning(
            Transcript.Reasoning(
              segments: [.text(Transcript.TextSegment(content: "Thinking about addition..."))],
              signature: signatureData
            )
          ),
          .response(
            Transcript.Response(
              segments: [.text(Transcript.TextSegment(content: "2+2 is 4."))]
            )
          ),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      #expect(result.contents.count == 2)
      #expect(result.contents[0].role == "user")
      #expect(result.contents[1].role == "model")

      let modelParts = try #require(result.contents[1].parts)
      #expect(modelParts.count == 2)
      #expect(modelParts[0].thought == true)
      #expect(modelParts[0].thoughtSignature == "test-sig")
      #expect(modelParts[0].data == .text("Thinking about addition..."))
      #expect(modelParts[1].data == .text("2+2 is 4."))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func preservesThoughtSignatureWhenReasoningSegmentsEmpty() throws {
      let signatureData = Data("sig-only".utf8)
      let transcript = Transcript(
        entries: [
          .prompt(
            Transcript.Prompt(
              segments: [.text(Transcript.TextSegment(content: "Hi."))]
            )
          ),
          .reasoning(
            Transcript.Reasoning(
              segments: [],
              signature: signatureData
            )
          ),
          .response(
            Transcript.Response(
              segments: [.text(Transcript.TextSegment(content: "Hello!"))]
            )
          ),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      #expect(result.contents.count == 2)
      let modelParts = try #require(result.contents[1].parts)
      #expect(modelParts.count == 2)
      #expect(modelParts[0].thought == true)
      #expect(modelParts[0].thoughtSignature == "sig-only")
      #expect(modelParts[0].data == nil)
      #expect(modelParts[1].data == .text("Hello!"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesMultipleInstructionsEntriesIntoMultipleParts() throws {
      let transcript = Transcript(
        entries: [
          .instructions(
            Transcript.Instructions(
              segments: [.text(Transcript.TextSegment(content: "First instruction."))],
              toolDefinitions: []
            )
          ),
          .instructions(
            Transcript.Instructions(
              segments: [.text(Transcript.TextSegment(content: "Second instruction."))],
              toolDefinitions: []
            )
          ),
          .prompt(
            Transcript.Prompt(
              segments: [.text(Transcript.TextSegment(content: "Hello!"))]
            )
          ),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      let systemInstruction = try #require(result.systemInstruction)
      let parts = try #require(systemInstruction.parts)
      #expect(parts.count == 2)
      #expect(parts[0].data == .text("First instruction."))
      #expect(parts[1].data == .text("Second instruction."))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolCallsIntoModelTurn() throws {
      let args = try GeneratedContent(json: "{\"location\":\"Paris\"}")
      let toolCall = Transcript.ToolCall(
        id: "call-1",
        toolName: "get_weather",
        arguments: args
      )
      let transcript = Transcript(
        entries: [
          .prompt(
            Transcript.Prompt(
              segments: [.text(Transcript.TextSegment(content: "Weather?"))]
            )
          ),
          .toolCalls(Transcript.ToolCalls(id: "calls-1", [toolCall])),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      #expect(result.contents.count == 2)
      #expect(result.contents[0].role == "user")
      #expect(result.contents[1].role == "model")
      let modelParts = try #require(result.contents[1].parts)
      #expect(modelParts.count == 1)
      guard case .functionCall(let functionCall) = modelParts[0].data else {
        Issue.record("Expected functionCall part data")
        return
      }
      #expect(functionCall.id == "call-1")
      #expect(functionCall.name == "get_weather")
      #expect(functionCall.args?["location"] == .string("Paris"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolOutputWithTextSegmentWrappingUnderResult() throws {
      let toolOutput = Transcript.ToolOutput(
        id: "call-1",
        toolName: "get_weather",
        segments: [.text(Transcript.TextSegment(content: "Sunny, 22°C"))]
      )
      let transcript = Transcript(entries: [.toolOutput(toolOutput)])

      let result = try GeminiTranscriptTranslator.translate(transcript)

      #expect(result.contents.count == 1)
      #expect(result.contents[0].role == "user")
      let userParts = try #require(result.contents[0].parts)
      #expect(userParts.count == 1)
      guard case .functionResponse(let functionResponse) = userParts[0].data else {
        Issue.record("Expected functionResponse part data")
        return
      }
      #expect(functionResponse.id == "call-1")
      #expect(functionResponse.name == "get_weather")
      #expect(functionResponse.response?["result"] == .string("Sunny, 22°C"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolOutputWithJSONTextPreservingStringUnderResult() throws {
      let jsonString = "{\"temperature\":22,\"condition\":\"sunny\"}"
      let toolOutput = Transcript.ToolOutput(
        id: "call-1",
        toolName: "get_weather",
        segments: [
          .text(Transcript.TextSegment(content: jsonString))
        ]
      )
      let transcript = Transcript(entries: [.toolOutput(toolOutput)])

      let result = try GeminiTranscriptTranslator.translate(transcript)

      let userParts = try #require(result.contents.first?.parts)
      guard case .functionResponse(let functionResponse) = userParts.first?.data else {
        Issue.record("Expected functionResponse part data")
        return
      }
      #expect(functionResponse.id == "call-1")
      #expect(functionResponse.name == "get_weather")
      #expect(functionResponse.response?["result"] == .string(jsonString))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)

    func translatesToolOutputWithStructuredSegmentUnpackingDirectly() throws {
      let content = try GeneratedContent(json: "{\"temperature\":22}")
      let structuredSegment = Transcript.StructuredSegment(
        id: "seg-1",
        schemaName: "Weather",
        content: content
      )
      let toolOutput = Transcript.ToolOutput(
        id: "call-1",
        toolName: "get_weather",
        segments: [.structure(structuredSegment)]
      )
      let transcript = Transcript(entries: [.toolOutput(toolOutput)])

      let result = try GeminiTranscriptTranslator.translate(transcript)

      let userParts = try #require(result.contents.first?.parts)
      guard case .functionResponse(let functionResponse) = userParts.first?.data else {
        Issue.record("Expected functionResponse part data")
        return
      }
      #expect(functionResponse.id == "call-1")
      #expect(functionResponse.name == "get_weather")
      #expect(functionResponse.response?["temperature"] == .number(22))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func coalescesParallelToolCallsAndOutputs() throws {
      let call1 = Transcript.ToolCall(
        id: "call-1",
        toolName: "get_weather",
        arguments: try GeneratedContent(json: "{\"location\":\"Paris\"}")
      )
      let call2 = Transcript.ToolCall(
        id: "call-2",
        toolName: "get_time",
        arguments: try GeneratedContent(json: "{\"location\":\"Tokyo\"}")
      )
      let output1 = Transcript.ToolOutput(
        id: "call-1",
        toolName: "get_weather",
        segments: [.text(Transcript.TextSegment(content: "22°C"))]
      )
      let output2 = Transcript.ToolOutput(
        id: "call-2",
        toolName: "get_time",
        segments: [.text(Transcript.TextSegment(content: "15:00"))]
      )
      let transcript = Transcript(
        entries: [
          .toolCalls(Transcript.ToolCalls(id: "calls-1", [call1, call2])),
          .toolOutput(output1),
          .toolOutput(output2),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      #expect(result.contents.count == 2)
      #expect(result.contents[0].role == "model")
      let modelParts = try #require(result.contents[0].parts)
      #expect(modelParts.count == 2)
      guard case .functionCall(let fc1) = modelParts[0].data,
        case .functionCall(let fc2) = modelParts[1].data
      else {
        Issue.record("Expected two functionCall parts")
        return
      }
      #expect(fc1.id == "call-1")
      #expect(fc2.id == "call-2")
      #expect(result.contents[1].role == "user")
      let userParts = try #require(result.contents[1].parts)
      #expect(userParts.count == 2)
      guard case .functionResponse(let fr1) = userParts[0].data,
        case .functionResponse(let fr2) = userParts[1].data
      else {
        Issue.record("Expected two functionResponse parts in single user turn")
        return
      }
      #expect(fr1.id == "call-1")
      #expect(fr2.id == "call-2")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolCallsWithEmptyArguments() throws {
      let call = Transcript.ToolCall(
        id: "call-1",
        toolName: "get_time",
        arguments: try GeneratedContent(json: "{}")
      )
      let transcript = Transcript(
        entries: [.toolCalls(Transcript.ToolCalls(id: "calls-1", [call]))]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      let modelParts = try #require(result.contents.first?.parts)
      #expect(modelParts.count == 1)
      guard case .functionCall(let functionCall) = modelParts[0].data else {
        Issue.record("Expected functionCall part")
        return
      }
      #expect(functionCall.id == "call-1")
      #expect(functionCall.name == "get_time")
      #expect(functionCall.args == nil)
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func coalescesReasoningAndToolCallsIntoSingleModelTurn() throws {
      let signatureData = Data("test-sig".utf8)
      let call = Transcript.ToolCall(
        id: "call-1",
        toolName: "get_weather",
        arguments: try GeneratedContent(json: "{\"location\":\"Paris\"}")
      )
      let transcript = Transcript(
        entries: [
          .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hi."))])),
          .reasoning(
            Transcript.Reasoning(
              segments: [.text(Transcript.TextSegment(content: "Need to check weather."))],
              signature: signatureData
            )
          ),
          .toolCalls(Transcript.ToolCalls(id: "calls-1", [call])),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      #expect(result.contents.count == 2)
      #expect(result.contents[0].role == "user")
      #expect(result.contents[1].role == "model")
      let modelParts = try #require(result.contents[1].parts)
      #expect(modelParts.count == 2)
      #expect(modelParts[0].thought == true)
      #expect(modelParts[0].thoughtSignature == nil)
      #expect(modelParts[0].data == .text("Need to check weather."))
      #expect(modelParts[1].thoughtSignature == "test-sig")
      guard case .functionCall(let functionCall) = modelParts[1].data else {
        Issue.record("Expected functionCall part")
        return
      }
      #expect(functionCall.id == "call-1")
      #expect(functionCall.name == "get_weather")
    }

    @Generable
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    @available(tvOS, unavailable)
    struct City {
      var name: String
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func instructionsWithToolDefinitionsTranslatesCleanly() throws {
      let toolDefinition = Transcript.ToolDefinition(
        name: "get_weather",
        description: "Get weather",
        parameters: City.generationSchema
      )
      let transcript = Transcript(
        entries: [
          .instructions(
            Transcript.Instructions(
              segments: [.text(Transcript.TextSegment(content: "Be concise."))],
              toolDefinitions: [toolDefinition]
            )
          ),
          .prompt(Transcript.Prompt(segments: [.text(Transcript.TextSegment(content: "Hello"))])),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      let systemInstruction = try #require(result.systemInstruction)
      #expect(systemInstruction.parts?.first?.data == Part.PartData.text("Be concise."))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolOutputWithMultipleSegmentsIntoMultipleParts() throws {
      let toolOutput = Transcript.ToolOutput(
        id: "call-1",
        toolName: "get_weather",
        segments: [
          .text(Transcript.TextSegment(content: "Part 1")),
          .text(Transcript.TextSegment(content: "Part 2")),
        ]
      )
      let transcript = Transcript(entries: [.toolOutput(toolOutput)])

      let result = try GeminiTranscriptTranslator.translate(transcript)

      let userParts = try #require(result.contents.first?.parts)
      #expect(userParts.count == 2)
      guard case .functionResponse(let fr1) = userParts[0].data,
        case .functionResponse(let fr2) = userParts[1].data
      else {
        Issue.record("Expected functionResponse part data for both segments")
        return
      }
      #expect(fr1.id == "call-1")
      #expect(fr1.name == "get_weather")
      #expect(fr1.response?["result"] == .string("Part 1"))
      #expect(fr2.id == "call-1")
      #expect(fr2.name == "get_weather")
      #expect(fr2.response?["result"] == .string("Part 2"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolOutputWithAttachmentThrowsUnsupportedTranscriptContent() throws {
      let imageAttachment = Transcript.ImageAttachment(
        imageURL: URL(fileURLWithPath: "/tmp/test.png")
      )
      let attachment = Transcript.Segment.attachment(
        Transcript.AttachmentSegment(
          id: "att-1",
          content: .image(imageAttachment)
        )
      )
      let toolOutput = Transcript.ToolOutput(
        id: "call-1",
        toolName: "get_weather",
        segments: [
          .text(Transcript.TextSegment(content: "Here is the image:")),
          attachment,
        ]
      )
      let transcript = Transcript(entries: [.toolOutput(toolOutput)])

      do {
        _ = try GeminiTranscriptTranslator.translate(transcript)
        Issue.record("Expected unsupportedTranscriptContent error")
      } catch LanguageModelError.unsupportedTranscriptContent {
        // Expected
      } catch {
        Issue.record("Unexpected error thrown: \(error)")
      }
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func emptyToolCallsDoesNotDropPendingReasoningSignature() throws {
      let signatureData = Data("test-sig".utf8)
      let prompt = Transcript.Prompt(
        segments: [.text(Transcript.TextSegment(content: "Hi"))]
      )
      let reasoning = Transcript.Reasoning(
        segments: [.text(Transcript.TextSegment(content: "Thinking..."))],
        signature: signatureData
      )
      let emptyToolCalls = Transcript.ToolCalls(id: "calls-empty", [])
      let finalResponse = Transcript.Response(
        segments: [.text(Transcript.TextSegment(content: "Hello!"))]
      )
      let transcript = Transcript(
        entries: [
          .prompt(prompt),
          .reasoning(reasoning),
          .toolCalls(emptyToolCalls),
          .response(finalResponse),
        ]
      )

      let result = try GeminiTranscriptTranslator.translate(transcript)

      let modelTurn = try #require(result.contents.last)
      let modelParts = try #require(modelTurn.parts)
      #expect(modelParts.first?.thoughtSignature == "test-sig")
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
