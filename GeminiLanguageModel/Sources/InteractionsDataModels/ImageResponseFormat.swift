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

/// Configuration for image output format.
package struct ImageResponseFormat: Codable, Sendable, Equatable, Hashable {

  /// The aspect ratio for the image output.
  package let aspectRatio: AspectRatio?

  /// The delivery mode for the image output.
  package let delivery: Delivery?

  /// The size of the image output.
  package let imageSize: ImageSize?

  /// The MIME type of the image output.
  package let mimeType: String?

  package let type: String?

  /// Creates a new `ImageResponseFormat`.
  ///
  /// - Parameters:
  ///   - aspectRatio: The aspect ratio for the image output.
  ///   - delivery: The delivery mode for the image output.
  ///   - imageSize: The size of the image output.
  package init(
    aspectRatio: AspectRatio? = nil,
    delivery: Delivery? = nil,
    imageSize: ImageSize? = nil
  ) {
    self.aspectRatio = aspectRatio
    self.delivery = delivery
    self.imageSize = imageSize
    self.mimeType = "image/jpeg"
    self.type = "image"
  }
  enum CodingKeys: String, CodingKey {
    case aspectRatio = "aspect_ratio"
    case delivery = "delivery"
    case imageSize = "image_size"
    case mimeType = "mime_type"
    case type = "type"
  }
}
