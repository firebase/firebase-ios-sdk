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

      /// Round-trips a signature-only reasoning entry on a part that has data.
      ///
      /// Gemini returns the signature of a text response on a trailing empty text part, which the
      /// executor records as a separate signature-only `.reasoning` entry. Round-tripping it as a
      /// stand-alone `Part` with no data is rejected by the Gemini Enterprise Agent Platform, so
      /// the signature is re-attached to the last part of the current model turn instead (normally
      /// the response text; a function call part if the signature arrived after the call). If
      /// there is no suitable part, an empty thought part carries the signature so the part has
      /// data.
      ///
      /// - Parameter signature: The opaque thought signature to round-trip.
      func attachTrailingSignature(_ signature: String) {
        if let turnIndex = turns.indices.last, turns[turnIndex].role == "model",
          let partIndex = turns[turnIndex].parts.indices.last,
          turns[turnIndex].parts[partIndex].thoughtSignature == nil
        {
          turns[turnIndex].parts[partIndex].thoughtSignature = signature
        } else {
          appendPart(thoughtPart("", signature: signature), role: "model")
        }
      }

      /// Flushes any buffered reasoning thoughts or signature into a model part.
      func flushPendingReasoningIfNeeded() {
        defer {
          pendingReasoningText = nil
          pendingReasoningSignature = nil
        }
        if let text = pendingReasoningText {
          appendPart(thoughtPart(text, signature: pendingReasoningSignature), role: "model")
        } else if let signature = pendingReasoningSignature {
          attachTrailingSignature(signature)
        }
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
          for part in try extractPromptParts(from: prompt.segments, in: entry) {
            appendPart(part, role: "user")
          }

        case .response(let response):
          let text = try extractText(from: response.segments, in: entry)
          var part = Part { $0.data = .text(text) }
          if pendingReasoningText == nil, let signature = pendingReasoningSignature {
            // A signature-only reasoning entry directly preceding a response is assumed to have
            // come from the response's own text, so round-trip it on the text part rather than as
            // a data-less thought part.
            part.thoughtSignature = signature
            pendingReasoningSignature = nil
          } else {
            flushPendingReasoningIfNeeded()
          }
          appendPart(part, role: "model")

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

        // `Transcript.Entry.data` was added in Xcode 27.2 (Swift 6.4.2+).
        #if compiler(>=6.4.2)
          case .data:
            throw makeUnsupportedError(
              entry,
              description: "Data transcript entries are not supported."
            )
        #endif  // compiler(>=6.4.2)

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
    ///   - text: The reasoning text; empty for a signature-only thought.
    ///   - signature: The opaque thought signature to round-trip, if any.
    /// - Returns: A thought `Part`.
    private static func thoughtPart(_ text: String, signature: String?) -> Part {
      Part {
        $0.data = .text(text)
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

    /// Extracts the Gemini parts for the segments of a prompt entry.
    ///
    /// Segment order is preserved: each contiguous, non-empty run of text segments becomes one
    /// text part and each image attachment becomes one inline data part. A prompt that would
    /// otherwise produce no parts (for example, a prompt containing only empty text) produces a
    /// single empty text part.
    ///
    /// - Parameters:
    ///   - segments: The prompt segments to translate.
    ///   - entry: The enclosing transcript entry for error reporting.
    /// - Returns: The parts for the prompt, in order.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if unsupported segments are
    ///   found or an image attachment can't be translated.
    private static func extractPromptParts(
      from segments: [Transcript.Segment],
      in entry: Transcript.Entry
    ) throws -> [Part] {
      var parts: [Part] = []
      var pendingText: String?

      func flushPendingText() {
        if let text = pendingText, !text.isEmpty {
          parts.append(Part { $0.data = .text(text) })
        }
        pendingText = nil
      }

      for segment in segments {
        switch segment {
        case .text(let textSegment):
          pendingText = (pendingText ?? "") + textSegment.content
        case .attachment(let attachmentSegment):
          switch attachmentSegment.content {
          case .image(let imageAttachment):
            flushPendingText()
            let imageData = try translateImage(imageAttachment, in: entry)
            parts.append(Part { $0.data = imageData })
          // `Transcript.Attachment.data` was added in Xcode 27.2 (Swift 6.4.2+).
          #if compiler(>=6.4.2)
            case .data:
              throw makeUnsupportedError(
                entry,
                description: "Data attachment segments in prompts are not supported."
              )
          #endif  // compiler(>=6.4.2)
          @unknown default:
            throw makeUnsupportedError(
              entry,
              description: "Unsupported attachment segment in prompt."
            )
          }
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
      flushPendingText()

      return parts.isEmpty ? [Part { $0.data = .text("") }] : parts
    }

    /// Translates an image attachment into Gemini part data.
    ///
    /// - Parameters:
    ///   - imageAttachment: The image attachment to translate.
    ///   - entry: The enclosing transcript entry for error reporting.
    /// - Returns: The part data for the image.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if the image can't be
    ///   translated.
    private static func translateImage(
      _ imageAttachment: Transcript.ImageAttachment,
      in entry: Transcript.Entry
    ) throws -> Part.PartData {
      do {
        return try GeminiImageTranslator.partData(for: imageAttachment)
      } catch {
        throw makeUnsupportedError(entry, description: error.description)
      }
    }

    /// Concatenates the text segments of an instructions, response, or reasoning entry.
    ///
    /// Prompt entries, which can also contain image attachments, are translated by
    /// `extractPromptParts(from:in:)` instead.
    ///
    /// - Parameters:
    ///   - segments: The segments of an instructions, response, or reasoning entry.
    ///   - entry: The enclosing transcript entry for error reporting.
    /// - Returns: The concatenated text, which may be empty.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if any segment isn't a text
    ///   segment.
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
            description: "Attachment segments are only supported in prompts."
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

    /// Concatenates the text segments of an instructions, response, or reasoning entry, if there
    /// are any.
    ///
    /// This is equivalent to `extractText(from:in:)`, except that empty text is returned as `nil`.
    ///
    /// - Parameters:
    ///   - segments: The segments of an instructions, response, or reasoning entry.
    ///   - entry: The enclosing transcript entry for error reporting.
    /// - Returns: The concatenated text, or `nil` if it's empty.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if any segment isn't a text
    ///   segment.
    private static func extractOptionalText(
      from segments: [Transcript.Segment],
      in entry: Transcript.Entry
    ) throws -> String? {
      let text = try extractText(from: segments, in: entry)
      return text.isEmpty ? nil : text
    }
  }
#endif  // canImport(FoundationModels) && compiler(>=6.4)
