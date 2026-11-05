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

  /// The `function` object of a tool definition in transcript JSON.
  ///
  /// Instructions descriptions also print an array of these objects.
  struct TranscriptCodableToolFunction: Codable {
    /// The tool's name.
    var name: String

    /// The tool's description, as given to the model.
    var description: String

    /// The schema of the tool's arguments.
    var parameters: GenerationSchema

    /// Creates the function object for a tool definition.
    ///
    /// - Parameter toolDefinition: The tool definition to encode.
    init(_ toolDefinition: Transcript.ToolDefinition) {
      self.name = toolDefinition.name
      self.description = toolDefinition.description
      self.parameters = toolDefinition.parameters
    }

    /// The tool definition this function object describes.
    var toolDefinition: Transcript.ToolDefinition {
      Transcript.ToolDefinition(name: name, description: description, parameters: parameters)
    }
  }

  /// The transcript JSON form of `Transcript.ToolDefinition`.
  ///
  /// The format is `{"type": "function", "function": {"name", "description", "parameters"}}`.
  struct TranscriptCodableToolDefinition: Codable {
    /// The tool definition this value wraps.
    var toolDefinition: Transcript.ToolDefinition

    /// The JSON keys of a tool definition.
    enum CodingKeys: String, CodingKey {
      case type
      case function
    }

    /// Wraps a tool definition for coding.
    ///
    /// - Parameter toolDefinition: The tool definition to encode.
    init(_ toolDefinition: Transcript.ToolDefinition) {
      self.toolDefinition = toolDefinition
    }

    /// Creates a tool definition by decoding from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the type is unknown or a value is missing or invalid.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      guard type == "function" else {
        throw DecodingError.dataCorruptedError(
          forKey: .type,
          in: container,
          debugDescription: "Unsupported tool type: \(type)"
        )
      }
      let function = try container.decode(TranscriptCodableToolFunction.self, forKey: .function)
      self.toolDefinition = function.toolDefinition
    }

    /// Encodes the tool definition into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the parameters schema can't be encoded.
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("function", forKey: .type)
      try container.encode(TranscriptCodableToolFunction(toolDefinition), forKey: .function)
    }
  }

  /// The transcript JSON form of `Transcript.ToolCall`.
  ///
  /// The format is `{"id", "name", "arguments", "metadata"?}`, where `arguments` is a JSON string
  /// that holds the arguments' ``GeneratedContent/jsonString``.
  struct TranscriptCodableToolCall: Codable {
    /// The tool call this value wraps.
    var toolCall: Transcript.ToolCall

    /// The JSON keys of a tool call.
    enum CodingKeys: String, CodingKey {
      case id
      case name
      case arguments
      case metadata
    }

    /// Wraps a tool call for coding.
    ///
    /// - Parameter toolCall: The tool call to encode.
    init(_ toolCall: Transcript.ToolCall) {
      self.toolCall = toolCall
    }

    /// Creates a tool call by decoding from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if a value is missing or the arguments aren't valid JSON.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let id = try container.decode(String.self, forKey: .id)
      let name = try container.decode(String.self, forKey: .name)
      let rawArguments = try container.decode(String.self, forKey: .arguments)
      let arguments: GeneratedContent
      do {
        arguments = try GeneratedContent(json: rawArguments)
      } catch {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: container.codingPath + [CodingKeys.arguments],
            debugDescription: "The tool call arguments aren't valid JSON.",
            underlyingError: error
          )
        )
      }
      var toolCall = Transcript.ToolCall(
        id: id,
        metadata: [:],
        toolName: name,
        arguments: arguments
      )
      toolCall.metadata = try container.decodeTranscriptMetadata(forKey: .metadata)
      toolCall.rawArguments = rawArguments
      self.toolCall = toolCall
    }

    /// Encodes the tool call into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if a metadata value can't be encoded.
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(toolCall.id, forKey: .id)
      try container.encode(toolCall.toolName, forKey: .name)
      try container.encode(toolCall.argumentsJSONString, forKey: .arguments)
      try container.encodeTranscriptMetadata(toolCall.metadata, forKey: .metadata)
    }
  }
#endif  // compiler(>=6.4)
