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
  /// An internal data model for `UsageMetadata`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGenerateContentResponseUsageMetadata`
  /// 
  /// Metadata on the generation request's token usage.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GenerateContentResponseUsageMetadata`
  /// 
  /// Usage metadata about the content generation request and response.
  /// This message provides a detailed breakdown of token usage and other
  /// relevant metrics.
  package struct UsageMetadata: Codable, Sendable, Equatable, Hashable {
    /// Number of tokens in the prompt. When `cached_content` is set, this is
    /// 
    /// ### Gemini Developer API
    /// 
    /// Number of tokens in the prompt. When `cached_content` is set, this is
    /// still the total effective prompt size meaning this includes the number of
    /// tokens in the cached content.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The total number of tokens in the prompt. This includes any text, images,
    /// or other media provided in the request. When `cached_content` is set,
    /// this also includes the number of tokens in the cached content.
    package let promptTokenCount: Int?
    
    /// Number of tokens in the cached part of the prompt (the cached content)
    /// 
    /// ### Gemini Developer API
    /// 
    /// Number of tokens in the cached part of the prompt (the cached content)
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The number of tokens in the cached content that was used for this
    /// request.
    package let cachedContentTokenCount: Int?
    
    /// Total number of tokens across all the generated response candidates.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Total number of tokens across all the generated response candidates.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The total number of tokens in the generated candidates.
    package let candidatesTokenCount: Int?
    
    /// Output only. Number of tokens present in tool-use prompt(s).
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Number of tokens present in tool-use prompt(s).
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The number of tokens in the results from tool executions, which are
    /// provided back to the model as input, if applicable.
    package let toolUsePromptTokenCount: Int?
    
    /// Output only. Number of tokens of thoughts for thinking models.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Number of tokens of thoughts for thinking models.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The number of tokens that were part of the model's generated "thoughts"
    /// output, if applicable.
    package let thoughtsTokenCount: Int?
    
    /// Total token count for the generation request (prompt + thoughts +
    /// 
    /// ### Gemini Developer API
    /// 
    /// Total token count for the generation request (prompt + thoughts +
    /// response candidates).
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The total number of tokens for the entire request. This is the sum of
    /// `prompt_token_count`, `candidates_token_count`,
    /// `tool_use_prompt_token_count`, and `thoughts_token_count`.
    package let totalTokenCount: Int?
    
    /// Output only. List of modalities that were processed in the request input.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. List of modalities that were processed in the request input.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A detailed breakdown of the token count for each modality in the prompt.
    package let promptTokensDetails: [ModalityTokenCount]?
    
    /// Output only. List of modalities of the cached content in the request input.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. List of modalities of the cached content in the request input.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A detailed breakdown of the token count for each modality in the cached
    /// content.
    package let cacheTokensDetails: [ModalityTokenCount]?
    
    /// Output only. List of modalities that were returned in the response.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. List of modalities that were returned in the response.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A detailed breakdown of the token count for each modality in the
    /// generated candidates.
    package let candidatesTokensDetails: [ModalityTokenCount]?
    
    /// Output only. List of modalities that were processed for tool-use request inputs.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. List of modalities that were processed for tool-use request inputs.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. A detailed breakdown by modality of the token counts from the results
    /// of tool executions, which are provided back to the model as input.
    package let toolUsePromptTokensDetails: [ModalityTokenCount]?
    
    /// Output only. Service tier of the request.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Service tier of the request.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let serviceTier: ServiceTier?
    
    /// Output only. The traffic type for this request.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Output only. The traffic type for this request.
    package let trafficType: TrafficType?
    

    /// Creates a new `UsageMetadata`.
    ///
    /// - Parameters:
    ///   - promptTokenCount: Number of tokens in the prompt. When `cached_content` is set, this is (behavior varies by backend). For more details, see ``promptTokenCount``.
    ///   - cachedContentTokenCount: Number of tokens in the cached part of the prompt (the cached content) (behavior varies by backend). For more details, see ``cachedContentTokenCount``.
    ///   - candidatesTokenCount: Total number of tokens across all the generated response candidates. (behavior varies by backend). For more details, see ``candidatesTokenCount``.
    ///   - toolUsePromptTokenCount: Output only. Number of tokens present in tool-use prompt(s). (behavior varies by backend). For more details, see ``toolUsePromptTokenCount``.
    ///   - thoughtsTokenCount: Output only. Number of tokens of thoughts for thinking models. (behavior varies by backend). For more details, see ``thoughtsTokenCount``.
    ///   - totalTokenCount: Total token count for the generation request (prompt + thoughts + (behavior varies by backend). For more details, see ``totalTokenCount``.
    ///   - promptTokensDetails: Output only. List of modalities that were processed in the request input. (behavior varies by backend). For more details, see ``promptTokensDetails``.
    ///   - cacheTokensDetails: Output only. List of modalities of the cached content in the request input. (behavior varies by backend). For more details, see ``cacheTokensDetails``.
    ///   - candidatesTokensDetails: Output only. List of modalities that were returned in the response. (behavior varies by backend). For more details, see ``candidatesTokensDetails``.
    ///   - toolUsePromptTokensDetails: Output only. List of modalities that were processed for tool-use request inputs. (behavior varies by backend). For more details, see ``toolUsePromptTokensDetails``.
    ///   - serviceTier: Output only. Service tier of the request. (Gemini Developer API only). For more details, see ``serviceTier``.
    ///   - trafficType: Output only. The traffic type for this request. (Gemini Enterprise Agent Platform only). For more details, see ``trafficType``.
    package init(
      promptTokenCount: Int? = nil,
      cachedContentTokenCount: Int? = nil,
      candidatesTokenCount: Int? = nil,
      toolUsePromptTokenCount: Int? = nil,
      thoughtsTokenCount: Int? = nil,
      totalTokenCount: Int? = nil,
      promptTokensDetails: [ModalityTokenCount]? = nil,
      cacheTokensDetails: [ModalityTokenCount]? = nil,
      candidatesTokensDetails: [ModalityTokenCount]? = nil,
      toolUsePromptTokensDetails: [ModalityTokenCount]? = nil,
      serviceTier: ServiceTier? = nil,
      trafficType: TrafficType? = nil
    ) {
      self.promptTokenCount = promptTokenCount
      self.cachedContentTokenCount = cachedContentTokenCount
      self.candidatesTokenCount = candidatesTokenCount
      self.toolUsePromptTokenCount = toolUsePromptTokenCount
      self.thoughtsTokenCount = thoughtsTokenCount
      self.totalTokenCount = totalTokenCount
      self.promptTokensDetails = promptTokensDetails
      self.cacheTokensDetails = cacheTokensDetails
      self.candidatesTokensDetails = candidatesTokensDetails
      self.toolUsePromptTokensDetails = toolUsePromptTokensDetails
      self.serviceTier = serviceTier
      self.trafficType = trafficType
    }
    enum CodingKeys: String, CodingKey {
      case promptTokenCount = "promptTokenCount"
      case cachedContentTokenCount = "cachedContentTokenCount"
      case candidatesTokenCount = "candidatesTokenCount"
      case toolUsePromptTokenCount = "toolUsePromptTokenCount"
      case thoughtsTokenCount = "thoughtsTokenCount"
      case totalTokenCount = "totalTokenCount"
      case promptTokensDetails = "promptTokensDetails"
      case cacheTokensDetails = "cacheTokensDetails"
      case candidatesTokensDetails = "candidatesTokensDetails"
      case toolUsePromptTokensDetails = "toolUsePromptTokensDetails"
      case serviceTier = "serviceTier"
      case trafficType = "trafficType"
    }
  }
}