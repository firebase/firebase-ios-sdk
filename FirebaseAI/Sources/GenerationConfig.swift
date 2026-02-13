// Copyright 2023 Google LLC
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

import Foundation

/// A struct defining model parameters to be used when sending generative AI
/// requests to the backend model.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct GenerationConfig: Sendable {
  /// Controls the degree of randomness in token selection.
  var temperature: Float?

  /// Controls diversity of generated text.
  var topP: Float?

  /// Limits the number of highest probability words considered.
  var topK: Int?

  /// The number of response variations to return.
  var candidateCount: Int?

  /// Maximum number of tokens that can be generated in the response.
  var maxOutputTokens: Int?

  /// Controls the likelihood of repeating the same words or phrases already generated in the text.
  var presencePenalty: Float?

  /// Controls the likelihood of repeating words, with the penalty increasing for each repetition.
  var frequencyPenalty: Float?

  /// A set of up to 5 `String`s that will stop output generation.
  var stopSequences: [String]?

  /// Output response MIME type of the generated candidate text.
  var responseMIMEType: String?

  /// Output schema of the generated candidate text.
  var responseSchema: Schema?

  /// Output schema of the generated response in [JSON Schema](https://json-schema.org/) format.
  ///
  /// If set, `responseSchema` must be omitted and `responseMIMEType` is required.
  var responseJSONSchema: JSONSchema?

  /// Supported modalities of the response.
  var responseModalities: [ResponseModality]?

  /// Configuration for controlling the "thinking" behavior of compatible Gemini models.
  var thinkingConfig: ThinkingConfig?

  /// Creates a new `GenerationConfig` value.
  ///
  /// See the
  /// [Configure model parameters](https://firebase.google.com/docs/vertex-ai/model-parameters)
  /// guide and the
  /// [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  /// for more details.
  ///
  /// - Parameters:
  ///   - temperature:Controls the randomness of the language model's output. Higher values (for
  ///     example, 1.0) make the text more random and creative, while lower values (for example,
  ///     0.1) make it more focused and deterministic.
  ///
  ///     > Note: A temperature of 0 means that the highest probability tokens are always selected.
  ///     > In this case, responses for a given prompt are mostly deterministic, but a small amount
  ///     > of variation is still possible.
  ///
  ///     > Important: The range of supported temperature values depends on the model; see the
  ///     > [documentation](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#temperature)
  ///     > for more details.
  ///   - topP: Controls diversity of generated text. Higher values (e.g., 0.9) produce more diverse
  ///     text, while lower values (e.g., 0.5) make the output more focused.
  ///
  ///     The supported range is 0.0 to 1.0.
  ///
  ///     > Important: The default `topP` value depends on the model; see the
  ///     > [documentation](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#top-p)
  ///     > for more details.
  ///   - topK: Limits the number of highest probability words the model considers when generating
  ///     text. For example, a topK of 40 means only the 40 most likely words are considered for the
  ///     next token. A higher value increases diversity, while a lower value makes the output more
  ///     deterministic.
  ///
  ///     The supported range is 1 to 40.
  ///
  ///     > Important: Support for `topK` and the default value depends on the model; see the
  ///     [documentation](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#top-k)
  ///     for more details.
  ///   - candidateCount: The number of response variations to return; defaults to 1 if not set.
  ///     Support for multiple candidates depends on the model; see the
  ///     [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  ///     for more details.
  ///   - maxOutputTokens: Maximum number of tokens that can be generated in the response.
  ///     See the configure model parameters [documentation](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#max-output-tokens)
  ///     for more details.
  ///   - presencePenalty: Controls the likelihood of repeating the same words or phrases already
  ///     generated in the text. Higher values increase the penalty of repetition, resulting in more
  ///     diverse output.
  ///
  ///     > Note: While both `presencePenalty` and `frequencyPenalty` discourage repetition,
  ///     > `presencePenalty` applies the same penalty regardless of how many times the word/phrase
  ///     > has already appeared, whereas `frequencyPenalty` increases the penalty for *each*
  ///     > repetition of a word/phrase.
  ///
  ///     > Important: The range of supported `presencePenalty` values depends on the model; see the
  ///     > [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  ///     > for more details
  ///   - frequencyPenalty: Controls the likelihood of repeating words or phrases, with the penalty
  ///     increasing for each repetition. Higher values increase the penalty of repetition,
  ///     resulting in more diverse output.
  ///
  ///     > Note: While both `frequencyPenalty` and `presencePenalty` discourage repetition,
  ///     > `frequencyPenalty` increases the penalty for *each* repetition of a word/phrase, whereas
  ///     > `presencePenalty` applies the same penalty regardless of how many times the word/phrase
  ///     > has already appeared.
  ///
  ///     > Important: The range of supported `frequencyPenalty` values depends on the model; see
  ///     > the
  ///     > [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  ///     > for more details
  ///   - stopSequences: A set of up to 5 `String`s that will stop output generation. If specified,
  ///     the API will stop at the first appearance of a stop sequence. The stop sequence will not
  ///     be included as part of the response. See the
  ///     [Cloud documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/inference#generationconfig)
  ///     for more details.
  ///   - responseMIMEType: Output response MIME type of the generated candidate text.
  ///
  ///     Supported MIME types:
  ///     - `text/plain`: Text output; the default behavior if unspecified.
  ///     - `application/json`: JSON response in the candidates.
  ///     - `text/x.enum`: For classification tasks, output an enum value as defined in the
  ///       `responseSchema`.
  ///   - responseSchema: Output schema of the generated candidate text. If set, a compatible
  ///     `responseMIMEType` must also be set.
  ///
  ///     Compatible MIME types:
  ///     - `application/json`: Schema for JSON response.
  ///
  ///     Refer to the
  ///     [Generate structured
  ///     output](https://firebase.google.com/docs/vertex-ai/structured-output?platform=ios) guide
  ///     for more details.
  ///   - responseModalities: The data types (modalities) that may be returned in model responses.
  ///
  ///     See the [multimodal
  ///     responses](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal-response-generation)
  ///     documentation for more details.
  ///
  ///     > Warning: Specifying response modalities is a **Public Preview** feature, which means
  ///     > that it is not subject to any SLA or deprecation policy and could change in
  ///     > backwards-incompatible ways.
  ///   - thinkingConfig: Configuration for controlling the "thinking" behavior of compatible Gemini
  ///     models; see ``ThinkingConfig`` for more details.
  public init(temperature: Float? = nil, topP: Float? = nil, topK: Int? = nil,
              candidateCount: Int? = nil, maxOutputTokens: Int? = nil,
              presencePenalty: Float? = nil, frequencyPenalty: Float? = nil,
              stopSequences: [String]? = nil, responseMIMEType: String? = nil,
              responseSchema: Schema? = nil, responseModalities: [ResponseModality]? = nil,
              thinkingConfig: ThinkingConfig? = nil) {
    // Explicit init because otherwise if we re-arrange the above variables it changes the API
    // surface.
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.candidateCount = candidateCount
    self.maxOutputTokens = maxOutputTokens
    self.presencePenalty = presencePenalty
    self.frequencyPenalty = frequencyPenalty
    self.stopSequences = stopSequences
    self.responseMIMEType = responseMIMEType
    self.responseSchema = responseSchema
    responseJSONSchema = nil
    self.responseModalities = responseModalities
    self.thinkingConfig = thinkingConfig
  }

  init(temperature: Float? = nil, topP: Float? = nil, topK: Int? = nil, candidateCount: Int? = nil,
       maxOutputTokens: Int? = nil, presencePenalty: Float? = nil, frequencyPenalty: Float? = nil,
       stopSequences: [String]? = nil, responseMIMEType: String, responseJSONSchema: JSONSchema,
       responseModalities: [ResponseModality]? = nil, thinkingConfig: ThinkingConfig? = nil) {
    self.temperature = temperature
    self.topP = topP
    self.topK = topK
    self.candidateCount = candidateCount
    self.maxOutputTokens = maxOutputTokens
    self.presencePenalty = presencePenalty
    self.frequencyPenalty = frequencyPenalty
    self.stopSequences = stopSequences
    self.responseMIMEType = responseMIMEType
    responseSchema = nil
    self.responseJSONSchema = responseJSONSchema
    self.responseModalities = responseModalities
    self.thinkingConfig = thinkingConfig
  }

  /// Merges two configurations, giving precedence to values found in the `overrides` parameter.
  ///
  /// - Parameters:
  ///   - base: The foundational configuration (e.g., model-level defaults).
  ///   - overrides: The configuration containing values that should supersede the base (e.g.,
  /// request-level specific settings).
  /// - Returns: A merged `GenerationConfig` prioritizing `overrides`, or `nil` if both inputs are
  /// `nil`.
  static func merge(_ base: GenerationConfig?,
                    with overrides: GenerationConfig?) -> GenerationConfig? {
    // 1. If the base config is missing, return the overrides (which might be nil).
    guard let baseConfig = base else {
      return overrides
    }

    // 2. If overrides are missing, strictly return the base.
    guard let overrideConfig = overrides else {
      return baseConfig
    }

    // 3. Start with a copy of the base config.
    var config = baseConfig

    // 4. Overwrite with any non-nil values found in the overrides.
    config.temperature = overrideConfig.temperature ?? config.temperature
    config.topP = overrideConfig.topP ?? config.topP
    config.topK = overrideConfig.topK ?? config.topK
    config.candidateCount = overrideConfig.candidateCount ?? config.candidateCount
    config.maxOutputTokens = overrideConfig.maxOutputTokens ?? config.maxOutputTokens
    config.presencePenalty = overrideConfig.presencePenalty ?? config.presencePenalty
    config.frequencyPenalty = overrideConfig.frequencyPenalty ?? config.frequencyPenalty
    config.stopSequences = overrideConfig.stopSequences ?? config.stopSequences
    config.responseMIMEType = overrideConfig.responseMIMEType ?? config.responseMIMEType
    config.responseModalities = overrideConfig.responseModalities ?? config.responseModalities
    config.thinkingConfig = overrideConfig.thinkingConfig ?? config.thinkingConfig

    // 5. Handle Schema mutual exclusivity with precedence for `responseJSONSchema`.
    if let responseJSONSchema = overrideConfig.responseJSONSchema {
      config.responseJSONSchema = responseJSONSchema
      config.responseSchema = nil
    } else if let responseSchema = overrideConfig.responseSchema {
      config.responseSchema = responseSchema
      config.responseJSONSchema = nil
    }

    return config
  }

  /// Merges configurations and explicitly enforces settings required for JSON structured output.
  ///
  /// - Parameters:
  ///   - base: The foundational configuration (e.g., model defaults).
  ///   - overrides: The configuration containing overrides (e.g., request specific).
  ///   - jsonSchema: The JSON schema to enforce on the output.
  /// - Returns: A non-nil `GenerationConfig` with the merged values and JSON constraints applied.
  static func merge(_ base: GenerationConfig?,
                    with overrides: GenerationConfig?,
                    enforcingJSONSchema jsonSchema: JSONSchema) -> GenerationConfig {
    // 1. Merge base and overrides, defaulting to a fresh config if both are nil.
    var config = GenerationConfig.merge(base, with: overrides) ?? GenerationConfig()

    // 2. Enforce the specific constraints for JSON Schema generation.
    config.responseMIMEType = "application/json"
    config.responseJSONSchema = jsonSchema
    config.responseSchema = nil // Clear conflicting legacy schema

    // 3. Clear incompatible or conflicting options.
    config.candidateCount = nil // Structured output typically requires default candidate behaviour
    config.responseModalities = nil // Ensure text-only output for JSON

    return config
  }
}

