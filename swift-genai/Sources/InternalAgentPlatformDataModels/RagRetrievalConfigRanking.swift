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
  /// Config for ranking and reranking.
  public struct RagRetrievalConfigRanking: Codable, Sendable, Equatable, Hashable {
    /// Optional. Config for LlmRanker.
    public var llmRanker: RagRetrievalConfigRankingLlmRanker?
    
    /// Optional. Config for Rank Service.
    public var rankService: RagRetrievalConfigRankingRankService?
    
    /// Creates a new `RagRetrievalConfigRanking`.
    public init(
      llmRanker: RagRetrievalConfigRankingLlmRanker? = nil,
      rankService: RagRetrievalConfigRankingRankService? = nil
    ) {
      self.llmRanker = llmRanker
      self.rankService = rankService
    }
    enum CodingKeys: String, CodingKey {
      case llmRanker = "llmRanker"
      case rankService = "rankService"
    }
  }
}