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
  /// Config for filters.
  public struct RagRetrievalConfigFilter: Codable, Sendable, Equatable, Hashable {
    /// Optional. String for metadata filtering.
    public var metadataFilter: String?
    
    /// Optional. Only returns contexts with vector distance smaller than the threshold.
    public var vectorDistanceThreshold: Double?
    
    /// Optional. Only returns contexts with vector similarity larger than the threshold.
    public var vectorSimilarityThreshold: Double?
    
    /// Creates a new `RagRetrievalConfigFilter`.
    public init(
      metadataFilter: String? = nil,
      vectorDistanceThreshold: Double? = nil,
      vectorSimilarityThreshold: Double? = nil
    ) {
      self.metadataFilter = metadataFilter
      self.vectorDistanceThreshold = vectorDistanceThreshold
      self.vectorSimilarityThreshold = vectorSimilarityThreshold
    }
    enum CodingKeys: String, CodingKey {
      case metadataFilter = "metadataFilter"
      case vectorDistanceThreshold = "vectorDistanceThreshold"
      case vectorSimilarityThreshold = "vectorSimilarityThreshold"
    }
  }
}