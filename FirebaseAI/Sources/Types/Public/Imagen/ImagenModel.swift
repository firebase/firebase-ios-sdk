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

import FirebaseAppCheckInterop
import FirebaseAuthInterop
import Foundation

/// Represents a remote Imagen model with the ability to generate images using text prompts.
///
/// See the [generate images
/// documentation](https://firebase.google.com/docs/vertex-ai/generate-images-imagen?platform=ios)
/// for more details about the image generation capabilities offered by the Imagen model in the
/// Firebase AI SDK SDK.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class ImagenModel {
  /// Model name prefix to identify Imagen models.
  static let imagenModelNamePrefix = "imagen-"

  /// The resource name of the model in the backend; has the format "models/model-name".
  let modelResourceName: String

  /// Configuration for the backend API used by this model.
  let apiConfig: APIConfig

  /// The backing service responsible for sending and receiving model requests to the backend.
  let generativeAIService: GenerativeAIService

  let generationConfig: ImagenGenerationConfig?

  let safetySettings: ImagenSafetySettings?

  /// Configuration parameters for sending requests to the backend.
  let requestOptions: RequestOptions

  init(modelResourceName: String,
       firebaseInfo: FirebaseInfo,
       apiConfig: APIConfig,
       generationConfig: ImagenGenerationConfig?,
       safetySettings: ImagenSafetySettings?,
       requestOptions: RequestOptions,
       urlSession: URLSession = GenAIURLSession.default) {
    self.modelResourceName = modelResourceName
    self.apiConfig = apiConfig
    generativeAIService = GenerativeAIService(
      firebaseInfo: firebaseInfo,
      urlSession: urlSession
    )
    self.generationConfig = generationConfig
    self.safetySettings = safetySettings
    self.requestOptions = requestOptions
  }

  /// Generates images using the Imagen model and returns them as inline data.
  ///
  /// The individual ``ImagenInlineImage/data`` is provided for each of the generated
  /// ``ImagenGenerationResponse/images``.
  ///
  /// > Note: By default, 1 image sample is generated; see ``ImagenGenerationConfig/numberOfImages``
  /// to configure the number of images that are generated.
  ///
  /// - Parameters:
  ///   - prompt: A text prompt describing the image(s) to generate.
  public func generateImages(prompt: String) async throws
    -> ImagenGenerationResponse<ImagenInlineImage> {
    return try await generateImages(
      prompt: prompt,
      parameters: ImagenModel.imageGenerationParameters(
        storageURI: nil,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
    )
  }

  /// Generates images using the Imagen model and stores them in Cloud Storage (GCS) for Firebase.
  ///
  /// The generated images are stored in a subdirectory of the requested `gcsURI`, named as a random
  /// numeric hash. For example, for the `gcsURI` `"gs://bucket-name/path/"`, the generated images
  /// are stored in `"gs://bucket-name/path/1234567890123/"` with the names `sample_0.png`,
  /// `sample_1.png`, `sample_2.png`, ..., `sample_N.png`. In this example, `1234567890123` is the
  /// hash value and `N` is the number of images that were generated, up to the number requested in
  /// ``ImagenGenerationConfig/numberOfImages``. The individual ``ImagenGCSImage/gcsURI`` is
  /// provided for each of the generated ``ImagenGenerationResponse/images``.
  ///
  /// > Note: By default, 1 image sample is generated; see ``ImagenGenerationConfig/numberOfImages``
  /// to configure the number of images that are generated.
  ///
  /// - Parameters:
  ///   - prompt: A text prompt describing the image(s) to generate.
  ///   - gcsURI: The Cloud Storage (GCS) for Firebase URI where the generated images are stored.
  ///     This is a `"gs://"`-prefixed URI , for example, `"gs://bucket-name/path/"`.
  ///
  /// TODO(#14451): Make this `public` when backend support is ready.
  func generateImages(prompt: String, gcsURI: String) async throws
    -> ImagenGenerationResponse<ImagenGCSImage> {
    return try await generateImages(
      prompt: prompt,
      parameters: ImagenModel.imageGenerationParameters(
        storageURI: gcsURI,
        generationConfig: generationConfig,
        safetySettings: safetySettings
      )
    )
  }

  func generateImages<T>(prompt: String,
                         parameters: ImageGenerationParameters) async throws
    -> ImagenGenerationResponse<T> where T: Decodable, T: ImagenImageRepresentable {
    let request = ImagenGenerationRequest<T>(
      model: modelResourceName,
      apiConfig: apiConfig,
      options: requestOptions,
      instances: [ImageGenerationInstance(prompt: prompt)],
      parameters: parameters
    )

    return try await generativeAIService.loadRequest(request: request)
  }

  static func imageGenerationParameters(storageURI: String?,
                                        generationConfig: ImagenGenerationConfig?,
                                        safetySettings: ImagenSafetySettings?)
    -> ImageGenerationParameters {
    return ImageGenerationParameters(
      sampleCount: generationConfig?.numberOfImages ?? 1,
      storageURI: storageURI,
      negativePrompt: generationConfig?.negativePrompt,
      aspectRatio: generationConfig?.aspectRatio?.rawValue,
      safetyFilterLevel: safetySettings?.safetyFilterLevel?.rawValue,
      personGeneration: safetySettings?.personFilterLevel?.rawValue,
      outputOptions: generationConfig?.imageFormat.map {
        ImageGenerationOutputOptions(
          mimeType: $0.mimeType,
          compressionQuality: $0.compressionQuality
        )
      },
      addWatermark: generationConfig?.addWatermark,
      includeResponsibleAIFilterReason: true,
      includeSafetyAttributes: true
    )
  }
}
