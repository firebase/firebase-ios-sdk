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
  /// An internal data model for `RagRetrievalConfigFilter`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1RagRetrievalConfigFilter`
  /// 
  /// Config for filters.
  package struct RagRetrievalConfigFilter: Codable, Sendable, Equatable, Hashable {
    /// Optional. Only returns contexts with vector distance smaller than the threshold.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Only returns contexts with vector distance smaller than the threshold.
    package let vectorDistanceThreshold: Double?
    
    /// Optional. Only returns contexts with vector similarity larger than the threshold.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Only returns contexts with vector similarity larger than the threshold.
    package let vectorSimilarityThreshold: Double?
    
    /// Optional. String for metadata filtering.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. String for metadata filtering.
    package let metadataFilter: String?
    

    /// Creates a new `RagRetrievalConfigFilter`.
    ///
    /// - Parameters:
    ///   - vectorDistanceThreshold: Optional. Only returns contexts with vector distance smaller than the threshold. (Gemini Enterprise Agent Platform only). For more details, see ``vectorDistanceThreshold``.
    ///   - vectorSimilarityThreshold: Optional. Only returns contexts with vector similarity larger than the threshold. (Gemini Enterprise Agent Platform only). For more details, see ``vectorSimilarityThreshold``.
    ///   - metadataFilter: Optional. String for metadata filtering. (Gemini Enterprise Agent Platform only). For more details, see ``metadataFilter``.
    package init(
      vectorDistanceThreshold: Double? = nil,
      vectorSimilarityThreshold: Double? = nil,
      metadataFilter: String? = nil
    ) {
      self.vectorDistanceThreshold = vectorDistanceThreshold
      self.vectorSimilarityThreshold = vectorSimilarityThreshold
      self.metadataFilter = metadataFilter
    }
    enum CodingKeys: String, CodingKey {
      case vectorDistanceThreshold = "vectorDistanceThreshold"
      case vectorSimilarityThreshold = "vectorSimilarityThreshold"
      case metadataFilter = "metadataFilter"
    }
  }
}