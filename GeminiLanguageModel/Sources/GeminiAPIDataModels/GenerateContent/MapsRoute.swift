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

/// Route information from Google Maps.
///
/// > Important: This type is not supported in the Gemini Developer API.
package struct MapsRoute: Codable, Sendable, Equatable, Hashable, Buildable {
  /// The total distance of the route, in meters.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var distanceMeters: Int?

  /// The total duration of the route.
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var duration: String?

  /// An encoded polyline of the route. See
  /// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  ///
  /// > Important: This property is not supported in the Gemini Developer API.
  package var encodedPolyline: String?

  /// Initializes a new `MapsRoute`.
  package init() {}

  enum CodingKeys: String, CodingKey {
    case distanceMeters
    case duration
    case encodedPolyline
  }
}
