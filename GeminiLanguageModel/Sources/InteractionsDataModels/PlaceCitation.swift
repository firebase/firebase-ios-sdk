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

/// A place citation annotation.
package struct PlaceCitation: Codable, Sendable, Equatable, Hashable {

  /// End of the attributed segment, exclusive.
  package let endIndex: Int?

  /// Title of the place.
  package let name: String?

  /// The ID of the place, in `places/{place_id}` format.
  package let placeId: String?

  /// Snippets of reviews that are used to generate answers about the
  /// features of a given place in Google Maps.
  package let reviewSnippets: [ReviewSnippet]?

  /// Start of segment of the response that is attributed to this source.
  ///
  /// Index indicates the start of the segment, measured in bytes.
  package let startIndex: Int?

  package let type: String?

  /// URI reference of the place.
  package let url: String?

  /// Creates a new `PlaceCitation`.
  ///
  /// - Parameters:
  ///   - endIndex: End of the attributed segment, exclusive.
  ///   - name: Title of the place.
  ///   - placeId: The ID of the place, in `places/{place_id}` format.
  ///   - reviewSnippets: Snippets of reviews that are used to generate answers about the
  ///   - startIndex: Start of segment of the response that is attributed to this source.
  ///   - url: URI reference of the place.
  package init(
    endIndex: Int? = nil,
    name: String? = nil,
    placeId: String? = nil,
    reviewSnippets: [ReviewSnippet]? = nil,
    startIndex: Int? = nil,
    url: String? = nil
  ) {
    self.endIndex = endIndex
    self.name = name
    self.placeId = placeId
    self.reviewSnippets = reviewSnippets
    self.startIndex = startIndex
    self.type = "place_citation"
    self.url = url
  }
  enum CodingKeys: String, CodingKey {
    case endIndex = "end_index"
    case name = "name"
    case placeId = "place_id"
    case reviewSnippets = "review_snippets"
    case startIndex = "start_index"
    case type = "type"
    case url = "url"
  }
}
