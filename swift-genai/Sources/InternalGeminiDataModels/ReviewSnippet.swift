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
  /// An internal data model for `ReviewSnippet`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGroundingChunkMapsPlaceAnswerSourcesReviewSnippet`
  /// 
  /// Encapsulates a snippet of a user review that answers a question about
  /// the features of a specific place in Google Maps.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GroundingChunkMapsPlaceAnswerSourcesReviewSnippet`
  /// 
  /// A review snippet that is used to generate the answer.
  package struct ReviewSnippet: Codable, Sendable, Equatable, Hashable {
    /// The ID of the review snippet.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The ID of the review snippet.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The ID of the review that is being referenced.
    package let reviewId: String?
    
    /// A link that corresponds to the user review on Google Maps.
    /// 
    /// ### Gemini Developer API
    /// 
    /// A link that corresponds to the user review on Google Maps.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// A link to show the review on Google Maps.
    package let googleMapsUri: String?
    
    /// Title of the review.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Title of the review.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The title of the review.
    package let title: String?
    

    /// Creates a new `ReviewSnippet`.
    ///
    /// - Parameters:
    ///   - reviewId: The ID of the review snippet. (behavior varies by backend). For more details, see ``reviewId``.
    ///   - googleMapsUri: A link that corresponds to the user review on Google Maps. (behavior varies by backend). For more details, see ``googleMapsUri``.
    ///   - title: Title of the review. (behavior varies by backend). For more details, see ``title``.
    package init(
      reviewId: String? = nil,
      googleMapsUri: String? = nil,
      title: String? = nil
    ) {
      self.reviewId = reviewId
      self.googleMapsUri = googleMapsUri
      self.title = title
    }
    enum CodingKeys: String, CodingKey {
      case reviewId = "reviewId"
      case googleMapsUri = "googleMapsUri"
      case title = "title"
    }
  }
}