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
  /// A grounding chunk from Google Maps. A Maps chunk corresponds to a single place.
  package struct Maps: Codable, Sendable, Equatable, Hashable {
    /// Sources that provide answers about the features of a given place in Google Maps.
    package var placeAnswerSources: PlaceAnswerSources?
    
    /// The ID of the place, in `places/{place_id}` format. A user can use this ID to look up that place.
    package var placeId: String?
    
    /// Text description of the place answer.
    package var text: String?
    
    /// Title of the place.
    package var title: String?
    
    /// URI reference of the place.
    package var uri: String?
    
    /// Creates a new `Maps`.
    package init(
      placeAnswerSources: PlaceAnswerSources? = nil,
      placeId: String? = nil,
      text: String? = nil,
      title: String? = nil,
      uri: String? = nil
    ) {
      self.placeAnswerSources = placeAnswerSources
      self.placeId = placeId
      self.text = text
      self.title = title
      self.uri = uri
    }
    enum CodingKeys: String, CodingKey {
      case placeAnswerSources = "placeAnswerSources"
      case placeId = "placeId"
      case text = "text"
      case title = "title"
      case uri = "uri"
    }
  }
}