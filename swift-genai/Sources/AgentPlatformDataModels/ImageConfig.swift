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


extension AgentPlatform {
  /// Configuration for image generation. This message allows you to control various aspects of image generation, such as the output format, aspect ratio, and whether the model can generate images of people.
  public struct ImageConfig: Codable, Sendable, Equatable, Hashable {
    /// Optional. The desired aspect ratio for the generated images. The following aspect ratios are supported: "1:1" "2:3", "3:2" "3:4", "4:3" "4:5", "5:4" "9:16", "16:9" "21:9"
    public var aspectRatio: String?
    
    /// Optional. The image output format for generated images.
    public var imageOutputOptions: ImageConfigImageOutputOptions?
    
    /// Optional. Specifies the size of generated images. Supported values are `1K`, `2K`, `4K`. If not specified, the model will use default value `1K`.
    public var imageSize: String?
    
    /// Optional. Controls whether the model can generate people.
    public var personGeneration: PersonGeneration?
    
    /// Optional. Controls whether prominent people (celebrities) generation is allowed. If used with personGeneration, personGeneration enum would take precedence. For instance, if ALLOW_NONE is set, all person generation would be blocked. If this field is unspecified, the default behavior is to allow prominent people.
    public var prominentPeople: ProminentPeople?
    
    /// Creates a new `ImageConfig`.
    public init(
      aspectRatio: String? = nil,
      imageOutputOptions: ImageConfigImageOutputOptions? = nil,
      imageSize: String? = nil,
      personGeneration: PersonGeneration? = nil,
      prominentPeople: ProminentPeople? = nil
    ) {
      self.aspectRatio = aspectRatio
      self.imageOutputOptions = imageOutputOptions
      self.imageSize = imageSize
      self.personGeneration = personGeneration
      self.prominentPeople = prominentPeople
    }
    enum CodingKeys: String, CodingKey {
      case aspectRatio = "aspectRatio"
      case imageOutputOptions = "imageOutputOptions"
      case imageSize = "imageSize"
      case personGeneration = "personGeneration"
      case prominentPeople = "prominentPeople"
    }
  }
}