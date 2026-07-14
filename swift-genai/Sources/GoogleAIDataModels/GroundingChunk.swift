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
  /// A `GroundingChunk` represents a segment of supporting evidence that grounds the model's response. It can be a chunk from the web, a retrieved context from a file, or information from Google Maps.
  public struct GroundingChunk: Codable, Sendable, Equatable, Hashable {
    /// Optional. Grounding chunk from image search.
    public var image: Image?
    
    /// Optional. Grounding chunk from Google Maps.
    public var maps: Maps?
    
    /// Optional. Grounding chunk from context retrieved by the file search tool.
    public var retrievedContext: RetrievedContext?
    
    /// Grounding chunk from the web.
    public var web: Web?
    
    /// Creates a new `GroundingChunk`.
    public init(
      image: Image? = nil,
      maps: Maps? = nil,
      retrievedContext: RetrievedContext? = nil,
      web: Web? = nil
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