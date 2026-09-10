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

/// An internal data model for `GoogleMapsResultPlaces`.
package struct GoogleMapsResultPlaces: Codable, Sendable, Equatable, Hashable {

  package let name: String?

  package let placeId: String?

  package let reviewSnippets: [ReviewSnippet]?

  package let url: String?

  /// Creates a new `GoogleMapsResultPlaces`.
  ///
  /// - Parameters:
  ///   - name: For more details, see ``name``.
  ///   - placeId: For more details, see ``placeId``.
  ///   - reviewSnippets: For more details, see ``reviewSnippets``.
  ///   - url: For more details, see ``url``.
  package init(
    name: String? = nil,
    placeId: String? = nil,
    reviewSnippets: [ReviewSnippet]? = nil,
    url: String? = nil
  ) {
    self.name = name
    self.placeId = placeId
    self.reviewSnippets = reviewSnippets
    self.url = url
  }
  enum CodingKeys: String, CodingKey {
    case name = "name"
    case placeId = "place_id"
    case reviewSnippets = "review_snippets"
    case url = "url"
  }
}
