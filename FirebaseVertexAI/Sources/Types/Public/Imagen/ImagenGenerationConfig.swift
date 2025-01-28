// Copyright 2024 Google LLC
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImagenGenerationConfig {
  public var negativePrompt: String?
  public var numberOfImages: Int?
  public var aspectRatio: ImagenAspectRatio?
  public var imageFormat: ImagenImageFormat?
  public var addWatermark: Bool?

  public init(negativePrompt: String? = nil, numberOfImages: Int? = nil,
              aspectRatio: ImagenAspectRatio? = nil, imageFormat: ImagenImageFormat? = nil,
              addWatermark: Bool? = nil) {
    self.numberOfImages = numberOfImages
    self.negativePrompt = negativePrompt
    self.imageFormat = imageFormat
    self.aspectRatio = aspectRatio
    self.addWatermark = addWatermark
  }
}
