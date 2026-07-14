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
  /// Config for image generation features.
  public struct ImageConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The aspect ratio of the image to generate. Supported aspect ratios: `1:1`, `1:4`, `4:1`, `1:8`, `8:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, or `21:9`. If not specified, the model will choose a default aspect ratio based on any reference images provided.
    public var aspectRatio: String?
    
    /// Optional. Specifies the size of generated images. Supported values are `512`, `1K`, `2K`, `4K`. If not specified, the model will use default value `1K`.
    public var imageSize: String?
    
    /// Creates a new `ImageConfig`.
    public init(
      aspectRatio: String? = nil,
      imageSize: String? = nil
    ) {
      self.aspectRatio = aspectRatio
      self.imageSize = imageSize
    }
    enum CodingKeys: String, CodingKey {
      case aspectRatio = "aspectRatio"
      case imageSize = "imageSize"
    }
  }
}