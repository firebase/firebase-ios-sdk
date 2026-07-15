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
  /// An internal data model for `ImageChunk`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaGroundingChunkImage`
  /// 
  /// Chunk from image search.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1GroundingChunkImage`
  /// 
  /// An `Image` chunk is a piece of evidence that comes from an image search
  /// result. It contains the URI of the image search result and the URI of the
  /// image. This is used to provide the user with a link to the source of the
  /// information.
  package struct ImageChunk: Codable, Sendable, Equatable, Hashable {
    /// The web page URI for attribution.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The web page URI for attribution.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The URI of the image search result page.
    package let sourceUri: String?
    
    /// The image asset URL.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The image asset URL.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The URI of the image.
    package let imageUri: String?
    
    /// The title of the web page that the image is from.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The title of the web page that the image is from.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The title of the image search result page.
    package let title: String?
    
    /// The root domain of the web page that the image is from, e.g.
    /// 
    /// ### Gemini Developer API
    /// 
    /// The root domain of the web page that the image is from, e.g.
    /// "example.com".
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// The domain of the image search result page.
    package let domain: String?
    

    /// Creates a new `ImageChunk`.
    ///
    /// - Parameters:
    ///   - sourceUri: The web page URI for attribution. (behavior varies by backend). For more details, see ``sourceUri``.
    ///   - imageUri: The image asset URL. (behavior varies by backend). For more details, see ``imageUri``.
    ///   - title: The title of the web page that the image is from. (behavior varies by backend). For more details, see ``title``.
    ///   - domain: The root domain of the web page that the image is from, e.g. (behavior varies by backend). For more details, see ``domain``.
    package init(
      sourceUri: String? = nil,
      imageUri: String? = nil,
      title: String? = nil,
      domain: String? = nil
    ) {
      self.sourceUri = sourceUri
      self.imageUri = imageUri
      self.title = title
      self.domain = domain
    }
    enum CodingKeys: String, CodingKey {
      case sourceUri = "sourceUri"
      case imageUri = "imageUri"
      case title = "title"
      case domain = "domain"
    }
  }
}