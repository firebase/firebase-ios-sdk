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

/// Encapsulates a snippet of a user review that answers a question about
/// the features of a specific place in Google Maps.
package struct ReviewSnippet: Codable, Sendable, Equatable, Hashable {

  /// The ID of the review snippet.
  package let reviewId: String?

  /// Title of the review.
  package let title: String?

  /// A link that corresponds to the user review on Google Maps.
  package let url: String?

  /// Creates a new `ReviewSnippet`.
  ///
  /// - Parameters:
  ///   - reviewId: The ID of the review snippet.
  ///   - title: Title of the review.
  ///   - url: A link that corresponds to the user review on Google Maps.
  package init(
    reviewId: String? = nil,
    title: String? = nil,
    url: String? = nil
  ) {
    self.reviewId = reviewId
    self.title = title
    self.url = url
  }
  enum CodingKeys: String, CodingKey {
    case reviewId = "review_id"
    case title = "title"
    case url = "url"
  }
}
