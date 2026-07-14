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
package import InternalSharedDataModels


extension GeminiDataModels {
  /// Configuration options for model generation and outputs. Not all parameters are configurable for every model.
  /// 
  /// Variant:
  /// Configuration for content generation. This message contains all the parameters that control how the model generates content. It allows you to influence the randomness, length, and structure of the output.
  package struct GenerationConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. If enabled, the model will detect emotions and adapt its responses accordingly. For example, if the model detects that the user is frustrated, it may provide a more empathetic response.
    /// 
    /// > Important: `enableAffectiveDialog` is only available in the Gemini Enterprise Agent Platform.
    package let enableAffectiveDialog: Bool?
    
    /// Optional. Routing configuration.
    /// 
    /// > Important: `routingConfig` is only available in the Gemini Enterprise Agent Platform.
    package let routingConfig: GenerationConfigRoutingConfig?
    
    /// Optional. MIME type of the generated candidate text. Supported MIME types are: `text/plain`: (default) Text output. `application/json`: JSON response in the response candidates. `text/x.enum`: ENUM as a string response in the response candidates. Refer to the [docs](https://ai.google.dev/gemini-api/docs/prompting_with_media#plain_text_formats) for a list of all supported text MIME types.
    /// 
    /// Variant:
    /// Optional. The IANA standard MIME type of the response. The model will generate output that conforms to this MIME type. Supported values include 'text/plain' (default) and 'application/json'. The model needs to be prompted to output the appropriate response type, otherwise the behavior is undefined. Deprecated: Use `response_format` instead.
    package let responseMimeType: String?
    
    /// Optional. If specified, the media resolution specified will be used.
    /// 
    /// Variant:
    /// Optional. The token resolution at which input media content is sampled. This is used to control the trade-off between the quality of the response and the number of tokens used to represent the media. A higher resolution allows the model to perceive more detail, which can lead to a more nuanced response, but it will also use more tokens. This does not affect the image dimensions sent to the model.
    package let mediaResolution: MediaResolution?
    
    /// Optional. Presence penalty applied to the next token's logprobs if the token has already been seen in the response. This penalty is binary on/off and not dependant on the number of times the token is used (after the first). Use frequency_penalty for a penalty that increases with each use. A positive penalty will discourage the use of tokens that have already been used in the response, increasing the vocabulary. A negative penalty will encourage the use of tokens that have already been used in the response, decreasing the vocabulary.
    /// 
    /// Variant:
    /// Optional. Penalizes tokens that have already appeared in the generated text. A positive value encourages the model to generate more diverse and less repetitive text. Valid values can range from [-2.0, 2.0].
    package let presencePenalty: Double?
    
    /// Optional. An internal detail. Use `responseJsonSchema` rather than this field.
    /// 
    /// Variant:
    /// Optional. When this field is set, response_schema must be omitted and response_mime_type must be set to `application/json`. Deprecated: Use `response_format` instead.
    package let responseJsonSchema: JSONValue?
    
    /// Optional. Output schema of the generated candidate text. Schemas must be a subset of the [OpenAPI schema](https://spec.openapis.org/oas/v3.0.3#schema) and can be objects, primitives or arrays. If set, a compatible `response_mime_type` must also be set. Compatible MIME types: `application/json`: Schema for JSON response. Refer to the [JSON text generation guide](https://ai.google.dev/gemini-api/docs/json-mode) for more details.
    /// 
    /// Variant:
    /// Optional. Lets you to specify a schema for the model's response, ensuring that the output conforms to a particular structure. This is useful for generating structured data such as JSON. The schema is a subset of the [OpenAPI 3.0 schema object](https://spec.openapis.org/oas/v3.0.3#schema) object. When this field is set, you must also set the `response_mime_type` to `application/json`. Deprecated: Use `response_format` instead.
    package let responseSchema: Schema?
    
    /// Optional. Config for model selection.
    /// 
    /// > Important: `modelConfig` is only available in the Gemini Enterprise Agent Platform.
    @available(*, deprecated)
    package let modelConfig: GenerationConfigModelConfig?
    
