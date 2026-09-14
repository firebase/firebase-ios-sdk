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

/// A tool that can be used by the model to call Google Maps.
package struct GoogleMaps: Codable, Sendable, Equatable, Hashable {

  /// Whether to return a widget context token in the tool call result of the
  /// response.
  package let enableWidget: Bool?

  /// The latitude of the user's location.
  package let latitude: Double?

  /// The longitude of the user's location.
  package let longitude: Double?

  package let type: String?

  /// Creates a new `GoogleMaps`.
  ///
  /// - Parameters:
  ///   - enableWidget: Whether to return a widget context token in the tool call result of the
  ///   - latitude: The latitude of the user's location.
  ///   - longitude: The longitude of the user's location.
  package init(
    enableWidget: Bool? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil
  ) {
    self.enableWidget = enableWidget
    self.latitude = latitude
    self.longitude = longitude
    self.type = "google_maps"
  }
  enum CodingKeys: String, CodingKey {
    case enableWidget = "enable_widget"
    case latitude = "latitude"
    case longitude = "longitude"
    case type = "type"
  }
}
