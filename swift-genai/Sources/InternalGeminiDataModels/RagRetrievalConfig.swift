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
  /// An internal data model for `RagRetrievalConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1RagRetrievalConfig`
  /// 
  /// Specifies the context retrieval config.
  package struct RagRetrievalConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The number of contexts to retrieve.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The number of contexts to retrieve.
    package let topK: Int?
    
    /// Optional. Config for Hybrid Search.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Config for Hybrid Search.
    package let hybridSearch: RagRetrievalConfigHybridSearch?
    
    /// Optional. Config for filters.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Config for filters.
    package let filter: RagRetrievalConfigFilter?
    
    /// Optional. Config for ranking and reranking.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Config for ranking and reranking.
    package let ranking: RagRetrievalConfigRanking?
    

    /// Creates a new `RagRetrievalConfig`.
    ///
    /// - Parameters:
    ///   - topK: Optional. The number of contexts to retrieve. (Gemini Enterprise Agent Platform only). For more details, see ``topK``.
    ///   - hybridSearch: Optional. Config for Hybrid Search. (Gemini Enterprise Agent Platform only). For more details, see ``hybridSearch``.
    ///   - filter: Optional. Config for filters. (Gemini Enterprise Agent Platform only). For more details, see ``filter``.
    ///   - ranking: Optional. Config for ranking and reranking. (Gemini Enterprise Agent Platform only). For more details, see ``ranking``.
    package init(
      topK: Int? = nil,
      hybridSearch: RagRetrievalConfigHybridSearch? = nil,
      filter: RagRetrievalConfigFilter? = nil,
      ranking: RagRetrievalConfigRanking? = nil
    ) {
      self.topK = topK
      self.hybridSearch = hybridSearch
      self.filter = filter
      self.ranking = ranking
    }
    enum CodingKeys: String, CodingKey {
      case topK = "topK"
      case hybridSearch = "hybridSearch"
      case filter = "filter"
      case ranking = "ranking"
    }
  }
}