    /// Optional. Configuration for the response output format. Allows specifying output configuration per modality (text, audio, image) in a flat structure.
    /// 
    /// Variant:
    /// Optional. New response format field for the model to configure output formatting and delivery.
    package let responseFormat: ResponseFormatConfig?
    
    /// Optional. Enables enhanced civic answers. It may not be available for all models.
    /// 
    /// > Important: `enableEnhancedCivicAnswers` is only available in the Gemini Developer API.
    package let enableEnhancedCivicAnswers: Bool?
    
    /// Optional. Controls the randomness of the output. Note: The default value varies by model, see the `Model.temperature` attribute of the `Model` returned from the `getModel` function. Values can range from [0.0, 2.0].
    /// 
    /// Variant:
    /// Optional. Controls the randomness of the output. A higher temperature results in more creative and diverse responses, while a lower temperature makes the output more predictable and focused. The valid range is (0.0, 2.0].
    package let temperature: Double?
    
    /// Optional. Frequency penalty applied to the next token's logprobs, multiplied by the number of times each token has been seen in the respponse so far. A positive penalty will discourage the use of tokens that have already been used, proportional to the number of times the token has been used: The more a token is used, the more difficult it is for the model to use that token again increasing the vocabulary of responses. Caution: A _negative_ penalty will encourage the model to reuse tokens proportional to the number of times the token has been used. Small negative values will reduce the vocabulary of a response. Larger negative values will cause the model to start repeating a common token until it hits the max_output_tokens limit.
    /// 
    /// Variant:
    /// Optional. Penalizes tokens based on their frequency in the generated text. A positive value helps to reduce the repetition of words and phrases. Valid values can range from [-2.0, 2.0].
    package let frequencyPenalty: Double?
    
    /// Optional. If true, export the logprobs results in response.
    /// 
    /// Variant:
    /// Optional. If set to true, the log probabilities of the output tokens are returned. Log probabilities are the logarithm of the probability of a token appearing in the output. A higher log probability means the token is more likely to be generated. This can be useful for analyzing the model's confidence in its own output and for debugging.
    package let responseLogprobs: Bool?
    
    /// Optional. If enabled, audio timestamps will be included in the request to the model. This can be useful for synchronizing audio with other modalities in the response.
    /// 
    /// > Important: `audioTimestamp` is only available in the Gemini Enterprise Agent Platform.
    package let audioTimestamp: Bool?
    
    /// Optional. The requested modalities of the response. Represents the set of modalities that the model can return, and should be expected in the response. This is an exact match to the modalities of the response. A model may have multiple combinations of supported modalities. If the requested modalities do not match any of the supported combinations, an error will be returned. An empty list is equivalent to requesting only text.
    /// 
    /// Variant:
    /// Optional. The modalities of the response. The model will generate a response that includes all the specified modalities. For example, if this is set to `[TEXT, IMAGE]`, the response will include both text and an image.
    package let responseModalities: [String]?
    
    /// Optional. Config for image generation. An error will be returned if this field is set for models that don't support these config options.
    /// 
    /// Variant:
    /// Optional. Config for image generation features. Deprecated: Use `response_format.image` instead.
    package let imageConfig: ImageConfig?
    
    /// Optional. The speech generation config.
    package let speechConfig: SpeechConfig?
    
    /// Optional. The maximum number of tokens to consider when sampling. Gemini models use Top-p (nucleus) sampling or a combination of Top-k and nucleus sampling. Top-k sampling considers the set of `top_k` most probable tokens. Models running with nucleus sampling don't allow top_k setting. Note: The default value varies by `Model` and is specified by the`Model.top_p` attribute returned from the `getModel` function. An empty `top_k` attribute indicates that the model doesn't apply top-k sampling and doesn't allow setting `top_k` on requests.
    /// 
    /// Variant:
    /// Optional. Specifies the top-k sampling threshold. The model considers only the top k most probable tokens for the next token. This can be useful for generating more coherent and less random text. For example, a `top_k` of 40 means the model will choose the next word from the 40 most likely words.
    package let topK: Int?
    
