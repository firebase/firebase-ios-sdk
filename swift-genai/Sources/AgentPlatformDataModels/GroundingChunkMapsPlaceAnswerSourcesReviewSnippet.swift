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
  /// A review snippet that is used to generate the answer.
  package struct GroundingChunkMapsPlaceAnswerSourcesReviewSnippet: Codable, Sendable, Equatable, Hashable {
    /// A link to show the review on Google Maps.
    package var googleMapsUri: String?
    
    /// The ID of the review that is being referenced.
    package var reviewId: String?
    
    /// The title of the review.
    package var title: String?
    
    /// Creates a new `GroundingChunkMapsPlaceAnswerSourcesReviewSnippet`.
    package init(
      googleMapsUri: String? = nil,
      reviewId: String? = nil,
      title: String? = nil
    ) {
      self.googleMapsUri = googleMapsUri
      self.reviewId = reviewId
      self.title = title
    }
    enum CodingKeys: String, CodingKey {
      case googleMapsUri = "googleMapsUri"
      case reviewId = "reviewId"
      case title = "title"
    }
  }
}