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
import GoogleAIDataModels
import AgentPlatformDataModels

/// A tool that allows the model to ground its responses in data from Google Maps.
///
/// > Important: When using this feature, you are required to comply with the
/// "Grounding with Google Maps" usage requirements for your chosen API provider.
public struct GoogleMaps: Sendable, Hashable {
  init() {}
}

/// A grounding chunk sourced from Google Maps.
public struct GoogleMapsGroundingChunk: Sendable, Equatable, Hashable {
  /// The URL of the retrieved map data.
  public let url: URL?
  /// The title of the retrieved map data.
  public let title: String?
  /// The Place ID of the retrieved map data.
  public let placeID: String?

  enum CodingKeys: String, CodingKey {
    case url = "uri" // Decode "uri" from backend, store as "url"
    case title
    case placeID = "placeId"
  }

}

// MARK: - Mappings

extension GoogleMaps {
  func toGoogleAI() -> GoogleAI.GoogleMaps {
    GoogleAI.GoogleMaps()
  }

  func toAgentPlatform() -> AgentPlatform.GoogleMaps {
    AgentPlatform.GoogleMaps()
  }

  init(fromGoogleAI maps: GoogleAI.GoogleMaps) {}
  init(fromAgentPlatform maps: AgentPlatform.GoogleMaps) {}
}

extension GoogleMapsGroundingChunk {
  func toGoogleAI() -> GoogleAI.Maps {
    GoogleAI.Maps(
      placeId: placeID,
      title: title,
      uri: url?.absoluteString
    )
  }

  func toAgentPlatform() -> AgentPlatform.GroundingChunkMaps {
    AgentPlatform.GroundingChunkMaps(
      placeId: placeID,
      title: title,
      uri: url?.absoluteString
    )
  }

  init(fromGoogleAI maps: GoogleAI.Maps) {
    self.url = maps.uri.flatMap { URL(string: $0) }
    self.title = maps.title
    self.placeID = maps.placeId
  }

  init(fromAgentPlatform maps: AgentPlatform.GroundingChunkMaps) {
    self.url = maps.uri.flatMap { URL(string: $0) }
    self.title = maps.title
    self.placeID = maps.placeId
  }
}
