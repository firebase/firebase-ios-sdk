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

#if compiler(>=6.4)
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  #if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
  #endif

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Entry: CustomStringConvertible {
    /// A textual representation of this entry.
    public var description: String {
      switch self {
      case .instructions(let instructions):
        instructions.description
      case .prompt(let prompt):
        prompt.description
      case .toolCalls(let toolCalls):
        toolCalls.description
      case .toolOutput(let toolOutput):
        toolOutput.description
      case .response(let response):
        response.description
      case .reasoning(let reasoning):
        reasoning.description
      #if compiler(>=6.4.2)
        case .data(let dataEntry):
          dataEntry.description
      #endif  // compiler(>=6.4.2)
      }
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.TextSegment: CustomStringConvertible {
    /// A textual representation of this text segment.
    public var description: String {
      content
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.StructuredSegment: CustomStringConvertible {
    /// A textual representation of this structured segment.
    public var description: String {
      content.jsonString
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.AttachmentSegment: CustomStringConvertible {
    /// A textual representation of this attachment segment.
    public var description: String {
      switch content {
      case .image:
        "[attachment \(id)]"
      #if compiler(>=6.4.2)
        case .data(let dataAttachment):
          "[data \(dataAttachment.contentType.identifier), \(dataAttachment.content.count) bytes]"
      #endif  // compiler(>=6.4.2)
      }
    }
  }

  extension Transcript.Reasoning {
    /// A textual representation of this reasoning entry.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, *)
    @available(watchOS, unavailable)
    @available(tvOS, unavailable)
    public var description: String {
      "[reasoning \(id)]"
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Segment: CustomStringConvertible {
    /// A textual representation of this segment.
    public var description: String {
      switch self {
      case .text(let text):
        text.description
      case .structure(let structure):
        structure.description
      case .attachment(let attachment):
        attachment.description
      }
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Instructions: CustomStringConvertible {
    /// A textual representation of these instructions.
    public var description: String {
      var result = "Instructions: " + Transcript.describe(segments)
      if !toolDefinitions.isEmpty {
        result += "\nTools: " + Transcript.compactJSON(toolDefinitions)
      }
      return result
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Prompt: CustomStringConvertible {
    /// A textual representation of this prompt.
    public var description: String {
      "Prompt: " + Transcript.describe(segments) + "\nResponse format: "
        + (responseFormat?.name ?? "none")
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.ResponseFormat: CustomStringConvertible {
    /// A textual representation of this response format.
    public var description: String {
      switch kind {
      case .schema(let schema):
        schema.transcriptCompactJSON
      }
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.ToolCalls: CustomStringConvertible {
    /// A textual representation of these tool calls.
    public var description: String {
      "Tool calls: " + calls.map(\.description).joined(separator: "\n")
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.ToolCall: CustomStringConvertible {
    /// A textual representation of this tool call.
    public var description: String {
      "\(toolName)(\(argumentsJSONString))"
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.ToolOutput: CustomStringConvertible {
    /// A textual representation of this tool output.
    public var description: String {
      "Tool output from \(toolName): " + Transcript.describe(segments)
    }
  }

  @available(iOS 26.0, macOS 26.0, visionOS 26.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension Transcript.Response: CustomStringConvertible {
    /// A textual representation of this response.
    public var description: String {
      "Response: " + Transcript.describe(segments)
    }
  }

  // MARK: - Helpers

  extension Transcript {
    /// Joins the descriptions of segments with newlines, as entry descriptions do.
    ///
    /// - Parameter segments: The segments to describe.
    /// - Returns: The segment descriptions separated by `"\n"`.
    static func describe(_ segments: [Transcript.Segment]) -> String {
      segments.map(\.description).joined(separator: "\n")
    }

    /// Returns tool definitions as a compact JSON array with sorted keys.
    ///
    /// Each element has the `name`, `description`, and `parameters` keys of the `function`
    /// object in transcript JSON.
    ///
    /// - Parameter toolDefinitions: The tool definitions to serialize.
    /// - Returns: The JSON text, or `"[]"` if encoding fails.
    static func compactJSON(_ toolDefinitions: [Transcript.ToolDefinition]) -> String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let functions = toolDefinitions.map(TranscriptCodableToolFunction.init)
      guard let data = try? encoder.encode(functions) else {
        return "[]"
      }
      return String(decoding: data, as: UTF8.self)
    }
  }
#endif  // compiler(>=6.4)
