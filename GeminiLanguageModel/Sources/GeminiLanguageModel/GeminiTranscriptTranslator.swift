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

      var pendingReasoningText: String?
      var pendingReasoningSignature: String?

      /// Flushes any buffered reasoning thoughts or signature into a model part.
      func flushPendingReasoningIfNeeded() {
        if let text = pendingReasoningText {
          appendPart(
            Part(
              data: .text(text),
              thought: true,
              thoughtSignature: pendingReasoningSignature
            ),
            role: "model"
          )
        } else if let signature = pendingReasoningSignature {
          appendPart(
            Part(
              data: nil,
              thought: true,
              thoughtSignature: signature
            ),
            role: "model"
          )
        }
        pendingReasoningText = nil
        pendingReasoningSignature = nil
      }

      for entry in transcript {
        switch entry {
        case .instructions(let instructions):
          flushPendingReasoningIfNeeded()
          let text = try extractText(from: instructions.segments, in: entry)
          if !text.isEmpty {
            systemInstructionParts.append(Part(data: .text(text)))
          }

        case .prompt(let prompt):
          flushPendingReasoningIfNeeded()
          let text = try extractText(from: prompt.segments, in: entry)
          appendPart(Part(data: .text(text)), role: "user")

        case .response(let response):
          flushPendingReasoningIfNeeded()
          let text = try extractText(from: response.segments, in: entry)
          appendPart(Part(data: .text(text)), role: "model")

        case .reasoning(let reasoning):
          let text = try extractOptionalText(from: reasoning.segments, in: entry)
          let signatureString = reasoning.signature.map {
            String(decoding: $0, as: UTF8.self)
          }
          if let text {
            pendingReasoningText = (pendingReasoningText ?? "") + text
          }
          if let signatureString {
            pendingReasoningSignature = signatureString
          }

        case .toolCalls(let toolCalls):
          guard !toolCalls.isEmpty else { break }
          if let text = pendingReasoningText {
            appendPart(
              Part(
                data: .text(text),
                thought: true
              ),
              role: "model"
            )
          }
          let callSignature = pendingReasoningSignature
          pendingReasoningText = nil
          pendingReasoningSignature = nil

          for call in toolCalls {
            let args: [String: JSONValue]?
            if case .structure(let properties, _) = call.arguments.kind {
              args = properties.isEmpty ? nil : properties.mapValues { jsonValue(from: $0) }
            } else {
              args = nil
            }
            let functionCall = FunctionCall(
              id: call.id,
              name: call.toolName,
              args: args
            )
            appendPart(
              Part(
                data: .functionCall(functionCall),
                thoughtSignature: callSignature
              ),
              role: "model"
            )
          }

        case .toolOutput(let toolOutput):
          flushPendingReasoningIfNeeded()
          if toolOutput.segments.isEmpty {
            let functionResponse = FunctionResponse(
              id: toolOutput.id,
              name: toolOutput.toolName,
              response: ["result": .null]
            )
            appendPart(Part(data: .functionResponse(functionResponse)), role: "user")
          } else {
            for segment in toolOutput.segments {
              let response = try extractResponse(from: segment, in: entry)
              let functionResponse = FunctionResponse(
                id: toolOutput.id,
                name: toolOutput.toolName,
                response: response
              )
              appendPart(Part(data: .functionResponse(functionResponse)), role: "user")
            }
          }

        @unknown default:
          throw makeUnsupportedError(
            entry,
            description: "Unsupported transcript entry."
          )
        }
      }

      flushPendingReasoningIfNeeded()

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

    /// Converts a `GeneratedContent` value into a corresponding `JSONValue`.
    ///
    /// - Parameter content: The generated content to convert.
    /// - Returns: The mapped `JSONValue`.
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

    /// Extracts a JSON object dictionary representation from a tool output segment.
    ///
    /// - Parameters:
    ///   - segment: The tool output segment to extract.
    ///   - entry: The enclosing transcript entry for error reporting.
    /// - Returns: A dictionary of key-value pairs suitable for `FunctionResponse.response`.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if unsupported segments are
    ///   found.
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
#endif  // canImport(FoundationModels) && compiler(>=6.4)
