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
package import InternalGoogleAIDataModels
package import InternalAgentPlatformDataModels

// MARK: - GenerationConfig

/// Configuration options for model generation and outputs.
public struct GenerationConfig: Codable, Sendable, Equatable, Hashable {
  /// Optional. Number of generated responses to return.
  public var candidateCount: Int?

  /// Optional. If enabled, the model will detect emotions and adapt its responses accordingly.
  public var enableAffectiveDialog: Bool?

  /// Optional. Frequency penalty applied to the next token's logprobs.
  public var frequencyPenalty: Double?

  /// Optional. The maximum number of tokens to include in a response candidate.
  public var maxOutputTokens: Int?

  /// Optional. If specified, the media resolution specified will be used.
  public var mediaResolution: MediaResolution?

  /// Optional. Presence penalty applied to the next token's logprobs if the token has already been seen.
  public var presencePenalty: Double?

  /// Optional. Configuration for the response output format.
  public var responseFormat: [ResponseFormat]?

  /// Optional. MIME type of the generated candidate text.
  /// - Note: Only supported on GoogleAI backend. Excluded on AgentPlatform.
  public var responseMimeType: String?

  /// Optional. Schema for the model's response.
  /// - Note: Only supported on GoogleAI backend. Excluded on AgentPlatform.
  package var responseSchema: InternalGoogleAIDataModels.GoogleAI.Schema?

  /// Optional. The requested modalities of the response.
  public var responseModalities: [String]?

  /// Optional. Seed used in decoding.
  public var seed: Int?

  /// Optional. Controls the randomness of the output.
  public var temperature: Double?

  /// Optional. Config for thinking features.
  public var thinkingConfig: ThinkingConfig?

  /// Optional. The maximum number of tokens to consider when sampling.
  public var topK: Double?

  /// Optional. The maximum cumulative probability of tokens to consider when sampling.
  public var topP: Double?

  /// Optional. This sets the number of top logprobs to return.
  public var logprobs: Int?

  /// Optional. The set of character sequences that will stop translation.
  public var stopSequences: [String]?

  /// Optional. If enabled, audio timestamps will be included in the request to the model.
  /// - Note: Only supported on AgentPlatform backend.
  public var audioTimestamp: Bool?

  public init(
    candidateCount: Int? = nil,
    enableAffectiveDialog: Bool? = nil,
    frequencyPenalty: Double? = nil,
    logprobs: Int? = nil,
    maxOutputTokens: Int? = nil,
    mediaResolution: MediaResolution? = nil,
    presencePenalty: Double? = nil,
    responseFormat: [ResponseFormat]? = nil,
    responseMimeType: String? = nil,
    responseModalities: [String]? = nil,
    seed: Int? = nil,
    stopSequences: [String]? = nil,
    temperature: Double? = nil,
    thinkingConfig: ThinkingConfig? = nil,
    topK: Double? = nil,
    topP: Double? = nil,
    audioTimestamp: Bool? = nil
  ) {
    self.candidateCount = candidateCount
    self.enableAffectiveDialog = enableAffectiveDialog
    self.frequencyPenalty = frequencyPenalty
    self.logprobs = logprobs
    self.maxOutputTokens = maxOutputTokens
    self.mediaResolution = mediaResolution
    self.presencePenalty = presencePenalty
    self.responseFormat = responseFormat
    self.responseMimeType = responseMimeType
    self.responseSchema = nil
    self.responseModalities = responseModalities
    self.seed = seed
    self.stopSequences = stopSequences
    self.temperature = temperature
    self.thinkingConfig = thinkingConfig
    self.topK = topK
    self.topP = topP
    self.audioTimestamp = audioTimestamp
  }

  package init(
    candidateCount: Int? = nil,
    enableAffectiveDialog: Bool? = nil,
    frequencyPenalty: Double? = nil,
    logprobs: Int? = nil,
    maxOutputTokens: Int? = nil,
    mediaResolution: MediaResolution? = nil,
    presencePenalty: Double? = nil,
    responseFormat: [ResponseFormat]? = nil,
    responseMimeType: String? = nil,
    responseSchema: InternalGoogleAIDataModels.GoogleAI.Schema? = nil,
    responseModalities: [String]? = nil,
    seed: Int? = nil,
    stopSequences: [String]? = nil,
    temperature: Double? = nil,
    thinkingConfig: ThinkingConfig? = nil,
    topK: Double? = nil,
    topP: Double? = nil,
    audioTimestamp: Bool? = nil
  ) {
    self.candidateCount = candidateCount
    self.enableAffectiveDialog = enableAffectiveDialog
    self.frequencyPenalty = frequencyPenalty
    self.logprobs = logprobs
    self.maxOutputTokens = maxOutputTokens
    self.mediaResolution = mediaResolution
    self.presencePenalty = presencePenalty
    self.responseFormat = responseFormat
    self.responseMimeType = responseMimeType
    self.responseSchema = responseSchema
    self.responseModalities = responseModalities
    self.seed = seed
    self.stopSequences = stopSequences
    self.temperature = temperature
    self.thinkingConfig = thinkingConfig
    self.topK = topK
    self.topP = topP
    self.audioTimestamp = audioTimestamp
  }
}

