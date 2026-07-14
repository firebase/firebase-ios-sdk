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
  /// A grounding chunk from Google Maps. A Maps chunk corresponds to a single place.
  /// 
  /// Variant:
  /// A `Maps` chunk is a piece of evidence that comes from Google Maps, containing information about places or routes. This is used to provide the user with rich, location-based information.
  package struct MapsChunk: Codable, Sendable, Equatable, Hashable {
    /// Text description of the place answer.
    /// 
    /// Variant:
    /// The text of the place answer.
    package let text: String?
    
    /// URI reference of the place.
    /// 
    /// Variant:
    /// The URI of the place.
    package let uri: String?
    
    /// Title of the place.
    /// 
    /// Variant:
    /// The title of the place.
    package let title: String?
    
    /// Output only. Route information.
    /// 
    /// > Important: `route` is only available in the Gemini Enterprise Agent Platform.
    package let route: MapsRoute?
    
    /// Sources that provide answers about the features of a given place in Google Maps.
    /// 
    /// Variant:
    /// The sources that were used to generate the place answer. This includes review snippets and photos that were used to generate the answer, as well as URIs to flag content.
    package let placeAnswerSources: PlaceAnswerSources?
    
    /// The ID of the place, in `places/{place_id}` format. A user can use this ID to look up that place.
    /// 
    /// Variant:
    /// This Place's resource name, in `places/{place_id}` format. This can be used to look up the place in the Google Maps API.
    package let placeId: String?
    
    /// Creates a new `MapsChunk`.
    package init(
      text: String? = nil,
      uri: String? = nil,
      title: String? = nil,
      route: MapsRoute? = nil,
      placeAnswerSources: PlaceAnswerSources? = nil,
      placeId: String? = nil
    ) {
      self.text = text
      self.uri = uri
      self.title = title
      self.route = route
      self.placeAnswerSources = placeAnswerSources
      self.placeId = placeId
    }
    enum CodingKeys: String, CodingKey {
      case text = "text"
      case uri = "uri"
      case title = "title"
      case route = "route"
      case placeAnswerSources = "placeAnswerSources"
      case placeId = "placeId"
    }
  }
}