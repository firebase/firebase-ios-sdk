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
  /// An `Image` chunk is a piece of evidence that comes from an image search result. It contains the URI of the image search result and the URI of the image. This is used to provide the user with a link to the source of the information.
  public struct GroundingChunkImage: Codable, Sendable, Equatable, Hashable {
    /// The domain of the image search result page.
    public var domain: String?
    
    /// The URI of the image.
    public var imageUri: String?
    
    /// The URI of the image search result page.
    public var sourceUri: String?
    
    /// The title of the image search result page.
    public var title: String?
    
    /// Creates a new `GroundingChunkImage`.
    public init(
      domain: String? = nil,
      imageUri: String? = nil,
      sourceUri: String? = nil,
      title: String? = nil
    ) {
      self.domain = domain
      self.imageUri = imageUri
      self.sourceUri = sourceUri
      self.title = title
    }
    enum CodingKeys: String, CodingKey {
      case domain = "domain"
      case imageUri = "imageUri"
      case sourceUri = "sourceUri"
      case title = "title"
    }
  }
}