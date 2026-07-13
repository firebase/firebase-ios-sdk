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
  /// The sources that were used to generate the place answer. This includes review snippets and photos that were used to generate the answer, as well as URIs to flag content.
  package struct GroundingChunkMapsPlaceAnswerSources: Codable, Sendable, Equatable, Hashable {
    /// Snippets of reviews that were used to generate the answer.
    package var reviewSnippets: [GroundingChunkMapsPlaceAnswerSourcesReviewSnippet]?
    
    /// Creates a new `GroundingChunkMapsPlaceAnswerSources`.
    package init(
      reviewSnippets: [GroundingChunkMapsPlaceAnswerSourcesReviewSnippet]? = nil
    ) {
      self.reviewSnippets = reviewSnippets
    }
    enum CodingKeys: String, CodingKey {
      case reviewSnippets = "reviewSnippets"
    }
  }
}