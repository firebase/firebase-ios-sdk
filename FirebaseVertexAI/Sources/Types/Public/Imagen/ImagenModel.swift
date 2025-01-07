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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class ImagenModel {
  /// The resource name of the model in the backend; has the format "models/model-name".
  let modelResourceName: String

  /// The backing service responsible for sending and receiving model requests to the backend.
  let generativeAIService: GenerativeAIService

  let modelConfig: ImagenModelConfig?

  let safetySettings: ImagenSafetySettings?

  /// Configuration parameters for sending requests to the backend.
  let requestOptions: RequestOptions

  init(name: String,
       projectID: String,
       apiKey: String,
       modelConfig: ImagenModelConfig?,
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
    self.modelConfig = modelConfig
    self.safetySettings = safetySettings
    self.requestOptions = requestOptions
  }

  public func generateImages(prompt: String,
                             generationConfig: ImagenGenerationConfig? = nil) async throws
    -> ImageGenerationResponse<ImagenInlineDataImage> {
    return try await generateImages(
      prompt: prompt,
      parameters: ImagenModel.imageGenerationParameters(
        storageURI: nil,
        generationConfig: generationConfig,
        modelConfig: modelConfig,
        safetySettings: safetySettings
      )
    )
  }

  public func generateImages(prompt: String, storageURI: String,
                             generationConfig: ImagenGenerationConfig? = nil) async throws
    -> ImageGenerationResponse<ImagenFileDataImage> {
    return try await generateImages(
      prompt: prompt,
      parameters: ImagenModel.imageGenerationParameters(
        storageURI: storageURI,
        generationConfig: generationConfig,
        modelConfig: modelConfig,
        safetySettings: safetySettings
      )
    )
  }

  func generateImages<T: Decodable>(prompt: String,
                                    parameters: ImageGenerationParameters) async throws
    -> ImageGenerationResponse<T> {
    let request = ImageGenerationRequest<T>(
      model: modelResourceName,
      options: requestOptions,
      instances: [ImageGenerationInstance(prompt: prompt)],
      parameters: parameters
    )

    return try await generativeAIService.loadRequest(request: request)
  }

  static func imageGenerationParameters(storageURI: String?,
                                        generationConfig: ImagenGenerationConfig?,
                                        modelConfig: ImagenModelConfig?,
                                        safetySettings: ImagenSafetySettings?)
    -> ImageGenerationParameters {
    return ImageGenerationParameters(
      sampleCount: generationConfig?.numberOfImages ?? 1,
      storageURI: storageURI,
      negativePrompt: generationConfig?.negativePrompt,
      aspectRatio: generationConfig?.aspectRatio?.rawValue,
      safetyFilterLevel: safetySettings?.safetyFilterLevel?.rawValue,
      personGeneration: safetySettings?.personFilterLevel?.rawValue,
      outputOptions: modelConfig?.imageFormat.map {
        ImageGenerationOutputOptions(
          mimeType: $0.mimeType,
          compressionQuality: $0.compressionQuality
        )
      },
      addWatermark: modelConfig?.addWatermark,
      includeResponsibleAIFilterReason: true
    )
  }
}
