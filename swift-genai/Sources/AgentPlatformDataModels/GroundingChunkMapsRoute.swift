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
  /// Route information from Google Maps.
  public struct GroundingChunkMapsRoute: Codable, Sendable, Equatable, Hashable {
    /// The total distance of the route, in meters.
    public var distanceMeters: Int?
    
    /// The total duration of the route.
    public var duration: Duration?
    
    /// An encoded polyline of the route. See https://developers.google.com/maps/documentation/utilities/polylinealgorithm
    public var encodedPolyline: String?
    
    /// Creates a new `GroundingChunkMapsRoute`.
    public init(
      distanceMeters: Int? = nil,
      duration: Duration? = nil,
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