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

extension GoogleAI {
  /// Metadata on the generation request's token usage.
  package struct UsageMetadata: Codable, Sendable, Equatable, Hashable {
    /// Output only. List of modalities of the cached content in the request input.
    package var cacheTokensDetails: [ModalityTokenCount]?
    
    /// Number of tokens in the cached part of the prompt (the cached content)
    package var cachedContentTokenCount: Int?
    
    /// Total number of tokens across all the generated response candidates.
    package var candidatesTokenCount: Int?
    
    /// Output only. List of modalities that were returned in the response.
    package var candidatesTokensDetails: [ModalityTokenCount]?
    
    /// Number of tokens in the prompt. When `cached_content` is set, this is still the total effective prompt size meaning this includes the number of tokens in the cached content.
    package var promptTokenCount: Int?
    
    /// Output only. List of modalities that were processed in the request input.
    package var promptTokensDetails: [ModalityTokenCount]?
    
    /// Output only. Service tier of the request.
    package var serviceTier: ServiceTier?
    
    /// Output only. Number of tokens of thoughts for thinking models.
    package var thoughtsTokenCount: Int?
    
    /// Output only. Number of tokens present in tool-use prompt(s).
    package var toolUsePromptTokenCount: Int?
    
    /// Output only. List of modalities that were processed for tool-use request inputs.
    package var toolUsePromptTokensDetails: [ModalityTokenCount]?
    
    /// Total token count for the generation request (prompt + thoughts + response candidates).
    package var totalTokenCount: Int?
    
    /// Creates a new `UsageMetadata`.
    package init(
      cacheTokensDetails: [ModalityTokenCount]? = nil,
      cachedContentTokenCount: Int? = nil,
      candidatesTokenCount: Int? = nil,
      candidatesTokensDetails: [ModalityTokenCount]? = nil,
      promptTokenCount: Int? = nil,
      promptTokensDetails: [ModalityTokenCount]? = nil,
      serviceTier: ServiceTier? = nil,
      thoughtsTokenCount: Int? = nil,
      toolUsePromptTokenCount: Int? = nil,
      toolUsePromptTokensDetails: [ModalityTokenCount]? = nil,
      totalTokenCount: Int? = nil
    ) {
      self.cacheTokensDetails = cacheTokensDetails
      self.cachedContentTokenCount = cachedContentTokenCount
      self.candidatesTokenCount = candidatesTokenCount
      self.candidatesTokensDetails = candidatesTokensDetails
      self.promptTokenCount = promptTokenCount
      self.promptTokensDetails = promptTokensDetails
      self.serviceTier = serviceTier
      self.thoughtsTokenCount = thoughtsTokenCount
      self.toolUsePromptTokenCount = toolUsePromptTokenCount
      self.toolUsePromptTokensDetails = toolUsePromptTokensDetails
      self.totalTokenCount = totalTokenCount
    }
    enum CodingKeys: String, CodingKey {
      case cacheTokensDetails = "cacheTokensDetails"
      case cachedContentTokenCount = "cachedContentTokenCount"
      case candidatesTokenCount = "candidatesTokenCount"
      case candidatesTokensDetails = "candidatesTokensDetails"
      case promptTokenCount = "promptTokenCount"
      case promptTokensDetails = "promptTokensDetails"
      case serviceTier = "serviceTier"
      case thoughtsTokenCount = "thoughtsTokenCount"
      case toolUsePromptTokenCount = "toolUsePromptTokenCount"
      case toolUsePromptTokensDetails = "toolUsePromptTokensDetails"
      case totalTokenCount = "totalTokenCount"
    }
  }
}