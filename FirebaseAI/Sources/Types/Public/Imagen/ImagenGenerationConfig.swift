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

/// Configuration options for generating images with Imagen.
///
/// See [Parameters for Imagen
/// models](https://firebase.google.com/docs/vertex-ai/model-parameters?platform=ios#imagen) to
/// learn about parameters available for use with Imagen models, including how to configure them.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImagenGenerationConfig {
  /// Specifies elements to exclude from the generated image.
  ///
  /// Defaults to `nil`, which disables negative prompting. Use a comma-separated list to describe
  /// unwanted elements or characteristics. See the [Cloud
  /// documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/image/generate-images#negative-prompt)
  /// for more details.
  ///
  /// > Important: Support for negative prompts depends on the Imagen model.
  public var negativePrompt: String?

  /// The number of image samples to generate; defaults to 1 if not specified.
  ///
  /// > Important: The number of sample images that may be generated in each request depends on the
  ///   model (typically up to 4); see the
  ///   [`sampleCount`](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/imagen-api#parameter_list)
  ///   documentation for more details.
  public var numberOfImages: Int?

  /// The aspect ratio of generated images.
  ///
  /// Defaults to to square, 1:1. Supported aspect ratios depend on the model; see
  /// ``ImagenAspectRatio`` for more details.
  public var aspectRatio: ImagenAspectRatio?

  /// The image format of generated images.
  ///
  /// Defaults to PNG. See ``ImagenImageFormat`` for more details.
  public var imageFormat: ImagenImageFormat?

  /// Whether to add an invisible watermark to generated images.
  ///
  /// If `true`, an invisible SynthID watermark is embedded in generated images to indicate that
  /// they are AI generated; `false` disables watermarking.
  ///
  /// > Important: The default value depends on the model; see the
  ///   [`addWatermark`](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/imagen-api#parameter_list)
  ///   documentation for model-specific details.
  public var addWatermark: Bool?

  /// Initializes configuration options for generating images with Imagen.
  ///
  /// - Parameters:
  ///   - negativePrompt: Specifies elements to exclude from the generated image; disabled if not
  ///     specified. See ``negativePrompt``.
  ///   - numberOfImages: The number of image samples to generate; defaults to 1 if not specified.
  ///     See ``numberOfImages``.
  ///   - aspectRatio: The aspect ratio of generated images; defaults to to square, 1:1. See
  ///     ``aspectRatio``.
  ///   - imageFormat: The image format of generated images; defaults to PNG. See ``imageFormat``.
  ///   - addWatermark: Whether to add an invisible watermark to generated images; the default value
  ///     depends on the model. See ``addWatermark``.
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
