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
  /// An internal data model for `ImageConfig`.
  /// 
  /// ### Gemini Developer API
  /// 
  /// Type: `GoogleAiGenerativelanguageV1betaImageConfig`
  /// 
  /// Config for image generation features.
  /// 
  /// ### Gemini Enterprise Agent Platform
  /// 
  /// Type: `GoogleCloudAiplatformV1beta1ImageConfig`
  /// 
  /// Configuration for image generation.
  /// 
  /// This message allows you to control various aspects of image generation, such
  /// as the output format, aspect ratio, and whether the model can generate
  /// images of people.
  package struct ImageConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The aspect ratio of the image to generate. Supported aspect ratios: `1:1`,
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. The aspect ratio of the image to generate. Supported aspect ratios: `1:1`,
    /// `1:4`, `4:1`, `1:8`, `8:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`,
    /// `9:16`, `16:9`, or `21:9`.
    /// 
    /// If not specified, the model will choose a default aspect ratio based on any
    /// reference images provided.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The desired aspect ratio for the generated images. The following
    /// aspect ratios are supported:
    /// 
    /// "1:1"
    /// "2:3", "3:2"
    /// "3:4", "4:3"
    /// "4:5", "5:4"
    /// "9:16", "16:9"
    /// "21:9"
    package let aspectRatio: String?
    
    /// Optional. Specifies the size of generated images. Supported values are `512`, `1K`,
    /// 
    /// ### Gemini Developer API
    /// 
    /// Optional. Specifies the size of generated images. Supported values are `512`, `1K`,
    /// `2K`, `4K`. If not specified, the model will use default value `1K`.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Specifies the size of generated images. Supported values are `1K`, `2K`,
    /// `4K`. If not specified, the model will use default value `1K`.
    package let imageSize: String?
    
    /// Optional. The image output format for generated images.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. The image output format for generated images.
    package let imageOutputOptions: ImageConfigImageOutputOptions?
    
    /// Optional. Controls whether the model can generate people.
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Controls whether the model can generate people.
    package let personGeneration: PersonGeneration?
    
    /// Optional. Controls whether prominent people (celebrities) generation is allowed. If
    /// 
    /// ### Gemini Developer API
    /// 
    /// > Important: This property is not supported in the Gemini Developer API.
    /// 
    /// ### Gemini Enterprise Agent Platform
    /// 
    /// Optional. Controls whether prominent people (celebrities) generation is allowed. If
    /// used with personGeneration, personGeneration enum would take precedence.
    /// For instance, if ALLOW_NONE is set, all person generation would be blocked.
    /// If this field is unspecified, the default behavior is to allow prominent
    /// people.
    package let prominentPeople: ProminentPeople?
    

    /// Creates a new `ImageConfig`.
    ///
    /// - Parameters:
    ///   - aspectRatio: Optional. The aspect ratio of the image to generate. Supported aspect ratios: `1:1`, (behavior varies by backend). For more details, see ``aspectRatio``.
    ///   - imageSize: Optional. Specifies the size of generated images. Supported values are `512`, `1K`, (behavior varies by backend). For more details, see ``imageSize``.
    ///   - imageOutputOptions: Optional. The image output format for generated images. (Gemini Enterprise Agent Platform only). For more details, see ``imageOutputOptions``.
    ///   - personGeneration: Optional. Controls whether the model can generate people. (Gemini Enterprise Agent Platform only). For more details, see ``personGeneration``.
    ///   - prominentPeople: Optional. Controls whether prominent people (celebrities) generation is allowed. If (Gemini Enterprise Agent Platform only). For more details, see ``prominentPeople``.
    package init(
      aspectRatio: String? = nil,
      imageSize: String? = nil,
      imageOutputOptions: ImageConfigImageOutputOptions? = nil,
      personGeneration: PersonGeneration? = nil,
      prominentPeople: ProminentPeople? = nil
    ) {
      self.aspectRatio = aspectRatio
      self.imageSize = imageSize
      self.imageOutputOptions = imageOutputOptions
      self.personGeneration = personGeneration
      self.prominentPeople = prominentPeople
    }
    enum CodingKeys: String, CodingKey {
      case aspectRatio = "aspectRatio"
      case imageSize = "imageSize"
      case imageOutputOptions = "imageOutputOptions"
      case personGeneration = "personGeneration"
      case prominentPeople = "prominentPeople"
    }
  }
}