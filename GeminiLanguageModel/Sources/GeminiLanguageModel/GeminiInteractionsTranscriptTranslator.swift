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
  import InteractionsDataModels

  /// Translates Apple's `FoundationModels.Transcript` into Gemini Interactions API step requests.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiInteractionsTranscriptTranslator {
    /// Translates a transcript into interaction steps and an optional system instruction.
    ///
    /// - Parameter transcript: The conversation history transcript.
    /// - Returns: A tuple containing the list of interaction steps and an optional system instruction string.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if unsupported entries or
    ///   segments are present.
    static func translate(
      _ transcript: Transcript
    ) throws -> (
      steps: [Step], systemInstruction: String?
    ) {
      var steps: [Step] = []
      var systemInstructions: [String] = []

      for entry in transcript {
        switch entry {
        case .instructions(let instructions):
          let text = try extractText(from: instructions.segments, in: entry)
          if !text.isEmpty {
            systemInstructions.append(text)
          }

        case .prompt(let prompt):
          let text = try extractText(from: prompt.segments, in: entry)
          let userInput = UserInputStep(content: [.textContent(TextContent(text: text))])
          steps.append(.userInputStep(userInput))

        case .response(let response):
          let text = try extractText(from: response.segments, in: entry)
          let modelOutput = ModelOutputStep(content: [.textContent(TextContent(text: text))])
          steps.append(.modelOutputStep(modelOutput))

        case .reasoning(let reasoning):
          let text = try extractOptionalText(from: reasoning.segments, in: entry)
          let summary = text.map { [ThoughtSummaryContent.textContent(TextContent(text: $0))] }
          let thought = ThoughtStep(signature: reasoning.signature, summary: summary)
          steps.append(.thoughtStep(thought))

        case .toolCalls(let toolCalls):
          for call in toolCalls {
            let args: [String: JSONValue]?
            if case .structure(let properties, _) = call.arguments.kind {
              args = properties.isEmpty ? nil : properties.mapValues { jsonValue(from: $0) }
            } else {
              args = nil
            }
            let functionCall = FunctionCallStep(
              arguments: args,
              id: call.id,
              name: call.toolName
            )
            steps.append(.functionCallStep(functionCall))
          }

        case .toolOutput(let toolOutput):
          if toolOutput.segments.isEmpty {
            let resultStep = FunctionResultStep(
              callId: toolOutput.id,
              name: toolOutput.toolName,
              result: .object(["result": .null])
            )
            steps.append(.functionResultStep(resultStep))
          } else {
            for segment in toolOutput.segments {
              let response = try extractResponse(from: segment, in: entry)
              let resultStep = FunctionResultStep(
                callId: toolOutput.id,
                name: toolOutput.toolName,
                result: .object(response)
              )
              steps.append(.functionResultStep(resultStep))
            }
          }

        @unknown default:
          throw makeUnsupportedError(
            entry,
            description: "Unsupported transcript entry."
          )
        }
      }

      let systemInstruction =
        systemInstructions.isEmpty ? nil : systemInstructions.joined(separator: "\n")
      return (steps: steps, systemInstruction: systemInstruction)
    }

    // MARK: - Private Helpers

    private static func makeUnsupportedError(
      _ entry: Transcript.Entry,
      description: String
    ) -> LanguageModelError {
      LanguageModelError.unsupportedTranscriptContent(
        LanguageModelError.UnsupportedTranscriptContent(
          unsupportedContent: [entry],
          debugDescription: description
        )
      )
    }

    private static func jsonValue(from content: GeneratedContent) -> JSONValue {
      switch content.kind {
      case .null:
        return .null
      case .bool(let value):
        return .bool(value)
      case .number(let value):
        return .number(value)
      case .string(let value):
        return .string(value)
      case .array(let values):
        return .array(values.map { jsonValue(from: $0) })
      case .structure(let properties, _):
        return .object(properties.mapValues { jsonValue(from: $0) })
      @unknown default:
        return .null
      }
    }

    private static func extractResponse(
      from segment: Transcript.Segment,
      in entry: Transcript.Entry
    ) throws -> [String: JSONValue] {
      switch segment {
      case .structure(let structuredSegment):
        let val = jsonValue(from: structuredSegment.content)
        if case .object(let obj) = val {
          return obj
        } else {
          return ["result": val]
        }
      case .text(let textSegment):
        return ["result": .string(textSegment.content)]

      case .attachment:
        throw makeUnsupportedError(
          entry,
          description: "Attachment segments in tool output are not supported."
        )
      @unknown default:
        throw makeUnsupportedError(
          entry,
          description: "Unsupported segment in tool output."
        )
      }
    }

    private static func extractText(
      from segments: [Transcript.Segment],
      in entry: Transcript.Entry
    ) throws -> String {
      var text = ""
      for segment in segments {
        switch segment {
        case .text(let textSegment):
          text.append(textSegment.content)
        case .attachment:
          throw makeUnsupportedError(
            entry,
            description: "Attachment segments in transcript are not supported."
          )
        case .structure:
          throw makeUnsupportedError(
            entry,
            description: "Structured segments in transcript are not supported."
          )
        @unknown default:
          throw makeUnsupportedError(
            entry,
            description: "Unsupported transcript segment."
          )
        }
      }
      return text
    }

    private static func extractOptionalText(
      from segments: [Transcript.Segment],
      in entry: Transcript.Entry
    ) throws -> String? {
      let text = try extractText(from: segments, in: entry)
      return text.isEmpty ? nil : text
    }
  }
#endif
