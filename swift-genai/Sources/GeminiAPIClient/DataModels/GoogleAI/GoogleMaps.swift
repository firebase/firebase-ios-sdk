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
  /// The GoogleMaps Tool that provides geospatial context for the user's query.
  package struct GoogleMaps: Codable, Sendable, Equatable, Hashable {
    /// Optional. Whether to return a widget context token in the GroundingMetadata of the response. Developers can use the widget context token to render a Google Maps widget with geospatial context related to the places that the model references in the response.
    package var enableWidget: Bool?
    
    /// Creates a new `GoogleMaps`.
    package init(
      enableWidget: Bool? = nil
    ) {
      self.enableWidget = enableWidget
    }
    enum CodingKeys: String, CodingKey {
      case enableWidget = "enableWidget"
    }
  }
}