// MARK: - Codable Conformances

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension GenerationConfig: Encodable {
  enum CodingKeys: String, CodingKey {
    case temperature
    case topP
    case topK
    case candidateCount
    case maxOutputTokens
    case presencePenalty
    case frequencyPenalty
    case stopSequences
    case responseMIMEType = "responseMimeType"
    case responseSchema
    case responseJSONSchema = "responseJsonSchema"
    case responseModalities
    case thinkingConfig
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(temperature, forKey: .temperature)
    try container.encodeIfPresent(topP, forKey: .topP)
    try container.encodeIfPresent(topK, forKey: .topK)
    try container.encodeIfPresent(candidateCount, forKey: .candidateCount)
    try container.encodeIfPresent(maxOutputTokens, forKey: .maxOutputTokens)
    try container.encodeIfPresent(presencePenalty, forKey: .presencePenalty)
    try container.encodeIfPresent(frequencyPenalty, forKey: .frequencyPenalty)
    try container.encodeIfPresent(stopSequences, forKey: .stopSequences)
    try container.encodeIfPresent(responseMIMEType, forKey: .responseMIMEType)
    try container.encodeIfPresent(responseSchema, forKey: .responseSchema)
    if let responseJSONSchema = responseJSONSchema {
      let schemaEncoder = SchemaEncoder(target: .gemini)
      let jsonSchema = try schemaEncoder.encode(responseJSONSchema)
      try container.encode(jsonSchema, forKey: .responseJSONSchema)
    }
    try container.encodeIfPresent(responseModalities, forKey: .responseModalities)
    try container.encodeIfPresent(thinkingConfig, forKey: .thinkingConfig)
  }
}