    /// Optional. Output schema of the generated response. This is an alternative to `response_schema` that accepts [JSON Schema](https://json-schema.org/). If set, `response_schema` must be omitted, but `response_mime_type` is required. While the full JSON Schema may be sent, not all features are supported. Specifically, only the following properties are supported: - `$id` - `$defs` - `$ref` - `$anchor` - `type` - `format` - `title` - `description` - `enum` (for strings and numbers) - `items` - `prefixItems` - `minItems` - `maxItems` - `minimum` - `maximum` - `anyOf` - `oneOf` (interpreted the same as `anyOf`) - `properties` - `additionalProperties` - `required` The non-standard `propertyOrdering` property may also be set. Cyclic references are unrolled to a limited degree and, as such, may only be used within non-required properties. (Nullable properties are not sufficient.) If `$ref` is set on a sub-schema, no other properties, except for than those starting as a `$`, may be set.
    /// 
    /// > Important: `_responseJsonSchema` is only available in the Gemini Developer API.
    package let responsejsonschema: JSONValue?
    
    /// Optional. The maximum cumulative probability of tokens to consider when sampling. The model uses combined Top-k and Top-p (nucleus) sampling. Tokens are sorted based on their assigned probabilities so that only the most likely tokens are considered. Top-k sampling directly limits the maximum number of tokens to consider, while Nucleus sampling limits the number of tokens based on the cumulative probability. Note: The default value varies by `Model` and is specified by the`Model.top_p` attribute returned from the `getModel` function. An empty `top_k` attribute indicates that the model doesn't apply top-k sampling and doesn't allow setting `top_k` on requests.
    /// 
    /// Variant:
    /// Optional. Specifies the nucleus sampling threshold. The model considers only the smallest set of tokens whose cumulative probability is at least `top_p`. This helps generate more diverse and less repetitive responses. For example, a `top_p` of 0.9 means the model considers tokens until the cumulative probability of the tokens to select from reaches 0.9. It's recommended to adjust either temperature or `top_p`, but not both.
    package let topP: Double?
    
    /// Optional. Seed used in decoding. If not set, the request uses a randomly generated seed.
    /// 
    /// Variant:
    /// Optional. A seed for the random number generator. By setting a seed, you can make the model's output mostly deterministic. For a given prompt and parameters (like temperature, top_p, etc.), the model will produce the same response every time. However, it's not a guaranteed absolute deterministic behavior. This is different from parameters like `temperature`, which control the *level* of randomness. `seed` ensures that the "random" choices the model makes are the same on every run, making it essential for testing and ensuring reproducible results.
    package let seed: Int?
    
    /// Optional. Only valid if response_logprobs=True. This sets the number of top logprobs, including the chosen candidate, to return at each decoding step in the Candidate.logprobs_result. The number must be in the range of [0, 20].
    /// 
    /// Variant:
    /// Optional. The number of top log probabilities to return for each token. This can be used to see which other tokens were considered likely candidates for a given position. A higher value will return more options, but it will also increase the size of the response.
    package let logprobs: Int?
    
    /// Optional. The set of character sequences (up to 5) that will stop output generation. If specified, the API will stop at the first appearance of a `stop_sequence`. The stop sequence will not be included as part of the response.
    /// 
    /// Variant:
    /// Optional. A list of character sequences that will stop the model from generating further tokens. If a stop sequence is generated, the output will end at that point. This is useful for controlling the length and structure of the output. For example, you can use ["\n", "###"] to stop generation at a new line or a specific marker.
    package let stopSequences: [String]?
    
    /// Optional. Config for translation.
    /// 
    /// > Important: `translationConfig` is only available in the Gemini Developer API.
    package let translationConfig: TranslationConfig?
    
    /// Optional. The maximum number of tokens to include in a response candidate. Note: The default value varies by model, see the `Model.output_token_limit` attribute of the `Model` returned from the `getModel` function.
    /// 
    /// Variant:
    /// Optional. The maximum number of tokens to generate in the response. A token is approximately four characters. The default value varies by model. This parameter can be used to control the length of the generated text and prevent overly long responses.
    package let maxOutputTokens: Int?
    
    /// Optional. Number of generated responses to return. If unset, this will default to 1. Please note that this doesn't work for previous generation models (Gemini 1.0 family)
    /// 
    /// Variant:
    /// Optional. The number of candidate responses to generate. A higher `candidate_count` can provide more options to choose from, but it also consumes more resources. This can be useful for generating a variety of responses and selecting the best one.
    package let candidateCount: Int?
    
