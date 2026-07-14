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
  /// Metadata related to the retrieval grounding source. This is part of the `GroundingMetadata` returned when grounding is enabled.
  public struct RetrievalMetadata: Codable, Sendable, Equatable, Hashable {
    /// Optional. A score indicating how likely it is that a Google Search query could help answer the prompt. The score is in the range of `[0, 1]`. A score of 1 means the model is confident that a search will be helpful, and 0 means it is not. This score is populated only when Google Search grounding and dynamic retrieval are enabled. The score is used to determine whether to trigger a search.
    public var googleSearchDynamicRetrievalScore: Double?
    
    /// Creates a new `RetrievalMetadata`.
    public init(
      googleSearchDynamicRetrievalScore: Double? = nil
    ) {
      self.googleSearchDynamicRetrievalScore = googleSearchDynamicRetrievalScore
    }
    enum CodingKeys: String, CodingKey {
      case googleSearchDynamicRetrievalScore = "googleSearchDynamicRetrievalScore"
    }
  }
}