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
  /// An internal data model for `CountTokensResponse`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaCountTokensResponse`
  /// 
  /// A response from `CountTokens`.
  /// 
  /// It returns the model's `token_count` for the `prompt`.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1CountTokensResponse`
  /// 
  /// Response message for PredictionService.CountTokens.
  package struct CountTokensResponse: Codable, Sendable, Equatable, Hashable {
    /// The number of tokens that the `Model` tokenizes the `prompt` into. Always
    /// 
    /// ### Gemini Developer API
    /// 
    /// The number of tokens that the `Model` tokenizes the `prompt` into. Always
    /// non-negative.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The total number of tokens counted across all instances from the request.
    package let totalTokens: Int?
    
    /// Number of tokens in the cached part of the prompt (the cached content).
    /// 
    /// ### Gemini Developer API
    /// 
    /// Number of tokens in the cached part of the prompt (the cached content).
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let cachedContentTokenCount: Int?
    
    /// Output only. List of modalities that were processed in the request input.
    package let promptTokensDetails: [ModalityTokenCount]?
    
    /// Output only. List of modalities that were processed in the cached content.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. List of modalities that were processed in the cached content.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// > Important: This property is not supported in the Gemini Enterprise Agent Platform.
    package let cacheTokensDetails: [ModalityTokenCount]?
    
    /// The total number of billable characters counted across all instances from
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The total number of billable characters counted across all instances from
    /// the request.
    package let totalBillableCharacters: Int?
    

    /// Creates a new `CountTokensResponse`.
    ///
    /// - Parameters:
    ///   - totalTokens: The number of tokens that the `Model` tokenizes the `prompt` into. Always (behavior varies by backend). For more details, see ``totalTokens``.
    ///   - cachedContentTokenCount: Number of tokens in the cached part of the prompt (the cached content). (Gemini Developer API only). For more details, see ``cachedContentTokenCount``.
    ///   - promptTokensDetails: Output only. List of modalities that were processed in the request input.
    ///   - cacheTokensDetails: Output only. List of modalities that were processed in the cached content. (Gemini Developer API only). For more details, see ``cacheTokensDetails``.
    ///   - totalBillableCharacters: The total number of billable characters counted across all instances from (Gemini Enterprise Agent Platform only). For more details, see ``totalBillableCharacters``.
    package init(
      totalTokens: Int? = nil,
      cachedContentTokenCount: Int? = nil,
      promptTokensDetails: [ModalityTokenCount]? = nil,
      cacheTokensDetails: [ModalityTokenCount]? = nil,
      totalBillableCharacters: Int? = nil
    ) {
      self.totalTokens = totalTokens
      self.cachedContentTokenCount = cachedContentTokenCount
      self.promptTokensDetails = promptTokensDetails
      self.cacheTokensDetails = cacheTokensDetails
      self.totalBillableCharacters = totalBillableCharacters
    }
    enum CodingKeys: String, CodingKey {
      case totalTokens = "totalTokens"
      case cachedContentTokenCount = "cachedContentTokenCount"
      case promptTokensDetails = "promptTokensDetails"
      case cacheTokensDetails = "cacheTokensDetails"
      case totalBillableCharacters = "totalBillableCharacters"
    }
  }
}