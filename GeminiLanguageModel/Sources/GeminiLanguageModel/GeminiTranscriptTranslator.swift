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

  /// Translates Apple's `FoundationModels.Transcript` into Gemini API content requests.
  @available(iOS 27.0, macOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  enum GeminiTranscriptTranslator {

    /// Translates a transcript into content turns and an optional system instruction.
    ///
    /// - Parameter transcript: The conversation history transcript.
    /// - Returns: A tuple containing the list of content turns and an optional system instruction.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if unsupported entries or
    ///   segments are present.
    static func translate(
      _ transcript: Transcript
    ) throws -> (
      contents: [Content], systemInstruction: Content?
    ) {
      var turns: [(role: String, parts: [Part])] = []
      var systemInstructionParts: [Part] = []

      func appendPart(_ part: Part, role: String) {
        if let lastIndex = turns.indices.last, turns[lastIndex].role == role {
          turns[lastIndex].parts.append(part)
        } else {
          turns.append((role: role, parts: [part]))
        }
      }

      for entry in transcript {
        switch entry {
        case .instructions(let instructions):
          let text = try extractText(from: instructions.segments, in: entry)
          guard instructions.toolDefinitions.isEmpty else {
            throw makeUnsupportedError(
              entry,
              description: "Tool definitions in instructions are not supported."
            )
          }
          systemInstructionParts.append(Part(data: .text(text)))

        case .prompt(let prompt):
          let text = try extractText(from: prompt.segments, in: entry)
          appendPart(Part(data: .text(text)), role: "user")

        case .response(let response):
          let text = try extractText(from: response.segments, in: entry)
          appendPart(Part(data: .text(text)), role: "model")

        case .reasoning(let reasoning):
          let signatureString = reasoning.signature.map {
            String(decoding: $0, as: UTF8.self)
          }
          let text = try extractOptionalText(from: reasoning.segments, in: entry)
          let partData: Part.PartData? = text.map { .text($0) }
          if partData != nil || signatureString != nil {
            appendPart(
              Part(
                data: partData,
                thought: true,
                thoughtSignature: signatureString
              ),
              role: "model"
            )
          }

        case .toolCalls:
          throw makeUnsupportedError(
            entry,
            description: "Tool calls in transcript are not supported."
          )

        case .toolOutput:
          throw makeUnsupportedError(
            entry,
            description: "Tool outputs in transcript are not supported."
          )

        @unknown default:
          throw makeUnsupportedError(
            entry,
            description: "Unsupported transcript entry."
          )
        }
      }

      let contents = turns.map { Content(parts: $0.parts, role: $0.role) }
      let systemInstruction: Content? =
        systemInstructionParts.isEmpty ? nil : Content(parts: systemInstructionParts)
      return (contents: contents, systemInstruction: systemInstruction)
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
#endif  // canImport(FoundationModels) && compiler(>=6.4)
