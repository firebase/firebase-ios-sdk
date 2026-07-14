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


extension GeminiDataModels {
  /// Metadata on the generation request's token usage.
  /// 
  /// Variant:
  /// Usage metadata about the content generation request and response. This message provides a detailed breakdown of token usage and other relevant metrics.
  package struct UsageMetadata: Codable, Sendable, Equatable, Hashable {
    /// Output only. Number of tokens of thoughts for thinking models.
    /// 
    /// Variant:
    /// Output only. The number of tokens that were part of the model's generated "thoughts" output, if applicable.
    package let thoughtsTokenCount: Int?
    
    /// Output only. List of modalities that were returned in the response.
    /// 
    /// Variant:
    /// Output only. A detailed breakdown of the token count for each modality in the generated candidates.
    package let candidatesTokensDetails: [ModalityTokenCount]?
    
    /// Output only. Number of tokens present in tool-use prompt(s).
    /// 
    /// Variant:
    /// Output only. The number of tokens in the results from tool executions, which are provided back to the model as input, if applicable.
    package let toolUsePromptTokenCount: Int?
    
    /// Output only. List of modalities of the cached content in the request input.
    /// 
    /// Variant:
    /// Output only. A detailed breakdown of the token count for each modality in the cached content.
    package let cacheTokensDetails: [ModalityTokenCount]?
    
    /// Output only. List of modalities that were processed for tool-use request inputs.
    /// 
    /// Variant:
    /// Output only. A detailed breakdown by modality of the token counts from the results of tool executions, which are provided back to the model as input.
    package let toolUsePromptTokensDetails: [ModalityTokenCount]?
    
    /// Number of tokens in the cached part of the prompt (the cached content)
    /// 
    /// Variant:
    /// Output only. The number of tokens in the cached content that was used for this request.
    package let cachedContentTokenCount: Int?
    
    /// Output only. The traffic type for this request.
    /// 
    /// > Important: `trafficType` is only available in the Gemini Enterprise Agent Platform.
    package let trafficType: TrafficType?
    
    /// Number of tokens in the prompt. When `cached_content` is set, this is still the total effective prompt size meaning this includes the number of tokens in the cached content.
    /// 
    /// Variant:
    /// The total number of tokens in the prompt. This includes any text, images, or other media provided in the request. When `cached_content` is set, this also includes the number of tokens in the cached content.
    package let promptTokenCount: Int?
    
    /// Output only. List of modalities that were processed in the request input.
    /// 
    /// Variant:
    /// Output only. A detailed breakdown of the token count for each modality in the prompt.
    package let promptTokensDetails: [ModalityTokenCount]?
    
    /// Total number of tokens across all the generated response candidates.
    /// 
    /// Variant:
    /// The total number of tokens in the generated candidates.
    package let candidatesTokenCount: Int?
    
    /// Total token count for the generation request (prompt + thoughts + response candidates).
    /// 
    /// Variant:
    /// The total number of tokens for the entire request. This is the sum of `prompt_token_count`, `candidates_token_count`, `tool_use_prompt_token_count`, and `thoughts_token_count`.
    package let totalTokenCount: Int?
    
    /// Output only. Service tier of the request.
    /// 
    /// > Important: `serviceTier` is only available in the Gemini Developer API.
    package let serviceTier: ServiceTier?
    
    /// Creates a new `UsageMetadata`.
    package init(
      thoughtsTokenCount: Int? = nil,
      candidatesTokensDetails: [ModalityTokenCount]? = nil,
      toolUsePromptTokenCount: Int? = nil,
      cacheTokensDetails: [ModalityTokenCount]? = nil,
      toolUsePromptTokensDetails: [ModalityTokenCount]? = nil,
      cachedContentTokenCount: Int? = nil,
      trafficType: TrafficType? = nil,
      promptTokenCount: Int? = nil,
      promptTokensDetails: [ModalityTokenCount]? = nil,
      candidatesTokenCount: Int? = nil,
      totalTokenCount: Int? = nil,
      serviceTier: ServiceTier? = nil
    ) {
      self.thoughtsTokenCount = thoughtsTokenCount
      self.candidatesTokensDetails = candidatesTokensDetails
      self.toolUsePromptTokenCount = toolUsePromptTokenCount
      self.cacheTokensDetails = cacheTokensDetails
      self.toolUsePromptTokensDetails = toolUsePromptTokensDetails
      self.cachedContentTokenCount = cachedContentTokenCount
      self.trafficType = trafficType
      self.promptTokenCount = promptTokenCount
      self.promptTokensDetails = promptTokensDetails
      self.candidatesTokenCount = candidatesTokenCount
      self.totalTokenCount = totalTokenCount
      self.serviceTier = serviceTier
    }
    enum CodingKeys: String, CodingKey {
      case thoughtsTokenCount = "thoughtsTokenCount"
      case candidatesTokensDetails = "candidatesTokensDetails"
      case toolUsePromptTokenCount = "toolUsePromptTokenCount"
      case cacheTokensDetails = "cacheTokensDetails"
      case toolUsePromptTokensDetails = "toolUsePromptTokensDetails"
      case cachedContentTokenCount = "cachedContentTokenCount"
      case trafficType = "trafficType"
      case promptTokenCount = "promptTokenCount"
      case promptTokensDetails = "promptTokensDetails"
      case candidatesTokenCount = "candidatesTokenCount"
      case totalTokenCount = "totalTokenCount"
      case serviceTier = "serviceTier"
    }
  }
}