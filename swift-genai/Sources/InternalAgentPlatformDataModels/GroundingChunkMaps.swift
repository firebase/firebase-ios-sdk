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
  /// A `Maps` chunk is a piece of evidence that comes from Google Maps, containing information about places or routes. This is used to provide the user with rich, location-based information.
  public struct GroundingChunkMaps: Codable, Sendable, Equatable, Hashable {
    /// The sources that were used to generate the place answer. This includes review snippets and photos that were used to generate the answer, as well as URIs to flag content.
    public var placeAnswerSources: GroundingChunkMapsPlaceAnswerSources?
    
    /// This Place's resource name, in `places/{place_id}` format. This can be used to look up the place in the Google Maps API.
    public var placeId: String?
    
    /// Output only. Route information.
    public var route: GroundingChunkMapsRoute?
    
    /// The text of the place answer.
    public var text: String?
    
    /// The title of the place.
    public var title: String?
    
    /// The URI of the place.
    public var uri: String?
    
    /// Creates a new `GroundingChunkMaps`.
    public init(
      placeAnswerSources: GroundingChunkMapsPlaceAnswerSources? = nil,
      placeId: String? = nil,
      route: GroundingChunkMapsRoute? = nil,
      text: String? = nil,
      title: String? = nil,
      uri: String? = nil
    ) {
      self.placeAnswerSources = placeAnswerSources
      self.placeId = placeId
      self.route = route
      self.text = text
      self.title = title
      self.uri = uri
    }
    enum CodingKeys: String, CodingKey {
      case placeAnswerSources = "placeAnswerSources"
      case placeId = "placeId"
      case route = "route"
      case text = "text"
      case title = "title"
      case uri = "uri"
    }
  }
}