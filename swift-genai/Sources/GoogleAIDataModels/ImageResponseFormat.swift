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
  /// Configuration for image output format.
  package struct ImageResponseFormat: Codable, Sendable, Equatable, Hashable {
    /// Optional. The aspect ratio for the image output.
    package var aspectRatio: AspectRatio?
    
    /// Optional. The delivery mode for the image output.
    package var delivery: Delivery?
    
    /// Optional. The size of the image output.
    package var imageSize: ImageSize?
    
    /// Optional. The MIME type of the image output.
    package var mimeType: MimeType?
    
    /// Creates a new `ImageResponseFormat`.
    package init(
      aspectRatio: AspectRatio? = nil,
      delivery: Delivery? = nil,
      imageSize: ImageSize? = nil,
      mimeType: MimeType? = nil
    ) {
      self.aspectRatio = aspectRatio
      self.delivery = delivery
      self.imageSize = imageSize
      self.mimeType = mimeType
    }
    enum CodingKeys: String, CodingKey {
      case aspectRatio = "aspectRatio"
      case delivery = "delivery"
      case imageSize = "imageSize"
      case mimeType = "mimeType"
    }
  }
}