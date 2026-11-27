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

  /// The transcript JSON form of `Transcript.Entry`.
  ///
  /// Each entry is an object with a `role` and an `id`:
  ///
  /// | Entry | `role` | Other keys |
  /// | :--- | :--- | :--- |
  /// | Instructions | `instructions` | `contents`, `tools` (when non-empty) |
  /// | Prompt | `user` | `contents`, `options`, `contextOptions`, `metadata`?, `responseFormat`? |
  /// | Reasoning | `reasoning` | `reasoning: {contents, signature?}`, `metadata`? |
  /// | Tool calls | `response` | `toolCalls` |
  /// | Tool output | `tool` | `toolCallID` (the id), `toolName`, `contents` |
  /// | Response | `response` | `contents`, `assets`?, `metadata`? |
  /// | Data | `data` | `contentType`, `content`, `metadata`? |
  ///
  /// Optional keys are omitted when empty.
  struct TranscriptCodableEntry: Codable {
    /// The entry this value wraps.
    var entry: Transcript.Entry

    /// The JSON keys of an entry.
    enum CodingKeys: String, CodingKey {
      case role
      case id
      case contents
      case tools
      case options
      case contextOptions
      case metadata
      case responseFormat
      case reasoning
      case toolCalls
      case toolCallID
      case toolName
      case assets
      case contentType
      case content
    }

    /// The JSON keys of the `reasoning` object.
    enum ReasoningCodingKeys: String, CodingKey {
      case contents
      case signature
    }

    /// Wraps an entry for coding.
    ///
    /// - Parameter entry: The entry to encode.
    init(_ entry: Transcript.Entry) {
      self.entry = entry
    }

    /// Creates an entry by decoding from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the role is unknown or a value is missing or invalid.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let role = try container.decode(String.self, forKey: .role)
      let id = try container.decode(String.self, forKey: .id)
      switch role {
      case "instructions":
        let tools =
          try container.decodeIfPresent([TranscriptCodableToolDefinition].self, forKey: .tools)
          ?? []
        entry = .instructions(
          Transcript.Instructions(
            id: id,
            segments: try Self.decodeSegments(from: container, forKey: .contents),
            toolDefinitions: tools.map(\.toolDefinition)
          )
        )
      case "user":
        var prompt = Transcript.Prompt(
          id: id,
          segments: try Self.decodeSegments(from: container, forKey: .contents),
          options: try container.decodeIfPresent(
            TranscriptCodableGenerationOptions.self,
            forKey: .options
          )?.options ?? GenerationOptions(),
          responseFormat: try container.decodeIfPresent(
            TranscriptCodableResponseFormat.self,
            forKey: .responseFormat
          )?.responseFormat
        )
        prompt.contextOptions =
          try container.decodeIfPresent(
            TranscriptCodableContextOptions.self,
            forKey: .contextOptions
          )?.options ?? ContextOptions()
        prompt.metadata = try container.decodeTranscriptMetadata(forKey: .metadata)
        entry = .prompt(prompt)
      case "reasoning":
        let reasoning = try container.nestedContainer(
          keyedBy: ReasoningCodingKeys.self,
          forKey: .reasoning
        )
        var value = Transcript.Reasoning(
          id: id,
          segments: try Self.decodeSegments(from: reasoning, forKey: .contents),
          signature: try Self.decodeSignature(from: reasoning)
        )
        value.metadata = try container.decodeTranscriptMetadata(forKey: .metadata)
        entry = .reasoning(value)
      case "tool":
        entry = .toolOutput(
          Transcript.ToolOutput(
            id: try container.decodeIfPresent(String.self, forKey: .toolCallID) ?? id,
            toolName: try container.decode(String.self, forKey: .toolName),
            segments: try Self.decodeSegments(from: container, forKey: .contents)
          )
        )
      case "response":
        if let toolCalls = try container.decodeIfPresent(
          [TranscriptCodableToolCall].self,
          forKey: .toolCalls
        ) {
          entry = .toolCalls(Transcript.ToolCalls(id: id, toolCalls.map(\.toolCall)))
        } else {
          entry = .response(
            Transcript.Response(
              id: id,
              assetIDs: try container.decodeIfPresent([String].self, forKey: .assets) ?? [],
              metadata: try container.decodeTranscriptMetadata(forKey: .metadata),
              segments: try Self.decodeSegments(from: container, forKey: .contents)
            )
          )
        }
      #if compiler(>=6.4.2)
        case "data":
          let typeID = try container.decode(String.self, forKey: .contentType)
          let contentType =
            (try? container.decode(UTType.self, forKey: .contentType))
            ?? UTType(typeID)
            ?? (typeID.isEmpty ? .data : UTType(importedAs: typeID))
          let content = try container.decode(Data.self, forKey: .content)
          let metadata =
            try container.decodeIfPresent(CodableGeneratedContent.self, forKey: .metadata)?.content
            ?? GeneratedContent(properties: [:])
          entry = .data(
            Transcript.DataEntry(
              id: id,
              contentType: contentType,
              content: content,
              metadata: metadata
            )
          )
      #endif  // compiler(>=6.4.2)
      default:
        throw DecodingError.dataCorruptedError(
          forKey: .role,
          in: container,
          debugDescription: "Unsupported transcript entry role: \(role)"
        )
      }
    }

    /// Encodes the entry into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if an image can't be loaded,
    ///   or an encoding error.
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch entry {
      case .instructions(let instructions):
        try container.encode("instructions", forKey: .role)
        try container.encode(instructions.id, forKey: .id)
        try Self.encode(instructions.segments, to: &container, forKey: .contents)
        if !instructions.toolDefinitions.isEmpty {
          try container.encode(
            instructions.toolDefinitions.map(TranscriptCodableToolDefinition.init),
            forKey: .tools
          )
        }
      case .prompt(let prompt):
        try container.encode("user", forKey: .role)
        try container.encode(prompt.id, forKey: .id)
        try Self.encode(prompt.segments, to: &container, forKey: .contents)
        try container.encode(TranscriptCodableGenerationOptions(prompt.options), forKey: .options)
        try container.encode(
          TranscriptCodableContextOptions(prompt.contextOptions),
          forKey: .contextOptions
        )
        try container.encodeTranscriptMetadata(prompt.metadata, forKey: .metadata)
        try container.encodeIfPresent(
          prompt.responseFormat.map(TranscriptCodableResponseFormat.init),
          forKey: .responseFormat
        )
      case .reasoning(let reasoning):
        try container.encode("reasoning", forKey: .role)
        try container.encode(reasoning.id, forKey: .id)
        var nested = container.nestedContainer(
          keyedBy: ReasoningCodingKeys.self, forKey: .reasoning)
        try Self.encode(reasoning.segments, to: &nested, forKey: .contents)
        try nested.encodeIfPresent(
          reasoning.signature?.base64EncodedString(),
          forKey: .signature
        )
        try container.encodeTranscriptMetadata(reasoning.metadata, forKey: .metadata)
      case .toolCalls(let toolCalls):
        try container.encode("response", forKey: .role)
        try container.encode(toolCalls.id, forKey: .id)
        try container.encode(
          toolCalls.calls.map(TranscriptCodableToolCall.init), forKey: .toolCalls)
      case .toolOutput(let toolOutput):
        try container.encode("tool", forKey: .role)
        try container.encode(toolOutput.id, forKey: .id)
        try container.encode(toolOutput.id, forKey: .toolCallID)
        try container.encode(toolOutput.toolName, forKey: .toolName)
        try Self.encode(toolOutput.segments, to: &container, forKey: .contents)
      case .response(let response):
        try container.encode("response", forKey: .role)
        try container.encode(response.id, forKey: .id)
        try Self.encode(response.segments, to: &container, forKey: .contents)
        if !response.assetIDs.isEmpty {
          try container.encode(response.assetIDs, forKey: .assets)
        }
        try container.encodeTranscriptMetadata(response.storedMetadata, forKey: .metadata)
      #if compiler(>=6.4.2)
        case .data(let dataEntry):
          try container.encode("data", forKey: .role)
          try container.encode(dataEntry.id, forKey: .id)
          try container.encode(dataEntry.contentType.identifier, forKey: .contentType)
          try container.encode(dataEntry.content, forKey: .content)
          try container.encodeTranscriptContent(dataEntry.metadata, forKey: .metadata)
      #endif  // compiler(>=6.4.2)
      }
    }

    /// Decodes a reasoning signature from its base64 string, independent of the decoder's data
    /// decoding strategy.
    ///
    /// - Parameter container: The `reasoning` object's container.
    /// - Returns: The signature bytes, or `nil` if the key is absent.
    /// - Throws: `DecodingError.dataCorrupted` if the value isn't valid base64.
    static func decodeSignature(
      from container: KeyedDecodingContainer<ReasoningCodingKeys>
    ) throws -> Data? {
      guard let string = try container.decodeIfPresent(String.self, forKey: .signature) else {
        return nil
      }
      guard let signature = Data(base64Encoded: string) else {
        throw DecodingError.dataCorruptedError(
          forKey: .signature,
          in: container,
          debugDescription: "The reasoning signature isn't valid base64."
        )
      }
      return signature
    }

    /// Decodes an array of segments, treating a missing key as no segments.
    ///
    /// - Parameters:
    ///   - container: The container to decode from.
    ///   - key: The key of the segment array.
    /// - Returns: The decoded segments.
    /// - Throws: `DecodingError` if a segment is invalid.
    static func decodeSegments<Key: CodingKey>(
      from container: KeyedDecodingContainer<Key>,
      forKey key: Key
    ) throws -> [Transcript.Segment] {
      try container.decodeIfPresent([TranscriptCodableSegment].self, forKey: key)?
        .map(\.segment) ?? []
    }

    /// Encodes an array of segments.
    ///
    /// - Parameters:
    ///   - segments: The segments to encode.
    ///   - container: The container to encode into.
    ///   - key: The key of the segment array.
    /// - Throws: `LanguageModelError.unsupportedTranscriptContent` if an image can't be loaded,
    ///   or an encoding error.
    static func encode<Key: CodingKey>(
      _ segments: [Transcript.Segment],
      to container: inout KeyedEncodingContainer<Key>,
      forKey key: Key
    ) throws {
      try container.encode(segments.map(TranscriptCodableSegment.init), forKey: key)
    }
  }
#endif  // compiler(>=6.4)
