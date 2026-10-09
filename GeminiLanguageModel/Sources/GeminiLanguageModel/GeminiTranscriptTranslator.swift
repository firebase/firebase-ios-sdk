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
        defer {
          pendingReasoningText = nil
          pendingReasoningSignature = nil
        }
        guard pendingReasoningText != nil || pendingReasoningSignature != nil else { return }
        appendPart(
          thoughtPart(pendingReasoningText, signature: pendingReasoningSignature),
          role: "model"
        )
      }

      for entry in transcript {
        switch entry {
        case .instructions(let instructions):
          flushPendingReasoningIfNeeded()
          let text = try extractText(from: instructions.segments, in: entry)
          if !text.isEmpty {
            systemInstructionParts.append(Part { $0.data = .text(text) })
          }

        case .prompt(let prompt):
          flushPendingReasoningIfNeeded()
          let text = try extractText(from: prompt.segments, in: entry)
          appendPart(Part { $0.data = .text(text) }, role: "user")

        case .response(let response):
          flushPendingReasoningIfNeeded()
          let text = try extractText(from: response.segments, in: entry)
          appendPart(Part { $0.data = .text(text) }, role: "model")

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
            appendPart(thoughtPart(text, signature: nil), role: "model")
          }
          let callSignature = pendingReasoningSignature
          pendingReasoningText = nil
          pendingReasoningSignature = nil

          for call in toolCalls {
            appendPart(
              functionCallPart(for: call, thoughtSignature: callSignature),
              role: "model"
            )
          }

        case .toolOutput(let toolOutput):
          flushPendingReasoningIfNeeded()
          if toolOutput.segments.isEmpty {
            appendPart(
              functionResponsePart(for: toolOutput, response: ["result": .null]),
              role: "user"
            )
          } else {
            for segment in toolOutput.segments {
              let response = try extractResponse(from: segment, in: entry)
              appendPart(functionResponsePart(for: toolOutput, response: response), role: "user")
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

      let contents = turns.map { turn in
        Content {
          $0.parts = turn.parts
          $0.role = turn.role
        }
      }
      let systemInstruction: Content? =
        systemInstructionParts.isEmpty ? nil : Content { $0.parts = systemInstructionParts }
      return (contents: contents, systemInstruction: systemInstruction)
    }

    // MARK: - Private Helpers

    /// Returns a `Part` marked as a model thought.
    ///
    /// - Parameters:
    ///   - text: The reasoning text, or `nil` for a signature-only thought.
    ///   - signature: The opaque thought signature to round-trip, if any.
    /// - Returns: A thought `Part`.
    private static func thoughtPart(_ text: String?, signature: String?) -> Part {
      Part {
        $0.data = text.map(Part.PartData.text)
        $0.thought = true
        $0.thoughtSignature = signature
      }
    }

    /// Returns a `Part` containing a function call for `call`.
    ///
    /// - Parameters:
    ///   - call: The transcript tool call to translate.
    ///   - thoughtSignature: The thought signature to attach to the part, if any.
    /// - Returns: A function call `Part`.
    private static func functionCallPart(
      for call: Transcript.ToolCall,
      thoughtSignature: String?
    ) -> Part {
      let args: JSONObject?
      if case .structure(let properties, _) = call.arguments.kind {
        args = properties.isEmpty ? nil : properties.mapValues { jsonValue(from: $0) }
      } else {
        args = nil
      }
      let functionCall = FunctionCall {
        $0.id = call.id
        $0.name = call.toolName
        $0.args = args
      }
      return Part {
        $0.data = .functionCall(functionCall)
        $0.thoughtSignature = thoughtSignature
      }
    }

    /// Returns a `Part` containing a function response for `toolOutput`.
    ///
    /// - Parameters:
    ///   - toolOutput: The transcript tool output that the response belongs to.
    ///   - response: The JSON object returned by the tool.
    /// - Returns: A function response `Part`.
    private static func functionResponsePart(
      for toolOutput: Transcript.ToolOutput,
      response: JSONObject
    ) -> Part {
      let functionResponse = FunctionResponse {
        $0.id = toolOutput.id
        $0.name = toolOutput.toolName
        $0.response = response
      }
      return Part { $0.data = .functionResponse(functionResponse) }
    }

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
