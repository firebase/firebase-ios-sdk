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
  /// A collection of supporting references for a segment or part of the model's response.
  public struct GroundingSupport: Codable, Sendable, Equatable, Hashable {
    /// The confidence scores for the support references. This list is parallel to the `grounding_chunk_indices` list. A score is a value between 0.0 and 1.0, with a higher score indicating a higher confidence that the reference supports the claim. For Gemini 2.0 and before, this list has the same size as `grounding_chunk_indices`. For Gemini 2.5 and later, this list is empty and should be ignored.
    public var confidenceScores: [Double]?
    
    /// A list of indices into the `grounding_chunks` field of the `GroundingMetadata` message. These indices specify which grounding chunks support the claim made in the content segment. For example, if this field has the values `[1, 3]`, it means that `grounding_chunks[1]` and `grounding_chunks[3]` are the sources for the claim in the content segment.
    public var groundingChunkIndices: [Int]?
    
    /// Indices into the `rendered_parts` field of the `GroundingMetadata` message. These indices specify which rendered parts are associated with this support message.
    public var renderedParts: [Int]?
    
    /// The content segment that this support message applies to.
    public var segment: Segment?
    
    /// Creates a new `GroundingSupport`.
    public init(
      confidenceScores: [Double]? = nil,
      groundingChunkIndices: [Int]? = nil,
      renderedParts: [Int]? = nil,
      segment: Segment? = nil
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