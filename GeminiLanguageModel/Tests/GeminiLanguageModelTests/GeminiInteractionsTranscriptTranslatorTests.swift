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
  import GeminiSharedDataModels
  import GeminiTestUtilities
  import InteractionsDataModels
  import Testing

  @testable import GeminiLanguageModel

  @Suite("GeminiInteractionsTranscriptTranslator Tests", .requireFoundationModels)
  struct GeminiInteractionsTranscriptTranslatorTests {
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

      let result = try GeminiInteractionsTranscriptTranslator.translate(transcript)

      #expect(result.systemInstruction == "You are a helpful assistant.")
      #expect(result.steps.count == 1)
      guard case .userInputStep(let userInput) = result.steps.first else {
        Issue.record("Expected userInputStep")
        return
      }
      let content = try #require(userInput.content?.first)
      guard case .textContent(let textContent) = content else {
        Issue.record("Expected textContent")
        return
      }
      #expect(textContent.text == "Hello!")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesMultiTurnConversation() throws {
      let signatureData = Data("sig-123".utf8)
      let transcript = Transcript(
        entries: [
          .prompt(
            Transcript.Prompt(
              segments: [.text(Transcript.TextSegment(content: "Explain gravity."))]
            )
          ),
          .reasoning(
            Transcript.Reasoning(
              segments: [.text(Transcript.TextSegment(content: "Physics thought process..."))],
              signature: signatureData
            )
          ),
          .response(
            Transcript.Response(
              segments: [.text(Transcript.TextSegment(content: "Gravity is a fundamental force."))]
            )
          ),
        ]
      )

      let result = try GeminiInteractionsTranscriptTranslator.translate(transcript)

      #expect(result.systemInstruction == nil)
      #expect(result.steps.count == 3)

      guard case .userInputStep(let userStep) = result.steps[0] else {
        Issue.record("Expected userInputStep at index 0")
        return
      }
      guard case .textContent(let userText) = userStep.content?.first else {
        Issue.record("Expected textContent in userStep")
        return
      }
      #expect(userText.text == "Explain gravity.")

      guard case .thoughtStep(let thoughtStep) = result.steps[1] else {
        Issue.record("Expected thoughtStep at index 1")
        return
      }
      #expect(thoughtStep.signature == signatureData)
      guard case .textContent(let thoughtText) = thoughtStep.summary?.first else {
        Issue.record("Expected textContent in thoughtStep summary")
        return
      }
      #expect(thoughtText.text == "Physics thought process...")

      guard case .modelOutputStep(let modelStep) = result.steps[2] else {
        Issue.record("Expected modelOutputStep at index 2")
        return
      }
      guard case .textContent(let modelText) = modelStep.content?.first else {
        Issue.record("Expected textContent in modelStep")
        return
      }
      #expect(modelText.text == "Gravity is a fundamental force.")
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesToolCallsAndToolOutput() throws {
      let callID = "call_abc"
      let args = try GeneratedContent(json: "{\"location\":\"Paris\"}")
      let toolCall = Transcript.ToolCall(
        id: callID,
        toolName: "get_weather",
        arguments: args
      )
      let transcript = Transcript(
        entries: [
          .prompt(
            Transcript.Prompt(
              segments: [.text(Transcript.TextSegment(content: "What's the weather?"))]
            )
          ),
          .toolCalls(Transcript.ToolCalls(id: "calls-1", [toolCall])),
          .toolOutput(
            Transcript.ToolOutput(
              id: callID,
              toolName: "get_weather",
              segments: [.text(Transcript.TextSegment(content: "Sunny, 22°C"))]
            )
          ),
        ]
      )

      let result = try GeminiInteractionsTranscriptTranslator.translate(transcript)

      #expect(result.steps.count == 3)

      guard case .functionCallStep(let fc) = result.steps[1] else {
        Issue.record("Expected functionCallStep at index 1")
        return
      }
      #expect(fc.id == callID)
      #expect(fc.name == "get_weather")
      #expect(fc.arguments?["location"] == JSONValue.string("Paris"))

      guard case .functionResultStep(let fr) = result.steps[2] else {
        Issue.record("Expected functionResultStep at index 2")
        return
      }
      #expect(fr.callId == callID)
      #expect(fr.name == "get_weather")
      guard case .object(let resObj) = fr.result else {
        Issue.record("Expected object result")
        return
      }
      #expect(resObj["result"] == JSONValue.string("Sunny, 22°C"))
    }

    @Test
    @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
    func translatesEmptyToolOutputToNullResult() throws {
      let callID = "call_empty"
      let transcript = Transcript(
        entries: [
          .toolOutput(
            Transcript.ToolOutput(
              id: callID,
              toolName: "do_something",
              segments: []
            )
          )
        ]
      )

      let result = try GeminiInteractionsTranscriptTranslator.translate(transcript)

      #expect(result.steps.count == 1)
      guard case .functionResultStep(let fr) = result.steps.first else {
        Issue.record("Expected functionResultStep")
        return
      }
      #expect(fr.callId == callID)
      #expect(fr.name == "do_something")
      #expect(fr.result == .object(["result": .null]))
    }
  }
#endif
