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
/// See the [Cloud
/// documentation](https://cloud.google.com/vertex-ai/generative-ai/docs/image/generate-images) for
/// more details about the image generation capabilities offered by the Imagen model.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class ImagenModel {
  /// The resource name of the model in the backend; has the format "models/model-name".
  let modelResourceName: String

  /// The backing service responsible for sending and receiving model requests to the backend.
  let generativeAIService: GenerativeAIService

  let generationConfig: ImagenGenerationConfig?

  let safetySettings: ImagenSafetySettings?

  /// Configuration parameters for sending requests to the backend.
  let requestOptions: RequestOptions

  init(name: String,
       projectID: String,
       apiKey: String,
       generationConfig: ImagenGenerationConfig?,
       safetySettings: ImagenSafetySettings?,
       requestOptions: RequestOptions,
       appCheck: AppCheckInterop?,
       auth: AuthInterop?,
       urlSession: URLSession = .shared) {
    modelResourceName = name
    generativeAIService = GenerativeAIService(
      projectID: projectID,
      apiKey: apiKey,
      appCheck: appCheck,
      auth: auth,
      urlSession: urlSession
    )
    self.generationConfig = generationConfig
    self.safetySettings = safetySettings
    self.requestOptions = requestOptions
  }

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

  public func generateImages(prompt: String, gcsUri: String) async throws
    -> ImagenGenerationResponse<ImagenGCSImage> {
    return try await generateImages(
      prompt: prompt,
      parameters: ImagenModel.imageGenerationParameters(
        storageURI: gcsUri,
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
      includeResponsibleAIFilterReason: true
    )
  }
}
