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
  /// Chunk from image search.
  package struct Image: Codable, Sendable, Equatable, Hashable {
    /// The root domain of the web page that the image is from, e.g. "example.com".
    package var domain: String?
    
    /// The image asset URL.
    package var imageUri: String?
    
    /// The web page URI for attribution.
    package var sourceUri: String?
    
    /// The title of the web page that the image is from.
    package var title: String?
    
    /// Creates a new `Image`.
    package init(
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