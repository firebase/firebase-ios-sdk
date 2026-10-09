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

/// A `Maps` chunk is a piece of evidence that comes from Google Maps, containing information about
/// places or routes. This is used to provide the user with rich, location-based information.
package struct MapsChunk: Codable, Sendable, Equatable, Hashable, Buildable {
  /// The sources that were used to generate the place answer. This includes review snippets and
  /// photos that were used to generate the answer, as well as URIs to flag content.
  package var placeAnswerSources: PlaceAnswerSources?

  /// This Place's resource name, in `places/{place_id}` format. This can be used to look up the
  /// place in the Google Maps API.
  package var placeID: String?

  /// Route information.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var route: MapsRoute?

  /// The text of the place answer.
  package var text: String?

  /// The title of the place.
  package var title: String?

  /// The URI of the place.
  package var uri: String?

  /// Initializes a new `MapsChunk`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case placeAnswerSources
    case placeID = "placeId"
    case route
    case text
    case title
    case uri
  }
}
