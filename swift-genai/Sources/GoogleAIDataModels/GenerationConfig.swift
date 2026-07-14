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

import Foundation
public import SharedDataModels


extension GoogleAI {
  /// Configuration options for model generation and outputs. Not all parameters are configurable for every model.
  public struct GenerationConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Output schema of the generated response. This is an alternative to `response_schema` that accepts [JSON Schema](https://json-schema.org/). If set, `response_schema` must be omitted, but `response_mime_type` is required. While the full JSON Schema may be sent, not all features are supported. Specifically, only the following properties are supported: - `$id` - `$defs` - `$ref` - `$anchor` - `type` - `format` - `title` - `description` - `enum` (for strings and numbers) - `items` - `prefixItems` - `minItems` - `maxItems` - `minimum` - `maximum` - `anyOf` - `oneOf` (interpreted the same as `anyOf`) - `properties` - `additionalProperties` - `required` The non-standard `propertyOrdering` property may also be set. Cyclic references are unrolled to a limited degree and, as such, may only be used within non-required properties. (Nullable properties are not sufficient.) If `$ref` is set on a sub-schema, no other properties, except for than those starting as a `$`, may be set.
    public var responsejsonschema: JSONValue?
    
    /// Optional. Number of generated responses to return. If unset, this will default to 1. Please note that this doesn't work for previous generation models (Gemini 1.0 family)
    public var candidateCount: Int?
    
    /// Optional. If enabled, the model will detect emotions and adapt its responses accordingly.
    public var enableAffectiveDialog: Bool?
    
    /// Optional. Enables enhanced civic answers. It may not be available for all models.
    public var enableEnhancedCivicAnswers: Bool?
    
    /// Optional. Frequency penalty applied to the next token's logprobs, multiplied by the number of times each token has been seen in the respponse so far. A positive penalty will discourage the use of tokens that have already been used, proportional to the number of times the token has been used: The more a token is used, the more difficult it is for the model to use that token again increasing the vocabulary of responses. Caution: A _negative_ penalty will encourage the model to reuse tokens proportional to the number of times the token has been used. Small negative values will reduce the vocabulary of a response. Larger negative values will cause the model to start repeating a common token until it hits the max_output_tokens limit.
    public var frequencyPenalty: Double?
    
    /// Optional. Config for image generation. An error will be returned if this field is set for models that don't support these config options.
    public var imageConfig: ImageConfig?
    
    /// Optional. Only valid if response_logprobs=True. This sets the number of top logprobs, including the chosen candidate, to return at each decoding step in the Candidate.logprobs_result. The number must be in the range of [0, 20].
    public var logprobs: Int?
    
    /// Optional. The maximum number of tokens to include in a response candidate. Note: The default value varies by model, see the `Model.output_token_limit` attribute of the `Model` returned from the `getModel` function.
    public var maxOutputTokens: Int?
    
    /// Optional. If specified, the media resolution specified will be used.
    public var mediaResolution: MediaResolution?
    
    /// Optional. Presence penalty applied to the next token's logprobs if the token has already been seen in the response. This penalty is binary on/off and not dependant on the number of times the token is used (after the first). Use frequency_penalty for a penalty that increases with each use. A positive penalty will discourage the use of tokens that have already been used in the response, increasing the vocabulary. A negative penalty will encourage the use of tokens that have already been used in the response, decreasing the vocabulary.
    public var presencePenalty: Double?
    
    /// Optional. Configuration for the response output format. Allows specifying output configuration per modality (text, audio, image) in a flat structure.
    public var responseFormat: ResponseFormatConfig?
    
    /// Optional. An internal detail. Use `responseJsonSchema` rather than this field.
    public var responseJsonSchema: JSONValue?
    
    /// Optional. If true, export the logprobs results in response.
    public var responseLogprobs: Bool?
    
    /// Optional. MIME type of the generated candidate text. Supported MIME types are: `text/plain`: (default) Text output. `application/json`: JSON response in the response candidates. `text/x.enum`: ENUM as a string response in the response candidates. Refer to the [docs](https://ai.google.dev/gemini-api/docs/prompting_with_media#plain_text_formats) for a list of all supported text MIME types.
    public var responseMimeType: String?
    
    /// Optional. The requested modalities of the response. Represents the set of modalities that the model can return, and should be expected in the response. This is an exact match to the modalities of the response. A model may have multiple combinations of supported modalities. If the requested modalities do not match any of the supported combinations, an error will be returned. An empty list is equivalent to requesting only text.
    public var responseModalities: [String]?
    
    /// Optional. Output schema of the generated candidate text. Schemas must be a subset of the [OpenAPI schema](https://spec.openapis.org/oas/v3.0.3#schema) and can be objects, primitives or arrays. If set, a compatible `response_mime_type` must also be set. Compatible MIME types: `application/json`: Schema for JSON response. Refer to the [JSON text generation guide](https://ai.google.dev/gemini-api/docs/json-mode) for more details.
    public var responseSchema: Schema?
    
    /// Optional. Seed used in decoding. If not set, the request uses a randomly generated seed.
    public var seed: Int?
    
    /// Optional. The speech generation config.
    public var speechConfig: SpeechConfig?
    
    /// Optional. The set of character sequences (up to 5) that will stop output generation. If specified, the API will stop at the first appearance of a `stop_sequence`. The stop sequence will not be included as part of the response.
    public var stopSequences: [String]?
    
    /// Optional. Controls the randomness of the output. Note: The default value varies by model, see the `Model.temperature` attribute of the `Model` returned from the `getModel` function. Values can range from [0.0, 2.0].
    public var temperature: Double?
    
    /// Optional. Config for thinking features. An error will be returned if this field is set for models that don't support thinking.
    public var thinkingConfig: ThinkingConfig?
    
    /// Optional. The maximum number of tokens to consider when sampling. Gemini models use Top-p (nucleus) sampling or a combination of Top-k and nucleus sampling. Top-k sampling considers the set of `top_k` most probable tokens. Models running with nucleus sampling don't allow top_k setting. Note: The default value varies by `Model` and is specified by the`Model.top_p` attribute returned from the `getModel` function. An empty `top_k` attribute indicates that the model doesn't apply top-k sampling and doesn't allow setting `top_k` on requests.
    public var topK: Int?
    
    /// Optional. The maximum cumulative probability of tokens to consider when sampling. The model uses combined Top-k and Top-p (nucleus) sampling. Tokens are sorted based on their assigned probabilities so that only the most likely tokens are considered. Top-k sampling directly limits the maximum number of tokens to consider, while Nucleus sampling limits the number of tokens based on the cumulative probability. Note: The default value varies by `Model` and is specified by the`Model.top_p` attribute returned from the `getModel` function. An empty `top_k` attribute indicates that the model doesn't apply top-k sampling and doesn't allow setting `top_k` on requests.
    public var topP: Double?
    
    /// Optional. Config for translation.
    public var translationConfig: TranslationConfig?
    
    /// Creates a new `GenerationConfig`.
    public init(
      responsejsonschema: JSONValue? = nil,
      candidateCount: Int? = nil,
      enableAffectiveDialog: Bool? = nil,
      enableEnhancedCivicAnswers: Bool? = nil,
      frequencyPenalty: Double? = nil,
      imageConfig: ImageConfig? = nil,
      logprobs: Int? = nil,
      maxOutputTokens: Int? = nil,
      mediaResolution: MediaResolution? = nil,
      presencePenalty: Double? = nil,
      responseFormat: ResponseFormatConfig? = nil,
      responseJsonSchema: JSONValue? = nil,
      responseLogprobs: Bool? = nil,
      responseMimeType: String? = nil,
      responseModalities: [String]? = nil,
      responseSchema: Schema? = nil,
      seed: Int? = nil,
      speechConfig: SpeechConfig? = nil,
      stopSequences: [String]? = nil,
      temperature: Double? = nil,
      thinkingConfig: ThinkingConfig? = nil,
      topK: Int? = nil,
      topP: Double? = nil,
      translationConfig: TranslationConfig? = nil
    ) {
      self.responsejsonschema = responsejsonschema
      self.candidateCount = candidateCount
      self.enableAffectiveDialog = enableAffectiveDialog
      self.enableEnhancedCivicAnswers = enableEnhancedCivicAnswers
      self.frequencyPenalty = frequencyPenalty
      self.imageConfig = imageConfig
      self.logprobs = logprobs
      self.maxOutputTokens = maxOutputTokens
      self.mediaResolution = mediaResolution
      self.presencePenalty = presencePenalty
      self.responseFormat = responseFormat
      self.responseJsonSchema = responseJsonSchema
      self.responseLogprobs = responseLogprobs
      self.responseMimeType = responseMimeType
      self.responseModalities = responseModalities
      self.responseSchema = responseSchema
      self.seed = seed
      self.speechConfig = speechConfig
      self.stopSequences = stopSequences
      self.temperature = temperature
      self.thinkingConfig = thinkingConfig
      self.topK = topK
      self.topP = topP
      self.translationConfig = translationConfig
    }
    enum CodingKeys: String, CodingKey {
      case responsejsonschema = "_responseJsonSchema"
      case candidateCount = "candidateCount"
      case enableAffectiveDialog = "enableAffectiveDialog"
      case enableEnhancedCivicAnswers = "enableEnhancedCivicAnswers"
      case frequencyPenalty = "frequencyPenalty"
      case imageConfig = "imageConfig"
      case logprobs = "logprobs"
      case maxOutputTokens = "maxOutputTokens"
      case mediaResolution = "mediaResolution"
      case presencePenalty = "presencePenalty"
      case responseFormat = "responseFormat"
      case responseJsonSchema = "responseJsonSchema"
      case responseLogprobs = "responseLogprobs"
      case responseMimeType = "responseMimeType"
      case responseModalities = "responseModalities"
      case responseSchema = "responseSchema"
      case seed = "seed"
      case speechConfig = "speechConfig"
      case stopSequences = "stopSequences"
      case temperature = "temperature"
      case thinkingConfig = "thinkingConfig"
      case topK = "topK"
      case topP = "topP"
      case translationConfig = "translationConfig"
    }
  }
}