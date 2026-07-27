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

/// An internal data model for `MapsChunk`.
///
/// ### Gemini Developer API
///
/// Type: `GoogleAiGenerativelanguageV1betaGroundingChunkMaps`
///
/// A grounding chunk from Google Maps. A Maps chunk corresponds to a single
/// place.
///
/// ### Gemini Enterprise Agent Platform
///
/// Type: `GoogleCloudAiplatformV1beta1GroundingChunkMaps`
///
/// A `Maps` chunk is a piece of evidence that comes from Google Maps,
/// containing information about places or routes. This is used to provide
/// the user with rich, location-based information.
public struct MapsChunk: Codable, Sendable, Equatable, Hashable {
  /// URI reference of the place.
  ///
  /// ### Gemini Developer API
  ///
  /// URI reference of the place.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// The URI of the place.
  public let uri: String?

  /// Title of the place.
  ///
  /// ### Gemini Developer API
  ///
  /// Title of the place.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// The title of the place.
  public let title: String?

  /// Text description of the place answer.
  ///
  /// ### Gemini Developer API
  ///
  /// Text description of the place answer.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// The text of the place answer.
  public let text: String?

  /// The ID of the place, in `places/{place_id}` format. A user can use this
  ///
  /// ### Gemini Developer API
  ///
  /// The ID of the place, in `places/{place_id}` format. A user can use this
  /// ID to look up that place.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// This Place's resource name, in `places/{place_id}` format. This can be
  /// used to look up the place in the Google Maps API.
  public let placeId: String?

  /// Sources that provide answers about the features of a given place in
  ///
  /// ### Gemini Developer API
  ///
  /// Sources that provide answers about the features of a given place in
  /// Google Maps.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// The sources that were used to generate the place answer. This includes
  /// review snippets and photos that were used to generate the answer, as well
  /// as URIs to flag content.
  public let placeAnswerSources: PlaceAnswerSources?

  /// Output only. Route information.
  ///
  /// ### Gemini Developer API
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  ///
  /// ### Gemini Enterprise Agent Platform
  ///
  /// Output only. Route information.
  public let route: MapsRoute?

  /// Creates a new `MapsChunk`.
  ///
  /// - Parameters:
  ///   - uri: URI reference of the place. (behavior varies by backend). For more details, see
  /// ``uri``.
  ///   - title: Title of the place. (behavior varies by backend). For more details, see ``title``.
  ///   - text: Text description of the place answer. (behavior varies by backend). For more
  /// details, see ``text``.
  ///   - placeId: The ID of the place, in `places/{place_id}` format. A user can use this (behavior
  /// varies by backend). For more details, see ``placeId``.
  ///   - placeAnswerSources: Sources that provide answers about the features of a given place in
  /// (behavior varies by backend). For more details, see ``placeAnswerSources``.
  ///   - route: Output only. Route information. (Gemini Enterprise Agent Platform only). For more
  /// details, see ``route``.
  public init(uri: String? = nil,
              title: String? = nil,
              text: String? = nil,
              placeId: String? = nil,
              placeAnswerSources: PlaceAnswerSources? = nil,
              route: MapsRoute? = nil) {
    self.uri = uri
    self.title = title
    self.text = text
    self.placeId = placeId
    self.placeAnswerSources = placeAnswerSources
    self.route = route
  }

  enum CodingKeys: String, CodingKey {
    case uri
    case title
    case text
    case placeId
    case placeAnswerSources
    case route
  }
}
