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
  /// An object that represents a latitude/longitude pair. This is expressed as a pair of doubles to represent degrees latitude and degrees longitude. Unless specified otherwise, this object must conform to the WGS84 standard. Values must be within normalized ranges.
  public struct LatLng: Codable, Sendable, Equatable, Hashable {
    /// The latitude in degrees. It must be in the range [-90.0, +90.0].
    public var latitude: Double?
    
    /// The longitude in degrees. It must be in the range [-180.0, +180.0].
    public var longitude: Double?
    
    /// Creates a new `LatLng`.
    public init(
      latitude: Double? = nil,
      longitude: Double? = nil
    ) {
      self.latitude = latitude
      self.longitude = longitude
    }
    enum CodingKeys: String, CodingKey {
      case latitude = "latitude"
      case longitude = "longitude"
    }
  }
}