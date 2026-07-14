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


extension AgentPlatform {
  /// Configuration for content generation. This message contains all the parameters that control how the model generates content. It allows you to influence the randomness, length, and structure of the output.
  public struct GenerationConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. If enabled, audio timestamps will be included in the request to the model. This can be useful for synchronizing audio with other modalities in the response.
    public var audioTimestamp: Bool?
    
    /// Optional. The number of candidate responses to generate. A higher `candidate_count` can provide more options to choose from, but it also consumes more resources. This can be useful for generating a variety of responses and selecting the best one.
    public var candidateCount: Int?
    
    /// Optional. If enabled, the model will detect emotions and adapt its responses accordingly. For example, if the model detects that the user is frustrated, it may provide a more empathetic response.
    public var enableAffectiveDialog: Bool?
    
    /// Optional. Penalizes tokens based on their frequency in the generated text. A positive value helps to reduce the repetition of words and phrases. Valid values can range from [-2.0, 2.0].
    public var frequencyPenalty: Double?
    
    /// Optional. Config for image generation features. Deprecated: Use `response_format.image` instead.
    @available(*, deprecated)
    public var imageConfig: ImageConfig?
    
    /// Optional. The number of top log probabilities to return for each token. This can be used to see which other tokens were considered likely candidates for a given position. A higher value will return more options, but it will also increase the size of the response.
    public var logprobs: Int?
    
    /// Optional. The maximum number of tokens to generate in the response. A token is approximately four characters. The default value varies by model. This parameter can be used to control the length of the generated text and prevent overly long responses.
    public var maxOutputTokens: Int?
    
    /// Optional. The token resolution at which input media content is sampled. This is used to control the trade-off between the quality of the response and the number of tokens used to represent the media. A higher resolution allows the model to perceive more detail, which can lead to a more nuanced response, but it will also use more tokens. This does not affect the image dimensions sent to the model.
    public var mediaResolution: MediaResolution?
    
    /// Optional. Config for model selection.
    @available(*, deprecated)
    public var modelConfig: GenerationConfigModelConfig?
    
    /// Optional. Penalizes tokens that have already appeared in the generated text. A positive value encourages the model to generate more diverse and less repetitive text. Valid values can range from [-2.0, 2.0].
    public var presencePenalty: Double?
    
    /// Optional. New response format field for the model to configure output formatting and delivery.
    public var responseFormat: [ResponseFormat]?
    
    /// Optional. When this field is set, response_schema must be omitted and response_mime_type must be set to `application/json`. Deprecated: Use `response_format` instead.
    @available(*, deprecated)
    public var responseJsonSchema: JSONValue?
    
    /// Optional. If set to true, the log probabilities of the output tokens are returned. Log probabilities are the logarithm of the probability of a token appearing in the output. A higher log probability means the token is more likely to be generated. This can be useful for analyzing the model's confidence in its own output and for debugging.
    public var responseLogprobs: Bool?
    
    /// Optional. The IANA standard MIME type of the response. The model will generate output that conforms to this MIME type. Supported values include 'text/plain' (default) and 'application/json'. The model needs to be prompted to output the appropriate response type, otherwise the behavior is undefined. Deprecated: Use `response_format` instead.
    @available(*, deprecated)
    public var responseMimeType: String?
    
    /// Optional. The modalities of the response. The model will generate a response that includes all the specified modalities. For example, if this is set to `[TEXT, IMAGE]`, the response will include both text and an image.
    public var responseModalities: [String]?
    
    /// Optional. Lets you to specify a schema for the model's response, ensuring that the output conforms to a particular structure. This is useful for generating structured data such as JSON. The schema is a subset of the [OpenAPI 3.0 schema object](https://spec.openapis.org/oas/v3.0.3#schema) object. When this field is set, you must also set the `response_mime_type` to `application/json`. Deprecated: Use `response_format` instead.
    @available(*, deprecated)
    public var responseSchema: Schema?
    
    /// Optional. Routing configuration.
    public var routingConfig: GenerationConfigRoutingConfig?
    
    /// Optional. A seed for the random number generator. By setting a seed, you can make the model's output mostly deterministic. For a given prompt and parameters (like temperature, top_p, etc.), the model will produce the same response every time. However, it's not a guaranteed absolute deterministic behavior. This is different from parameters like `temperature`, which control the *level* of randomness. `seed` ensures that the "random" choices the model makes are the same on every run, making it essential for testing and ensuring reproducible results.
    public var seed: Int?
    
    /// Optional. The speech generation config.
    public var speechConfig: SpeechConfig?
    
