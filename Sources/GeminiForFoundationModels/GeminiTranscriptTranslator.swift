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
  import GeminiAPIDataModels

  /// Translates Apple's `FoundationModels.Transcript` into Gemini API content requests.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiTranscriptTranslator {

    /// Translates a transcript into content turns and an optional system instruction.
    ///
    /// - Parameter transcript: The conversation history transcript.
    /// - Returns: A tuple containing the list of content turns and an optional system instruction.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if unsupported entries or segments
    ///   are present.
    static func translate(
      _ transcript: Transcript
    ) throws -> (
      contents: [Content], systemInstruction: Content?
    ) {
      var contents: [Content] = []
      var systemInstruction: Content?

      for entry in transcript {
        switch entry {
        case .instructions(let instructions):
          let text = try extractText(from: instructions.segments, in: entry)
          guard instructions.toolDefinitions.isEmpty else {
            throw LanguageModelError.unsupportedTranscriptContent(
              .init(
                unsupportedContent: [entry],
                debugDescription: "Tool definitions in instructions are not supported."
              )
            )
          }
          systemInstruction = Content(
            parts: [Part(data: .text(text))],
          )

        case .prompt(let prompt):
          let text = try extractText(from: prompt.segments, in: entry)
          contents.append(
            Content(
              parts: [Part(data: .text(text))],
              role: "user"
            )
          )

        case .response(let response):
          let text = try extractText(from: response.segments, in: entry)
          contents.append(
            Content(
              parts: [Part(data: .text(text))],
              role: "model"
            )
          )

        case .reasoning(let reasoning):
          let signatureString: String?
          if let signature = reasoning.signature {
            signatureString = String(decoding: signature, as: UTF8.self)
          } else {
            signatureString = nil
          }
          if let text = try extractOptionalText(from: reasoning.segments, in: entry) {
            contents.append(
              Content(
                parts: [
                  Part(
                    data: .text(text),
                    thought: true,
                    thoughtSignature: signatureString,
                  )
                ],
                role: "model"
              )
            )
          }

        case .toolCalls:
          throw LanguageModelError.unsupportedTranscriptContent(
            .init(
              unsupportedContent: [entry],
              debugDescription: "Tool calls in transcript are not supported."
            )
          )

        case .toolOutput:
          throw LanguageModelError.unsupportedTranscriptContent(
            .init(
              unsupportedContent: [entry],
              debugDescription: "Tool outputs in transcript are not supported."
            )
          )

        @unknown default:
          throw LanguageModelError.unsupportedTranscriptContent(
            .init(
              unsupportedContent: [entry],
              debugDescription: "Unsupported transcript entry."
            )
          )
        }
      }

      return (contents: contents, systemInstruction: systemInstruction)
    }

    // MARK: - Private Helpers

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
          throw LanguageModelError.unsupportedTranscriptContent(
            .init(
              unsupportedContent: [entry],
              debugDescription: "Attachment segments in transcript are not supported."
            )
          )
        case .structure:
          throw LanguageModelError.unsupportedTranscriptContent(
            .init(
              unsupportedContent: [entry],
              debugDescription: "Structured segments in transcript are not supported."
            )
          )
        @unknown default:
          throw LanguageModelError.unsupportedTranscriptContent(
            .init(
              unsupportedContent: [entry],
              debugDescription: "Unsupported transcript segment."
            )
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
#endif  // canImport(FoundationModels) && compiler(>=6.4)
