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
  import Testing

  import GeminiAPIDataModels
  import SharedTestUtilities

  @testable import GeminiForFoundationModels

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
        systemInstruction.parts?.first?.data == Part.PartData.text("You are a helpful assistant."))
      #expect(result.contents.count == 1)
      #expect(result.contents.first?.role == "user")
      #expect(result.contents.first?.parts?.first?.data == Part.PartData.text("Hello!"))
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
      #expect(modelParts[0].data == Part.PartData.text("Thinking about addition..."))
      #expect(modelParts[1].data == Part.PartData.text("2+2 is 4."))
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
      #expect(modelParts[1].data == Part.PartData.text("Hello!"))
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
