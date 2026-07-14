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
  /// A response from `CountTokens`. It returns the model's `token_count` for the `prompt`.
  /// 
  /// Variant:
  /// Response message for PredictionService.CountTokens.
  package struct CountTokensResponse: Codable, Sendable, Equatable, Hashable {
    /// The total number of billable characters counted across all instances from the request.
    /// 
    /// > Important: `totalBillableCharacters` is only available in the Gemini Enterprise Agent Platform.
    package let totalBillableCharacters: Int?
    
    /// The number of tokens that the `Model` tokenizes the `prompt` into. Always non-negative.
    /// 
    /// Variant:
    /// The total number of tokens counted across all instances from the request.
    package let totalTokens: Int?
    
    /// Number of tokens in the cached part of the prompt (the cached content).
    /// 
    /// > Important: `cachedContentTokenCount` is only available in the Gemini Developer API.
    package let cachedContentTokenCount: Int?
    
    /// Output only. List of modalities that were processed in the request input.
    package let promptTokensDetails: [ModalityTokenCount]?
    
    /// Output only. List of modalities that were processed in the cached content.
    /// 
    /// > Important: `cacheTokensDetails` is only available in the Gemini Developer API.
    package let cacheTokensDetails: [ModalityTokenCount]?
    
    /// Creates a new `CountTokensResponse`.
    package init(
      totalBillableCharacters: Int? = nil,
      totalTokens: Int? = nil,
      cachedContentTokenCount: Int? = nil,
      promptTokensDetails: [ModalityTokenCount]? = nil,
      cacheTokensDetails: [ModalityTokenCount]? = nil
    ) {
      self.totalBillableCharacters = totalBillableCharacters
      self.totalTokens = totalTokens
      self.cachedContentTokenCount = cachedContentTokenCount
      self.promptTokensDetails = promptTokensDetails
      self.cacheTokensDetails = cacheTokensDetails
    }
    enum CodingKeys: String, CodingKey {
      case totalBillableCharacters = "totalBillableCharacters"
      case totalTokens = "totalTokens"
      case cachedContentTokenCount = "cachedContentTokenCount"
      case promptTokensDetails = "promptTokensDetails"
      case cacheTokensDetails = "cacheTokensDetails"
    }
  }
}