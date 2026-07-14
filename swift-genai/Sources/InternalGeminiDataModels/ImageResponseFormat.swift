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
  /// Configuration for image output format.
  /// 
  /// Variant:
  /// Configuration for image-specific output formatting.
  package struct ImageResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. The MIME type of the image output.
    package let mimeType: MimeType?
    
    /// Optional. The aspect ratio for the image output.
    package let aspectRatio: AspectRatio?
    
    /// Optional. The delivery mode for the image output.
    /// 
    /// Variant:
    /// Optional. Delivery mode for the generated content.
    package let delivery: Delivery?
    
    /// Optional. The size of the image output.
    package let imageSize: ImageSize?
    
    /// Creates a new `ImageResponseFormat`.
    package init(
      mimeType: MimeType? = nil,
      aspectRatio: AspectRatio? = nil,
      delivery: Delivery? = nil,
      imageSize: ImageSize? = nil
    ) {
      self.mimeType = mimeType
      self.aspectRatio = aspectRatio
      self.delivery = delivery
      self.imageSize = imageSize
    }
    enum CodingKeys: String, CodingKey {
      case mimeType = "mimeType"
      case aspectRatio = "aspectRatio"
      case delivery = "delivery"
      case imageSize = "imageSize"
    }
  }
}