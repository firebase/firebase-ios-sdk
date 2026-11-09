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

  /// The transcript JSON form of `GenerationOptions`.
  ///
  /// Sampling becomes `{"greedy": true}`, `{"topK": k, "randomSeed": s}`, or
  /// `{"topP": p, "randomSeed": s}`; the other options are written only when set, so default
  /// options encode as `{}`.
  struct TranscriptCodableGenerationOptions: Codable {
    /// The options this value wraps.
    var options: GenerationOptions

    /// The JSON keys of generation options.
    enum CodingKeys: String, CodingKey {
      case greedy
      case topK
      case topP
      case randomSeed
      case temperature
      case maximumResponseTokens
      case toolCallingMode
    }

    /// Wraps generation options for coding.
    ///
    /// - Parameter options: The options to encode.
    init(_ options: GenerationOptions) {
      self.options = options
    }

    /// Creates options by decoding from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if a value has the wrong type or an unknown tool-calling mode.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      var options = GenerationOptions()
      let seed = try container.decodeIfPresent(UInt64.self, forKey: .randomSeed)
      if try container.decodeIfPresent(Bool.self, forKey: .greedy) == true {
        options.samplingMode = .greedy
      } else if let topK = try container.decodeIfPresent(Int.self, forKey: .topK) {
        options.samplingMode = .random(top: topK, seed: seed)
      } else if let topP = try container.decodeIfPresent(Double.self, forKey: .topP) {
        options.samplingMode = .random(probabilityThreshold: topP, seed: seed)
      }
      options.temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
      options.maximumResponseTokens = try container.decodeIfPresent(
        Int.self,
        forKey: .maximumResponseTokens
      )
      if let mode = try container.decodeIfPresent(String.self, forKey: .toolCallingMode) {
        switch mode {
        case "allowed":
          options.toolCallingMode = .allowed
        case "required":
          options.toolCallingMode = .required
        case "disallowed":
          options.toolCallingMode = .disallowed
        default:
          throw DecodingError.dataCorruptedError(
            forKey: .toolCallingMode,
            in: container,
            debugDescription: "Unknown tool calling mode: \(mode)"
          )
        }
      }
      self.options = options
    }

    /// Encodes the options into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if a value can't be encoded.
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch options.samplingMode?.kind {
      case .greedy:
        try container.encode(true, forKey: .greedy)
      case .randomTopK(let topK, let seed):
        try container.encode(topK, forKey: .topK)
        try container.encodeIfPresent(seed, forKey: .randomSeed)
      case .randomProbabilityThreshold(let topP, let seed):
        try container.encode(topP, forKey: .topP)
        try container.encodeIfPresent(seed, forKey: .randomSeed)
      case nil:
        break
      }
      try container.encodeIfPresent(options.temperature, forKey: .temperature)
      try container.encodeIfPresent(
        options.maximumResponseTokens,
        forKey: .maximumResponseTokens
      )
      switch options.toolCallingMode?.kind {
      case .allowed:
        try container.encode("allowed", forKey: .toolCallingMode)
      case .required:
        try container.encode("required", forKey: .toolCallingMode)
      case .disallowed:
        try container.encode("disallowed", forKey: .toolCallingMode)
      case nil:
        break
      }
    }
  }

  /// The transcript JSON form of `ContextOptions`.
  ///
  /// Reasoning levels are written as `"light"`, `"moderate"`, `"deep"`, or the custom string.
  struct TranscriptCodableContextOptions: Codable {
    /// The options this value wraps.
    var options: ContextOptions

    /// The JSON keys of context options.
    enum CodingKeys: String, CodingKey {
      case includeSchemaInPrompt
      case reasoningLevel
    }

    /// Wraps context options for coding.
    ///
    /// - Parameter options: The options to encode.
    init(_ options: ContextOptions) {
      self.options = options
    }

    /// Creates options by decoding from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if a value has the wrong type.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      var options = ContextOptions()
      options.includeSchemaInPrompt = try container.decodeIfPresent(
        Bool.self,
        forKey: .includeSchemaInPrompt
      )
      if let level = try container.decodeIfPresent(String.self, forKey: .reasoningLevel) {
        switch level {
        case "light":
          options.reasoningLevel = .light
        case "moderate":
          options.reasoningLevel = .moderate
        case "deep":
          options.reasoningLevel = .deep
        default:
          options.reasoningLevel = .custom(level)
        }
      }
      self.options = options
    }

    /// Encodes the options into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if a value can't be encoded.
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encodeIfPresent(options.includeSchemaInPrompt, forKey: .includeSchemaInPrompt)
      switch options.reasoningLevel {
      case .light:
        try container.encode("light", forKey: .reasoningLevel)
      case .moderate:
        try container.encode("moderate", forKey: .reasoningLevel)
      case .deep:
        try container.encode("deep", forKey: .reasoningLevel)
      case .custom(let level):
        try container.encode(level, forKey: .reasoningLevel)
      case nil:
        break
      }
    }
  }

  /// The transcript JSON form of `Transcript.ResponseFormat`.
  ///
  /// The format is `{"type": "jsonSchema", "jsonSchema": {"name", "description"?, "schema"}}`.
  struct TranscriptCodableResponseFormat: Codable {
    /// The response format this value wraps.
    var responseFormat: Transcript.ResponseFormat

    /// The JSON keys of a response format.
    enum CodingKeys: String, CodingKey {
      case type
      case jsonSchema
    }

    /// The JSON keys of the `jsonSchema` object.
    enum JSONSchemaCodingKeys: String, CodingKey {
      case name
      case description
      case schema
    }

    /// Wraps a response format for coding.
    ///
    /// - Parameter responseFormat: The response format to encode.
    init(_ responseFormat: Transcript.ResponseFormat) {
      self.responseFormat = responseFormat
    }

    /// Creates a response format by decoding from the given decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: `DecodingError` if the type is unknown or the schema is invalid.
    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(String.self, forKey: .type)
      guard type == "jsonSchema" else {
        throw DecodingError.dataCorruptedError(
          forKey: .type,
          in: container,
          debugDescription: "Unsupported response format type: \(type)"
        )
      }
      let jsonSchema = try container.nestedContainer(
        keyedBy: JSONSchemaCodingKeys.self,
        forKey: .jsonSchema
      )
      let name = try jsonSchema.decode(String.self, forKey: .name)
      let schema = try jsonSchema.decode(GenerationSchema.self, forKey: .schema)
      self.responseFormat = Transcript.ResponseFormat(kind: .schema(schema), decodedName: name)
    }

    /// Encodes the response format into the given encoder.
    ///
    /// - Parameter encoder: The encoder to write data to.
    /// - Throws: An error if the schema can't be encoded.
    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode("jsonSchema", forKey: .type)
      var jsonSchema = container.nestedContainer(
        keyedBy: JSONSchemaCodingKeys.self,
        forKey: .jsonSchema
      )
      try jsonSchema.encode(responseFormat.name, forKey: .name)
      switch responseFormat.kind {
      case .schema(let schema):
        try jsonSchema.encodeIfPresent(schema.typeDescription, forKey: .description)
        try jsonSchema.encode(schema, forKey: .schema)
      }
    }
  }
#endif  // compiler(>=6.4)
