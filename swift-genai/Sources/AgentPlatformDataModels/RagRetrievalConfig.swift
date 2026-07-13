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
  /// Specifies the context retrieval config.
  package struct RagRetrievalConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. Config for filters.
    package var filter: RagRetrievalConfigFilter?
    
    /// Optional. Config for Hybrid Search.
    package var hybridSearch: RagRetrievalConfigHybridSearch?
    
    /// Optional. Config for ranking and reranking.
    package var ranking: RagRetrievalConfigRanking?
    
    /// Optional. The number of contexts to retrieve.
    package var topK: Int?
    
    /// Creates a new `RagRetrievalConfig`.
    package init(
      filter: RagRetrievalConfigFilter? = nil,
      hybridSearch: RagRetrievalConfigHybridSearch? = nil,
      ranking: RagRetrievalConfigRanking? = nil,
      topK: Int? = nil
    ) {
      self.filter = filter
      self.hybridSearch = hybridSearch
      self.ranking = ranking
      self.topK = topK
    }
    enum CodingKeys: String, CodingKey {
      case filter = "filter"
      case hybridSearch = "hybridSearch"
      case ranking = "ranking"
      case topK = "topK"
    }
  }
}