// MARK: - GoogleAI Mappings

extension GenerationConfig {
  package func toGoogleAI() -> GoogleAI.GenerationConfig {
    GoogleAI.GenerationConfig(
      candidateCount: candidateCount,
      enableAffectiveDialog: enableAffectiveDialog,
      frequencyPenalty: frequencyPenalty,
      logprobs: logprobs,
      maxOutputTokens: maxOutputTokens,
      mediaResolution: mediaResolution?.toGoogleAI(),
      presencePenalty: presencePenalty,
      responseFormat: responseFormat?.first?.toGoogleAI(),
      responseMimeType: responseMimeType,
      responseModalities: responseModalities,
      responseSchema: responseSchema,
      seed: seed,
      stopSequences: stopSequences,
      temperature: temperature,
      thinkingConfig: thinkingConfig?.toGoogleAI(),
      topK: topK.map { Int($0) },
      topP: topP
    )
  }

  package init(fromGoogleAI config: GoogleAI.GenerationConfig) {
    self.candidateCount = config.candidateCount
    self.enableAffectiveDialog = config.enableAffectiveDialog
    self.frequencyPenalty = config.frequencyPenalty
    self.logprobs = config.logprobs
    self.maxOutputTokens = config.maxOutputTokens
    self.mediaResolution = config.mediaResolution.map { MediaResolution(fromGoogleAI: $0) }
    self.presencePenalty = config.presencePenalty
    self.responseFormat = config.responseFormat.map { [ResponseFormat(fromGoogleAI: $0)] }
    self.responseMimeType = config.responseMimeType
    self.responseSchema = config.responseSchema
    self.responseModalities = config.responseModalities
    self.seed = config.seed
    self.stopSequences = config.stopSequences
    self.temperature = config.temperature
    self.thinkingConfig = config.thinkingConfig.map { ThinkingConfig(fromGoogleAI: $0) }
    self.topK = config.topK.map { Double($0) }
    self.topP = config.topP
    self.audioTimestamp = nil
  }
}

// MARK: - AgentPlatform Mappings

extension GenerationConfig {
  package func toAgentPlatform() -> AgentPlatform.GenerationConfig {
    AgentPlatform.GenerationConfig(
      audioTimestamp: audioTimestamp,
      candidateCount: candidateCount,
      enableAffectiveDialog: enableAffectiveDialog,
      frequencyPenalty: frequencyPenalty,
      maxOutputTokens: maxOutputTokens,
      mediaResolution: mediaResolution?.toAgentPlatformMediaResolution(),
      presencePenalty: presencePenalty,
      responseFormat: responseFormat?.map { $0.toAgentPlatform() },
      responseModalities: responseModalities,
      seed: seed,
      temperature: temperature,
      thinkingConfig: thinkingConfig?.toAgentPlatform(),
      topK: topK,
      topP: topP
    )
  }

  package init(fromAgentPlatform config: AgentPlatform.GenerationConfig) {
    self.candidateCount = config.candidateCount
    self.enableAffectiveDialog = config.enableAffectiveDialog
    self.frequencyPenalty = config.frequencyPenalty
    self.logprobs = nil
    self.maxOutputTokens = config.maxOutputTokens
    self.mediaResolution = config.mediaResolution.map { MediaResolution(fromAgentPlatform: $0) }
    self.presencePenalty = config.presencePenalty
    self.responseFormat = config.responseFormat?.map { ResponseFormat(fromAgentPlatform: $0) }
    self.responseMimeType = nil
    self.responseSchema = nil
    self.responseModalities = config.responseModalities
    self.seed = config.seed
    self.stopSequences = nil
    self.temperature = config.temperature
    self.thinkingConfig = config.thinkingConfig.map { ThinkingConfig(fromAgentPlatform: $0) }
    self.topK = config.topK
    self.topP = config.topP
    self.audioTimestamp = config.audioTimestamp
  }
}
