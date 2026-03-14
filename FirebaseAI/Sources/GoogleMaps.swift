// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// A tool that allows the model to ground its responses in data from Google Maps.
///
/// > Important: When using this feature, you are required to comply with the
/// "Grounding with Google Maps" usage requirements for your chosen API provider.
public struct GoogleMaps: Sendable, Encodable {
  public init() {}
}

/// A grounding chunk sourced from Google Maps.
public struct GoogleMapsGroundingChunk: Sendable, Equatable, Hashable, Decodable {
  /// The URI of the retrieved map data.
  public let uri: String
  /// The title of the retrieved map data.
  public let title: String
  /// The Place ID of the retrieved map data.
  public let placeID: String

  enum CodingKeys: String, CodingKey {
    case uri
    case title
    case placeID = "placeId"
  }
}
