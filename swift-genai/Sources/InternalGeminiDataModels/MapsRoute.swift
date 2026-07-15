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
  /// An internal data model for `MapsRoute`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// > Important: This type is not supported in the Gemini Developer API.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GroundingChunkMapsRoute`
  /// 
  /// Route information from Google Maps.
  package struct MapsRoute: Codable, Sendable, Equatable, Hashable {
    /// The total distance of the route, in meters.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The total distance of the route, in meters.
    package let distanceMeters: Int?
    
    /// The total duration of the route.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The total duration of the route.
    package let duration: String?
    
    /// An encoded polyline of the route. See
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// An encoded polyline of the route. See
    /// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    package let encodedPolyline: String?
    

    /// Creates a new `MapsRoute`.
    ///
    /// - Parameters:
    ///   - distanceMeters: The total distance of the route, in meters. (Gemini Enterprise Agent Platform only). For more details, see ``distanceMeters``.
    ///   - duration: The total duration of the route. (Gemini Enterprise Agent Platform only). For more details, see ``duration``.
    ///   - encodedPolyline: An encoded polyline of the route. See (Gemini Enterprise Agent Platform only). For more details, see ``encodedPolyline``.
    package init(
      distanceMeters: Int? = nil,
      duration: String? = nil,
      encodedPolyline: String? = nil
    ) {
      self.distanceMeters = distanceMeters
      self.duration = duration
      self.encodedPolyline = encodedPolyline
    }
    enum CodingKeys: String, CodingKey {
      case distanceMeters = "distanceMeters"
      case duration = "duration"
      case encodedPolyline = "encodedPolyline"
    }
  }
}