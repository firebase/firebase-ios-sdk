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
  /// Grounding support.
  package struct GroundingSupport: Codable, Sendable, Equatable, Hashable {
    /// Segment of the content this support belongs to.
    package let segment: Segment?
    
    /// Optional. A list of indices (into 'grounding_chunk' in `response.candidate.grounding_metadata`) specifying the citations associated with the claim. For instance [1,3,4] means that grounding_chunk[1], grounding_chunk[3], grounding_chunk[4] are the retrieved content attributed to the claim. If the response is streaming, the grounding_chunk_indices refer to the indices across all responses. It is the client's responsibility to accumulate the grounding chunks from all responses (while maintaining the same order).
    package let groundingChunkIndices: [Int]?
    
    /// Optional. Confidence score of the support references. Ranges from 0 to 1. 1 is the most confident. This list must have the same size as the grounding_chunk_indices.
    package let confidenceScores: [Double]?
    
    /// Output only. Indices into the `parts` field of the candidate's content. These indices specify which rendered parts are associated with this support source.
    package let renderedParts: [Int]?
    
    /// Creates a new `GroundingSupport`.
    package init(
      segment: Segment? = nil,
      groundingChunkIndices: [Int]? = nil,
      confidenceScores: [Double]? = nil,
      renderedParts: [Int]? = nil
    ) {
      self.segment = segment
      self.groundingChunkIndices = groundingChunkIndices
      self.confidenceScores = confidenceScores
      self.renderedParts = renderedParts
    }
    enum CodingKeys: String, CodingKey {
      case segment = "segment"
      case groundingChunkIndices = "groundingChunkIndices"
      case confidenceScores = "confidenceScores"
      case renderedParts = "renderedParts"
    }
  }
}