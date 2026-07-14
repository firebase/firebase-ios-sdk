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
  /// Chunk from image search.
  /// 
  /// Variant:
  /// An `Image` chunk is a piece of evidence that comes from an image search result. It contains the URI of the image search result and the URI of the image. This is used to provide the user with a link to the source of the information.
  package struct ImageChunk: Codable, Sendable, Equatable, Hashable {
    /// The root domain of the web page that the image is from, e.g. "example.com".
    /// 
    /// Variant:
    /// The domain of the image search result page.
    package let domain: String?
    
    /// The web page URI for attribution.
    /// 
    /// Variant:
    /// The URI of the image search result page.
    package let sourceUri: String?
    
    /// The title of the web page that the image is from.
    /// 
    /// Variant:
    /// The title of the image search result page.
    package let title: String?
    
    /// The image asset URL.
    /// 
    /// Variant:
    /// The URI of the image.
    package let imageUri: String?
    
    /// Creates a new `ImageChunk`.
    package init(
      domain: String? = nil,
      sourceUri: String? = nil,
      title: String? = nil,
      imageUri: String? = nil
    ) {
      self.domain = domain
      self.sourceUri = sourceUri
      self.title = title
      self.imageUri = imageUri
    }
    enum CodingKeys: String, CodingKey {
      case domain = "domain"
      case sourceUri = "sourceUri"
      case title = "title"
      case imageUri = "imageUri"
    }
  }
}