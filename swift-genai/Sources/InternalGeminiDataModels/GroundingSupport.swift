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
  /// An internal data model for `GroundingSupport`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGroundingSupport`
  /// 
  /// Grounding support.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GroundingSupport`
  /// 
  /// A collection of supporting references for a segment or part of the
  /// model's response.
  package struct GroundingSupport: Codable, Sendable, Equatable, Hashable {
    /// Segment of the content this support belongs to.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Segment of the content this support belongs to.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The content segment that this support message applies to.
    package let segment: Segment?
    
    /// Optional. A list of indices (into 'grounding_chunk' in
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. A list of indices (into 'grounding_chunk' in
    /// `response.candidate.grounding_metadata`) specifying the citations
    /// associated with the claim. For instance [1,3,4] means that
    /// grounding_chunk[1], grounding_chunk[3], grounding_chunk[4] are the
    /// retrieved content attributed to the claim. If the response is streaming,
    /// the grounding_chunk_indices refer to the indices across all responses.
    /// It is the client's responsibility to accumulate the grounding chunks from
    /// all responses (while maintaining the same order).
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// A list of indices into the `grounding_chunks` field of the
    /// `GroundingMetadata` message. These indices specify which grounding chunks
    /// support the claim made in the content segment.
    /// 
    /// For example, if this field has the values `[1, 3]`, it means that
    /// `grounding_chunks[1]` and `grounding_chunks[3]` are the sources for the
    /// claim in the content segment.
    package let groundingChunkIndices: [Int]?
    
    /// Optional. Confidence score of the support references. Ranges from 0 to 1. 1 is the
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Confidence score of the support references. Ranges from 0 to 1. 1 is the
    /// most confident. This list must have the same size as the
    /// grounding_chunk_indices.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The confidence scores for the support references. This list is
    /// parallel to the `grounding_chunk_indices` list. A score is a value between
    /// 0.0 and 1.0, with a higher score indicating a higher confidence that the
    /// reference supports the claim.
    /// 
    /// For Gemini 2.0 and before, this list has the same size as
    /// `grounding_chunk_indices`. For Gemini 2.5 and later, this list is empty
    /// and should be ignored.
    package let confidenceScores: [Double]?
    
    /// Output only. Indices into the `parts` field of the candidate's content. These indices
    /// 
    /// ### Gemini Developer API
    /// 
    /// Output only. Indices into the `parts` field of the candidate's content. These indices
    /// specify which rendered parts are associated with this support source.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Indices into the `rendered_parts` field of the `GroundingMetadata`
    /// message. These indices specify which rendered parts are associated with
    /// this support message.
    package let renderedParts: [Int]?
    

    /// Creates a new `GroundingSupport`.
    ///
    /// - Parameters:
    ///   - segment: Segment of the content this support belongs to. (behavior varies by backend). For more details, see ``segment``.
    ///   - groundingChunkIndices: Optional. A list of indices (into 'grounding_chunk' in (behavior varies by backend). For more details, see ``groundingChunkIndices``.
    ///   - confidenceScores: Optional. Confidence score of the support references. Ranges from 0 to 1. 1 is the (behavior varies by backend). For more details, see ``confidenceScores``.
    ///   - renderedParts: Output only. Indices into the `parts` field of the candidate's content. These indices (behavior varies by backend). For more details, see ``renderedParts``.
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