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
import FirebaseCore
import Foundation

// Avoids exposing internal FirebaseCore APIs to Swift users.
internal import FirebaseCoreExtension

/// The Firebase AI SDK provides access to Gemini models directly from your app.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public final class FirebaseAI: Sendable {
  // MARK: - Public APIs

  /// Creates an instance of `FirebaseAI`.
  ///
  /// - Parameters:
  ///   - app: A custom `FirebaseApp` used for initialization; if not specified, uses the default
  ///     ``FirebaseApp``.
  ///   - backend: The backend API for the Firebase AI SDK; if not specified, uses the default
  ///     ``Backend/googleAI()`` (Gemini Developer API).
  ///   - useLimitedUseAppCheckTokens: When sending tokens to the backend, this option enables
  ///     the usage of App Check's limited-use tokens instead of the standard cached tokens. Learn
  ///     more about [limited-use tokens](https://firebase.google.com/docs/ai-logic/app-check),
  ///     including their nuances, when to use them, and best practices for integrating them into
  ///     your app.
  ///
  ///     _This flag is set to `false` by default._
  ///   > Migrating to limited-use tokens sooner minimizes disruption when support for replay
  ///   > protection is added.
  /// - Returns: A `FirebaseAI` instance, configured with the custom `FirebaseApp`.
  public static func firebaseAI(app: FirebaseApp? = nil,
                                backend: Backend = .googleAI(),
                                useLimitedUseAppCheckTokens: Bool = false) -> FirebaseAI {
    let instance = createInstance(
      app: app,
      apiConfig: backend.apiConfig,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
    )
    // Verify that the `FirebaseAI` instance is always configured with the production endpoint since
    // this is the public API surface for creating an instance.
    assert(instance.apiConfig.service.endpoint == .firebaseProxyProd)
    assert(instance.apiConfig.version == .v1beta)
    return instance
  }

  /// Initializes a generative model with the given parameters.
  ///
  /// - Note: Refer to [Gemini models](https://firebase.google.com/docs/vertex-ai/gemini-models) for
  /// guidance on choosing an appropriate model for your use case.
  ///
  /// - Parameters:
  ///   - modelName: The name of the model to use; see
  ///     [available model names
  ///     ](https://firebase.google.com/docs/vertex-ai/gemini-models#available-model-names) for a
  ///     list of supported model names.
  ///   - generationConfig: The content generation parameters your model should use.
  ///   - safetySettings: A value describing what types of harmful content your model should allow.
  ///   - tools: A list of ``Tool`` objects that the model may use to generate the next response.
  ///   - toolConfig: Tool configuration for any `Tool` specified in the request.
  ///   - systemInstruction: Instructions that direct the model to behave a certain way; currently
  ///     only text content is supported.
  ///   - requestOptions: Configuration parameters for sending requests to the backend.
  public func generativeModel(modelName: String,
                              generationConfig: GenerationConfig? = nil,
                              safetySettings: [SafetySetting]? = nil,
                              tools: [Tool]? = nil,
                              toolConfig: ToolConfig? = nil,
                              systemInstruction: ModelContent? = nil,
                              requestOptions: RequestOptions = RequestOptions())
    -> GenerativeModel {
    if !modelName.starts(with: GenerativeModel.geminiModelNamePrefix)
      && !modelName.starts(with: GenerativeModel.gemmaModelNamePrefix) {
      AILog.warning(code: .unsupportedGeminiModel, """
      Unsupported Gemini model "\(modelName)"; see \
      https://firebase.google.com/docs/vertex-ai/models for a list supported Gemini model names.
      """)
    }

    return GenerativeModel(
      modelName: modelName,
      modelResourceName: modelResourceName(modelName: modelName),
      firebaseInfo: firebaseInfo,
      apiConfig: apiConfig,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      tools: tools,
      toolConfig: toolConfig,
      systemInstruction: systemInstruction,
      requestOptions: requestOptions
    )
  }

  /// Initializes an ``ImagenModel`` with the given parameters.
  ///
  /// - Note: Refer to [Imagen models](https://firebase.google.com/docs/vertex-ai/models) for
  /// guidance on choosing an appropriate model for your use case.
  ///
  /// - Parameters:
  ///   - modelName: The name of the Imagen 3 model to use.
  ///   - generationConfig: Configuration options for generating images with Imagen.
  ///   - safetySettings: Settings describing what types of potentially harmful content your model
  ///     should allow.
  ///   - requestOptions: Configuration parameters for sending requests to the backend.
  public func imagenModel(modelName: String, generationConfig: ImagenGenerationConfig? = nil,
                          safetySettings: ImagenSafetySettings? = nil,
                          requestOptions: RequestOptions = RequestOptions()) -> ImagenModel {
    if !modelName.starts(with: ImagenModel.imagenModelNamePrefix) {
      AILog.warning(code: .unsupportedImagenModel, """
      Unsupported Imagen model "\(modelName)"; see \
      https://firebase.google.com/docs/vertex-ai/models for a list supported Imagen model names.
      """)
    }

    return ImagenModel(
      modelResourceName: modelResourceName(modelName: modelName),
      firebaseInfo: firebaseInfo,
      apiConfig: apiConfig,
      generationConfig: generationConfig,
      safetySettings: safetySettings,
      requestOptions: requestOptions
    )
  }

  /// **[Public Preview]** Initializes a ``LiveGenerativeModel`` with the given parameters.
  ///
  /// - Note: Refer to [the Firebase docs on the Live
  /// API](https://firebase.google.com/docs/ai-logic/live-api#models-that-support-capability) for
  /// guidance on choosing an appropriate model for your use case.
  ///
  /// > Warning: Using the Firebase AI Logic SDKs with the Gemini Live API is in Public
  /// Preview, which means that the feature is not subject to any SLA or deprecation policy and
  /// could change in backwards-incompatible ways.
  ///
  /// - Parameters:
  ///   - modelName: The name of the model to use.
  ///   - generationConfig: The content generation parameters your model should use.
  ///   - tools: A list of ``Tool`` objects that the model may use to generate the next response.
  ///   - toolConfig: Tool configuration for any ``Tool`` specified in the request.
  ///   - systemInstruction: Instructions that direct the model to behave a certain way; currently
  ///     only text content is supported.
  ///   - requestOptions: Configuration parameters for sending requests to the backend.
  @available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, *)
  @available(watchOS, unavailable)
  public func liveModel(modelName: String,
                        generationConfig: LiveGenerationConfig? = nil,
                        tools: [Tool]? = nil,
                        toolConfig: ToolConfig? = nil,
                        systemInstruction: ModelContent? = nil,
                        requestOptions: RequestOptions = RequestOptions()) -> LiveGenerativeModel {
    return LiveGenerativeModel(
      modelResourceName: modelResourceName(modelName: modelName),
      firebaseInfo: firebaseInfo,
      apiConfig: apiConfig,
      generationConfig: generationConfig,
      tools: tools,
      toolConfig: toolConfig,
      systemInstruction: systemInstruction,
      requestOptions: requestOptions
    )
  }

  /// Class to enable FirebaseAI to register via the Objective-C based Firebase component system
  /// to include FirebaseAI in the userAgent.
  @objc(FIRVertexAIComponent) class FirebaseVertexAIComponent: NSObject {}

  // MARK: - Private

  /// Firebase data relevant to Firebase AI.
  let firebaseInfo: FirebaseInfo

  let apiConfig: APIConfig

  /// A map of active `FirebaseAI` instances keyed by the `FirebaseApp`,  the `APIConfig`, and
  /// `useLimitedUseAppCheckTokens`.
  private nonisolated(unsafe) static var instances: [InstanceKey: FirebaseAI] = [:]

  /// Lock to manage access to the `instances` array to avoid race conditions.
  private nonisolated(unsafe) static var instancesLock: os_unfair_lock = .init()

  static func createInstance(app: FirebaseApp?,
                             apiConfig: APIConfig,
                             useLimitedUseAppCheckTokens: Bool) -> FirebaseAI {
    guard let app = app ?? FirebaseApp.app() else {
      fatalError("No instance of the default Firebase app was found.")
    }

    os_unfair_lock_lock(&instancesLock)

    // Unlock before the function returns.
    defer { os_unfair_lock_unlock(&instancesLock) }

    let instanceKey = InstanceKey(
      appName: app.name,
      apiConfig: apiConfig,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
    )
    if let instance = instances[instanceKey] {
      return instance
    }
    let newInstance = FirebaseAI(
      app: app,
      apiConfig: apiConfig,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
    )
    instances[instanceKey] = newInstance
    return newInstance
  }

  init(app: FirebaseApp, apiConfig: APIConfig,
       useLimitedUseAppCheckTokens: Bool) {
    guard let projectID = app.options.projectID else {
      fatalError("The Firebase app named \"\(app.name)\" has no project ID in its configuration.")
    }
    guard let apiKey = app.options.apiKey else {
      fatalError("The Firebase app named \"\(app.name)\" has no API key in its configuration.")
    }
    firebaseInfo = FirebaseInfo(
      appCheck: ComponentType<AppCheckInterop>.instance(
        for: AppCheckInterop.self,
        in: app.container
      ),
      auth: ComponentType<AuthInterop>.instance(for: AuthInterop.self, in: app.container),
      projectID: projectID,
      apiKey: apiKey,
      firebaseAppID: app.options.googleAppID,
      firebaseApp: app,
      useLimitedUseAppCheckTokens: useLimitedUseAppCheckTokens
    )
    self.apiConfig = apiConfig
  }

  func modelResourceName(modelName: String) -> String {
    guard !modelName.isEmpty && modelName
      .allSatisfy({ !$0.isWhitespace && !$0.isNewline && $0 != "/" }) else {
      fatalError("""
      Invalid model name "\(modelName)" specified; see \
      https://firebase.google.com/docs/vertex-ai/gemini-model#available-models for a list of \
      available models.
      """)
    }

    switch apiConfig.service {
    case let .vertexAI(endpoint: _, location: location):
      return vertexAIModelResourceName(modelName: modelName, location: location)
    case .googleAI:
      return developerModelResourceName(modelName: modelName)
    }
  }

  private func vertexAIModelResourceName(modelName: String, location: String) -> String {
    guard !location.isEmpty && location
      .allSatisfy({ !$0.isWhitespace && !$0.isNewline && $0 != "/" }) else {
      fatalError("""
      Invalid location "\(location)" specified; see \
      https://firebase.google.com/docs/vertex-ai/locations?platform=ios#available-locations \
      for a list of available locations.
      """)
    }

    let projectID = firebaseInfo.projectID
    return "projects/\(projectID)/locations/\(location)/publishers/google/models/\(modelName)"
  }

  private func developerModelResourceName(modelName: String) -> String {
    switch apiConfig.service.endpoint {
    case .firebaseProxyStaging, .firebaseProxyProd:
      let projectID = firebaseInfo.projectID
      return "projects/\(projectID)/models/\(modelName)"
    case .googleAIBypassProxy:
      return "models/\(modelName)"
    }
  }

  /// Identifier for a unique instance of ``FirebaseAI``.
  ///
  /// This type is `Hashable` so that it can be used as a key in the `instances` dictionary.
  private struct InstanceKey: Sendable, Hashable {
    let appName: String
    let apiConfig: APIConfig
    let useLimitedUseAppCheckTokens: Bool
  }
}