    /// Optional. A list of character sequences that will stop the model from generating further tokens. If a stop sequence is generated, the output will end at that point. This is useful for controlling the length and structure of the output. For example, you can use ["\n", "###"] to stop generation at a new line or a specific marker.
    public var stopSequences: [String]?
    
    /// Optional. Controls the randomness of the output. A higher temperature results in more creative and diverse responses, while a lower temperature makes the output more predictable and focused. The valid range is (0.0, 2.0].
    public var temperature: Double?
    
    /// Optional. Configuration for thinking features. An error will be returned if this field is set for models that don't support thinking.
    public var thinkingConfig: GenerationConfigThinkingConfig?
    
    /// Optional. Specifies the top-k sampling threshold. The model considers only the top k most probable tokens for the next token. This can be useful for generating more coherent and less random text. For example, a `top_k` of 40 means the model will choose the next word from the 40 most likely words.
    public var topK: Double?
    
    /// Optional. Specifies the nucleus sampling threshold. The model considers only the smallest set of tokens whose cumulative probability is at least `top_p`. This helps generate more diverse and less repetitive responses. For example, a `top_p` of 0.9 means the model considers tokens until the cumulative probability of the tokens to select from reaches 0.9. It's recommended to adjust either temperature or `top_p`, but not both.
    public var topP: Double?
    
    /// Creates a new `GenerationConfig`.
    public init(
      audioTimestamp: Bool? = nil,
      candidateCount: Int? = nil,
      enableAffectiveDialog: Bool? = nil,
      frequencyPenalty: Double? = nil,
      imageConfig: ImageConfig? = nil,
      logprobs: Int? = nil,
      maxOutputTokens: Int? = nil,
      mediaResolution: MediaResolution? = nil,
      modelConfig: GenerationConfigModelConfig? = nil,
      presencePenalty: Double? = nil,
      responseFormat: [ResponseFormat]? = nil,
      responseJsonSchema: JSONValue? = nil,
      responseLogprobs: Bool? = nil,
      responseMimeType: String? = nil,
      responseModalities: [String]? = nil,
      responseSchema: Schema? = nil,
      routingConfig: GenerationConfigRoutingConfig? = nil,
      seed: Int? = nil,
      speechConfig: SpeechConfig? = nil,
      stopSequences: [String]? = nil,
      temperature: Double? = nil,
      thinkingConfig: GenerationConfigThinkingConfig? = nil,
      topK: Double? = nil,
      topP: Double? = nil
    ) {
      self.audioTimestamp = audioTimestamp
      self.candidateCount = candidateCount
      self.enableAffectiveDialog = enableAffectiveDialog
      self.frequencyPenalty = frequencyPenalty
      self.imageConfig = imageConfig
      self.logprobs = logprobs
      self.maxOutputTokens = maxOutputTokens
      self.mediaResolution = mediaResolution
      self.modelConfig = modelConfig
      self.presencePenalty = presencePenalty
      self.responseFormat = responseFormat
      self.responseJsonSchema = responseJsonSchema
      self.responseLogprobs = responseLogprobs
      self.responseMimeType = responseMimeType
      self.responseModalities = responseModalities
      self.responseSchema = responseSchema
      self.routingConfig = routingConfig
      self.seed = seed
      self.speechConfig = speechConfig
      self.stopSequences = stopSequences
      self.temperature = temperature
      self.thinkingConfig = thinkingConfig
      self.topK = topK
      self.topP = topP
    }
    enum CodingKeys: String, CodingKey {
      case audioTimestamp = "audioTimestamp"
      case candidateCount = "candidateCount"
      case enableAffectiveDialog = "enableAffectiveDialog"
      case frequencyPenalty = "frequencyPenalty"
      case imageConfig = "imageConfig"
      case logprobs = "logprobs"
      case maxOutputTokens = "maxOutputTokens"
      case mediaResolution = "mediaResolution"
      case modelConfig = "modelConfig"
      case presencePenalty = "presencePenalty"
      case responseFormat = "responseFormat"
      case responseJsonSchema = "responseJsonSchema"
      case responseLogprobs = "responseLogprobs"
      case responseMimeType = "responseMimeType"
      case responseModalities = "responseModalities"
      case responseSchema = "responseSchema"
      case routingConfig = "routingConfig"
      case seed = "seed"
      case speechConfig = "speechConfig"
      case stopSequences = "stopSequences"
      case temperature = "temperature"
      case thinkingConfig = "thinkingConfig"
      case topK = "topK"
      case topP = "topP"
    }
  }
}