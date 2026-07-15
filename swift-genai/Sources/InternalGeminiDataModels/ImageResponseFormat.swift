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
  /// An internal data model for `ImageResponseFormat`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaImageResponseFormat`
  /// 
  /// Configuration for image output format.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ImageResponseFormat`
  /// 
  /// Configuration for image-specific output formatting.
  package struct ImageResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. The MIME type of the image output.
    package let mimeType: MimeType?
    
    /// Optional. The delivery mode for the image output.
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The delivery mode for the image output.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Delivery mode for the generated content.
    package let delivery: Delivery?
    
    /// Optional. The aspect ratio for the image output.
    package let aspectRatio: AspectRatio?
    
    /// Optional. The size of the image output.
    package let imageSize: ImageSize?
    

    /// Creates a new `ImageResponseFormat`.
    ///
    /// - Parameters:
    ///   - mimeType: Optional. The MIME type of the image output.
    ///   - delivery: Optional. The delivery mode for the image output. (behavior varies by backend). For more details, see ``delivery``.
    ///   - aspectRatio: Optional. The aspect ratio for the image output.
    ///   - imageSize: Optional. The size of the image output.
    package init(
      mimeType: MimeType? = nil,
      delivery: Delivery? = nil,
      aspectRatio: AspectRatio? = nil,
      imageSize: ImageSize? = nil
    ) {
      self.mimeType = mimeType
      self.delivery = delivery
      self.aspectRatio = aspectRatio
      self.imageSize = imageSize
    }
    enum CodingKeys: String, CodingKey {
      case mimeType = "mimeType"
      case delivery = "delivery"
      case aspectRatio = "aspectRatio"
      case imageSize = "imageSize"
    }
  }
}