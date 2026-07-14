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
  /// Route information from Google Maps.
  /// 
  /// > Important: This type is only available in the Gemini Enterprise Agent Platform.
  package struct MapsRoute: Codable, Sendable, Equatable, Hashable {
    /// The total distance of the route, in meters.
    /// 
    /// > Important: `distanceMeters` is only available in the Gemini Enterprise Agent Platform.
    package let distanceMeters: Int?
    
    /// The total duration of the route.
    /// 
    /// > Important: `duration` is only available in the Gemini Enterprise Agent Platform.
    package let duration: String?
    
    /// An encoded polyline of the route. See https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    /// 
    /// > Important: `encodedPolyline` is only available in the Gemini Enterprise Agent Platform.
    package let encodedPolyline: String?
    
    /// Creates a new `MapsRoute`.
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