    /// Optional. Config for thinking features. An error will be returned if this field is set for models that don't support thinking.
    /// 
    /// Variant:
    /// Optional. Configuration for thinking features. An error will be returned if this field is set for models that don't support thinking.
    package let thinkingConfig: ThinkingConfig?
    
    /// Creates a new `GenerationConfig`.
    package init(
      enableAffectiveDialog: Bool? = nil,
      routingConfig: GenerationConfigRoutingConfig? = nil,
      responseMimeType: String? = nil,
      mediaResolution: MediaResolution? = nil,
      presencePenalty: Double? = nil,
      responseJsonSchema: JSONValue? = nil,
      responseSchema: Schema? = nil,
      modelConfig: GenerationConfigModelConfig? = nil,
      responseFormat: ResponseFormatConfig? = nil,
      enableEnhancedCivicAnswers: Bool? = nil,
      temperature: Double? = nil,
      frequencyPenalty: Double? = nil,
      responseLogprobs: Bool? = nil,
      audioTimestamp: Bool? = nil,
      responseModalities: [String]? = nil,
      imageConfig: ImageConfig? = nil,
      speechConfig: SpeechConfig? = nil,
      topK: Int? = nil,
      responsejsonschema: JSONValue? = nil,
      topP: Double? = nil,
      seed: Int? = nil,
      logprobs: Int? = nil,
      stopSequences: [String]? = nil,
      translationConfig: TranslationConfig? = nil,
      maxOutputTokens: Int? = nil,
      candidateCount: Int? = nil,
      thinkingConfig: ThinkingConfig? = nil
    ) {
      self.enableAffectiveDialog = enableAffectiveDialog
      self.routingConfig = routingConfig
      self.responseMimeType = responseMimeType
      self.mediaResolution = mediaResolution
      self.presencePenalty = presencePenalty
      self.responseJsonSchema = responseJsonSchema
      self.responseSchema = responseSchema
      self.modelConfig = modelConfig
      self.responseFormat = responseFormat
      self.enableEnhancedCivicAnswers = enableEnhancedCivicAnswers
      self.temperature = temperature
      self.frequencyPenalty = frequencyPenalty
      self.responseLogprobs = responseLogprobs
      self.audioTimestamp = audioTimestamp
      self.responseModalities = responseModalities
      self.imageConfig = imageConfig
      self.speechConfig = speechConfig
      self.topK = topK
      self.responsejsonschema = responsejsonschema
      self.topP = topP
      self.seed = seed
      self.logprobs = logprobs
      self.stopSequences = stopSequences
      self.translationConfig = translationConfig
      self.maxOutputTokens = maxOutputTokens
      self.candidateCount = candidateCount
      self.thinkingConfig = thinkingConfig
    }
    enum CodingKeys: String, CodingKey {
      case enableAffectiveDialog = "enableAffectiveDialog"
      case routingConfig = "routingConfig"
      case responseMimeType = "responseMimeType"
      case mediaResolution = "mediaResolution"
      case presencePenalty = "presencePenalty"
      case responseJsonSchema = "responseJsonSchema"
      case responseSchema = "responseSchema"
      case modelConfig = "modelConfig"
      case responseFormat = "responseFormat"
      case enableEnhancedCivicAnswers = "enableEnhancedCivicAnswers"
      case temperature = "temperature"
      case frequencyPenalty = "frequencyPenalty"
      case responseLogprobs = "responseLogprobs"
      case audioTimestamp = "audioTimestamp"
      case responseModalities = "responseModalities"
      case imageConfig = "imageConfig"
      case speechConfig = "speechConfig"
      case topK = "topK"
      case responsejsonschema = "_responseJsonSchema"
      case topP = "topP"
      case seed = "seed"
      case logprobs = "logprobs"
      case stopSequences = "stopSequences"
      case translationConfig = "translationConfig"
      case maxOutputTokens = "maxOutputTokens"
      case candidateCount = "candidateCount"
      case thinkingConfig = "thinkingConfig"
    }
  }
}