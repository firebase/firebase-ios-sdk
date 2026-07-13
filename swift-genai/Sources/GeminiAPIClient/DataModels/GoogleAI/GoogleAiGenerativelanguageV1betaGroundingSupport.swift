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
  /// Grounding support.
  package struct GoogleAiGenerativelanguageV1betaGroundingSupport: Codable, Sendable, Equatable, Hashable {
    /// Optional. Confidence score of the support references. Ranges from 0 to 1. 1 is the most confident. This list must have the same size as the grounding_chunk_indices.
    package var confidenceScores: [Double]?
    
    /// Optional. A list of indices (into 'grounding_chunk' in `response.candidate.grounding_metadata`) specifying the citations associated with the claim. For instance [1,3,4] means that grounding_chunk[1], grounding_chunk[3], grounding_chunk[4] are the retrieved content attributed to the claim. If the response is streaming, the grounding_chunk_indices refer to the indices across all responses. It is the client's responsibility to accumulate the grounding chunks from all responses (while maintaining the same order).
    package var groundingChunkIndices: [Int]?
    
    /// Output only. Indices into the `parts` field of the candidate's content. These indices specify which rendered parts are associated with this support source.
    package var renderedParts: [Int]?
    
    /// Segment of the content this support belongs to.
    package var segment: GoogleAiGenerativelanguageV1betaSegment?
    
    /// Creates a new `GoogleAiGenerativelanguageV1betaGroundingSupport`.
    package init(
      confidenceScores: [Double]? = nil,
      groundingChunkIndices: [Int]? = nil,
      renderedParts: [Int]? = nil,
      segment: GoogleAiGenerativelanguageV1betaSegment? = nil
    ) {
      self.confidenceScores = confidenceScores
      self.groundingChunkIndices = groundingChunkIndices
      self.renderedParts = renderedParts
      self.segment = segment
    }
    enum CodingKeys: String, CodingKey {
      case confidenceScores = "confidenceScores"
      case groundingChunkIndices = "groundingChunkIndices"
      case renderedParts = "renderedParts"
      case segment = "segment"
    }
  }
}