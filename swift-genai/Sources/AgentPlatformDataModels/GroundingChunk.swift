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
  /// A piece of evidence that supports a claim made by the model. This is used to show a citation for a claim made by the model. When grounding is enabled, the model returns a `GroundingChunk` that contains a reference to the source of the information.
  package struct GroundingChunk: Codable, Sendable, Equatable, Hashable {
    /// A grounding chunk from an image search result. See the `Image` message for details.
    package var image: GroundingChunkImage?
    
    /// A grounding chunk from Google Maps. See the `Maps` message for details.
    package var maps: GroundingChunkMaps?
    
    /// A grounding chunk from a data source retrieved by a retrieval tool, such as Vertex AI Search. See the `RetrievedContext` message for details
    package var retrievedContext: GroundingChunkRetrievedContext?
    
    /// A grounding chunk from a web page, typically from Google Search. See the `Web` message for details.
    package var web: GroundingChunkWeb?
    
    /// Creates a new `GroundingChunk`.
    package init(
      image: GroundingChunkImage? = nil,
      maps: GroundingChunkMaps? = nil,
      retrievedContext: GroundingChunkRetrievedContext? = nil,
      web: GroundingChunkWeb? = nil
    ) {
      self.image = image
      self.maps = maps
      self.retrievedContext = retrievedContext
      self.web = web
    }
    enum CodingKeys: String, CodingKey {
      case image = "image"
      case maps = "maps"
      case retrievedContext = "retrievedContext"
      case web = "web"
    }
  }
}