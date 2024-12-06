import FirebaseAppCheckInterop
import FirebaseAuthInterop
import Foundation

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class ImagenModel {
  /// The resource name of the model in the backend; has the format "models/model-name".
  let modelResourceName: String

  /// The backing service responsible for sending and receiving model requests to the backend.
  let generativeAIService: GenerativeAIService

  /// Configuration parameters for sending requests to the backend.
  let requestOptions: RequestOptions

  init(name: String,
       projectID: String,
       apiKey: String,
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
    self.requestOptions = requestOptions
  }

  public func generateImages(prompt: String) async throws
    -> ImageGenerationResponse<ImagenInlineDataImage> {
    return try await generateImages(
      prompt: prompt,
      parameters: imageGenerationParameters(storageURI: nil)
    )
  }

  public func generateImages(prompt: String, storageURI: String) async throws
    -> ImageGenerationResponse<ImagenFileDataImage> {
    return try await generateImages(
      prompt: prompt,
      parameters: imageGenerationParameters(storageURI: storageURI)
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

  func imageGenerationParameters(storageURI: String?) -> ImageGenerationParameters {
    // TODO(#14221): Add support for configuring these parameters.
    return ImageGenerationParameters(
      sampleCount: 1,
      storageURI: storageURI,
      seed: nil,
      negativePrompt: nil,
      aspectRatio: nil,
      safetyFilterLevel: nil,
      personGeneration: nil,
      outputOptions: nil,
      addWatermark: nil,
      includeResponsibleAIFilterReason: true
    )
  }
}
