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
public struct GenerationConfig: Sendable, Equatable {
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

  /// Supported modalities of the response.
  var responseModalities: [ResponseModality]?

  /// Configuration for controlling the "thinking" behavior of compatible Gemini models.
  var thinkingConfig: ThinkingConfig?

  /// Configuration options for generating images.
  var imageConfig: ImageConfig?

  /// Configuration for controlling the voice of the model during conversation.
  var speechConfig: ProtoSpeechConfig?

  /// Creates a new `GenerationConfig` value.
  ///
  /// See the
  /// [Configure model parameters](https://firebase.google.com/docs/ai-logic/model-parameters)
  /// guide for more details.
  ///
  /// - Parameters:
  ///   - maxOutputTokens: Maximum number of tokens that can be generated in the response.
  ///     See [configure model
  ///     parameters](https://firebase.google.com/docs/ai-logic/model-parameters#parameters-descriptions-gemini).
  ///   - stopSequences: A set of up to 5 `String`s that will stop output generation. If specified,
  ///     the API will stop at the first appearance of a stop sequence. The stop sequence will not
  ///     be included as part of the response.
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
  ///     output](https://firebase.google.com/docs/ai-logic/generate-structured-output) guide
  ///     for more details.
  ///   - responseModalities: The data types (modalities) that may be returned in model responses.
  ///
  ///     See the [configure model parameters
  ///     documentation](https://firebase.google.com/docs/ai-logic/model-parameters#parameters-descriptions-gemini)
  ///     for more details.
  ///
  ///     > Warning: Specifying response modalities is a **Public Preview** feature, which means
  ///     > that it is not subject to any SLA or deprecation policy and could change in
  ///     > backwards-incompatible ways.
  ///   - thinkingConfig: Configuration for controlling the "thinking" behavior of compatible Gemini
  ///     models; see ``ThinkingConfig`` for more details.
  ///   - speechConfig: Configuration for controlling the voice of the model during conversation;
  ///     see ``SpeechConfig`` for more details.
  ///
  ///     > Warning: Specifying a speech configuration is a **Public Preview** feature, which means
  ///     > that it is not subject to any SLA or deprecation policy and could change in
  ///     > backwards-incompatible ways.
  ///   - imageConfig: Configuration options for generating images.
  @available(
    *,
    deprecated,
    message: "candidateCount, temperature, topP, topK, presencePenalty, and frequencyPenalty are unsupported in Gemini 3.x and later models."
  )
  public init(temperature: Float? = nil, topP: Float? = nil, topK: Int? = nil,
              candidateCount: Int? = nil, maxOutputTokens: Int? = nil,
              presencePenalty: Float? = nil, frequencyPenalty: Float? = nil,
              stopSequences: [String]? = nil, responseMIMEType: String? = nil,
              responseSchema: Schema? = nil, responseModalities: [ResponseModality]? = nil,
              thinkingConfig: ThinkingConfig? = nil, imageConfig: ImageConfig? = nil,
              speechConfig: SpeechConfig? = nil) {
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
    self.responseModalities = responseModalities
    self.thinkingConfig = thinkingConfig
    self.imageConfig = imageConfig
    self.speechConfig = speechConfig?.speechConfig
  }

  /// Creates a new `GenerationConfig` value without deprecated tuning parameters.
  ///
  /// See the
  /// [Configure model parameters](https://firebase.google.com/docs/ai-logic/model-parameters)
  /// guide for more details.
  ///
  /// - Parameters:
  ///   - maxOutputTokens: Maximum number of tokens that can be generated in the response.
  ///     See [configure model
  ///     parameters](https://firebase.google.com/docs/ai-logic/model-parameters#parameters-descriptions-gemini)
  ///     for more details.
  ///   - stopSequences: A set of up to 5 `String`s that will stop output generation. If specified,
  ///     the API will stop at the first appearance of a stop sequence. The stop sequence will not
  ///     be included as part of the response.
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
  ///     output](https://firebase.google.com/docs/ai-logic/generate-structured-output) guide
  ///     for more details.
  ///   - responseModalities: The data types (modalities) that may be returned in model responses.
  ///
  ///     See [configure model parameters](https://firebase.google.com/docs/ai-logic/model-parameters#parameters-descriptions-gemini).
  ///
  ///     > Warning: Specifying response modalities is a **Public Preview** feature, which means
  ///     > that it is not subject to any SLA or deprecation policy and could change in
  ///     > backwards-incompatible ways.
  ///   - thinkingConfig: Configuration for controlling the "thinking" behavior of compatible Gemini
  ///     models; see ``ThinkingConfig`` for more details.
  ///   - speechConfig: Configuration for controlling the voice of the model during conversation;
  ///     see ``SpeechConfig`` for more details.
  ///
  ///     > Warning: Specifying a speech configuration is a **Public Preview** feature, which means
  ///     > that it is not subject to any SLA or deprecation policy and could change in
  ///     > backwards-incompatible ways.
  ///   - imageConfig: Configuration options for generating images.
  public init(maxOutputTokens: Int? = nil,
              stopSequences: [String]? = nil, responseMIMEType: String? = nil,
              responseSchema: Schema? = nil, responseModalities: [ResponseModality]? = nil,
              thinkingConfig: ThinkingConfig? = nil, imageConfig: ImageConfig? = nil,
              speechConfig: SpeechConfig? = nil) {
    temperature = nil
    topP = nil
    topK = nil
    candidateCount = nil
    self.maxOutputTokens = maxOutputTokens
    presencePenalty = nil
    frequencyPenalty = nil
    self.stopSequences = stopSequences
    self.responseMIMEType = responseMIMEType
    self.responseSchema = responseSchema
    self.responseModalities = responseModalities
    self.thinkingConfig = thinkingConfig
    self.imageConfig = imageConfig
    self.speechConfig = speechConfig?.speechConfig
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
    config.imageConfig = overrideConfig.imageConfig ?? config.imageConfig
    config.speechConfig = overrideConfig.speechConfig ?? config.speechConfig
    config.responseSchema = overrideConfig.responseSchema ?? config.responseSchema

    return config
  }
}

// MARK: - Codable Conformances

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
    case responseModalities
    case thinkingConfig
    case imageConfig
    case speechConfig
  }
}
