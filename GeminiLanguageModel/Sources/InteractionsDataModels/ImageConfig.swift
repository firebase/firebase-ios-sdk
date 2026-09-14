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

/// The configuration for image interaction.
@available(*, deprecated)
package struct ImageConfig: Codable, Sendable, Equatable, Hashable {

  package let aspectRatio: AspectRatio?

  package let imageSize: ImageSize?

  /// Creates a new `ImageConfig`.
  ///
  /// - Parameters:
  ///   - aspectRatio: For more details, see ``aspectRatio``.
  ///   - imageSize: For more details, see ``imageSize``.
  package init(
    aspectRatio: AspectRatio? = nil,
    imageSize: ImageSize? = nil
  ) {
    self.aspectRatio = aspectRatio
    self.imageSize = imageSize
  }
  enum CodingKeys: String, CodingKey {
    case aspectRatio = "aspect_ratio"
    case imageSize = "image_size"
  }
}
