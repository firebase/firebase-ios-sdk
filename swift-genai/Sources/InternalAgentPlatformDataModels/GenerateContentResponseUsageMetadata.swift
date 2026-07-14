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


extension AgentPlatform {
  /// Usage metadata about the content generation request and response. This message provides a detailed breakdown of token usage and other relevant metrics.
  public struct GenerateContentResponseUsageMetadata: Codable, Sendable, Equatable, Hashable {
    /// Output only. A detailed breakdown of the token count for each modality in the cached content.
    public var cacheTokensDetails: [ModalityTokenCount]?
    
    /// Output only. The number of tokens in the cached content that was used for this request.
    public var cachedContentTokenCount: Int?
    
    /// The total number of tokens in the generated candidates.
    public var candidatesTokenCount: Int?
    
    /// Output only. A detailed breakdown of the token count for each modality in the generated candidates.
    public var candidatesTokensDetails: [ModalityTokenCount]?
    
    /// The total number of tokens in the prompt. This includes any text, images, or other media provided in the request. When `cached_content` is set, this also includes the number of tokens in the cached content.
    public var promptTokenCount: Int?
    
    /// Output only. A detailed breakdown of the token count for each modality in the prompt.
    public var promptTokensDetails: [ModalityTokenCount]?
    
    /// Output only. The number of tokens that were part of the model's generated "thoughts" output, if applicable.
    public var thoughtsTokenCount: Int?
    
    /// Output only. The number of tokens in the results from tool executions, which are provided back to the model as input, if applicable.
    public var toolUsePromptTokenCount: Int?
    
    /// Output only. A detailed breakdown by modality of the token counts from the results of tool executions, which are provided back to the model as input.
    public var toolUsePromptTokensDetails: [ModalityTokenCount]?
    
    /// The total number of tokens for the entire request. This is the sum of `prompt_token_count`, `candidates_token_count`, `tool_use_prompt_token_count`, and `thoughts_token_count`.
    public var totalTokenCount: Int?
    
    /// Output only. The traffic type for this request.
    public var trafficType: TrafficType?
    
    /// Creates a new `GenerateContentResponseUsageMetadata`.
    public init(
      cacheTokensDetails: [ModalityTokenCount]? = nil,
      cachedContentTokenCount: Int? = nil,
      candidatesTokenCount: Int? = nil,
      candidatesTokensDetails: [ModalityTokenCount]? = nil,
      promptTokenCount: Int? = nil,
      promptTokensDetails: [ModalityTokenCount]? = nil,
      thoughtsTokenCount: Int? = nil,
      toolUsePromptTokenCount: Int? = nil,
      toolUsePromptTokensDetails: [ModalityTokenCount]? = nil,
      totalTokenCount: Int? = nil,
      trafficType: TrafficType? = nil
    ) {
      self.cacheTokensDetails = cacheTokensDetails
      self.cachedContentTokenCount = cachedContentTokenCount
      self.candidatesTokenCount = candidatesTokenCount
      self.candidatesTokensDetails = candidatesTokensDetails
      self.promptTokenCount = promptTokenCount
      self.promptTokensDetails = promptTokensDetails
      self.thoughtsTokenCount = thoughtsTokenCount
      self.toolUsePromptTokenCount = toolUsePromptTokenCount
      self.toolUsePromptTokensDetails = toolUsePromptTokensDetails
      self.totalTokenCount = totalTokenCount
      self.trafficType = trafficType
    }
    enum CodingKeys: String, CodingKey {
      case cacheTokensDetails = "cacheTokensDetails"
      case cachedContentTokenCount = "cachedContentTokenCount"
      case candidatesTokenCount = "candidatesTokenCount"
      case candidatesTokensDetails = "candidatesTokensDetails"
      case promptTokenCount = "promptTokenCount"
      case promptTokensDetails = "promptTokensDetails"
      case thoughtsTokenCount = "thoughtsTokenCount"
      case toolUsePromptTokenCount = "toolUsePromptTokenCount"
      case toolUsePromptTokensDetails = "toolUsePromptTokensDetails"
      case totalTokenCount = "totalTokenCount"
      case trafficType = "trafficType"
    }
  }
}