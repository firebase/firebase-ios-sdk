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
  /// Config for image generation features.
  /// 
  /// Variant:
  /// Configuration for image generation. This message allows you to control various aspects of image generation, such as the output format, aspect ratio, and whether the model can generate images of people.
  package struct ImageConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The aspect ratio of the image to generate. Supported aspect ratios: `1:1`, `1:4`, `4:1`, `1:8`, `8:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, or `21:9`. If not specified, the model will choose a default aspect ratio based on any reference images provided.
    /// 
    /// Variant:
    /// Optional. The desired aspect ratio for the generated images. The following aspect ratios are supported: "1:1" "2:3", "3:2" "3:4", "4:3" "4:5", "5:4" "9:16", "16:9" "21:9"
    package let aspectRatio: String?
    
    /// Optional. Controls whether the model can generate people.
    /// 
    /// > Important: `personGeneration` is only available in the Gemini Enterprise Agent Platform.
    package let personGeneration: PersonGeneration?
    
    /// Optional. Controls whether prominent people (celebrities) generation is allowed. If used with personGeneration, personGeneration enum would take precedence. For instance, if ALLOW_NONE is set, all person generation would be blocked. If this field is unspecified, the default behavior is to allow prominent people.
    /// 
    /// > Important: `prominentPeople` is only available in the Gemini Enterprise Agent Platform.
    package let prominentPeople: ProminentPeople?
    
    /// Optional. The image output format for generated images.
    /// 
    /// > Important: `imageOutputOptions` is only available in the Gemini Enterprise Agent Platform.
    package let imageOutputOptions: ImageConfigImageOutputOptions?
    
    /// Optional. Specifies the size of generated images. Supported values are `512`, `1K`, `2K`, `4K`. If not specified, the model will use default value `1K`.
    /// 
    /// Variant:
    /// Optional. Specifies the size of generated images. Supported values are `1K`, `2K`, `4K`. If not specified, the model will use default value `1K`.
    package let imageSize: String?
    
    /// Creates a new `ImageConfig`.
    package init(
      aspectRatio: String? = nil,
      personGeneration: PersonGeneration? = nil,
      prominentPeople: ProminentPeople? = nil,
      imageOutputOptions: ImageConfigImageOutputOptions? = nil,
      imageSize: String? = nil
    ) {
      self.aspectRatio = aspectRatio
      self.personGeneration = personGeneration
      self.prominentPeople = prominentPeople
      self.imageOutputOptions = imageOutputOptions
      self.imageSize = imageSize
    }
    enum CodingKeys: String, CodingKey {
      case aspectRatio = "aspectRatio"
      case personGeneration = "personGeneration"
      case prominentPeople = "prominentPeople"
      case imageOutputOptions = "imageOutputOptions"
      case imageSize = "imageSize"
    }
  }
}