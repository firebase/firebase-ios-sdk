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
  /// A `GroundingChunk` represents a segment of supporting evidence that grounds the model's response. It can be a chunk from the web, a retrieved context from a file, or information from Google Maps.
  /// 
  /// Variant:
  /// A piece of evidence that supports a claim made by the model. This is used to show a citation for a claim made by the model. When grounding is enabled, the model returns a `GroundingChunk` that contains a reference to the source of the information.
  package struct GroundingChunk: Codable, Sendable, Equatable, Hashable {
    /// Optional. Grounding chunk from image search.
    /// 
    /// Variant:
    /// A grounding chunk from an image search result. See the `Image` message for details.
    package let image: ImageChunk?
    
    /// Grounding chunk from the web.
    /// 
    /// Variant:
    /// A grounding chunk from a web page, typically from Google Search. See the `Web` message for details.
    package let web: WebChunk?
    
    /// Optional. Grounding chunk from Google Maps.
    /// 
    /// Variant:
    /// A grounding chunk from Google Maps. See the `Maps` message for details.
    package let maps: MapsChunk?
    
    /// Optional. Grounding chunk from context retrieved by the file search tool.
    /// 
    /// Variant:
    /// A grounding chunk from a data source retrieved by a retrieval tool, such as Vertex AI Search. See the `RetrievedContext` message for details
    package let retrievedContext: RetrievedContextChunk?
    
    /// Creates a new `GroundingChunk`.
    package init(
      image: ImageChunk? = nil,
      web: WebChunk? = nil,
      maps: MapsChunk? = nil,
      retrievedContext: RetrievedContextChunk? = nil
    ) {
      self.image = image
      self.web = web
      self.maps = maps
      self.retrievedContext = retrievedContext
    }
    enum CodingKeys: String, CodingKey {
      case image = "image"
      case web = "web"
      case maps = "maps"
      case retrievedContext = "retrievedContext"
    }
  }
}