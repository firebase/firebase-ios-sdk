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

/// The result of the Google Maps.
package struct GoogleMapsResult: Codable, Sendable, Equatable, Hashable {

  package let places: [GoogleMapsResultPlaces]?

  package let widgetContextToken: String?

  /// Creates a new `GoogleMapsResult`.
  ///
  /// - Parameters:
  ///   - places: For more details, see ``places``.
  ///   - widgetContextToken: For more details, see ``widgetContextToken``.
  package init(
    places: [GoogleMapsResultPlaces]? = nil,
    widgetContextToken: String? = nil
  ) {
    self.places = places
    self.widgetContextToken = widgetContextToken
  }
  enum CodingKeys: String, CodingKey {
    case places = "places"
    case widgetContextToken = "widget_context_token"
  }
}
